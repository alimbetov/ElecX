from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    p.write_text(text.replace(old, new, 1))

p = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
text = Path(p).read_text()

text = text.replace(
    "import 'editor_layout_policy.dart';\n",
    "import 'editor_layout_policy.dart';\nimport 'editor_p2_session.dart';\nimport 'editor_project_document.dart';\n",
    1,
)

text = text.replace(
    '''class UnifiedWorkspaceEditorScreen extends StatefulWidget {\n  const UnifiedWorkspaceEditorScreen({super.key});\n''',
    '''class UnifiedWorkspaceEditorScreen extends StatefulWidget {\n  const UnifiedWorkspaceEditorScreen({\n    super.key,\n    this.projectStore,\n  });\n\n  /// Optional injection point used by tests and future project-hub routing.\n  /// Production lazily opens the application documents project store.\n  final EditorProjectStore? projectStore;\n''',
    1,
)

text = text.replace(
    '''  late final EditorController controller;\n  late final EditorBuildingWorkspace workspace;\n  late final SiteMapInteractionController siteInteraction;\n  late final EditorShellState shell;\n''',
    '''  late EditorController controller;\n  late EditorBuildingWorkspace workspace;\n  late final SiteMapInteractionController siteInteraction;\n  late final EditorShellState shell;\n  Future<EditorProjectStore>? _projectStoreFuture;\n  bool _projectIoBusy = false;\n''',
    1,
)

text = text.replace(
    '''    shell = EditorShellState()..addListener(_refresh);\n  }\n\n  void _refresh() {''',
    '''    shell = EditorShellState()..addListener(_refresh);\n    final injectedStore = widget.projectStore;\n    if (injectedStore != null) {\n      _projectStoreFuture = Future<EditorProjectStore>.value(injectedStore);\n    }\n  }\n\n  Future<EditorProjectStore> _projectStore() =>\n      _projectStoreFuture ??= JsonFileEditorProjectStore.openDefault();\n\n  void _refresh() {''',
    1,
)

insert_anchor = '''  Future<void> _editProjectNorth() async {\n'''
if text.count(insert_anchor) != 1:
    raise RuntimeError('project IO method anchor mismatch')
methods = r'''  Future<void> _saveProject() async {
    if (_projectIoBusy) return;
    setState(() => _projectIoBusy = true);
    try {
      final document = EditorProjectDocument.capture(workspace);
      final store = await _projectStore();
      await store.save(document);
      if (!mounted) return;
      _showProjectMessage('Проект сохранён');
    } catch (error) {
      if (!mounted) return;
      _showProjectMessage('Не удалось сохранить проект: $error', isError: true);
    } finally {
      if (mounted) setState(() => _projectIoBusy = false);
    }
  }

  Future<void> _openSavedProject() async {
    if (_projectIoBusy) return;
    setState(() => _projectIoBusy = true);
    try {
      final projectId = workspace.site.site.id;
      final store = await _projectStore();
      final document = await store.load(projectId);
      if (!mounted) return;
      if (document == null) {
        _showProjectMessage('Сохранённая версия проекта не найдена');
        return;
      }
      final restored = document.restore();
      _replaceProject(restored);
      _showProjectMessage('Проект открыт из сохранённой версии');
    } catch (error) {
      if (!mounted) return;
      _showProjectMessage('Не удалось открыть проект: $error', isError: true);
    } finally {
      if (mounted) setState(() => _projectIoBusy = false);
    }
  }

  void _replaceProject(RestoredEditorProject restored) {
    final previousController = controller;
    final previousWorkspace = workspace;

    previousWorkspace.removeListener(_refresh);
    previousController.removeListener(_refresh);
    previousController.disposeP2State();
    previousWorkspace.dispose();
    previousController.dispose();

    controller = restored.editor..addListener(_refresh);
    workspace = restored.workspace..addListener(_refresh);
    siteInteraction.clear();
    setState(() {});
  }

  void _showProjectMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.errorContainer
              : null,
        ),
      );
  }

'''
text = text.replace(insert_anchor, methods + insert_anchor, 1)

text = text.replace(
    '''    workspace.removeListener(_refresh);\n    workspace.dispose();\n    controller.removeListener(_refresh);\n    controller.dispose();\n''',
    '''    workspace.removeListener(_refresh);\n    workspace.dispose();\n    controller.removeListener(_refresh);\n    controller.disposeP2State();\n    controller.dispose();\n''',
    1,
)

text = text.replace(
    '''              compact: !desktop,\n              onOpenMiniMap: _openMiniMap,\n            ),''',
    '''              compact: !desktop,\n              projectIoBusy: _projectIoBusy,\n              onSaveProject: _saveProject,\n              onOpenProject: _openSavedProject,\n              onOpenMiniMap: _openMiniMap,\n            ),''',
    1,
)

text = text.replace(
    '''    required this.compact,\n    required this.onOpenMiniMap,\n  });\n\n  final EditorBuildingWorkspace workspace;\n  final EditorShellState shell;\n  final bool compact;\n  final VoidCallback onOpenMiniMap;\n''',
    '''    required this.compact,\n    required this.projectIoBusy,\n    required this.onSaveProject,\n    required this.onOpenProject,\n    required this.onOpenMiniMap,\n  });\n\n  final EditorBuildingWorkspace workspace;\n  final EditorShellState shell;\n  final bool compact;\n  final bool projectIoBusy;\n  final VoidCallback onSaveProject;\n  final VoidCallback onOpenProject;\n  final VoidCallback onOpenMiniMap;\n''',
    1,
)

text = text.replace(
    '''      actions: [\n        IconButton(\n          tooltip: 'Контекстная карта',''',
    '''      actions: [\n        IconButton(\n          key: const ValueKey('project-open'),\n          tooltip: 'Открыть сохранённую версию',\n          onPressed: projectIoBusy ? null : onOpenProject,\n          icon: const Icon(Icons.folder_open_outlined),\n        ),\n        IconButton(\n          key: const ValueKey('project-save'),\n          tooltip: 'Сохранить проект',\n          onPressed: projectIoBusy ? null : onSaveProject,\n          icon: projectIoBusy\n              ? const SizedBox.square(\n                  dimension: 18,\n                  child: CircularProgressIndicator(strokeWidth: 2),\n                )\n              : const Icon(Icons.save_outlined),\n        ),\n        IconButton(\n          tooltip: 'Контекстная карта',''',
    1,
)

Path(p).write_text(text)

# In-memory persistence store keeps widget tests deterministic and proves that
# Save/Open is wired to the canonical document rather than a visual mock.
Path('test/unified_workspace_persistence_ui_test.dart').write_text(r'''import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};
  int saveCount = 0;
  int loadCount = 0;

  @override
  Future<void> save(EditorProjectDocument document) async {
    saveCount++;
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    loadCount++;
    return documents[projectId];
  }
}

void main() {
  testWidgets('desktop Save and Open use canonical project store', (tester) async {
    final store = _MemoryProjectStore();
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(projectStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('project-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('project-open')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(store.saveCount, 1);
    expect(store.documents, hasLength(1));
    expect(find.text('Проект сохранён'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-open')));
    await tester.pumpAndSettle();
    expect(store.loadCount, 1);
    expect(find.text('Проект открыт из сохранённой версии'), findsOneWidget);

    // The restored controller/workspace must still render the real editor.
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('project-save')), findsOneWidget);
  });
}
''')
