import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/route_host.dart';
import 'context_minimap.dart';
import 'device_catalog_panel.dart';
import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_keyboard_scope.dart';
import 'editor_layout_policy.dart';
import 'editor_p2_session.dart';
import 'editor_project_document.dart';
import 'editor_project_recovery.dart';
import 'project_persistence_metadata.dart';
import 'project_save_diagnostics.dart';
import 'editor_shell_state.dart';
import 'editor_ui_tokens.dart';
import 'engineering_placement_cursor_hud.dart';
import 'project_compass_overlay.dart';
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
    this.initialMetadata,
  });

  /// Optional injection point used by tests and project-hub routing.
  /// Production lazily opens the application documents project store.
  final EditorProjectStore? projectStore;

  /// Recovery storage is intentionally separate from explicit project files.
  final EditorProjectRecoveryStore? recoveryStore;

  /// Debounce used by recovery autosave. Exposed for deterministic tests.
  final Duration autosaveDelay;

  /// When provided, the screen starts from the persisted canonical document
  /// instead of constructing the demo workspace.
  final EditorProjectDocument? initialDocument;

  /// Identity for a newly created unsaved project. The physical site keeps
  /// its own ids; project identity is independent and immutable.
  final EditorProjectMetadata? initialMetadata;

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
  String? _saveFailureHint;
  bool _projectIoBusy = false;
  late EditorProjectMetadata _projectMetadata;
  late EditorProjectSaveStatus _saveStatus;
  int _projectRevision = 0;
  int _savedRevision = 0;
  bool _allowPop = false;

  bool get _hasUnsavedChanges =>
      _projectRevision != _savedRevision ||
      _saveStatus == EditorProjectSaveStatus.saveFailed;

  @override
  void initState() {
    super.initState();
    final initialDocument = widget.initialDocument;
    if (initialDocument == null) {
      _projectMetadata = widget.initialMetadata ??
          EditorProjectMetadata.create(projectName: 'Новый проект');
      _saveStatus = EditorProjectSaveStatus.modified;
      _projectRevision = 1;
      _savedRevision = 0;
      controller = EditorController.demo()..addListener(_onProjectChanged);
      workspace = EditorBuildingWorkspace.demo(controller)
        ..addListener(_onProjectChanged);
    } else {
      _projectMetadata = initialDocument.metadata;
      _saveStatus = EditorProjectSaveStatus.saved;
      final restored = initialDocument.restore();
      controller = restored.editor..addListener(_onProjectChanged);
      workspace = restored.workspace..addListener(_onProjectChanged);
    }
    siteInteraction = SiteMapInteractionController();
    shell = EditorShellState()..addListener(_refresh);
    final injectedStore = widget.projectStore;
    if (injectedStore != null) {
      _projectStoreFuture = Future<EditorProjectStore>.value(injectedStore);
    }
    final injectedRecoveryStore = widget.recoveryStore;
    if (injectedRecoveryStore != null) {
      _recoveryStoreFuture =
          Future<EditorProjectRecoveryStore>.value(injectedRecoveryStore);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleAutosave();
      _offerRecoveryIfNewer();
    });
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

  void _onProjectChanged() {
    _projectRevision++;
    if (_saveStatus != EditorProjectSaveStatus.saving &&
        _saveStatus != EditorProjectSaveStatus.saveFailed) {
      _saveStatus = EditorProjectSaveStatus.modified;
    }
    _refresh();
    _scheduleAutosave();
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
    } catch (error) {
      debugPrint('ElecX recovery autosave skipped: $error');
    } finally {
      _autosaveInFlight = false;
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
        await store.discard(_projectMetadata.projectId);
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
    if (!_recoveryEnabled) return;
    try {
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.discard(_projectMetadata.projectId);
      _lastAutosavedRevision = -1;
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
      final detail =
          EditorProjectSaveDiagnostics.unexpectedPersistenceMessage(error);
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
    final previousController = controller;
    final previousWorkspace = workspace;

    previousWorkspace.removeListener(_onProjectChanged);
    previousController.removeListener(_onProjectChanged);
    previousController.disposeP2State();
    previousWorkspace.dispose();
    previousController.dispose();

    controller = restored.editor..addListener(_onProjectChanged);
    workspace = restored.workspace..addListener(_onProjectChanged);
    _projectMetadata = metadata;
    _projectRevision =
        markSaved ? 0 : (recoveryRevision <= 0 ? 1 : recoveryRevision);
    _savedRevision = 0;
    _saveStatus = markSaved
        ? EditorProjectSaveStatus.saved
        : EditorProjectSaveStatus.modified;
    _saveFailureHint = null;
    siteInteraction.clear();
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
    final current = workspace.site.site.projectNorth;
    final input = TextEditingController(
      text: current.northAzimuthDegrees.toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ориентация проекта'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Азимут севера',
            suffixText: '°',
            helperText: '0° = север вверх по плану, угол по часовой стрелке',
          ),
          onSubmitted: (text) {
            final parsed = double.tryParse(text.replaceAll(',', '.'));
            if (parsed != null && parsed >= 0 && parsed < 360) {
              Navigator.of(dialogContext).pop(parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(input.text.replaceAll(',', '.'));
              if (parsed == null || parsed < 0 || parsed >= 360) return;
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    input.dispose();
    if (value == null || !mounted) return;
    workspace.updateProjectNorth(
      current.copyWith(northAzimuthDegrees: value),
    );
  }

  void _openMiniMap() {
    showContextMiniMapSheet(
      context: context,
      workspace: workspace,
      siteInteraction: siteInteraction,
    );
  }

  void _openSiteEntity(SiteMapEntity entity) {
    switch (entity.kind) {
      case SiteMapEntityKind.outdoorZone:
        final id = entity.targetId;
        if (id != null) workspace.selectOutdoorZone(id);
      case SiteMapEntityKind.building:
        workspace.selectLevel(1);
      case SiteMapEntityKind.lot:
      case SiteMapEntityKind.network:
        break;
    }
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
    if (connection != null) {
      workspace.selectLevel(connection.levelNumber);
    }

    final surface = indoor.surface;
    if (surface == null) return;
    final preferredSpaceId = connection?.targetSpaceId ?? surface.spaceId;
    if (controller.level.spaces.any((space) => space.id == preferredSpaceId)) {
      controller.selectSpace(preferredSpaceId);
    } else if (controller.level.spaces.any(
      (space) => space.id == surface.spaceId,
    )) {
      controller.selectSpace(surface.spaceId);
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
    shell.removeListener(_refresh);
    shell.dispose();
    siteInteraction.dispose();
    workspace.removeListener(_onProjectChanged);
    workspace.dispose();
    controller.removeListener(_onProjectChanged);
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
            final planContext =
                workspace.context == EditorWorkspaceContext.siteOutdoor ||
                    controller.viewMode == EditorViewMode.plan;
            final canvas = Stack(
              children: [
                Positioned.fill(child: rawCanvas),
                if (planContext)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: ProjectCompassOverlay(
                      projectNorth: workspace.site.site.projectNorth,
                      onTap: _editProjectNorth,
                    ),
                  ),
                if (workspace.context != EditorWorkspaceContext.siteOutdoor)
                  Positioned(
                    right: 12,
                    bottom: 52,
                    child:
                        EngineeringPlacementCursorHud(controller: controller),
                  ),
              ],
            );

            return Scaffold(
              drawer: desktop
                  ? null
                  : Drawer(
                      width: EditorLayoutPolicy.navigatorWidth(mode),
                      child: SafeArea(
                        child: UnifiedSiteNavigator(
                          workspace: workspace,
                          interaction: siteInteraction,
                          onOpenSiteMap: _openMiniMap,
                          compact: true,
                        ),
                      ),
                    ),
              endDrawer: desktop
                  ? null
                  : Drawer(
                      width: EditorLayoutPolicy.inspectorWidth(mode),
                      child: SafeArea(
                        child: DeviceCatalogPanel(controller: controller),
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
                  if (shell.contextBarVisible)
                    _ContextStrip(workspace: workspace),
                  Expanded(
                    child: desktop
                        ? _DesktopWorkspace(
                            workspace: workspace,
                            shell: shell,
                            interaction: siteInteraction,
                            canvas: canvas,
                            onOpenMiniMap: _openMiniMap,
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
    required this.interaction,
    required this.canvas,
    required this.onOpenMiniMap,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final SiteMapInteractionController interaction;
  final Widget canvas;
  final VoidCallback onOpenMiniMap;

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
            child: UnifiedSiteNavigator(
              workspace: workspace,
              interaction: interaction,
              onOpenSiteMap: onOpenMiniMap,
            ),
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
  const _CatalogPanel({required this.controller, required this.onCollapse});

  final EditorController controller;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('Компоненты'),
            trailing: IconButton(
              tooltip: 'Свернуть каталог',
              onPressed: onCollapse,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: DeviceCatalogPanel(controller: controller)),
        ],
      );
}
