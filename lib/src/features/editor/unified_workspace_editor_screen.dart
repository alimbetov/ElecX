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
  });

  /// Optional injection point used by tests and future project-hub routing.
  /// Production lazily opens the application documents project store.
  final EditorProjectStore? projectStore;

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
  bool _projectIoBusy = false;

  @override
  void initState() {
    super.initState();
    controller = EditorController.demo()..addListener(_refresh);
    workspace = EditorBuildingWorkspace.demo(controller)..addListener(_refresh);
    siteInteraction = SiteMapInteractionController();
    shell = EditorShellState()..addListener(_refresh);
    final injectedStore = widget.projectStore;
    if (injectedStore != null) {
      _projectStoreFuture = Future<EditorProjectStore>.value(injectedStore);
    }
  }

  Future<EditorProjectStore> _projectStore() =>
      _projectStoreFuture ??= JsonFileEditorProjectStore.openDefault();

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProject() async {
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
    shell.removeListener(_refresh);
    shell.dispose();
    siteInteraction.dispose();
    workspace.removeListener(_refresh);
    workspace.dispose();
    controller.removeListener(_refresh);
    controller.disposeP2State();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditorKeyboardScope(
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
                  child: EngineeringPlacementCursorHud(controller: controller),
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
    required this.onSaveProject,
    required this.onOpenProject,
    required this.onOpenMiniMap,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final bool compact;
  final bool projectIoBusy;
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
            ? 'ElecX · ${workspace.site.site.name}'
            : 'ElecX · ${workspace.activeLevel?.displayName ?? ''}',
      ),
      actions: [
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
