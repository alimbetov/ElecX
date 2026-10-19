import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import '../../domain/route_host.dart';
import 'context_minimap.dart';
import 'device_catalog_panel.dart';
import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_keyboard_scope.dart';
import 'editor_layout_policy.dart';
import 'editor_shell_state.dart';
import 'editor_ui_tokens.dart';
import 'engineering_placement_cursor_hud.dart';
import 'site_map_canvas.dart';
import 'site_map_interaction.dart';
import 'spatial_canvas.dart';
import 'surface_canvas.dart';
import 'unified_icon_toolbar.dart';
import 'unified_site_navigator.dart';

class UnifiedWorkspaceEditorScreen extends StatefulWidget {
  const UnifiedWorkspaceEditorScreen({super.key});

  @override
  State<UnifiedWorkspaceEditorScreen> createState() =>
      _UnifiedWorkspaceEditorScreenState();
}

class _UnifiedWorkspaceEditorScreenState
    extends State<UnifiedWorkspaceEditorScreen> {
  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final SiteMapInteractionController siteInteraction;
  late final EditorShellState shell;

  @override
  void initState() {
    super.initState();
    controller = EditorController.demo()..addListener(_refresh);
    workspace = EditorBuildingWorkspace.demo(controller)..addListener(_refresh);
    siteInteraction = SiteMapInteractionController();
    shell = EditorShellState()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
    } else if (controller.level.spaces
        .any((space) => space.id == surface.spaceId)) {
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
          final canvas = Stack(
            children: [
              Positioned.fill(child: rawCanvas),
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
    required this.onOpenMiniMap,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final bool compact;
  final VoidCallback onOpenMiniMap;

  @override
  Size get preferredSize => const Size.fromHeight(EditorUiTokens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final editor = workspace.editor;
    return AppBar(
      toolbarHeight: EditorUiTokens.appBarHeight,
      titleSpacing: compact ? 6 : 12,
      title: Row(
        children: [
          const Icon(Icons.electric_bolt_outlined, size: 19),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              compact ? 'ElecX' : _contextPath(workspace),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      actions: [
        if (!compact)
          IconButton(
            tooltip: shell.navigatorVisible
                ? 'Свернуть навигатор'
                : 'Показать навигатор',
            onPressed: shell.toggleNavigator,
            icon: Icon(
              shell.navigatorVisible
                  ? Icons.keyboard_double_arrow_left
                  : Icons.keyboard_double_arrow_right,
              size: 19,
            ),
          ),
        IconButton(
          tooltip: 'Микро-карта',
          onPressed: onOpenMiniMap,
          icon: const Icon(Icons.map_outlined, size: 19),
        ),
        if (workspace.context == EditorWorkspaceContext.buildingLevel) ...[
          IconButton(
            tooltip: 'Предыдущий уровень',
            onPressed: workspace.previousLevel,
            icon: const Icon(Icons.keyboard_arrow_down, size: 19),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  child: Text(
                    workspace.activeLevel?.displayName ?? editor.level.name,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Следующий уровень',
            onPressed: workspace.nextLevel,
            icon: const Icon(Icons.keyboard_arrow_up, size: 19),
          ),
        ],
        if (!compact) ...[
          IconButton(
            tooltip: shell.inspectorVisible
                ? 'Свернуть каталог'
                : 'Показать каталог',
            onPressed: shell.toggleInspector,
            icon: Icon(
              shell.inspectorVisible
                  ? Icons.keyboard_double_arrow_right
                  : Icons.keyboard_double_arrow_left,
              size: 19,
            ),
          ),
          IconButton(
            tooltip: shell.focusMode ? 'Выйти из Focus mode' : 'Focus mode',
            onPressed: shell.toggleFocusMode,
            icon: Icon(
              shell.focusMode ? Icons.fullscreen_exit : Icons.fullscreen,
              size: 20,
            ),
          ),
        ],
        if (compact)
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Каталог оборудования',
              onPressed: Scaffold.of(context).openEndDrawer,
              icon: const Icon(Icons.widgets_outlined, size: 19),
            ),
          ),
        const SizedBox(width: 2),
      ],
    );
  }
}

class _ContextStrip extends StatelessWidget {
  const _ContextStrip({required this.workspace});

  final EditorBuildingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final editor = workspace.editor;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: EditorUiTokens.contextBarHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          children: [
            ActionChip(
              avatar: const Icon(Icons.park_outlined, size: 14),
              label: const Text('Двор'),
              visualDensity: VisualDensity.compact,
              onPressed: workspace.site.outdoorZones.isEmpty
                  ? null
                  : () => workspace.selectOutdoorZone(
                        workspace.site.outdoorZones.first.id,
                      ),
            ),
            const SizedBox(width: 4),
            if (workspace.context == EditorWorkspaceContext.siteOutdoor)
              ActionChip(
                avatar: const Icon(Icons.apartment_outlined, size: 14),
                label: const Text('Building A'),
                visualDensity: VisualDensity.compact,
                onPressed: () => workspace.selectLevel(1),
              )
            else ...[
              _ContextPill(
                icon: Icons.layers_outlined,
                label: workspace.activeLevel?.displayName ?? editor.level.name,
              ),
              if (workspace.selectedZone case final zone?)
                _ContextPill(icon: Icons.home_work_outlined, label: zone.name),
              if (editor.selectedSpace case final room?)
                _ContextPill(
                  icon: room.type == SpaceType.corridor
                      ? Icons.linear_scale
                      : Icons.crop_square,
                  label: room.name,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              children: [
                Icon(icon, size: 13),
                const SizedBox(width: 5),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
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
          SizedBox(
            height: EditorUiTokens.panelHeaderHeight,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.widgets_outlined, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'КАТАЛОГ ОБОРУДОВАНИЯ',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Свернуть каталог',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCollapse,
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: DeviceCatalogPanel(controller: controller)),
        ],
      );
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
        width: EditorUiTokens.collapsedRailWidth,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: Icon(icon, size: 19),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.workspace});

  final EditorBuildingWorkspace workspace;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            _contextPath(workspace),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
}

String _contextPath(EditorBuildingWorkspace workspace) {
  if (workspace.context == EditorWorkspaceContext.siteOutdoor) {
    final outdoorId = workspace.activeOutdoorZoneId;
    final outdoor = workspace.site.outdoorZones
        .where((zone) => zone.id == outdoorId)
        .firstOrNull;
    return '${workspace.site.site.name} > ${outdoor?.name ?? 'Двор'}';
  }
  final level = workspace.activeLevel;
  final zone = workspace.selectedZone;
  final room = workspace.editor.selectedSpace;
  final parts = <String>[
    workspace.site.site.name,
    workspace.building.building.name,
    level?.displayName ?? workspace.editor.level.name,
    if (zone != null) zone.name,
    if (room != null) room.name,
  ];
  return parts.join(' > ');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
