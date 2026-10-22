import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/project_orientation.dart';
import '../../domain/route_host.dart';
import 'canonical_editor_production_runtime.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_editor_screen_cutover_binding.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_space_semantics_adapter.dart';
import 'canonical_project_navigator.dart';
import 'context_minimap.dart';
import 'device_catalog_panel.dart';
import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'editor_keyboard_scope.dart';
import 'editor_layout_policy.dart';
import 'editor_p2_session.dart';
import 'editor_project_document.dart';
import 'editor_project_recovery.dart';
import 'project_north_edit_dialog.dart';
import 'project_persistence_metadata.dart';
import 'project_save_diagnostics.dart';
import 'room_circuit_overview.dart';
import 'room_circuit_panel.dart';
import 'room_surface_navigator.dart';
import 'space_semantics_inspector.dart';
import 'space_semantics_inspector_editing.dart';
import 'editor_shell_state.dart';
import 'editor_ui_tokens.dart';
import 'engineering_placement_cursor_hud.dart';
import 'project_compass_overlay.dart';
import 'project_compass_projection.dart';
import 'site_map_canvas.dart';
import 'site_map_interaction.dart';
import 'spatial_canvas.dart';
import 'surface_canvas.dart';
import 'unified_icon_toolbar.dart';
import 'unified_site_navigator.dart';

class UnifiedWorkspaceEditorScreen extends StatefulWidget {
  const UnifiedWorkspaceEditorScreen({
    super.key,
    this.projectStore,
    this.recoveryStore,
    this.autosaveDelay = const Duration(seconds: 2),
    this.initialDocument,
    this.initialRecovery,
    this.initialMetadata,
    this.canonicalRuntime,
  }) : assert(initialDocument == null || initialRecovery == null);

  final EditorProjectStore? projectStore;
  final EditorProjectRecoveryStore? recoveryStore;
  final Duration autosaveDelay;
  final EditorProjectDocument? initialDocument;
  final EditorProjectRecoverySnapshot? initialRecovery;
  final EditorProjectMetadata? initialMetadata;
  final CanonicalEditorProductionRuntimeConfig? canonicalRuntime;

  @override
  State<UnifiedWorkspaceEditorScreen> createState() =>
      _UnifiedWorkspaceEditorScreenState();
}

