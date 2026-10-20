from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


root = Path('.')
editor = root / 'lib/src/features/editor'
projects = root / 'lib/src/features/projects'

screen = editor / 'unified_workspace_editor_screen.dart'
replace_once(
    screen,
    """    this.autosaveDelay = const Duration(seconds: 2),
    this.initialDocument,
    this.initialMetadata,
  });
""",
    """    this.autosaveDelay = const Duration(seconds: 2),
    this.initialDocument,
    this.initialRecovery,
    this.initialMetadata,
  }) : assert(initialDocument == null || initialRecovery == null);
""",
)
replace_once(
    screen,
    """  final EditorProjectDocument? initialDocument;

  /// Identity for a newly created unsaved project. The physical site keeps
""",
    """  final EditorProjectDocument? initialDocument;

  /// Explicit recovery entry opened from Project Hub. Recovery is never
  /// treated as an explicit Save: the editor starts in Modified state.
  final EditorProjectRecoverySnapshot? initialRecovery;

  /// Identity for a newly created unsaved project. The physical site keeps
""",
)
replace_once(
    screen,
    """    final initialDocument = widget.initialDocument;
    if (initialDocument == null) {
""",
    """    final initialRecovery = widget.initialRecovery;
    final initialDocument = initialRecovery?.document ?? widget.initialDocument;
    if (initialDocument == null) {
""",
)
replace_once(
    screen,
    """    } else {
      _projectMetadata = initialDocument.metadata;
      _saveStatus = EditorProjectSaveStatus.saved;
      final restored = initialDocument.restore();
""",
    """    } else {
      _projectMetadata = initialDocument.metadata;
      if (initialRecovery == null) {
        _saveStatus = EditorProjectSaveStatus.saved;
      } else {
        _saveStatus = EditorProjectSaveStatus.modified;
        _projectRevision = initialRecovery.revision > 0
            ? initialRecovery.revision
            : 1;
        _savedRevision = 0;
        _lastAutosavedRevision = _projectRevision;
      }
      final restored = initialDocument.restore();
""",
)
replace_once(
    screen,
    """      _scheduleAutosave();
      _offerRecoveryIfNewer();
""",
    """      _scheduleAutosave();
      if (widget.initialRecovery == null) {
        _offerRecoveryIfNewer();
      }
""",
)

hub = projects / 'project_hub_screen.dart'
replace_once(
    hub,
    "import '../editor/editor_project_document.dart';\n",
    "import '../editor/editor_project_document.dart';\nimport '../editor/editor_project_recovery.dart';\n",
)
replace_once(
    hub,
    """  const ProjectHubScreen({
    super.key,
    this.projectStore,
  });

  final EditorProjectStore? projectStore;
""",
    """  const ProjectHubScreen({
    super.key,
    this.projectStore,
    this.recoveryStore,
  });

  final EditorProjectStore? projectStore;
  final EditorProjectRecoveryStore? recoveryStore;
""",
)
replace_once(
    hub,
    """  late final Future<EditorProjectStore> _storeFuture;
  late Future<List<EditorProjectDocument>> _projectsFuture;
""",
    """  late final Future<EditorProjectStore> _storeFuture;
  late final Future<EditorProjectRecoveryStore?> _recoveryStoreFuture;
  late Future<_ProjectHubData> _projectsFuture;
""",
)
replace_once(
    hub,
    """    _storeFuture = widget.projectStore == null
        ? JsonFileEditorProjectStore.openDefault()
        : Future<EditorProjectStore>.value(widget.projectStore!);
    _projectsFuture = _loadProjects();
  }

  Future<List<EditorProjectDocument>> _loadProjects() async {
    final store = await _storeFuture;
    return store.list();
  }
""",
    """    _storeFuture = widget.projectStore == null
        ? JsonFileEditorProjectStore.openDefault()
        : Future<EditorProjectStore>.value(widget.projectStore!);
    _recoveryStoreFuture = widget.recoveryStore != null
        ? Future<EditorProjectRecoveryStore?>.value(widget.recoveryStore)
        : widget.projectStore == null
            ? JsonFileEditorProjectRecoveryStore.openDefault()
            : Future<EditorProjectRecoveryStore?>.value(null);
    _projectsFuture = _loadProjects();
  }

  Future<_ProjectHubData> _loadProjects() async {
    final store = await _storeFuture;
    final projects = await store.list();
    final recoveryStore = await _recoveryStoreFuture;
    final allRecoveries = recoveryStore == null
        ? const <EditorProjectRecoverySnapshot>[]
        : await recoveryStore.list();
    final savedById = {
      for (final document in projects) document.projectId: document,
    };
    final recoveries = [
      for (final recovery in allRecoveries)
        if (savedById[recovery.projectId] == null ||
            recovery.capturedAt.isAfter(
              savedById[recovery.projectId]!.updatedAt,
            ))
          recovery,
    ];
    return _ProjectHubData(
      projects: projects,
      recoveries: List.unmodifiable(recoveries),
    );
  }
""",
)
replace_once(
    hub,
    """  Future<void> _openEditor({
    EditorProjectDocument? document,
    EditorProjectMetadata? metadata,
  }) async {
    final store = await _storeFuture;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnifiedWorkspaceEditorScreen(
          projectStore: store,
          initialDocument: document,
          initialMetadata: metadata,
        ),
      ),
    );
    _reloadProjects();
  }
""",
    """  Future<void> _openEditor({
    EditorProjectDocument? document,
    EditorProjectRecoverySnapshot? recovery,
    EditorProjectMetadata? metadata,
  }) async {
    final store = await _storeFuture;
    final recoveryStore = await _recoveryStoreFuture;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnifiedWorkspaceEditorScreen(
          projectStore: store,
          recoveryStore: recoveryStore,
          initialDocument: document,
          initialRecovery: recovery,
          initialMetadata: metadata,
        ),
      ),
    );
    _reloadProjects();
  }

  Future<void> _discardRecovery(EditorProjectRecoverySnapshot recovery) async {
    final store = await _recoveryStoreFuture;
    if (store == null) return;
    await store.discard(recovery.projectId);
    _reloadProjects();
  }
""",
)
replace_once(
    hub,
    """      body: FutureBuilder<List<EditorProjectDocument>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
""",
    """      body: FutureBuilder<_ProjectHubData>(
        future: _projectsFuture,
        builder: (context, snapshot) {
""",
)
replace_once(
    hub,
    """          final projects = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Продолжить', style: Theme.of(context).textTheme.titleLarge),
""",
    """          final data = snapshot.data ?? const _ProjectHubData();
          final projects = data.projects;
          final recoveries = data.recoveries;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (recoveries.isNotEmpty) ...[
                Text(
                  'Аварийное восстановление',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final recovery in recoveries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecoveryProjectCard(
                      recovery: recovery,
                      onRestore: () => _openEditor(recovery: recovery),
                      onDiscard: () => _discardRecovery(recovery),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              Text('Продолжить', style: Theme.of(context).textTheme.titleLarge),
""",
)
# Insert support classes before _ProjectCard.
replace_once(
    hub,
    "\nclass _ProjectCard extends StatelessWidget {\n",
    r'''
final class _ProjectHubData {
  const _ProjectHubData({
    this.projects = const [],
    this.recoveries = const [],
  });

  final List<EditorProjectDocument> projects;
  final List<EditorProjectRecoverySnapshot> recoveries;
}

class _RecoveryProjectCard extends StatelessWidget {
  const _RecoveryProjectCard({
    required this.recovery,
    required this.onRestore,
    required this.onDiscard,
  });

  final EditorProjectRecoverySnapshot recovery;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('recovery-project-${recovery.projectId}'),
        child: ListTile(
          leading: const Icon(Icons.restore_page_outlined),
          title: Text(recovery.document.projectName),
          subtitle: Text(
            'Автокопия · ${recovery.capturedAt.toLocal()} · '
            '${recovery.document.p2State.components.length} компонентов · '
            '${recovery.document.p2State.routes.length} трасс',
          ),
          onTap: onRestore,
          trailing: IconButton(
            key: ValueKey('discard-recovery-${recovery.projectId}'),
            tooltip: 'Удалить аварийную копию',
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      );
}

class _ProjectCard extends StatelessWidget {
''',
)

