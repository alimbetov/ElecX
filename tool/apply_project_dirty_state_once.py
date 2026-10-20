from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    p.write_text(text.replace(old, new, 1))

# ---------------------------------------------------------------------------
# Editor dirty-state, immutable project identity, save races and close guard.
# ---------------------------------------------------------------------------
p = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
replace_once(
    p,
    "import 'editor_project_document.dart';\n",
    "import 'editor_project_document.dart';\nimport 'project_persistence_metadata.dart';\n",
    'editor metadata import',
)
replace_once(
    p,
    '''  const UnifiedWorkspaceEditorScreen({\n    super.key,\n    this.projectStore,\n    this.initialDocument,\n  });\n''',
    '''  const UnifiedWorkspaceEditorScreen({\n    super.key,\n    this.projectStore,\n    this.initialDocument,\n    this.initialMetadata,\n  });\n''',
    'editor constructor',
)
replace_once(
    p,
    '''  final EditorProjectDocument? initialDocument;\n\n  @override\n''',
    '''  final EditorProjectDocument? initialDocument;\n\n  /// Identity for a newly created unsaved project. The physical site keeps\n  /// its own ids; project identity is independent and immutable.\n  final EditorProjectMetadata? initialMetadata;\n\n  @override\n''',
    'editor initial metadata field',
)
replace_once(
    p,
    '''  Future<EditorProjectStore>? _projectStoreFuture;\n  bool _projectIoBusy = false;\n''',
    '''  Future<EditorProjectStore>? _projectStoreFuture;\n  bool _projectIoBusy = false;\n  late EditorProjectMetadata _projectMetadata;\n  late EditorProjectSaveStatus _saveStatus;\n  int _projectRevision = 0;\n  int _savedRevision = 0;\n  bool _allowPop = false;\n\n  bool get _hasUnsavedChanges =>\n      _projectRevision != _savedRevision ||\n      _saveStatus == EditorProjectSaveStatus.saveFailed;\n''',
    'dirty fields',
)
replace_once(
    p,
    '''    if (initialDocument == null) {\n      controller = EditorController.demo()..addListener(_refresh);\n      workspace = EditorBuildingWorkspace.demo(controller)\n        ..addListener(_refresh);\n    } else {\n      final restored = initialDocument.restore();\n      controller = restored.editor..addListener(_refresh);\n      workspace = restored.workspace..addListener(_refresh);\n    }\n''',
    '''    if (initialDocument == null) {\n      _projectMetadata = widget.initialMetadata ??\n          EditorProjectMetadata.create(projectName: 'Новый проект');\n      _saveStatus = EditorProjectSaveStatus.modified;\n      _projectRevision = 1;\n      _savedRevision = 0;\n      controller = EditorController.demo()..addListener(_onProjectChanged);\n      workspace = EditorBuildingWorkspace.demo(controller)\n        ..addListener(_onProjectChanged);\n    } else {\n      _projectMetadata = initialDocument.metadata;\n      _saveStatus = EditorProjectSaveStatus.saved;\n      final restored = initialDocument.restore();\n      controller = restored.editor..addListener(_onProjectChanged);\n      workspace = restored.workspace..addListener(_onProjectChanged);\n    }\n''',
    'dirty init',
)
replace_once(
    p,
    '''  void _refresh() {\n    if (mounted) {\n      setState(() {});\n    }\n  }\n\n  Future<void> _saveProject() async {\n''',
    '''  void _refresh() {\n    if (mounted) {\n      setState(() {});\n    }\n  }\n\n  void _onProjectChanged() {\n    _projectRevision++;\n    if (_saveStatus != EditorProjectSaveStatus.saving &&\n        _saveStatus != EditorProjectSaveStatus.saveFailed) {\n      _saveStatus = EditorProjectSaveStatus.modified;\n    }\n    _refresh();\n  }\n\n  Future<void> _saveProject() async {\n''',
    'project listener',
)
replace_once(
    p,
    '''  Future<void> _saveProject() async {\n    if (_projectIoBusy) return;\n    setState(() => _projectIoBusy = true);\n    try {\n      final document = EditorProjectDocument.capture(workspace);\n      final store = await _projectStore();\n      await store.save(document);\n      if (!mounted) return;\n      _showProjectMessage('Проект сохранён');\n    } catch (error) {\n      if (!mounted) return;\n      _showProjectMessage('Не удалось сохранить проект: $error', isError: true);\n    } finally {\n      if (mounted) setState(() => _projectIoBusy = false);\n    }\n  }\n''',
    '''  Future<void> _saveProject() async {\n    if (_projectIoBusy) return;\n    final revisionAtCapture = _projectRevision;\n    final touchedMetadata = _projectMetadata.touch();\n    setState(() {\n      _projectIoBusy = true;\n      _saveStatus = EditorProjectSaveStatus.saving;\n    });\n    try {\n      final document = EditorProjectDocument.capture(\n        workspace,\n        metadata: touchedMetadata,\n      );\n      final store = await _projectStore();\n      await store.save(document);\n      if (!mounted) return;\n      _projectMetadata = touchedMetadata;\n      _savedRevision = revisionAtCapture;\n      _saveStatus = _projectRevision == revisionAtCapture\n          ? EditorProjectSaveStatus.saved\n          : EditorProjectSaveStatus.modified;\n      _showProjectMessage('Проект сохранён');\n    } catch (error) {\n      if (!mounted) return;\n      _saveStatus = EditorProjectSaveStatus.saveFailed;\n      _showProjectMessage('Не удалось сохранить проект: $error', isError: true);\n    } finally {\n      if (mounted) {\n        setState(() => _projectIoBusy = false);\n      }\n    }\n  }\n''',
    'race-safe save',
)
replace_once(
    p,
    '''  Future<void> _openSavedProject() async {\n    if (_projectIoBusy) return;\n    setState(() => _projectIoBusy = true);\n    try {\n      final projectId = workspace.site.site.id;\n''',
    '''  Future<void> _openSavedProject() async {\n    if (_projectIoBusy) return;\n    if (_hasUnsavedChanges &&\n        !await _confirmDiscardChanges(\n          title: 'Открыть сохранённую версию?',\n          message: 'Несохранённые изменения текущей версии будут потеряны.',\n        )) {\n      return;\n    }\n    setState(() => _projectIoBusy = true);\n    try {\n      final projectId = _projectMetadata.projectId;\n''',
    'open guard and identity',
)
replace_once(
    p,
    '''      final restored = document.restore();\n      _replaceProject(restored);\n''',
    '''      final restored = document.restore();\n      _replaceProject(restored, document.metadata);\n''',
    'replace loaded metadata',
)
replace_once(
    p,
    '''  void _replaceProject(RestoredEditorProject restored) {\n    final previousController = controller;\n    final previousWorkspace = workspace;\n\n    previousWorkspace.removeListener(_refresh);\n    previousController.removeListener(_refresh);\n''',
    '''  void _replaceProject(\n    RestoredEditorProject restored,\n    EditorProjectMetadata metadata,\n  ) {\n    final previousController = controller;\n    final previousWorkspace = workspace;\n\n    previousWorkspace.removeListener(_onProjectChanged);\n    previousController.removeListener(_onProjectChanged);\n''',
    'replace project signature',
)
replace_once(
    p,
    '''    controller = restored.editor..addListener(_refresh);\n    workspace = restored.workspace..addListener(_refresh);\n    siteInteraction.clear();\n    setState(() {});\n  }\n\n  void _showProjectMessage''',
    '''    controller = restored.editor..addListener(_onProjectChanged);\n    workspace = restored.workspace..addListener(_onProjectChanged);\n    _projectMetadata = metadata;\n    _projectRevision = 0;\n    _savedRevision = 0;\n    _saveStatus = EditorProjectSaveStatus.saved;\n    siteInteraction.clear();\n    setState(() {});\n  }\n\n  Future<bool> _confirmDiscardChanges({\n    required String title,\n    required String message,\n  }) async {\n    if (!_hasUnsavedChanges) return true;\n    final discard = await showDialog<bool>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        key: const ValueKey('unsaved-project-dialog'),\n        title: Text(title),\n        content: Text(message),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(false),\n            child: const Text('Остаться'),\n          ),\n          FilledButton(\n            key: const ValueKey('discard-unsaved-project'),\n            onPressed: () => Navigator.of(dialogContext).pop(true),\n            child: const Text('Не сохранять'),\n          ),\n        ],\n      ),\n    );\n    return discard ?? false;\n  }\n\n  Future<void> _confirmCloseFromBack() async {\n    final discard = await _confirmDiscardChanges(\n      title: 'Закрыть проект?',\n      message: 'Есть несохранённые изменения.',\n    );\n    if (!discard || !mounted) return;\n    setState(() => _allowPop = true);\n    Navigator.of(context).pop();\n  }\n\n  void _showProjectMessage''',
    'discard guard methods',
)
replace_once(
    p,
    '''    workspace.removeListener(_refresh);\n    workspace.dispose();\n    controller.removeListener(_refresh);\n''',
    '''    workspace.removeListener(_onProjectChanged);\n    workspace.dispose();\n    controller.removeListener(_onProjectChanged);\n''',
    'dispose project listeners',
)
replace_once(
    p,
    '''  Widget build(BuildContext context) {\n    return EditorKeyboardScope(\n      controller: controller,\n''',
    '''  Widget build(BuildContext context) {\n    return PopScope(\n      canPop: _allowPop || !_hasUnsavedChanges,\n      onPopInvokedWithResult: (didPop, result) {\n        if (!didPop) _confirmCloseFromBack();\n      },\n      child: EditorKeyboardScope(\n        controller: controller,\n''',
    'pop guard opening',
)
replace_once(
    p,
    '''        },\n      ),\n    );\n  }\n}\n\nclass _DesktopWorkspace''',
    '''        },\n      ),\n    ),\n    );\n  }\n}\n\nclass _DesktopWorkspace''',
    'pop guard closing',
)
replace_once(
    p,
    '''              projectIoBusy: _projectIoBusy,\n              onSaveProject: _saveProject,\n''',
    '''              projectIoBusy: _projectIoBusy,\n              projectMetadata: _projectMetadata,\n              saveStatus: _saveStatus,\n              onSaveProject: _saveProject,\n''',
    'appbar state args',
)
replace_once(
    p,
    '''    required this.projectIoBusy,\n    required this.onSaveProject,\n''',
    '''    required this.projectIoBusy,\n    required this.projectMetadata,\n    required this.saveStatus,\n    required this.onSaveProject,\n''',
    'appbar constructor state',
)
replace_once(
    p,
    '''  final bool projectIoBusy;\n  final VoidCallback onSaveProject;\n''',
    '''  final bool projectIoBusy;\n  final EditorProjectMetadata projectMetadata;\n  final EditorProjectSaveStatus saveStatus;\n  final VoidCallback onSaveProject;\n''',
    'appbar fields',
)
replace_once(
    p,
    '''      title: Text(\n        workspace.context == EditorWorkspaceContext.siteOutdoor\n            ? 'ElecX · ${workspace.site.site.name}'\n            : 'ElecX · ${workspace.activeLevel?.displayName ?? ''}',\n      ),\n      actions: [\n''',
    '''      title: Text(\n        workspace.context == EditorWorkspaceContext.siteOutdoor\n            ? 'ElecX · ${projectMetadata.projectName}'\n            : 'ElecX · ${projectMetadata.projectName} · ${workspace.activeLevel?.displayName ?? ''}',\n      ),\n      actions: [\n        if (!compact)\n          Padding(\n            key: const ValueKey('project-save-status'),\n            padding: const EdgeInsets.symmetric(horizontal: 8),\n            child: Center(\n              child: Text(\n                saveStatus.label,\n                style: Theme.of(context).textTheme.labelMedium,\n              ),\n            ),\n          ),\n''',
    'appbar title and status',
)

