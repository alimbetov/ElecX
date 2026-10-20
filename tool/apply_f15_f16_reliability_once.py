from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor missing in {path}: {old[:160]!r}')
    p.write_text(text.replace(old, new, 1))

# F15: recovery publication is generation-aware. A stale in-flight write must
# never resurrect a snapshot after discard/project replacement.
screen = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
replace_once(
    screen,
    '''  bool _autosaveInFlight = false;
  int _lastAutosavedRevision = -1;
''',
    '''  bool _autosaveInFlight = false;
  int _lastAutosavedRevision = -1;
  int _recoveryGeneration = 0;
''',
)
replace_once(
    screen,
    '''    final revision = _projectRevision;
    _autosaveInFlight = true;
    try {
      final document = EditorProjectDocument.capture(
        workspace,
        metadata: _projectMetadata,
      );
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.save(
        EditorProjectRecoverySnapshot(
          capturedAt: DateTime.now().toUtc(),
          revision: revision,
          document: document,
        ),
      );
      _lastAutosavedRevision = revision;
''',
    '''    final revision = _projectRevision;
    final generation = _recoveryGeneration;
    _autosaveInFlight = true;
    try {
      final document = EditorProjectDocument.capture(
        workspace,
        metadata: _projectMetadata,
      );
      final snapshot = EditorProjectRecoverySnapshot(
        capturedAt: DateTime.now().toUtc(),
        revision: revision,
        document: document,
      );
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.save(snapshot);
      if (generation != _recoveryGeneration ||
          snapshot.projectId != _projectMetadata.projectId) {
        await store.discard(snapshot.projectId);
        return;
      }
      _lastAutosavedRevision = revision;
''',
)
replace_once(
    screen,
    '''      if (mounted &&
          _hasUnsavedChanges &&
          _lastAutosavedRevision != _projectRevision) {
        _scheduleAutosave();
      }
''',
    '''      if (mounted &&
          generation == _recoveryGeneration &&
          _hasUnsavedChanges &&
          _lastAutosavedRevision != _projectRevision) {
        _scheduleAutosave();
      }
''',
)
replace_once(
    screen,
    '''  Future<void> _discardRecoveryBestEffort() async {
    _autosaveTimer?.cancel();
    if (!_recoveryEnabled) return;
    try {
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.discard(_projectMetadata.projectId);
      _lastAutosavedRevision = -1;
''',
    '''  Future<void> _discardRecoveryBestEffort() async {
    _autosaveTimer?.cancel();
    final generation = ++_recoveryGeneration;
    if (!_recoveryEnabled) return;
    final projectId = _projectMetadata.projectId;
    try {
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.discard(projectId);
      if (generation == _recoveryGeneration) {
        _lastAutosavedRevision = -1;
      }
''',
)
replace_once(
    screen,
    '''  void _replaceProject(
    RestoredEditorProject restored,
    EditorProjectMetadata metadata, {
''',
    '''  void _replaceProject(
    RestoredEditorProject restored,
    EditorProjectMetadata metadata, {
''',
)
# Add generation invalidation at the first line of _replaceProject body.
replace_once(
    screen,
    '''    int recoveryRevision = 1,
  }) {
    final previousController = controller;
''',
    '''    int recoveryRevision = 1,
  }) {
    _recoveryGeneration++;
    final previousController = controller;
''',
)

# F16: isolate corrupt project files and recover backup-only entries. Preserve
# the existing List API for callers while making listing fail-soft per file.
project_doc = 'lib/src/features/editor/editor_project_document.dart'
replace_once(
    project_doc,
    '''  @override
  Future<List<EditorProjectDocument>> list() async {
    if (!await rootDirectory.exists()) return const [];
    final result = <EditorProjectDocument>[];
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.elecx.json')) continue;
      final raw = jsonDecode(await entity.readAsString());
      if (raw is! Map) {
        throw FormatException(
          'ElecX project ${path.basename(entity.path)} must be a JSON object.',
        );
      }
      final stat = await entity.stat();
      result.add(
        EditorProjectDocument.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)),
          legacyTimestamp: stat.modified.toUtc(),
        ),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<EditorProjectDocument>.unmodifiable(result);
  }
''',
    '''  @override
  Future<List<EditorProjectDocument>> list() async {
    if (!await rootDirectory.exists()) return const [];
    final sourcesByBasePath = <String, File>{};
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final isPrimary = entity.path.endsWith('.elecx.json');
      final isBackup = entity.path.endsWith('.elecx.json.bak');
      if (!isPrimary && !isBackup) continue;
      final basePath = isBackup
          ? entity.path.substring(0, entity.path.length - '.bak'.length)
          : entity.path;
      if (isPrimary) {
        sourcesByBasePath[basePath] = entity;
      } else {
        sourcesByBasePath.putIfAbsent(basePath, () => entity);
      }
    }

    final result = <EditorProjectDocument>[];
    for (final source in sourcesByBasePath.values) {
      try {
        final raw = jsonDecode(await source.readAsString());
        if (raw is! Map) continue;
        final stat = await source.stat();
        result.add(
          EditorProjectDocument.fromJson(
            raw.map((key, value) => MapEntry(key.toString(), value)),
            legacyTimestamp: stat.modified.toUtc(),
          ),
        );
      } on FormatException {
        // One damaged project must not hide every healthy project in the Hub.
        continue;
      } on FileSystemException {
        // A file can disappear between directory enumeration and read.
        continue;
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<EditorProjectDocument>.unmodifiable(result);
  }
''',
)