(root / 'test/project_hub_recovery_test.dart').write_text(r'''import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};

  @override
  Future<void> save(EditorProjectDocument document) async {
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async =>
      documents[projectId];

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List.unmodifiable(documents.values);
}

final class _MemoryRecoveryStore implements EditorProjectRecoveryStore {
  final Map<String, EditorProjectRecoverySnapshot> snapshots = {};

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
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
    snapshots.remove(projectId);
  }
}

EditorProjectRecoverySnapshot _orphanRecovery() {
  final controller = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(controller);
  final metadata = EditorProjectMetadata.create(
    projectName: 'Несохранённый проект',
    now: DateTime.utc(2026, 10, 20, 10),
  );
  final document = EditorProjectDocument.capture(
    workspace,
    metadata: metadata,
  );
  workspace.dispose();
  controller.disposeP2State();
  controller.dispose();
  return EditorProjectRecoverySnapshot(
    capturedAt: DateTime.utc(2026, 10, 20, 10, 5),
    revision: 4,
    document: document,
  );
}

void main() {
  testWidgets(
      'hub exposes orphan recovery and opens it as Modified until explicit Save',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recoveryStore = _MemoryRecoveryStore();
    final recovery = _orphanRecovery();
    recoveryStore.snapshots[recovery.projectId] = recovery;

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectHubScreen(
          projectStore: projects,
          recoveryStore: recoveryStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Аварийное восстановление'), findsOneWidget);
    expect(
      find.byKey(ValueKey('recovery-project-${recovery.projectId}')),
      findsOneWidget,
    );
    expect(projects.documents, isEmpty);

    await tester.tap(
      find.byKey(ValueKey('recovery-project-${recovery.projectId}')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    expect(find.text('Modified'), findsOneWidget);
    expect(find.byKey(const ValueKey('project-recovery-dialog')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(projects.documents, hasLength(1));
    expect(recoveryStore.snapshots, isEmpty);
  });

  testWidgets('hub can discard orphan recovery without creating a project',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recoveryStore = _MemoryRecoveryStore();
    final recovery = _orphanRecovery();
    recoveryStore.snapshots[recovery.projectId] = recovery;

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectHubScreen(
          projectStore: projects,
          recoveryStore: recoveryStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('discard-recovery-${recovery.projectId}')),
    );
    await tester.pumpAndSettle();
    expect(recoveryStore.snapshots, isEmpty);
    expect(find.text('Аварийное восстановление'), findsNothing);
    expect(projects.documents, isEmpty);
  });
}
''')
