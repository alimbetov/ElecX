import 'package:flutter/material.dart';

import '../editor/editor_project_document.dart';
import '../editor/editor_project_recovery.dart';
import '../editor/project_persistence_metadata.dart';
import '../editor/unified_workspace_editor_screen.dart';

class ProjectHubScreen extends StatefulWidget {
  const ProjectHubScreen({super.key, this.projectStore, this.recoveryStore});

  final EditorProjectStore? projectStore;
  final EditorProjectRecoveryStore? recoveryStore;

  @override
  State<ProjectHubScreen> createState() => _ProjectHubScreenState();
}

class _ProjectHubScreenState extends State<ProjectHubScreen> {
  late final Future<EditorProjectStore> _storeFuture;
  late final Future<EditorProjectRecoveryStore?> _recoveryStoreFuture;
  late Future<_ProjectHubData> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = widget.projectStore == null
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

  void _reloadProjects() {
    if (!mounted) return;
    final nextProjects = _loadProjects();
    setState(() {
      _projectsFuture = nextProjects;
    });
  }

  Future<void> _createProject() async {
    var draftName = 'Новый проект';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('new-project-dialog'),
        title: const Text('Новый проект'),
        content: TextFormField(
          key: const ValueKey('new-project-name'),
          initialValue: draftName,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название проекта'),
          onChanged: (value) => draftName = value,
          onFieldSubmitted: (value) {
            final normalized = value.trim();
            if (normalized.isNotEmpty) {
              Navigator.of(dialogContext).pop(normalized);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('create-project-confirm'),
            onPressed: () {
              final normalized = draftName.trim();
              if (normalized.isNotEmpty) {
                Navigator.of(dialogContext).pop(normalized);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    await _openEditor(
      metadata: EditorProjectMetadata.create(projectName: name),
    );
  }

  Future<void> _openEditor({
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
        key: const ValueKey('create-project'),
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('Новый проект'),
      ),
      body: FutureBuilder<_ProjectHubData>(
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
          final data = snapshot.data ?? const _ProjectHubData();
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
              Text(
                'Мои проекты',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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

final class _ProjectHubData {
  const _ProjectHubData({this.projects = const [], this.recoveries = const []});

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
        key: ValueKey(
          '${prominent ? 'continue-project' : 'saved-project'}-${document.projectId}',
        ),
        child: ListTile(
          leading:
              Icon(prominent ? Icons.play_circle_outline : Icons.apartment),
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
