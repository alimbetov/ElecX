from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    p.write_text(text.replace(old, new, 1))

# ---------------------------------------------------------------------------
# Store discovery contract: reopen after a full application restart.
# ---------------------------------------------------------------------------
p = 'lib/src/features/editor/editor_project_document.dart'
replace_once(
    p,
    '''abstract interface class EditorProjectStore {\n  Future<void> save(EditorProjectDocument document);\n  Future<EditorProjectDocument?> load(String projectId);\n}\n''',
    '''abstract interface class EditorProjectStore {\n  Future<void> save(EditorProjectDocument document);\n  Future<EditorProjectDocument?> load(String projectId);\n  Future<List<EditorProjectDocument>> list();\n}\n''',
    'project store list contract',
)
replace_once(
    p,
    '''  File _target(String projectId) {\n''',
    '''  @override\n  Future<List<EditorProjectDocument>> list() async {\n    if (!await rootDirectory.exists()) return const [];\n    final result = <EditorProjectDocument>[];\n    await for (final entity in rootDirectory.list(followLinks: false)) {\n      if (entity is! File || !entity.path.endsWith('.elecx.json')) continue;\n      final raw = jsonDecode(await entity.readAsString());\n      if (raw is! Map) {\n        throw FormatException(\n          'ElecX project ${path.basename(entity.path)} must be a JSON object.',\n        );\n      }\n      result.add(\n        EditorProjectDocument.fromJson(\n          raw.map((key, value) => MapEntry(key.toString(), value)),\n        ),\n      );\n    }\n    result.sort((a, b) => a.projectName.compareTo(b.projectName));\n    return List.unmodifiable(result);\n  }\n\n  File _target(String projectId) {\n''',
    'file store list implementation',
)

# ---------------------------------------------------------------------------
# Editor accepts a persisted document as its initial lifecycle state.
# ---------------------------------------------------------------------------
p = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
replace_once(
    p,
    '''  const UnifiedWorkspaceEditorScreen({\n    super.key,\n    this.projectStore,\n  });\n\n  /// Optional injection point used by tests and future project-hub routing.\n  /// Production lazily opens the application documents project store.\n  final EditorProjectStore? projectStore;\n''',
    '''  const UnifiedWorkspaceEditorScreen({\n    super.key,\n    this.projectStore,\n    this.initialDocument,\n  });\n\n  /// Optional injection point used by tests and project-hub routing.\n  /// Production lazily opens the application documents project store.\n  final EditorProjectStore? projectStore;\n\n  /// When provided, the screen starts from the persisted canonical document\n  /// instead of constructing the demo workspace.\n  final EditorProjectDocument? initialDocument;\n''',
    'editor initial document contract',
)
replace_once(
    p,
    '''    controller = EditorController.demo()..addListener(_refresh);\n    workspace = EditorBuildingWorkspace.demo(controller)..addListener(_refresh);\n    siteInteraction = SiteMapInteractionController();\n''',
    '''    final initialDocument = widget.initialDocument;\n    if (initialDocument == null) {\n      controller = EditorController.demo()..addListener(_refresh);\n      workspace =\n          EditorBuildingWorkspace.demo(controller)..addListener(_refresh);\n    } else {\n      final restored = initialDocument.restore();\n      controller = restored.editor..addListener(_refresh);\n      workspace = restored.workspace..addListener(_refresh);\n    }\n    siteInteraction = SiteMapInteractionController();\n''',
    'restore initial editor document',
)

# Update the in-memory store used by the Save/Open widget regression.
p = 'test/unified_workspace_persistence_ui_test.dart'
replace_once(
    p,
    '''  @override\n  Future<EditorProjectDocument?> load(String projectId) async {\n    loadCount++;\n    return documents[projectId];\n  }\n}\n''',
    '''  @override\n  Future<EditorProjectDocument?> load(String projectId) async {\n    loadCount++;\n    return documents[projectId];\n  }\n\n  @override\n  Future<List<EditorProjectDocument>> list() async =>\n      List.unmodifiable(documents.values);\n}\n''',
    'memory store list contract',
)

