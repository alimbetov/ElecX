import 'package:flutter/material.dart';

import '../../application/project/project_repository.dart';
import '../../application/project/wizard/basic_building_wizard_provider.dart';
import '../../application/project/wizard/wizard_contracts.dart';
import '../../application/project/wizard/wizard_session.dart';
import '../editor/canonical_editor_demo_generation.dart';
import '../editor/canonical_editor_production_bootstrap.dart';
import '../editor/canonical_legacy_structure_projector.dart';
import '../editor/canonical_owning_editor_project_store.dart';
import '../editor/editor_project_document.dart';
import '../editor/editor_project_recovery.dart';
import '../editor/initial_editor_project_document.dart';
import '../editor/project_persistence_metadata.dart';
import '../editor/unified_workspace_editor_screen.dart';
import '../shared/production_error_boundary.dart';
import 'project_wizard_screen.dart';

class ProjectHubScreen extends StatefulWidget {
  const ProjectHubScreen({
    super.key,
    this.projectStore,
    this.recoveryStore,
    this.canonicalProjectRepository,
  });

  final EditorProjectStore? projectStore;
  final EditorProjectRecoveryStore? recoveryStore;
  final ProjectRepository? canonicalProjectRepository;

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

  ProductionSafeFailure _reportProjectHubError(
    Object error,
    StackTrace stackTrace, {
    required ProductionDiagnosticCode code,
    required String safeSummary,
    required String operation,
  }) =>
      ProductionErrorBoundary.report(
        error: error,
        stackTrace: stackTrace,
        code: code,
        safeSummary: safeSummary,
        library: 'elecx.project_hub',
        operation: operation,
      );

