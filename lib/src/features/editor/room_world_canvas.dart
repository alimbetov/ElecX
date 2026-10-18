import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/room_world_layout.dart';
import 'editor_controller.dart';

/// Connected engineering overview of one room.
///
/// It deliberately stays 2.5D: all faces are real [RoomSurfaceRef] objects,
/// but they are laid out with gravity semantics (ceiling above, floor below)
/// so routes and openings can be inspected without losing topology.
class RoomWorldCanvas extends StatelessWidget {
  const RoomWorldCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    if (space == null) {
      return const Center(child: Text('Выберите комнату'));
    }
    final walls = RoomSurfaceResolver.walls(space);
    final layout = RoomWorldLayout.build(space);
    final ceiling = layout.firstWhere(
      (tile) => tile.surface.type == SurfacePlaneType.ceiling,
    );
    final floor = layout.firstWhere(
      (tile) => tile.surface.type == SurfacePlaneType.floor,
    );
    final wallTiles = layout
        .where((tile) => tile.surface.type == SurfacePlaneType.wall)
        .toList(growable: false);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _WorldHeader(controller: controller, roomName: space.name),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: _SurfaceTile(
                controller: controller,
                space: space,
                surface: ceiling.surface,
                title: 'ПОТОЛОК',
                subtitle: 'верхняя плоскость · click для редактирования',
                gravity: Alignment.topCenter,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 4,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: wallTiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tile = wallTiles[index];
                  final wall = walls[index];
                  return SizedBox(
                    width: math.max(190, math.min(360, wall.lengthMm / 14)),
                    child: _SurfaceTile(
                      controller: controller,
                      space: space,
                      surface: tile.surface,
                      title: 'СТЕНА ${index + 1}',
                      subtitle: '${wall.lengthMm.round()} × ${wall.heightMm} mm',
                      gravity: Alignment.center,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: _SurfaceTile(
                controller: controller,
                space: space,
                surface: floor.surface,
                title: 'ПОЛ',
                subtitle: 'нижняя плоскость · click для редактирования',
                gravity: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({required this.controller, required this.roomName});

  final EditorController controller;
  final String roomName;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Назад на план',
              visualDensity: VisualDensity.compact,
              onPressed: controller.showPlan,
              icon: const Icon(Icons.arrow_back, size: 18),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$roomName · ROOM WORLD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const Icon(Icons.vertical_align_top, size: 15),
            const SizedBox(width: 4),
            Text('Потолок', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 12),
            const Icon(Icons.vertical_align_bottom, size: 15),
            const SizedBox(width: 4),
            Text('Пол', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 8),
          ],
        ),
      );
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.controller,
    required this.space,
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.gravity,
  });

  final EditorController controller;
  final EngineeringSpace space;
  final RoomSurfaceRef surface;
  final String title;
  final String subtitle;
  final Alignment gravity;

  void _openSurface() {
    switch (surface.type) {
      case SurfacePlaneType.floor:
        controller.showFloor();
      case SurfacePlaneType.ceiling:
        controller.showCeiling();
      case SurfacePlaneType.wall:
        controller.showWall(surface.wallIndex!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = controller.routeSegments
        .where((segment) => segment.surface == surface)
        .toList(growable: false);
    final openings = controller.openings
        .where((opening) => opening.hostWall == surface)
        .toList(growable: false);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openSurface,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 30, 10, 8),
                child: CustomPaint(
                  painter: _RoomWorldSurfacePainter(
                    space: space,
                    surface: surface,
                    routeSegments: routes,
                    openings: openings,
                    scheme: scheme,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 9,
              top: 6,
              right: 9,
              child: Row(
                children: [
                  Icon(_surfaceIcon(surface), size: 15),
                  const SizedBox(width: 5),
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (routes.isNotEmpty)
                    Tooltip(
                      message: 'Трасса: ${routes.length} segment(s)',
                      child: const Icon(Icons.alt_route, size: 15),
                    ),
                ],
              ),
            ),
            Align(
              alignment: gravity,
              child: IgnorePointer(
                child: Container(
                  width: 46,
                  height: 3,
                  margin: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _surfaceIcon(RoomSurfaceRef surface) => switch (surface.type) {
      SurfacePlaneType.floor => Icons.grid_4x4_outlined,
      SurfacePlaneType.ceiling => Icons.view_in_ar_outlined,
      SurfacePlaneType.wall => Icons.crop_landscape_outlined,
    };

class _RoomWorldSurfacePainter extends CustomPainter {
  const _RoomWorldSurfacePainter({
    required this.space,
    required this.surface,
    required this.routeSegments,
    required this.openings,
    required this.scheme,
  });

  final EngineeringSpace space;
  final RoomSurfaceRef surface;
  final List<SurfaceRouteSegmentDraft> routeSegments;
  final List<ArchitecturalOpening> openings;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = _surfaceBounds();
    final sx = size.width / math.max(1, bounds.$1);
    final sy = size.height / math.max(1, bounds.$2);
    final scale = math.min(sx, sy) * 0.88;
    final dx = (size.width - bounds.$1 * scale) / 2;
    final dy = (size.height - bounds.$2 * scale) / 2;

    Offset mapPoint(SurfacePointMm point) => Offset(
          dx + point.xMm * scale,
          size.height - (dy + point.yMm * scale),
        );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = scheme.outline;

    if (surface.type == SurfacePlaneType.wall) {
      final wall = RoomSurfaceResolver.wall(space, surface.wallIndex!);
      final path = Path();
      for (var i = 0; i < wall.profile.vertices.length; i++) {
        final point = wall.profile.vertices[i];
        final mapped = mapPoint(SurfacePointMm(point.xMm, point.yMm));
        if (i == 0) {
          path.moveTo(mapped.dx, mapped.dy);
        } else {
          path.lineTo(mapped.dx, mapped.dy);
        }
      }
      path.close();
      canvas.drawPath(path, outline);

      for (final opening in openings) {
        final a = mapPoint(
          SurfacePointMm(opening.offsetFromStartMm, opening.sillHeightMm),
        );
        final b = mapPoint(
          SurfacePointMm(opening.endOffsetMm, opening.topMm),
        );
        canvas.drawRect(
          Rect.fromPoints(a, b),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = scheme.tertiary,
        );
      }
    } else {
      final roomBounds = space.boundary.bounds;
      final path = Path();
      for (var i = 0; i < space.boundary.vertices.length; i++) {
        final vertex = space.boundary.vertices[i];
        final mapped = mapPoint(
          SurfacePointMm(
            vertex.x - roomBounds.left,
            vertex.y - roomBounds.bottom,
          ),
        );
        if (i == 0) {
          path.moveTo(mapped.dx, mapped.dy);
        } else {
          path.lineTo(mapped.dx, mapped.dy);
        }
      }
      path.close();
      canvas.drawPath(path, outline);
    }

    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.6
      ..color = scheme.primary;
    final nodePaint = Paint()..color = scheme.primary;
    for (final segment in routeSegments) {
      if (segment.points.isEmpty) continue;
      if (segment.points.length == 1) {
        canvas.drawCircle(mapPoint(segment.points.first), 3.2, nodePaint);
        continue;
      }
      final path = Path();
      final first = mapPoint(segment.points.first);
      path.moveTo(first.dx, first.dy);
      for (final point in segment.points.skip(1)) {
        final mapped = mapPoint(point);
        path.lineTo(mapped.dx, mapped.dy);
      }
      canvas.drawPath(path, routePaint);
      canvas.drawCircle(first, 3, nodePaint);
      canvas.drawCircle(mapPoint(segment.points.last), 3, nodePaint);
    }
  }

  (int, int) _surfaceBounds() {
    if (surface.type == SurfacePlaneType.wall) {
      final wall = RoomSurfaceResolver.wall(space, surface.wallIndex!);
      return (wall.lengthMm.round(), wall.heightMm);
    }
    final bounds = space.boundary.bounds;
    return (bounds.width, bounds.height);
  }

  @override
  bool shouldRepaint(covariant _RoomWorldSurfacePainter oldDelegate) =>
      oldDelegate.space != space ||
      oldDelegate.surface != surface ||
      oldDelegate.routeSegments != routeSegments ||
      oldDelegate.openings != openings ||
      oldDelegate.scheme != scheme;
}