# ---------------------------------------------------------------------------
# Replace the static demo-only Project Hub with a persisted project browser.
# ---------------------------------------------------------------------------
Path('lib/src/features/projects/project_hub_screen.dart').write_text(r'''import 'package:flutter/material.dart';

import '../editor/editor_project_document.dart';
import '../editor/unified_workspace_editor_screen.dart';

class ProjectHubScreen extends StatefulWidget {
  const ProjectHubScreen({
    super.key,
    this.projectStore,
  });

  final EditorProjectStore? projectStore;

  @override
  State<ProjectHubScreen> createState() => _ProjectHubScreenState();
}

class _ProjectHubScreenState extends State<ProjectHubScreen> {
  late final Future<EditorProjectStore> _storeFuture;
  late Future<List<EditorProjectDocument>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = widget.projectStore == null
        ? JsonFileEditorProjectStore.openDefault()
        : Future<EditorProjectStore>.value(widget.projectStore!);
    _projectsFuture = _loadProjects();
  }

  Future<List<EditorProjectDocument>> _loadProjects() async {
    final store = await _storeFuture;
    return store.list();
  }

  void _reloadProjects() {
    if (!mounted) return;
    setState(() => _projectsFuture = _loadProjects());
  }

  Future<void> _openEditor({EditorProjectDocument? document}) async {
    final store = await _storeFuture;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnifiedWorkspaceEditorScreen(
          projectStore: store,
          initialDocument: document,
        ),
      ),
    );
    _reloadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
        actions: [
          IconButton(
            tooltip: 'Обновить проекты',
            onPressed: _reloadProjects,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Новый проект'),
      ),
      body: FutureBuilder<List<EditorProjectDocument>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProjectLoadFailure(
              error: snapshot.error!,
              onRetry: _reloadProjects,
            );
          }
          final projects = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Продолжить', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (projects.isNotEmpty)
                _ProjectCard(
                  document: projects.first,
                  prominent: true,
                  onTap: () => _openEditor(document: projects.first),
                )
              else
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.history_toggle_off),
                    title: Text('Нет сохранённого проекта'),
                    subtitle: Text(
                      'Создайте проект и нажмите «Сохранить» в редакторе.',
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              Text('Мои проекты', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (projects.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.folder_outlined),
                    title: Text('Пока пусто'),
                    subtitle: Text(
                      'Сохранённые проекты появятся здесь после записи на диск.',
                    ),
                  ),
                )
              else
                for (final document in projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProjectCard(
                      document: document,
                      onTap: () => _openEditor(document: document),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.document,
    required this.onTap,
    this.prominent = false,
  });

  final EditorProjectDocument document;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('saved-project-${document.projectId}'),
        child: ListTile(
          leading: Icon(prominent ? Icons.play_circle_outline : Icons.apartment),
          title: Text(document.projectName),
          subtitle: Text(
            'Уровень ${document.activeLevelNumber} · '
            '${document.p2State.components.length} компонентов · '
            '${document.p2State.routes.length} трасс',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _ProjectLoadFailure extends StatelessWidget {
  const _ProjectLoadFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 32),
                  const SizedBox(height: 12),
                  const Text('Не удалось прочитать сохранённые проекты'),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
''')

# ---------------------------------------------------------------------------
# Persistence acceptance now includes store discovery and Project Hub reopen.
# ---------------------------------------------------------------------------
p = 'test/editor_project_persistence_test.dart'
text = Path(p).read_text()
anchor = "  test('unsupported schema is rejected explicitly', () {"
if text.count(anchor) != 1:
    raise RuntimeError('project persistence list test anchor mismatch')
new_test = r'''  test('file store lists saved projects for application restart', () async {
    final root = await Directory.systemTemp.createTemp('elecx-project-list-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final document = EditorProjectDocument.capture(workspace);
    final store = JsonFileEditorProjectStore(root);

    await store.save(document);
    final listed = await store.list();

    expect(listed, hasLength(1));
    expect(listed.single.projectId, document.projectId);
    expect(listed.single.projectName, document.projectName);
  });

'''
Path(p).write_text(text.replace(anchor, new_test + anchor, 1))

Path('test/project_hub_persistence_test.dart').write_text(r'''import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _HubMemoryStore implements EditorProjectStore {
  _HubMemoryStore(this.documents);

  final List<EditorProjectDocument> documents;

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    for (final document in documents) {
      if (document.projectId == projectId) return document;
    }
    return null;
  }

  @override
  Future<List<EditorProjectDocument>> list() async => List.unmodifiable(documents);

  @override
  Future<void> save(EditorProjectDocument document) async {
    final index = documents.indexWhere((item) => item.projectId == document.projectId);
    if (index < 0) {
      documents.add(document);
    } else {
      documents[index] = document;
    }
  }
}

void main() {
  testWidgets('project hub discovers persisted project and reopens editor',
      (tester) async {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    final document = EditorProjectDocument.capture(workspace);
    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();
    final store = _HubMemoryStore([document]);

    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProjectHubScreen(projectStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text(document.projectName), findsNWidgets(2));
    expect(
      find.byKey(ValueKey('saved-project-${document.projectId}')),
      findsNWidgets(2),
    );

    await tester.tap(
      find.byKey(ValueKey('saved-project-${document.projectId}')).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('project-save')), findsOneWidget);
  });
}
''')