  void _showSafeError(ProductionSafeFailure failure) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.userMessage)),
    );
  }

  Future<_ProjectHubData> _loadProjects() async {
    try {
      final store = await _storeFuture;
      final projects = await store.list();
      final recoveryStore = await _recoveryStoreFuture;
      final recoveries = recoveryStore == null
          ? const <EditorProjectRecoverySnapshot>[]
          : await recoveryStore.list();
      return _ProjectHubData(
        projects: projects,
        recoveries: List.unmodifiable(recoveries),
      );
    } catch (error, stackTrace) {
      _reportProjectHubError(
        error,
        stackTrace,
        code: ProductionDiagnosticCode.projectHubLoad,
        safeSummary: 'Не удалось прочитать сохранённые проекты.',
        operation: 'while loading projects and recovery snapshots',
      );
      rethrow;
    }
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
    final canonicalAvailable = widget.canonicalProjectRepository != null;
    final request = await showDialog<_NewProjectRequest>(
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
              Navigator.of(dialogContext).pop(
                _NewProjectRequest(
                  name: normalized,
                  mode: canonicalAvailable
                      ? _NewProjectMode.wizard
                      : _NewProjectMode.blank,
                ),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          if (canonicalAvailable)
            TextButton(
              key: const ValueKey('create-project-blank'),
              onPressed: () {
                final normalized = draftName.trim();
                if (normalized.isNotEmpty) {
                  Navigator.of(dialogContext).pop(
                    _NewProjectRequest(
                      name: normalized,
                      mode: _NewProjectMode.blank,
                    ),
                  );
                }
              },
              child: const Text('Пустой проект'),
            ),
          if (canonicalAvailable)
            TextButton.icon(
              key: const ValueKey('create-project-demo'),
              onPressed: () {
                final normalized = draftName.trim();
                if (normalized.isNotEmpty) {
                  Navigator.of(dialogContext).pop(
                    _NewProjectRequest(
                      name: normalized,
                      mode: _NewProjectMode.demo,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Демо'),
            ),
          FilledButton(
            key: const ValueKey('create-project-confirm'),
            onPressed: () {
              final normalized = draftName.trim();
              if (normalized.isNotEmpty) {
                Navigator.of(dialogContext).pop(
                  _NewProjectRequest(
                    name: normalized,
                    mode: canonicalAvailable
                        ? _NewProjectMode.wizard
                        : _NewProjectMode.blank,
                  ),
                );
              }
            },
            child: Text(
              canonicalAvailable ? 'Создать через Wizard' : 'Создать',
            ),
          ),
        ],
      ),
    );
    if (request == null || !mounted) return;

    final metadata = EditorProjectMetadata.create(projectName: request.name);
    final initialDocument = createInitialEditorProjectDocument(metadata);
    final store = await _storeFuture;
    try {
      await store.save(initialDocument);
    } catch (error, stackTrace) {
      final failure = _reportProjectHubError(
        error,
        stackTrace,
        code: ProductionDiagnosticCode.projectCreate,
        safeSummary: 'Не удалось создать проект на диске.',
        operation: 'while creating the initial project document',
      );
      _showSafeError(failure);
      return;
    }
    if (!mounted) return;

    if (request.mode == _NewProjectMode.demo) {
      try {
        final prepared = await _configureNewDemoProject(initialDocument);
        if (!mounted) return;
        if (prepared == null) {
          _reloadProjects();
          return;
        }
        await _openEditor(
          document: prepared.document,
          preparedCanonicalHandle: prepared.canonicalHandle,
        );
      } catch (error, stackTrace) {
        final failure = _reportProjectHubError(
          error,
          stackTrace,
          code: ProductionDiagnosticCode.projectCreate,
          safeSummary: 'Не удалось создать демонстрационный проект.',
          operation: 'while generating the canonical demo project',
        );
        _showSafeError(failure);
        _reloadProjects();
      }
      return;
    }

    if (request.mode == _NewProjectMode.wizard) {
      try {
        final prepared = await _configureNewProjectWithWizard(initialDocument);
        if (!mounted) return;
        if (prepared == null) {
          _reloadProjects();
          return;
        }
        await _openEditor(
          document: prepared.document,
          preparedCanonicalHandle: prepared.canonicalHandle,
        );
      } catch (error, stackTrace) {
        final failure = _reportProjectHubError(
          error,
          stackTrace,
          code: ProductionDiagnosticCode.projectWizardApply,
          safeSummary: 'Wizard не смог применить проект.',
          operation: 'while configuring a project through the wizard',
        );
        _showSafeError(failure);
        _reloadProjects();
      }
      return;
    }

    await _openEditor(document: initialDocument);
  }

  Future<_PreparedCanonicalProject?> _configureNewDemoProject(
    EditorProjectDocument initialDocument,
  ) async {
    final repository = widget.canonicalProjectRepository;
    if (repository == null) return null;
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: initialDocument,
      repository: repository,
    );
    final generated = await const CanonicalEditorDemoGenerator().generate(
      initialDocument: initialDocument,
      handle: handle,
    );
    final store = await _storeFuture;
    await store.save(generated.document);
    return _PreparedCanonicalProject(
      document: generated.document,
      canonicalHandle: generated.canonicalHandle,
    );
  }

  Future<_PreparedCanonicalProject?> _configureNewProjectWithWizard(
    EditorProjectDocument initialDocument,
  ) async {
    final repository = widget.canonicalProjectRepository;
    if (repository == null) return null;
    var handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: initialDocument,
      repository: repository,
    );
    if (!mounted) return null;
    final project = handle.session.project;
    final session = WizardSession(
      target: NewProjectWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: handle.wizardMutations,
    );
    final result = await ProjectWizardScreen.show(
      context: context,
      session: session,
      initialBuildingName: initialDocument.projectName,
    );
    if (result == null || !mounted) return null;

    const projector = CanonicalLegacyStructureProjector();
    final projected = projector.project(
      legacy: initialDocument,
      canonical: handle.session.project,
      binding: handle.binding,
    );

    handle.acceptWizardCommit(result);
    await handle.saveCanonical();
    final store = await _storeFuture;
    await store.save(projected);
    handle = handle.rebindToLegacy(projected);
    return _PreparedCanonicalProject(
      document: projected,
      canonicalHandle: handle,
    );
  }

  Future<void> _openEditor({
    EditorProjectDocument? document,
    EditorProjectRecoverySnapshot? recovery,
    EditorProjectMetadata? metadata,
    CanonicalEditorProductionHandle? preparedCanonicalHandle,
  }) async {
    final store = await _storeFuture;
    final recoveryStore = await _recoveryStoreFuture;
    var effectiveDocument = recovery?.document ?? document;
    var canonicalHandle = preparedCanonicalHandle;
    final canonicalRepository = widget.canonicalProjectRepository;
    if (effectiveDocument != null &&
        canonicalHandle == null &&
        canonicalRepository != null) {
      try {
        canonicalHandle = await CanonicalEditorProductionHandle.loadOrBootstrap(
          legacyDocument: effectiveDocument,
          repository: canonicalRepository,
        );
      } catch (error, stackTrace) {
        final failure = _reportProjectHubError(
          error,
          stackTrace,
          code: ProductionDiagnosticCode.canonicalProjectOpen,
          safeSummary: 'Canonical project state could not be opened safely.',
          operation: 'while opening canonical project state',
        );
        _showSafeError(failure);
        return;
      }
    }

    if (recovery == null &&
        effectiveDocument != null &&
        canonicalHandle != null) {
      const projector = CanonicalLegacyStructureProjector();
      try {
        if (projector.requiresProjection(
          legacy: effectiveDocument,
          canonical: canonicalHandle.owner.project,
          binding: canonicalHandle.binding,
        )) {
          final projected = projector.project(
            legacy: effectiveDocument,
            canonical: canonicalHandle.owner.project,
            binding: canonicalHandle.binding,
          );
          await store.save(projected);
          canonicalHandle = canonicalHandle.rebindToLegacy(projected);
          effectiveDocument = projected;
        }
      } catch (error, stackTrace) {
        final failure = _reportProjectHubError(
          error,
          stackTrace,
          code: ProductionDiagnosticCode.canonicalProjection,
          safeSummary: 'Структура проекта требует восстановления.',
          operation:
              'while projecting canonical state into the editor document',
        );
        _showSafeError(failure);
        return;
      }
    }
    if (!mounted) return;

    final editorStore = canonicalHandle == null
        ? store
        : CanonicalOwningEditorProjectStore(
            legacy: store,
            canonical: canonicalHandle,
          );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnifiedWorkspaceEditorScreen(
          projectStore: editorStore,
          recoveryStore: recoveryStore,
          initialDocument: recovery == null ? effectiveDocument : document,
          initialRecovery: recovery,
          initialMetadata: metadata,
          canonicalRuntime: canonicalHandle?.runtimeConfig,
        ),
      ),
    );
    _reloadProjects();
  }

  Future<void> _discardRecovery(EditorProjectRecoverySnapshot recovery) async {
    final store = await _recoveryStoreFuture;
    if (store == null || !mounted) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('discard-recovery-confirmation-dialog'),
            title: const Text('Удалить аварийную копию?'),
            content: const Text(
              'Несохранённые данные из этой аварийной копии будут удалены '
              'без возможности восстановления.',
            ),
            actions: [
              TextButton(
                key: const ValueKey('cancel-discard-recovery'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                key: const ValueKey('confirm-discard-recovery'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Удалить копию'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await store.discard(recovery.projectId);
      _reloadProjects();
    } catch (error, stackTrace) {
      final failure = _reportProjectHubError(
        error,
        stackTrace,
        code: ProductionDiagnosticCode.recoveryDiscard,
        safeSummary: 'Не удалось удалить аварийную копию.',
        operation: 'while discarding a recovery snapshot',
      );
      _showSafeError(failure);
    }
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
            return _ProjectLoadFailure(onRetry: _reloadProjects);
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
                      'Создайте новый проект, чтобы начать работу.',
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
                      'Созданные проекты появятся здесь после записи на диск.',
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

enum _NewProjectMode { wizard, blank, demo }

final class _NewProjectRequest {
  const _NewProjectRequest({required this.name, required this.mode});

  final String name;
  final _NewProjectMode mode;
}

final class _PreparedCanonicalProject {
  const _PreparedCanonicalProject({
    required this.document,
    required this.canonicalHandle,
  });

  final EditorProjectDocument document;
  final CanonicalEditorProductionHandle canonicalHandle;
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
            'Автокопия · rev ${recovery.revision} · '
            '${recovery.capturedAt.toLocal()} · '
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
  const _ProjectLoadFailure({required this.onRetry});

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
                  const Text(
                    'Повторите попытку. Подробности ошибки сохранены в диагностике. '
                    '[PX-HUB-001]',
                    textAlign: TextAlign.center,
                  ),
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
