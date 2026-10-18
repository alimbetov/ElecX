import 'package:flutter/material.dart';

import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_keyboard_scope.dart';
import 'editor_layout_policy.dart';
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

  @override
  void initState() {
    super.initState();
    controller = EditorController.demo()..addListener(_refresh);
    workspace = EditorBuildingWorkspace.demo(controller)..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
          final canvas = controller.viewMode == EditorViewMode.plan
              ? SpatialCanvas(controller: controller)
              : SurfaceCanvas(controller: controller);

          return Scaffold(
            drawer: desktop
                ? null
                : Drawer(
                    width: EditorLayoutPolicy.navigatorWidth(mode),
                    child: SafeArea(
                      child: UnifiedSiteNavigator(
                        workspace: workspace,
                        compact: true,
                      ),
                    ),
                  ),
            endDrawer: desktop
                ? null
                : Drawer(
                    width: EditorLayoutPolicy.inspectorWidth(mode),
                    child: SafeArea(child: _WorkspaceInspector(workspace: workspace)),
                  ),
            appBar: _WorkspaceAppBar(
              workspace: workspace,
              compact: !desktop,
            ),
            body: Column(
              children: [
                UnifiedEditorIconToolbar(
                  controller: controller,
                  compact: !desktop,
                ),
                _ContextStrip(workspace: workspace),
                Expanded(
                  child: desktop
                      ? Row(
                          children: [
                            SizedBox(
                              width: EditorLayoutPolicy.navigatorWidth(mode),
                              child: UnifiedSiteNavigator(workspace: workspace),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: canvas),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: EditorLayoutPolicy.inspectorWidth(mode),
                              child: _WorkspaceInspector(workspace: workspace),
                            ),
                          ],
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

class _WorkspaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _WorkspaceAppBar({required this.workspace, required this.compact});

  final EditorBuildingWorkspace workspace;
  final bool compact;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final editor = workspace.editor;
    return AppBar(
      titleSpacing: compact ? 6 : 18,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            compact ? 'ElecX' : 'ElecX · Site / Building',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            _contextPath(workspace),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        if (workspace.context == EditorWorkspaceContext.buildingLevel) ...[
          IconButton(
            tooltip: 'Предыдущий уровень',
            onPressed: workspace.previousLevel,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                workspace.activeLevel?.displayName ?? editor.level.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Следующий уровень',
            onPressed: workspace.nextLevel,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
        ],
        if (compact)
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Свойства',
              onPressed: Scaffold.of(context).openEndDrawer,
              icon: const Icon(Icons.tune),
            ),
          ),
        const SizedBox(width: 4),
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
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          children: [
            ActionChip(
              avatar: const Icon(Icons.park_outlined, size: 16),
              label: const Text('Двор'),
              onPressed: workspace.site.outdoorZones.isEmpty
                  ? null
                  : () => workspace.selectOutdoorZone(
                        workspace.site.outdoorZones.first.id,
                      ),
            ),
            const SizedBox(width: 6),
            if (workspace.context == EditorWorkspaceContext.siteOutdoor)
              ActionChip(
                avatar: const Icon(Icons.apartment_outlined, size: 16),
                label: const Text('Building A'),
                onPressed: () => workspace.selectLevel(1),
              )
            else ...[
              ActionChip(
                avatar: const Icon(Icons.layers_outlined, size: 16),
                label: Text(workspace.activeLevel?.displayName ?? editor.level.name),
                onPressed: null,
              ),
              if (workspace.selectedZone case final zone?) ...[
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.home_work_outlined, size: 16),
                  label: Text(zone.name),
                  onPressed: null,
                ),
              ],
              if (editor.selectedSpace case final room?) ...[
                const SizedBox(width: 6),
                ActionChip(
                  avatar: Icon(
                    room.type == SpaceType.corridor
                        ? Icons.linear_scale
                        : Icons.crop_square,
                    size: 16,
                  ),
                  label: Text(room.name),
                  onPressed: null,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceInspector extends StatelessWidget {
  const _WorkspaceInspector({required this.workspace});

  final EditorBuildingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final editor = workspace.editor;
    final level = workspace.activeLevel;
    final zone = workspace.selectedZone;
    final room = editor.selectedSpace;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('КОНТЕКСТ', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        _property('Режим', workspace.context == EditorWorkspaceContext.siteOutdoor
            ? 'Площадка / двор'
            : 'Здание'),
        if (workspace.context == EditorWorkspaceContext.buildingLevel) ...[
          _property('Уровень', level?.displayName ?? editor.level.name),
          _property('Отметка', '${editor.level.elevationMm} mm'),
          _property('Помещений', '${editor.level.spaces.length}'),
          _property('Квартир', '${level?.apartments.length ?? 0}'),
        ],
        if (zone != null) ...[
          const Divider(height: 28),
          Text('ЗОНА', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _property('Название', zone.name),
          _property('Помещений', '${zone.spaceIds.length}'),
        ],
        if (room != null) ...[
          const Divider(height: 28),
          Text('ПОМЕЩЕНИЕ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _property('Название', room.name),
          _property('Тип', room.type.name),
          _property(
            'Размер bbox',
            '${room.boundary.bounds.width} × ${room.boundary.bounds.height} mm',
          ),
        ],
      ],
    );
  }

  Widget _property(String name, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.workspace});

  final EditorBuildingWorkspace workspace;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}