# ---------------------------------------------------------------------------
# Project Hub creates real independent project identities.
# ---------------------------------------------------------------------------
p = 'lib/src/features/projects/project_hub_screen.dart'
replace_once(
    p,
    "import '../editor/editor_project_document.dart';\n",
    "import '../editor/editor_project_document.dart';\nimport '../editor/project_persistence_metadata.dart';\n",
    'hub metadata import',
)
replace_once(
    p,
    '''  Future<void> _openEditor({EditorProjectDocument? document}) async {\n    final store = await _storeFuture;\n''',
    '''  Future<void> _createProject() async {\n    final input = TextEditingController(text: 'Новый проект');\n    final name = await showDialog<String>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        key: const ValueKey('new-project-dialog'),\n        title: const Text('Новый проект'),\n        content: TextField(\n          key: const ValueKey('new-project-name'),\n          controller: input,\n          autofocus: true,\n          decoration: const InputDecoration(labelText: 'Название проекта'),\n          onSubmitted: (value) {\n            final normalized = value.trim();\n            if (normalized.isNotEmpty) {\n              Navigator.of(dialogContext).pop(normalized);\n            }\n          },\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(),\n            child: const Text('Отмена'),\n          ),\n          FilledButton(\n            key: const ValueKey('create-project-confirm'),\n            onPressed: () {\n              final normalized = input.text.trim();\n              if (normalized.isNotEmpty) {\n                Navigator.of(dialogContext).pop(normalized);\n              }\n            },\n            child: const Text('Создать'),\n          ),\n        ],\n      ),\n    );\n    input.dispose();\n    if (name == null || !mounted) return;\n    await _openEditor(\n      metadata: EditorProjectMetadata.create(projectName: name),\n    );\n  }\n\n  Future<void> _openEditor({\n    EditorProjectDocument? document,\n    EditorProjectMetadata? metadata,\n  }) async {\n    final store = await _storeFuture;\n''',
    'hub create project flow',
)
replace_once(
    p,
    '''          projectStore: store,\n          initialDocument: document,\n''',
    '''          projectStore: store,\n          initialDocument: document,\n          initialMetadata: metadata,\n''',
    'hub initial metadata route',
)
replace_once(
    p,
    '''      floatingActionButton: FloatingActionButton.extended(\n        onPressed: _openEditor,\n''',
    '''      floatingActionButton: FloatingActionButton.extended(\n        key: const ValueKey('create-project'),\n        onPressed: _createProject,\n''',
    'hub create button',
)