class _UnifiedWorkspaceEditorScreenState
    extends State<UnifiedWorkspaceEditorScreen> {
  late EditorController controller;
  late EditorBuildingWorkspace workspace;
  late final SiteMapInteractionController siteInteraction;
  late final EditorShellState shell;
  Future<EditorProjectStore>? _projectStoreFuture;
  Future<EditorProjectRecoveryStore>? _recoveryStoreFuture;
  Timer? _autosaveTimer;
  bool _autosaveInFlight = false;
  int _lastAutosavedRevision = -1;
  int _recoveryGeneration = 0;
  String? _saveFailureHint;
  bool _projectIoBusy = false;
  late EditorProjectMetadata _projectMetadata;
  late EditorProjectSaveStatus _saveStatus;
  int _projectRevision = 0;
  int _savedRevision = 0;
  int _lastP2CommittedRevision = 0;
  bool _allowPop = false;
  CanonicalEditorResolvedRuntime? _canonicalResolvedRuntime;
  CanonicalEditorScreenCutoverBinding? _canonicalCutoverBinding;
  CanonicalEditorMaterializationResult? _canonicalBlocked;

  bool get _hasUnsavedChanges =>
      _projectRevision != _savedRevision ||
      _saveStatus == EditorProjectSaveStatus.saveFailed;

  bool get _canonicalRuntimeActive => _canonicalCutoverBinding != null;

  bool get _canonicalProjectMatchesScreen {
    final resolved = _canonicalResolvedRuntime;
    return resolved != null &&
        resolved.session.project.id.value == _projectMetadata.projectId;
  }

  bool get _canEditProjectNorth {
    final resolved = _canonicalResolvedRuntime;
    final config = widget.canonicalRuntime;
    if (resolved == null || config?.onProjectNorthCommitted == null) {
      return false;
    }
    if (!_canonicalProjectMatchesScreen) return false;

    final canonicalProject = resolved.session.project;
    final editing = resolved.session.projectNorthEditing;
    return editing.canEdit &&
        editing.projectId == canonicalProject.id &&
        editing.version == canonicalProject.version &&
        resolved.persistenceOwnerProjectId == canonicalProject.id;
  }

  bool get _canEditSpaceSemantics {
    final resolved = _canonicalResolvedRuntime;
    final config = widget.canonicalRuntime;
    if (resolved == null || config?.onSpaceSemanticsCommitted == null) {
      return false;
    }
    if (!_canonicalProjectMatchesScreen) return false;

    final canonicalProject = resolved.session.project;
    final editing = resolved.session.spaceSemanticsEditing;
    return editing.canEdit &&
        editing.projectId == canonicalProject.id &&
        editing.version == canonicalProject.version &&
        resolved.persistenceOwnerProjectId == canonicalProject.id;
  }

  CompassProjectionState _compassProjectionState() {
    if (_canonicalBlocked != null ||
        workspace.context == EditorWorkspaceContext.siteOutdoor ||
        controller.viewMode != EditorViewMode.plan ||
        !_canonicalProjectMatchesScreen) {
      return ProjectCompassProjection.unavailable;
    }

    final resolved = _canonicalResolvedRuntime;
    if (resolved == null) return ProjectCompassProjection.unavailable;
    return ProjectCompassProjection.forPlan(
      resolved.session.project.engineeringMetadata.projectNorth,
    );
  }

  @override
  void initState() {
    super.initState();
    final initialRecovery = widget.initialRecovery;
    final initialDocument = initialRecovery?.document ?? widget.initialDocument;
    if (initialDocument == null) {
      _projectMetadata = widget.initialMetadata ??
          EditorProjectMetadata.create(projectName: 'Новый проект');
      _saveStatus = EditorProjectSaveStatus.modified;
      _projectRevision = 1;
      _savedRevision = 0;
      controller = EditorController.blank(
        levelId: 'level-${_projectMetadata.projectId}-1',
      )..addListener(_onProjectChanged);
      workspace = EditorBuildingWorkspace.blank(
        controller,
        projectId: _projectMetadata.projectId,
        projectName: _projectMetadata.projectName,
      )..addListener(_onProjectChanged);
    } else {
      _projectMetadata = initialDocument.metadata;
      if (initialRecovery == null) {
        _saveStatus = EditorProjectSaveStatus.saved;
      } else {
        _saveStatus = EditorProjectSaveStatus.modified;
        _projectRevision =
            initialRecovery.revision > 0 ? initialRecovery.revision : 1;
        _savedRevision = 0;
        _lastAutosavedRevision = _projectRevision;
      }
      final restored = initialDocument.restore();
      controller = restored.editor..addListener(_onProjectChanged);
      workspace = restored.workspace..addListener(_onProjectChanged);
    }
    _lastP2CommittedRevision = controller.p2.history.mutationRevision;
    controller.p2.addListener(_onP2Changed);
    siteInteraction = SiteMapInteractionController();
    shell = EditorShellState()..addListener(_refresh);
    _installCanonicalRuntime(pushInitialCanonicalState: false);
    final injectedStore = widget.projectStore;
    if (injectedStore != null) {
      _projectStoreFuture = Future<EditorProjectStore>.value(injectedStore);
    }
    final injectedRecoveryStore = widget.recoveryStore;
    if (injectedRecoveryStore != null) {
      _recoveryStoreFuture = Future<EditorProjectRecoveryStore>.value(
        injectedRecoveryStore,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushCanonicalToEditor();
      _scheduleAutosave();
      if (widget.initialRecovery == null) {
        _offerRecoveryIfNewer();
      }
    });
  }

  @override
  void didUpdateWidget(covariant UnifiedWorkspaceEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.canonicalRuntime, widget.canonicalRuntime)) {
      _installCanonicalRuntime(pushInitialCanonicalState: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pushCanonicalToEditor();
      });
    }
  }

  Future<EditorProjectStore> _projectStore() =>
      _projectStoreFuture ??= JsonFileEditorProjectStore.openDefault();

  bool get _recoveryEnabled =>
      widget.recoveryStore != null || widget.projectStore == null;

  Future<EditorProjectRecoveryStore?> _recoveryStoreOrNull() async {
    if (!_recoveryEnabled) return null;
    return _recoveryStoreFuture ??=
        JsonFileEditorProjectRecoveryStore.openDefault();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onP2Changed() {
    final committed = controller.p2.history.mutationRevision;
    if (committed == _lastP2CommittedRevision) {
      _refresh();
      return;
    }
    _lastP2CommittedRevision = committed;
    _onProjectChanged();
  }

  void _onProjectChanged() {
    if (controller.isSurfaceNavigationNotification) return;

    if (_canonicalCutoverBinding?.coordinator.isSynchronizing == true) {
      _refresh();
      return;
    }
    _projectRevision++;
    if (_saveStatus != EditorProjectSaveStatus.saving &&
        _saveStatus != EditorProjectSaveStatus.saveFailed) {
      _saveStatus = EditorProjectSaveStatus.modified;
    }
    _refresh();
    _scheduleAutosave();
  }

  void _installCanonicalRuntime({required bool pushInitialCanonicalState}) {
    _canonicalCutoverBinding?.dispose();
    _canonicalResolvedRuntime = null;
    _canonicalCutoverBinding = null;
    _canonicalBlocked = null;

    final config = widget.canonicalRuntime;
    if (config == null) return;

    try {
      final resolved = config.resolveRuntime(workspace, _projectMetadata);
      if (resolved == null) return;
      final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
        session: resolved.session,
        adapter: CanonicalEditorWorkspaceAdapter(
          workspace: workspace,
          binding: resolved.binding,
        ),
        materializer: resolved.materializer,
      );
      final topologyOwner = resolved.persistenceOwnerProjectId ==
                  resolved.session.project.id &&
              resolved.session.project.id.value == _projectMetadata.projectId
          ? config.onBoundaryTopologyCommitted
          : null;
      final binding = CanonicalEditorScreenCutoverBinding(
        coordinator: coordinator,
        onCanonicalNavigationChanged: (_) {
          _canonicalBlocked = null;
          _refresh();
        },
        onBoundaryTopologyCommitted: topologyOwner == null
            ? null
            : (editing, result) {
                topologyOwner(editing, result);
                _refresh();
              },
        onBlocked: _handleCanonicalBlocked,
        onError: _reportCanonicalCutoverError,
      );
      binding.start(pushInitialCanonicalState: pushInitialCanonicalState);
      _canonicalResolvedRuntime = resolved;
      _canonicalCutoverBinding = binding;
    } catch (error, stackTrace) {
      _reportCanonicalCutoverError(error, stackTrace);
      _canonicalResolvedRuntime = null;
      _canonicalCutoverBinding = null;
    }
  }

  void _disposeCanonicalRuntime() {
    _canonicalCutoverBinding?.dispose();
    _canonicalResolvedRuntime = null;
    _canonicalCutoverBinding = null;
    _canonicalBlocked = null;
  }

  void _handleCanonicalBlocked(CanonicalEditorMaterializationResult result) {
    _canonicalBlocked = result;
    _refresh();
  }

  void _reportCanonicalCutoverError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'ElecX canonical editor cutover',
      ),
    );
  }

  CanonicalEditorMaterializationResult? _pushCanonicalToEditor() {
    final binding = _canonicalCutoverBinding;
    if (binding == null) return null;
    try {
      final result = binding.pushCanonicalToEditor();
      if (result.canOpen && _canonicalBlocked != null) {
        _canonicalBlocked = null;
        _refresh();
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Widget? _spaceSemanticsInspector({required bool compact}) {
    final resolved = _canonicalResolvedRuntime;
    final config = widget.canonicalRuntime;
    if (resolved == null || config == null || !_canonicalProjectMatchesScreen) {
      return null;
    }
    final spaceId = resolved.session.navigation.selectedSpaceId;
    if (spaceId == null) return null;

    late final CanonicalSpaceSemanticsProjection projection;
    try {
      projection = CanonicalSpaceSemanticsAdapter(
        workspace: workspace,
        binding: resolved.binding,
      ).resolve(project: resolved.session.project, spaceId: spaceId);
    } on CanonicalSpaceSemanticsException {
      return null;
    } catch (error, stackTrace) {
      _reportCanonicalCutoverError(error, stackTrace);
      return null;
    }

    final editing = resolved.session.spaceSemanticsEditing;
    final coordinator = SpaceSemanticsInspectorEditingCoordinator(editing);
    final onUsageChanged = _canEditSpaceSemantics
        ? (usage) {
            try {
              final result = coordinator.setUsage(projection, usage);
              if (result == null) return;
              controller.documentHistory.recordCanonicalCommit(
                session: resolved.session,
                label: result.changeSet.commandType,
                rematerialize: () {
                  _pushCanonicalToEditor();
                },
              );
              try {
                config.onSpaceSemanticsCommitted?.call(editing, result);
              } finally {
                _refresh();
              }
            } catch (error, stackTrace) {
              _reportCanonicalCutoverError(error, stackTrace);
            }
          }
        : null;

    return ConstrainedBox(
      key: const ValueKey('space-semantics-production-inspector'),
      constraints: BoxConstraints(maxHeight: compact ? 360 : 320),
      child: SingleChildScrollView(
        child: SpaceSemanticsInspector(
          projection: projection,
          onUsageChanged: onUsageChanged,
        ),
      ),
    );
  }

  Widget _projectNavigator({required bool compact}) {
    final cutover = _canonicalCutoverBinding;
    final config = widget.canonicalRuntime;
    if (cutover == null || config == null) {
      return UnifiedSiteNavigator(
        workspace: workspace,
        interaction: siteInteraction,
        onOpenSiteMap: _openMiniMap,
        compact: compact,
      );
    }

    final session = cutover.coordinator.session;
    final selectedCanonicalSpaceId = session.navigation.selectedSpaceId;
    final selectedLegacySpaceId = selectedCanonicalSpaceId == null
        ? null
        : cutover.coordinator.adapter.binding
            .legacySpaceIds[selectedCanonicalSpaceId];
    final authoringEnabled = config.authoringEnabled;
    final navigator = CanonicalProjectNavigator(
      session: session,
      requestBuilding: authoringEnabled ? config.requestBuilding : null,
      requestLevel: authoringEnabled ? config.requestLevel : null,
      requestRoom: authoringEnabled ? config.requestRoom : null,
      onNavigationChanged: (_) {
        _pushCanonicalToEditor();
        _refresh();
      },
      onAuthoringCommitted: authoringEnabled
          ? (session, createdId) {
              controller.documentHistory.recordCanonicalCommit(
                session: session,
                label: 'Edit project structure',
                rematerialize: () {
                  _pushCanonicalToEditor();
                },
              );
              try {
                config.onAuthoringCommitted?.call(session, createdId);
              } finally {
                _pushCanonicalToEditor();
                _refresh();
              }
            }
          : null,
      onError: (error) =>
          _reportCanonicalCutoverError(error, StackTrace.current),
      compact: compact,
    );

    return Column(
      children: [
        Expanded(child: navigator),
        RoomSurfaceNavigator(
          controller: controller,
          canonicalSpaceId: selectedCanonicalSpaceId,
          legacySpaceId: selectedLegacySpaceId,
          collapsed: shell.roomSurfaceNavigatorCollapsed,
          onToggleCollapsed: shell.toggleRoomSurfaceNavigatorCollapsed,
        ),
      ],
    );
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (!_recoveryEnabled || !_hasUnsavedChanges) return;
    _autosaveTimer = Timer(widget.autosaveDelay, _writeRecoverySnapshot);
  }

  Future<void> _writeRecoverySnapshot() async {
    if (!mounted ||
        _autosaveInFlight ||
        _projectIoBusy ||
        !_hasUnsavedChanges ||
        _lastAutosavedRevision == _projectRevision) {
      return;
    }
    final issue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (issue != null) return;
    final revision = _projectRevision;
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
    } catch (error) {
      debugPrint('ElecX recovery autosave skipped: $error');
    } finally {
      _autosaveInFlight = false;
      if (mounted &&
          generation == _recoveryGeneration &&
          _hasUnsavedChanges &&
          _lastAutosavedRevision != _projectRevision) {
        _scheduleAutosave();
      }
    }
  }

  Future<void> _offerRecoveryIfNewer() async {
    if (!_recoveryEnabled) return;
    try {
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      final snapshot = await store.load(_projectMetadata.projectId);
      if (!mounted || snapshot == null) return;
      if (!snapshot.capturedAt.isAfter(_projectMetadata.updatedAt)) {
        await store.discard(snapshot.projectId);
        return;
      }
      final restore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('project-recovery-dialog'),
          title: const Text('Найдена аварийная копия'),
          content: Text(
            'Есть более свежая автокопия от ${snapshot.capturedAt.toLocal()}. '
            'Восстановить несохранённые изменения?',
          ),
          actions: [
            TextButton(
              key: const ValueKey('discard-project-recovery'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Удалить копию'),
            ),
            FilledButton(
              key: const ValueKey('restore-project-recovery'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (restore == true) {
        final restored = snapshot.document.restore();
        _replaceProject(
          restored,
          snapshot.document.metadata,
          markSaved: false,
          recoveryRevision: snapshot.revision,
        );
        _lastAutosavedRevision = snapshot.revision;
        _showProjectMessage('Восстановлена аварийная копия');
      } else if (restore == false) {
        await store.discard(snapshot.projectId);
      }
    } catch (error) {
      debugPrint('ElecX recovery lookup skipped: $error');
    }
  }

  Future<void> _discardRecoveryBestEffort() async {
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
    } catch (error) {
      debugPrint('ElecX recovery cleanup skipped: $error');
    }
  }

  Future<void> _showSaveFailure({
    required String title,
    required String detail,
  }) async {
    if (!mounted) return;
    setState(() {
      _saveStatus = EditorProjectSaveStatus.saveFailed;
      _saveFailureHint = detail;
    });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('save-failure-dialog'),
        title: Text(title),
        content: Text(detail),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProject() async {
    if (_projectIoBusy) return;
    final blockingIssue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (blockingIssue != null) {
      await _showSaveFailure(
        title: blockingIssue.title,
        detail: blockingIssue.detail,
      );
      return;
    }
    final revisionAtCapture = _projectRevision;
    final touchedMetadata = _projectMetadata.touch();
    setState(() {
      _projectIoBusy = true;
      _saveStatus = EditorProjectSaveStatus.saving;
    });
    try {
      final document = EditorProjectDocument.capture(
        workspace,
        metadata: touchedMetadata,
      );
      final store = await _projectStore();
      await store.save(document);
      if (!mounted) return;
      _projectMetadata = touchedMetadata;
      _savedRevision = revisionAtCapture;
      _saveFailureHint = null;
      _saveStatus = _projectRevision == revisionAtCapture
          ? EditorProjectSaveStatus.saved
          : EditorProjectSaveStatus.modified;
      if (_projectRevision == revisionAtCapture) {
        await _discardRecoveryBestEffort();
      } else {
        _scheduleAutosave();
      }
      _showProjectMessage('Проект сохранён');
    } on EditorProjectSaveBlockedException catch (error) {
      if (!mounted) return;
      await _showSaveFailure(
        title: error.issue.title,
        detail: error.issue.detail,
      );
    } catch (error) {
      if (!mounted) return;
      final detail = EditorProjectSaveDiagnostics.unexpectedPersistenceMessage(
        error,
      );
      await _showSaveFailure(
        title: 'Не удалось сохранить проект',
        detail: detail,
      );
    } finally {
      if (mounted) {
        setState(() => _projectIoBusy = false);
      }
    }
  }

  Future<void> _openSavedProject() async {
    if (_projectIoBusy) return;
    if (_hasUnsavedChanges &&
        !await _confirmDiscardChanges(
          title: 'Открыть сохранённую версию?',
          message: 'Несохранённые изменения текущей версии будут потеряны.',
        )) {
      return;
    }
    await _discardRecoveryBestEffort();
    setState(() => _projectIoBusy = true);
    try {
      final projectId = _projectMetadata.projectId;
      final store = await _projectStore();
      final document = await store.load(projectId);
      if (!mounted) return;
      if (document == null) {
        _showProjectMessage('Сохранённая версия проекта не найдена');
        return;
      }
      final restored = document.restore();
      _replaceProject(restored, document.metadata);
      _showProjectMessage('Проект открыт из сохранённой версии');
    } catch (error) {
      if (!mounted) return;
      _showProjectMessage('Не удалось открыть проект: $error', isError: true);
    } finally {
      if (mounted) setState(() => _projectIoBusy = false);
    }
  }

  void _replaceProject(
    RestoredEditorProject restored,
    EditorProjectMetadata metadata, {
    bool markSaved = true,
    int recoveryRevision = 1,
  }) {
    _recoveryGeneration++;
    final previousController = controller;
    final previousWorkspace = workspace;

    _disposeCanonicalRuntime();
    previousWorkspace.removeListener(_onProjectChanged);
    previousController.removeListener(_onProjectChanged);
    previousController.p2.removeListener(_onP2Changed);
    previousController.disposeDocumentHistory();
    previousController.disposeP2State();
    previousWorkspace.dispose();
    previousController.dispose();

    controller = restored.editor..addListener(_onProjectChanged);
    workspace = restored.workspace..addListener(_onProjectChanged);
    _lastP2CommittedRevision = controller.p2.history.mutationRevision;
    controller.p2.addListener(_onP2Changed);
    _projectMetadata = metadata;
    _projectRevision =
        markSaved ? 0 : (recoveryRevision <= 0 ? 1 : recoveryRevision);
    _savedRevision = 0;
    _saveStatus = markSaved
        ? EditorProjectSaveStatus.saved
        : EditorProjectSaveStatus.modified;
    _saveFailureHint = null;
    siteInteraction.clear();
    _installCanonicalRuntime(pushInitialCanonicalState: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pushCanonicalToEditor();
    });
    setState(() {});
  }

  Future<bool> _confirmDiscardChanges({
    required String title,
    required String message,
  }) async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('unsaved-project-dialog'),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            key: const ValueKey('discard-unsaved-project'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Не сохранять'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _confirmCloseFromBack() async {
    final discard = await _confirmDiscardChanges(
      title: 'Закрыть проект?',
      message: 'Есть несохранённые изменения.',
    );
    if (!discard || !mounted) return;
    await _discardRecoveryBestEffort();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  void _showProjectMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.errorContainer : null,
        ),
      );
  }

  Future<void> _editProjectNorth() async {
    final resolved = _canonicalResolvedRuntime;
    final config = widget.canonicalRuntime;
    if (!_canEditProjectNorth || resolved == null || config == null) {
      _showProjectMessage(
        'Редактирование Project North недоступно без canonical persistence owner.',
        isError: true,
      );
      return;
    }

    final editing = resolved.session.projectNorthEditing;
    final capturedProjectId = editing.projectId;
    final capturedVersion = editing.version;
    final ownerCallback = config.onProjectNorthCommitted!;

    final value = await showDialog<ProjectEngineeringNorth>(
      context: context,
      builder: (_) =>
          ProjectNorthEditDialog(initialValue: editing.currentProjectNorth),
    );
    if (value == null || !mounted) return;

    final currentResolved = _canonicalResolvedRuntime;
    final currentConfig = widget.canonicalRuntime;
    final currentEditing = resolved.session.projectNorthEditing;
    final currentProject = resolved.session.project;
    final affinityValid = identical(currentResolved, resolved) &&
        identical(currentConfig, config) &&
        _canonicalProjectMatchesScreen &&
        currentProject.id == capturedProjectId &&
        currentProject.version == capturedVersion &&
        currentEditing.canEdit &&
        currentEditing.projectId == capturedProjectId &&
        currentEditing.version == capturedVersion &&
        resolved.persistenceOwnerProjectId == capturedProjectId &&
        currentConfig?.onProjectNorthCommitted != null;
    if (!affinityValid) {
      _showProjectMessage(
        'Project North не изменён: canonical edit context изменился во время редактирования.',
        isError: true,
      );
      _refresh();
      return;
    }

    ProjectMutationResult? result;
    try {
      result = currentEditing.setProjectNorth(
        value,
        expectedVersion: capturedVersion,
      );
    } catch (error) {
      _showProjectMessage(
        'Не удалось изменить Project North: $error',
        isError: true,
      );
      return;
    }

    if (result == null) {
      _refresh();
      return;
    }

    final afterProject = resolved.session.project;
    if (afterProject.id != capturedProjectId ||
        afterProject.version.value != capturedVersion.value + 1 ||
        currentEditing.version != afterProject.version ||
        currentEditing.currentProjectNorth !=
            afterProject.engineeringMetadata.projectNorth ||
        result.project.id != afterProject.id ||
        result.project.version != afterProject.version ||
        result.changeSet.beforeVersion != capturedVersion ||
        result.changeSet.afterVersion != afterProject.version) {
      _showProjectMessage(
        'Project North committed, но canonical runtime потерял mutation affinity.',
        isError: true,
      );
      _refresh();
      return;
    }

    controller.documentHistory.recordCanonicalCommit(
      session: resolved.session,
      label: result.changeSet.commandType,
      rematerialize: () {
        _pushCanonicalToEditor();
      },
    );

    try {
      ownerCallback(currentEditing, result);
    } catch (error) {
      _showProjectMessage(
        'Project North committed, но persistence owner не подтвердил владение: $error',
        isError: true,
      );
      _refresh();
      return;
    }

    _refresh();
  }

  void _openMiniMap() {
    showContextMiniMapSheet(
      context: context,
      workspace: workspace,
      siteInteraction: siteInteraction,
      onEntityOpen: _canonicalRuntimeActive ? _openSiteEntity : null,
      onSpaceSelected:
          _canonicalRuntimeActive ? _selectLegacySpaceThroughCanonical : null,
    );
  }

  void _openSiteEntity(SiteMapEntity entity) {
    switch (entity.kind) {
      case SiteMapEntityKind.outdoorZone:
        final id = entity.targetId;
        if (id != null) workspace.selectOutdoorZone(id);
      case SiteMapEntityKind.building:
        final cutover = _canonicalCutoverBinding;
        if (cutover == null) {
          workspace.selectLevel(1);
          return;
        }
        cutover.coordinator.session.activateBuilding(
          cutover.coordinator.adapter.binding.buildingId,
        );
        _pushCanonicalToEditor();
        _refresh();
      case SiteMapEntityKind.lot:
      case SiteMapEntityKind.network:
        break;
    }
  }

  void _selectLegacySpaceThroughCanonical(String legacySpaceId) {
    final cutover = _canonicalCutoverBinding;
    if (cutover == null) {
      controller.selectSpace(legacySpaceId);
      return;
    }
    final canonicalSpaceId = cutover.coordinator.adapter.binding
        .canonicalSpaceIdForLegacy(legacySpaceId);
    if (canonicalSpaceId == null) {
      _handleCanonicalBlocked(
        CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          message: 'Legacy Space $legacySpaceId has no canonical binding.',
        ),
      );
      return;
    }
    cutover.coordinator.session.selectRoom(canonicalSpaceId);
    _pushCanonicalToEditor();
    _refresh();
  }

  void _followOutdoorTransition(RouteHostTransition transition) {
    final outdoor = transition.fromHost.kind == RouteHostKind.outdoorZone
        ? transition.fromHost
        : transition.toHost.kind == RouteHostKind.outdoorZone
            ? transition.toHost
            : null;
    final zoneId = outdoor?.outdoorZoneId;
    if (zoneId == null) return;
    workspace.selectOutdoorZone(zoneId);
    siteInteraction.select('outdoor:$zoneId');
  }

  void _followSiteTransition(RouteHostTransition transition) {
    final indoor = transition.fromHost.kind == RouteHostKind.indoorSurface
        ? transition.fromHost
        : transition.toHost.kind == RouteHostKind.indoorSurface
            ? transition.toHost
            : null;
    if (indoor == null) return;

    final connectionId = transition.siteConnectionId;
    final connection = connectionId == null
        ? null
        : workspace.site.connections
            .where((item) => item.id == connectionId)
            .firstOrNull;

    final surface = indoor.surface;
    if (surface == null) return;
    final preferredSpaceId = connection?.targetSpaceId ?? surface.spaceId;

    if (_canonicalRuntimeActive) {
      _selectLegacySpaceThroughCanonical(preferredSpaceId);
      if (controller.selectedSpaceId != preferredSpaceId) return;
    } else {
      if (connection != null) {
        workspace.selectLevel(connection.levelNumber);
      }
      if (controller.level.spaces.any(
        (space) => space.id == preferredSpaceId,
      )) {
        controller.selectSpace(preferredSpaceId);
      } else if (controller.level.spaces.any(
        (space) => space.id == surface.spaceId,
      )) {
        controller.selectSpace(surface.spaceId);
      }
    }

    switch (surface.type) {
      case SurfacePlaneType.wall:
        if (controller.selectedSpaceId == surface.spaceId) {
          controller.showWall(surface.wallIndex!);
        } else if (controller.selectedSpace != null) {
          controller.showWall(surface.wallIndex ?? 0);
        }
      case SurfacePlaneType.floor:
        controller.showFloor();
      case SurfacePlaneType.ceiling:
        controller.showCeiling();
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _disposeCanonicalRuntime();
    shell.removeListener(_refresh);
    shell.dispose();
    siteInteraction.dispose();
    workspace.removeListener(_onProjectChanged);
    workspace.dispose();
    controller.removeListener(_onProjectChanged);
    controller.p2.removeListener(_onP2Changed);
    controller.disposeDocumentHistory();
    controller.disposeP2State();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmCloseFromBack();
      },
      child: EditorKeyboardScope(
        controller: controller,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mode = EditorLayoutPolicy.forWidth(constraints.maxWidth);
            final desktop = mode == EditorLayoutMode.desktop;
            final canvas = AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final rawCanvas =
                    workspace.context == EditorWorkspaceContext.siteOutdoor
                        ? SiteMapCanvas(
                            entities: SiteMapProjection.tower(workspace),
                            interaction: siteInteraction,
                            routeController: controller,
                            onRouteTransitionTap: _followSiteTransition,
                            onEntityOpen: _openSiteEntity,
                          )
                        : controller.viewMode == EditorViewMode.plan
                            ? SpatialCanvas(controller: controller)
                            : SurfaceCanvas(
                                controller: controller,
                                onOutdoorTransition: _followOutdoorTransition,
                              );
                final compassProjection = _compassProjectionState();
                return Stack(
                  children: [
                    Positioned.fill(child: rawCanvas),
                    if (shell.compassVisible)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: ProjectCompassOverlay(
                          state: compassProjection,
                          onTap:
                              _canEditProjectNorth ? _editProjectNorth : null,
                        ),
                      ),
                    if (workspace.context != EditorWorkspaceContext.siteOutdoor)
                      Positioned(
                        right: 12,
                        bottom: 52,
                        child: EngineeringPlacementCursorHud(
                          controller: controller,
                        ),
                      ),
                  ],
                );
              },
            );

            return Scaffold(
              drawer: desktop
                  ? null
                  : Drawer(
                      width: EditorLayoutPolicy.navigatorWidth(mode),
                      child: SafeArea(child: _projectNavigator(compact: true)),
                    ),
              endDrawer: desktop
                  ? null
                  : Drawer(
                      width: EditorLayoutPolicy.inspectorWidth(mode),
                      child: SafeArea(
                        child: Column(
                          children: [
                            if (_spaceSemanticsInspector(compact: true)
                                case final semanticsInspector?) ...[
                              semanticsInspector,
                              const Divider(height: 1),
                            ],
                            RoomCircuitOverviewPanel(controller: controller),
                            RoomCircuitPanel(controller: controller),
                            const Divider(height: 1),
                            Expanded(
                              child: DeviceCatalogPanel(controller: controller),
                            ),
                          ],
                        ),
                      ),
                    ),
              appBar: _WorkspaceAppBar(
                workspace: workspace,
                shell: shell,
                compact: !desktop,
                projectIoBusy: _projectIoBusy,
                projectMetadata: _projectMetadata,
                saveStatus: _saveStatus,
                saveFailureHint: _saveFailureHint,
                onSaveProject: _saveProject,
                onOpenProject: _openSavedProject,
                onOpenMiniMap: _openMiniMap,
              ),
              body: Column(
                children: [
                  UnifiedEditorIconToolbar(
                    controller: controller,
                    compact: !desktop,
                  ),
                  if (_canonicalBlocked != null)
                    _CanonicalCutoverBlockedBanner(result: _canonicalBlocked!),
                  if (shell.contextBarVisible)
                    _ContextStrip(workspace: workspace),
                  Expanded(
                    child: desktop
                        ? _DesktopWorkspace(
                            workspace: workspace,
                            shell: shell,
                            canvas: canvas,
                            navigator: _projectNavigator(compact: false),
                            semanticsInspector: _spaceSemanticsInspector(
                              compact: false,
                            ),
                          )
                        : Stack(
                            children: [
                              Positioned.fill(child: canvas),
                              Positioned(
                                left: 10,
                                bottom: 10,
                                child: _ContextBadge(workspace: workspace),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.workspace,
    required this.shell,
    required this.canvas,
    required this.navigator,
    required this.semanticsInspector,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final Widget canvas;
  final Widget navigator;
  final Widget? semanticsInspector;

  @override
  Widget build(BuildContext context) {
    if (shell.focusMode) {
      return Padding(
        padding: const EdgeInsets.all(EditorUiTokens.canvasInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(EditorUiTokens.panelRadius),
          child: canvas,
        ),
      );
    }

    return Row(
      children: [
        if (shell.navigatorVisible)
          SizedBox(
            width: EditorUiTokens.desktopNavigatorWidth,
            child: navigator,
          )
        else
          _SideRail(
            icon: Icons.account_tree_outlined,
            tooltip: 'Показать навигатор',
            onPressed: shell.toggleNavigator,
          ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(EditorUiTokens.canvasInset),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EditorUiTokens.panelRadius),
              child: canvas,
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        if (shell.inspectorVisible)
          SizedBox(
            width: EditorUiTokens.desktopInspectorWidth,
            child: _CatalogPanel(
              controller: workspace.editor,
              onCollapse: shell.toggleInspector,
              semanticsInspector: semanticsInspector,
            ),
          )
        else
          _SideRail(
            icon: Icons.widgets_outlined,
            tooltip: 'Показать каталог оборудования',
            onPressed: shell.toggleInspector,
          ),
      ],
    );
  }
}

class _CanonicalCutoverBlockedBanner extends StatelessWidget {
  const _CanonicalCutoverBlockedBanner({required this.result});

  final CanonicalEditorMaterializationResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('canonical-cutover-blocked'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message ?? 'Текущий объект пока нельзя открыть на canvas.',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _WorkspaceAppBar({
    required this.workspace,
    required this.shell,
    required this.compact,
    required this.projectIoBusy,
    required this.projectMetadata,
    required this.saveStatus,
    required this.saveFailureHint,
    required this.onSaveProject,
    required this.onOpenProject,
    required this.onOpenMiniMap,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final bool compact;
  final bool projectIoBusy;
  final EditorProjectMetadata projectMetadata;
  final EditorProjectSaveStatus saveStatus;
  final String? saveFailureHint;
  final VoidCallback onSaveProject;
  final VoidCallback onOpenProject;
  final VoidCallback onOpenMiniMap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: compact ? 4 : 12,
      title: Text(
        workspace.context == EditorWorkspaceContext.siteOutdoor
            ? 'ElecX · ${projectMetadata.projectName}'
            : 'ElecX · ${projectMetadata.projectName} · ${workspace.activeLevel?.displayName ?? ''}',
      ),
      actions: [
        if (!compact)
          Padding(
            key: const ValueKey('project-save-status'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Tooltip(
                message: saveFailureHint ?? saveStatus.label,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (saveStatus == EditorProjectSaveStatus.saveFailed) ...[
                      const Icon(Icons.error_outline, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      saveStatus.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        IconButton(
          key: const ValueKey('project-open'),
          tooltip: 'Открыть сохранённую версию',
          onPressed: projectIoBusy ? null : onOpenProject,
          icon: const Icon(Icons.folder_open_outlined),
        ),
        IconButton(
          key: const ValueKey('project-save'),
          tooltip: 'Сохранить проект',
          onPressed: projectIoBusy ? null : onSaveProject,
          icon: projectIoBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
        ),
        Semantics(
          label: 'Compass',
          checked: shell.compassRequestedVisible,
          button: true,
          child: IconButton(
            key: const ValueKey('project-compass-toggle'),
            tooltip: shell.compassRequestedVisible
                ? 'Скрыть компас'
                : 'Показать компас',
            onPressed: shell.toggleCompass,
            icon: Icon(
              shell.compassRequestedVisible
                  ? Icons.explore
                  : Icons.explore_outlined,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Контекстная карта',
          onPressed: onOpenMiniMap,
          icon: const Icon(Icons.map_outlined),
        ),
        IconButton(
          tooltip: shell.focusMode ? 'Выйти из Focus' : 'Focus mode',
          onPressed: shell.toggleFocusMode,
          icon: Icon(
            shell.focusMode ? Icons.fullscreen_exit : Icons.fullscreen,
          ),
        ),
        if (!compact)
          IconButton(
            tooltip: 'Показать / скрыть контекст',
            onPressed: shell.toggleContextBar,
            icon: const Icon(Icons.info_outline),
          ),
      ],
    );
  }
}

class _ContextStrip extends StatelessWidget {
  const _ContextStrip({required this.workspace});

  final EditorBuildingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final label = workspace.context == EditorWorkspaceContext.siteOutdoor
        ? 'Площадка · ${workspace.site.site.name}'
        : 'Уровень ${workspace.activeLevel?.displayName ?? ''} · '
            '${workspace.selectedZone?.name ?? workspace.editor.selectedSpace?.name ?? 'без выбора'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.workspace});

  final EditorBuildingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final label = workspace.context == EditorWorkspaceContext.siteOutdoor
        ? workspace.site.site.name
        : '${workspace.activeLevel?.displayName ?? ''} · '
            '${workspace.editor.selectedSpace?.name ?? 'без помещения'}';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: Icon(icon),
            ),
          ),
        ),
      );
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({
    required this.controller,
    required this.onCollapse,
    required this.semanticsInspector,
  });

  final EditorController controller;
  final VoidCallback onCollapse;
  final Widget? semanticsInspector;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('Компоненты'),
            trailing: IconButton(
              tooltip: 'Свернуть каталог',
              onPressed: onCollapse,
              icon: Icon(Icons.chevron_right),
            ),
          ),
          const Divider(height: 1),
          if (semanticsInspector != null) ...[
            semanticsInspector!,
            const Divider(height: 1),
          ],
          RoomCircuitOverviewPanel(controller: controller),
          RoomCircuitPanel(controller: controller),
          const Divider(height: 1),
          Expanded(child: DeviceCatalogPanel(controller: controller)),
        ],
      );
}