# Regression tests.
test_path = Path('test/project_recovery_and_save_diagnostics_test.dart')
test = test_path.read_text()
if "import 'dart:async';" not in test:
    test = test.replace("import 'dart:io';\n", "import 'dart:async';\nimport 'dart:io';\n", 1)
if '_DelayedRecoveryStore' not in test:
    marker = 'EditorProjectDocument _invalidCableDocument() {'
    idx = test.find(marker)
    if idx == -1:
        raise SystemExit('recovery test helper anchor missing')
    helper = r'''
final class _DelayedRecoveryStore implements EditorProjectRecoveryStore {
  final Map<String, EditorProjectRecoverySnapshot> snapshots = {};
  final Completer<void> releaseFirstSave = Completer<void>();
  int saves = 0;
  int discards = 0;

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    saves++;
    if (saves == 1) await releaseFirstSave.future;
    snapshots[snapshot.projectId] = snapshot;
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async =>
      snapshots[projectId];

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async =>
      List.unmodifiable(snapshots.values);

  @override
  Future<void> discard(String projectId) async {
    discards++;
    snapshots.remove(projectId);
  }
}

'''
    test = test[:idx] + helper + test[idx:]

case_name = 'in-flight autosave cannot resurrect recovery after explicit Save'
if case_name not in test:
    end = test.rfind('\n}')
    if end == -1:
        raise SystemExit('recovery test main closing brace missing')
    case = r'''

  testWidgets('in-flight autosave cannot resurrect recovery after explicit Save',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recovery = _DelayedRecoveryStore();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projects,
          recoveryStore: recovery,
          autosaveDelay: const Duration(milliseconds: 5),
          initialMetadata: EditorProjectMetadata.create(
            projectName: 'Autosave race',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    expect(recovery.saves, 1);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pump();
    expect(projects.saves, 1);
    expect(recovery.discards, greaterThanOrEqualTo(1));

    recovery.releaseFirstSave.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(recovery.snapshots, isEmpty);
    expect(recovery.discards, greaterThanOrEqualTo(2));
    expect(find.text('Saved'), findsOneWidget);
  });
'''
    test = test[:end] + case + test[end:]
test_path.write_text(test)

persist_path = Path('test/editor_project_persistence_test.dart')
persist = persist_path.read_text()
case_name = 'project listing isolates corrupt files and recovers backup-only project'
if case_name not in persist:
    end = persist.rfind('\n}')
    if end == -1:
        raise SystemExit('persistence test main closing brace missing')
    case = r'''

  test('project listing isolates corrupt files and recovers backup-only project',
      () async {
    final temp = await Directory.systemTemp.createTemp('elecx-listing-');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final controller = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(controller);
    final document = EditorProjectDocument.capture(
      workspace,
      metadata: EditorProjectMetadata.create(projectName: 'Healthy project'),
    );
    final store = JsonFileEditorProjectStore(temp);
    await store.save(document);

    final primary = (await temp.list().where((entity) =>
            entity is File && entity.path.endsWith('.elecx.json')).first)
        as File;
    final backup = File('${primary.path}.bak');
    await primary.rename(backup.path);
    await File('${temp.path}/corrupt.elecx.json').writeAsString('{broken');

    final listed = await store.list();
    expect(listed.map((item) => item.projectId), [document.projectId]);

    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  });
'''
    persist = persist[:end] + case + persist[end:]
persist_path.write_text(persist)