# ---------------------------------------------------------------------------
# Widget regressions: dirty state, close guard and independent projects.
# ---------------------------------------------------------------------------
p = 'test/unified_workspace_persistence_ui_test.dart'
text = Path(p).read_text()
text = text.replace(
    "import 'package:elecx/src/features/editor/editor_project_document.dart';\n",
    "import 'package:elecx/src/features/editor/editor_project_document.dart';\nimport 'package:elecx/src/features/editor/project_persistence_metadata.dart';\n",
    1,
)
text = text.replace(
    "    expect(find.byKey(const ValueKey('project-open')), findsOneWidget);\n",
    "    expect(find.byKey(const ValueKey('project-open')), findsOneWidget);\n    expect(find.text('Modified'), findsOneWidget);\n",
    1,
)
text = text.replace(
    "    expect(find.text('Проект сохранён'), findsOneWidget);\n",
    "    expect(find.text('Проект сохранён'), findsOneWidget);\n    expect(find.text('Saved'), findsOneWidget);\n",
    1,
)
anchor = "}\n"
# append a separate route-level close guard regression before main's final brace
idx = text.rfind(anchor)
if idx < 0:
    raise RuntimeError('ui test final brace missing')
addition = r'''
  testWidgets('unsaved new project blocks back until discard is explicit',
      (tester) async {
    final store = _MemoryProjectStore();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('launch-editor'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UnifiedWorkspaceEditorScreen(
                    projectStore: store,
                    initialMetadata: EditorProjectMetadata.create(
                      projectName: 'Dirty project',
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('launch-editor')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unsaved-project-dialog')), findsOneWidget);
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discard-unsaved-project')));
    await tester.pumpAndSettle();
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsNothing);
  });
'''
text = text[:idx] + addition + text[idx:]
Path(p).write_text(text)

p = 'test/project_hub_persistence_test.dart'
text = Path(p).read_text()
idx = text.rfind("}\n")
if idx < 0:
    raise RuntimeError('hub test final brace missing')
addition = r'''
  testWidgets('hub creates independent project identities', (tester) async {
    final store = _HubMemoryStore([]);
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProjectHubScreen(projectStore: store)),
    );
    await tester.pumpAndSettle();

    Future<void> createAndSave(String name) async {
      await tester.tap(find.byKey(const ValueKey('create-project')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('new-project-name')), name);
      await tester.tap(find.byKey(const ValueKey('create-project-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project-save')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await createAndSave('Проект 1');
    await createAndSave('Проект 2');

    expect(store.documents, hasLength(2));
    expect(store.documents[0].projectId, isNot(store.documents[1].projectId));
    expect(store.documents.map((item) => item.projectName),
        containsAll(<String>['Проект 1', 'Проект 2']));
  });
'''
Path(p).write_text(text[:idx] + addition + text[idx:])
