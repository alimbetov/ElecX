import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/room_world_layout.dart';
import 'cad_visual_tokens.dart';
import 'editor_controller.dart';

/// Connected engineering overview of one room.
///
/// It is intentionally 2.5D: every tile is a real [RoomSurfaceRef], while
/// gravity semantics keep ceiling above, floor below and ordered walls between.
class RoomWorldCanvas extends StatelessWidget {
  const RoomWorldCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    if (space == null) {
      return const Center(child: Text('Выберите комнату'));
    }
    final layout = RoomWorldLayout.build(space);
    final walls = RoomSurfaceResolver.walls(space);
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            _RoomWorldStatus(controller: controller),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: _SurfaceTile(
                controller: controller,
                space: space,
                surface: ceiling.surface,
                title: 'ПОТОЛОК',
                subtitle: 'верхняя плоскость',
                role: _SurfaceRole.ceiling,
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
                  final wall = walls[index];
                  return SizedBox(
                    width: math.max(190, math.min(360, wall.lengthMm / 14)),
                    child: _SurfaceTile(
                      controller: controller,
                      space: space,
                      surface: wallTiles[index].surface,
                      title: 'СТЕНА ${index + 1}',
                      subtitle: '${wall.lengthMm.round()} × ${wall.heightMm} mm',
                      role: _SurfaceRole.wall,
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
                subtitle: 'нижняя плоскость',
                role: _SurfaceRole.floor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomWorldStatus extends StatelessWidget {
  const _RoomWorldStatus({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final route = _routeChain(controller.routeSegments);
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          const Icon(Icons.vertical_align_top, size: 15),
          const SizedBox(width: 4),
          Text('потолок ↑', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 10),
          Text('стены ↔', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 10),
          Text('пол ↓', style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          if (route.isNotEmpty) ...[
            Icon(Icons.alt_route, size: 15, color: CadVisualTokens.route(scheme)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CadVisualTokens.route(scheme),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${(controller.routeLengthMm / 1000).toStringAsFixed(2)} m',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

String _routeChain(List<SurfaceRouteSegmentDraft> segments) {
  if (segments.isEmpty) return '';
  final labels = <String>[];
  for (final segment in segments) {
    final label = switch (segment.surface.type) {
      SurfacePlaneType.floor => 'Floor',
      SurfacePlaneType.ceiling => 'Ceiling',
      SurfacePlaneType.wall => 'W${segment.surface.wallIndex! + 1}',
    };
    if (labels.isEmpty || labels.last != label) labels.add(label);
  }
  return labels.join(' → ');
}

enum _SurfaceRole { ceiling, wall, floor }

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.controller,
    required this.space,
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.role,
  });

  final EditorController controller;
  final EngineeringSpace space;
  final RoomSurfaceRef surface;
  final String title;
  final String subtitle;
  final _SurfaceRole role;

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
    final profileIsCustom = surface.type == SurfacePlaneType.wall &&
        space.wallProfiles.containsKey(surface.wallIndex);

    return Material(
      color: switch (role) {
        _SurfaceRole.ceiling => scheme.surfaceContainerLow.withValues(alpha: 0.72),
        _SurfaceRole.wall => scheme.surfaceContainerLow,
        _SurfaceRole.floor => scheme.surfaceContainerLowest,
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CadVisualTokens.surfaceRadius),
        side: BorderSide(
          color: profileIsCustom
              ? CadVisualTokens.profileGuide(scheme)
              : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openSurface,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 32, 10, 9),
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
                  if (profileIsCustom) ...[
                    Icon(
                      Icons.account_tree_outlined,
                      size: 14,
                      color: CadVisualTokens.profile(scheme),
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (routes.isNotEmpty) ...[
                    Icon(
                      Icons.alt_route,
                      size: 15,
                      color: CadVisualTokens.route(scheme),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${routes.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
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
      SurfacePlaneType.ceiling => Icons.vertical_align_top,
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
    final scale = math.min(
          size.width / math.max(1, bounds.$1),
          size.height / math.max(1, bounds.$2),
        ) *
        0.88;
    final dx = (size.width - bounds.$1 * scale) / 2;
    final dy = (size.height - bounds.$2 * scale) / 2;

    Offset mapPoint(SurfacePointMm point) => Offset(
          dx + point.xMm * scale,
          size.height - (dy + point.yMm * scale),
        );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CadVisualTokens.geometryStroke
      ..strokeJoin = StrokeJoin.miter
      ..color = CadVisualTokens.geometry(scheme);

    if (surface.type == SurfacePlaneType.wall) {
      final wall = RoomSurfaceResolver.wall(space, surface.wallIndex!);
      final profilePath = Path();
      for (var i = 0; i < wall.profile.vertices.length; i++) {
        final point = wall.profile.vertices[i];
        final mapped = mapPoint(SurfacePointMm(point.xMm, point.yMm));
        if (i == 0) {
          profilePath.moveTo(mapped.dx, mapped.dy);
        } else {
          profilePath.lineTo(mapped.dx, mapped.dy);
        }
      }
      profilePath.close();
      canvas.drawPath(
        profilePath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = CadVisualTokens.ghostFill(scheme),
      );
      canvas.drawPath(profilePath, outline);

      if (space.wallProfiles.containsKey(surface.wallIndex)) {
        canvas.drawPath(
          profilePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = CadVisualTokens.profileStroke
            ..strokeJoin = StrokeJoin.miter
            ..color = CadVisualTokens.profile(scheme),
        );
      }

      for (final opening in openings) {
        final rect = Rect.fromPoints(
          mapPoint(
            SurfacePointMm(opening.offsetFromStartMm, opening.sillHeightMm),
          ),
          mapPoint(SurfacePointMm(opening.endOffsetMm, opening.topMm)),
        );
        final openingColor = CadVisualTokens.opening(scheme);
        canvas.drawRect(
          rect,
          Paint()..color = openingColor.withValues(alpha: 0.08),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = CadVisualTokens.openingStroke
            ..color = openingColor,
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
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = CadVisualTokens.ghostFill(scheme),
      );
      canvas.drawPath(path, outline);
    }

    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = CadVisualTokens.routeStroke
      ..color = CadVisualTokens.route(scheme);
    final nodePaint = Paint()..color = CadVisualTokens.route(scheme);
    for (final segment in routeSegments) {
      if (segment.points.isEmpty) continue;
      final first = mapPoint(segment.points.first);
      if (segment.points.length == 1) {
        canvas.drawCircle(
          first,
          CadVisualTokens.transitionNodeRadius,
          nodePaint,
        );
        continue;
      }
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in segment.points.skip(1)) {
        final mapped = mapPoint(point);
        path.lineTo(mapped.dx, mapped.dy);
      }
      canvas.drawPath(path, routePaint);
      canvas.drawCircle(
        first,
        CadVisualTokens.transitionNodeRadius,
        nodePaint,
      );
      canvas.drawCircle(
        mapPoint(segment.points.last),
        CadVisualTokens.transitionNodeRadius,
        nodePaint,
      );
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
