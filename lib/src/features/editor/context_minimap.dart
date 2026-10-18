import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'editor_building_workspace.dart';
import 'site_map_canvas.dart';
import 'site_map_interaction.dart';

Future<void> showContextMiniMapSheet({
  required BuildContext context,
  required EditorBuildingWorkspace workspace,
  required SiteMapInteractionController siteInteraction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black26,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.18,
      maxChildSize: 0.82,
      snap: true,
      snapSizes: const [0.24, 0.46, 0.82],
      builder: (context, scrollController) => _MiniMapSheet(
        workspace: workspace,
        siteInteraction: siteInteraction,
        scrollController: scrollController,
      ),
    ),
  );
}

class _MiniMapSheet extends StatelessWidget {
  const _MiniMapSheet({
    required this.workspace,
    required this.siteInteraction,
    required this.scrollController,
  });

  final EditorBuildingWorkspace workspace;
  final SiteMapInteractionController siteInteraction;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final editor = workspace.editor;
    final selectedRoom = editor.selectedSpace;
    final zone = workspace.selectedZone;
    final siteMode = workspace.context == EditorWorkspaceContext.siteOutdoor;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SheetHandle(scrollController: scrollController),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        siteMode
                            ? 'Карта площадки'
                            : zone != null
                                ? zone.name
                                : workspace.activeLevel?.displayName ?? editor.level.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        siteMode
                            ? 'Двор · здание · точки входа'
                            : selectedRoom == null
                                ? 'Выберите помещение на мини-карте'
                                : '${selectedRoom.name} · ${selectedRoom.type.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Скрыть микро-карту',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
          if (!siteMode && selectedRoom != null)
            _SurfaceQuickNav(workspace: workspace, room: selectedRoom),
          const Divider(height: 1),
          Expanded(
            child: siteMode
                ? SiteMapCanvas(
                    entities: SiteMapProjection.tower(workspace),
                    interaction: siteInteraction,
                    onEntityOpen: (entity) {
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
                      Navigator.of(context).pop();
                    },
                  )
                : _LevelMiniMap(
                    workspace: workspace,
                    zoneSpaceIds: zone?.spaceIds,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 26,
        child: Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      );
}

class _SurfaceQuickNav extends StatelessWidget {
  const _SurfaceQuickNav({required this.workspace, required this.room});

  final EditorBuildingWorkspace workspace;
  final EngineeringSpace room;

  @override
  Widget build(BuildContext context) {
    final editor = workspace.editor;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        children: [
          _surfaceButton(
            context,
            label: 'Plan',
            icon: Icons.map_outlined,
            selected: editor.viewMode == EditorViewMode.plan,
            onPressed: editor.showPlan,
          ),
          _surfaceButton(
            context,
            label: 'Floor',
            icon: Icons.grid_on,
            selected: editor.activeSurface?.type == SurfacePlaneType.floor,
            onPressed: editor.showFloor,
          ),
          _surfaceButton(
            context,
            label: 'Ceil',
            icon: Icons.view_in_ar_outlined,
            selected: editor.activeSurface?.type == SurfacePlaneType.ceiling,
            onPressed: editor.showCeiling,
          ),
          for (var i = 0; i < room.boundary.vertices.length; i++)
            _surfaceButton(
              context,
              label: 'W${i + 1}',
              icon: Icons.crop_landscape,
              selected: editor.activeSurface?.type == SurfacePlaneType.wall &&
                  editor.activeSurface?.wallIndex == i,
              onPressed: () => editor.showWall(i),
            ),
        ],
      ),
    );
  }

  Widget _surfaceButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: selected
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(icon, size: 16),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 16),
                label: Text(label),
              ),
      );
}

class _LevelMiniMap extends StatefulWidget {
  const _LevelMiniMap({required this.workspace, this.zoneSpaceIds});

  final EditorBuildingWorkspace workspace;
  final Set<String>? zoneSpaceIds;

  @override
  State<_LevelMiniMap> createState() => _LevelMiniMapState();
}

class _LevelMiniMapState extends State<_LevelMiniMap> {
  String? _hoveredSpaceId;

  @override
  Widget build(BuildContext context) {
    final spaces = [
      for (final space in widget.workspace.editor.level.spaces)
        if (widget.zoneSpaceIds == null || widget.zoneSpaceIds!.contains(space.id)) space,
    ];
    if (spaces.isEmpty) {
      return const Center(child: Text('Нет геометрии для микро-карты'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = _unionBounds(spaces);
        return MouseRegion(
          onExit: (_) => setState(() => _hoveredSpaceId = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final hit = _hitSpace(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                bounds,
                spaces,
              );
              if (hit != null) widget.workspace.editor.selectSpace(hit.id);
            },
            onDoubleTapDown: (details) {
              final hit = _hitSpace(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                bounds,
                spaces,
              );
              if (hit != null) {
                widget.workspace.editor.selectSpace(hit.id);
                widget.workspace.editor.showPlan();
              }
            },
            child: CustomPaint(
              painter: _LevelMiniMapPainter(
                spaces: spaces,
                bounds: bounds,
                selectedSpaceId: widget.workspace.editor.selectedSpaceId,
                hoveredSpaceId: _hoveredSpaceId,
              ),
              child: MouseRegion(
                onHover: (event) {
                  final hit = _hitSpace(
                    event.localPosition,
                    Size(constraints.maxWidth, constraints.maxHeight),
                    bounds,
                    spaces,
                  );
                  if (hit?.id != _hoveredSpaceId) {
                    setState(() => _hoveredSpaceId = hit?.id);
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }

  MmBounds _unionBounds(List<EngineeringSpace> spaces) {
    var bounds = spaces.first.boundary.bounds;
    for (final space in spaces.skip(1)) {
      bounds = bounds.union(space.boundary.bounds);
    }
    return bounds;
  }

  EngineeringSpace? _hitSpace(
    Offset point,
    Size size,
    MmBounds bounds,
    List<EngineeringSpace> spaces,
  ) {
    final world = _screenToWorld(point, size, bounds);
    for (final space in spaces.reversed) {
      if (space.boundary.contains(world) || space.boundary.bounds.contains(world)) {
        return space;
      }
    }
    return null;
  }

  MmPoint _screenToWorld(Offset point, Size size, MmBounds bounds) {
    final transform = _MiniTransform.fit(bounds, size);
    return MmPoint(
      ((point.dx - transform.offset.dx) / transform.scale + bounds.left).round(),
      ((transform.offset.dy - point.dy) / transform.scale + bounds.top).round(),
    );
  }
}

class _LevelMiniMapPainter extends CustomPainter {
  _LevelMiniMapPainter({
    required this.spaces,
    required this.bounds,
    required this.selectedSpaceId,
    required this.hoveredSpaceId,
  });

  final List<EngineeringSpace> spaces;
  final MmBounds bounds;
  final String? selectedSpaceId;
  final String? hoveredSpaceId;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = _MiniTransform.fit(bounds, size);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F8FA));
    for (final space in spaces) {
      final selected = selectedSpaceId == space.id;
      final hovered = hoveredSpaceId == space.id;
      final path = Path();
      for (var i = 0; i < space.boundary.vertices.length; i++) {
        final p = transform.toScreen(space.boundary.vertices[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = selected
              ? const Color(0x33244A7C)
              : hovered
                  ? const Color(0x22244A7C)
                  : const Color(0x0D244A7C),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.4 : hovered ? 2.0 : 1.0
          ..color = const Color(0xFF244A7C),
      );
      if (space.boundary.bounds.width * transform.scale > 70 &&
          space.boundary.bounds.height * transform.scale > 26) {
        final center = transform.toScreen(space.boundary.bounds.center);
        final text = TextPainter(
          text: TextSpan(
            text: space.name,
            style: TextStyle(
              color: const Color(0xFF1F2937),
              fontSize: selected || hovered ? 12 : 10,
              fontWeight: selected || hovered ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 140);
        text.paint(canvas, Offset(center.dx - text.width / 2, center.dy - text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LevelMiniMapPainter oldDelegate) =>
      oldDelegate.selectedSpaceId != selectedSpaceId ||
      oldDelegate.hoveredSpaceId != hoveredSpaceId ||
      oldDelegate.spaces != spaces ||
      oldDelegate.bounds != bounds;
}

final class _MiniTransform {
  const _MiniTransform({required this.scale, required this.offset});

  factory _MiniTransform.fit(MmBounds bounds, Size size) {
    const padding = 22.0;
    final usableWidth = (size.width - padding * 2).clamp(1.0, double.infinity);
    final usableHeight = (size.height - padding * 2).clamp(1.0, double.infinity);
    final sx = usableWidth / (bounds.width == 0 ? 1 : bounds.width);
    final sy = usableHeight / (bounds.height == 0 ? 1 : bounds.height);
    final scale = sx < sy ? sx : sy;
    final drawingWidth = bounds.width * scale;
    final drawingHeight = bounds.height * scale;
    return _MiniTransform(
      scale: scale,
      offset: Offset(
        (size.width - drawingWidth) / 2,
        (size.height + drawingHeight) / 2,
      ),
    );
  }

  final double scale;
  final Offset offset;

  Offset toScreen(MmPoint point) => Offset(
        offset.dx + point.x * scale,
        offset.dy - point.y * scale,
      );
}
