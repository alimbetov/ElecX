import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';

enum RoomSurfaceNavigatorKind { plan, floor, ceiling, wall }

/// P5E read-only projection of the single canonical-selected Room into the
/// transitional editor surface model.
///
/// The projection owns no geometry. [wallCount] is derived from the currently
/// materialized room polygon and wall indices remain a cutover detail until P7
/// introduces stable BoundaryEdgeId ownership.
final class RoomSurfaceNavigatorProjection {
  const RoomSurfaceNavigatorProjection({
    required this.canonicalSpaceId,
    required this.legacySpaceId,
    required this.wallCount,
    required this.kind,
    required this.wallIndex,
  });

  final SpaceId canonicalSpaceId;
  final String legacySpaceId;
  final int wallCount;
  final RoomSurfaceNavigatorKind kind;
  final int? wallIndex;

  String get currentLabel => switch (kind) {
        RoomSurfaceNavigatorKind.plan => 'Plan',
        RoomSurfaceNavigatorKind.floor => 'Floor',
        RoomSurfaceNavigatorKind.ceiling => 'Ceiling',
        RoomSurfaceNavigatorKind.wall => 'Wall ${(wallIndex ?? 0) + 1}',
      };

  static RoomSurfaceNavigatorProjection? fromEditor({
    required EditorController controller,
    required SpaceId? canonicalSpaceId,
    required String? legacySpaceId,
  }) {
    if (canonicalSpaceId == null || legacySpaceId == null) return null;
    if (controller.selectedSpaceId != legacySpaceId) return null;
    final space = controller.selectedSpace;
    if (space == null || space.id != legacySpaceId) return null;

    final active = controller.activeSurface;
    final kind = controller.viewMode == EditorViewMode.plan || active == null
        ? RoomSurfaceNavigatorKind.plan
        : switch (active.type) {
            SurfacePlaneType.floor => RoomSurfaceNavigatorKind.floor,
            SurfacePlaneType.ceiling => RoomSurfaceNavigatorKind.ceiling,
            SurfacePlaneType.wall => RoomSurfaceNavigatorKind.wall,
          };
    final wallIndex =
        kind == RoomSurfaceNavigatorKind.wall ? active?.wallIndex : null;
    if (wallIndex != null &&
        (wallIndex < 0 || wallIndex >= space.boundary.vertices.length)) {
      return null;
    }

    return RoomSurfaceNavigatorProjection(
      canonicalSpaceId: canonicalSpaceId,
      legacySpaceId: legacySpaceId,
      wallCount: space.boundary.vertices.length,
      kind: kind,
      wallIndex: wallIndex,
    );
  }
}

class RoomSurfaceNavigator extends StatelessWidget {
  const RoomSurfaceNavigator({
    required this.controller,
    required this.canonicalSpaceId,
    required this.legacySpaceId,
    required this.collapsed,
    required this.onToggleCollapsed,
    super.key,
  });

  final EditorController controller;
  final SpaceId? canonicalSpaceId;
  final String? legacySpaceId;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final projection = RoomSurfaceNavigatorProjection.fromEditor(
          controller: controller,
          canonicalSpaceId: canonicalSpaceId,
          legacySpaceId: legacySpaceId,
        );
        if (projection == null) return const SizedBox.shrink();

        return Material(
          key: const ValueKey('room-surface-navigator'),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              ListTile(
                dense: true,
                title: const Text('ROOM NAVIGATOR'),
                subtitle: Text('Current surface: ${projection.currentLabel}'),
                trailing: IconButton(
                  key: const ValueKey('room-surface-collapse'),
                  tooltip: collapsed
                      ? 'Развернуть навигатор поверхностей'
                      : 'Свернуть навигатор поверхностей',
                  onPressed: onToggleCollapsed,
                  icon: Icon(
                    collapsed
                        ? Icons.expand_less_outlined
                        : Icons.expand_more_outlined,
                  ),
                ),
              ),
              if (!collapsed) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                  child: Semantics(
                    label:
                        'Room surface preview, ${projection.currentLabel}, canonical room ${projection.canonicalSpaceId.value}',
                    child: SizedBox(
                      height: 112,
                      child: CustomPaint(
                        key: const ValueKey('room-surface-mini-view'),
                        painter: _RoomSurfaceMiniPainter(
                          points: _normalizedRoomPoints(controller),
                          projection: projection,
                          scheme: Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _surfaceButton(
                        key: const ValueKey('room-surface-plan'),
                        label: 'Plan',
                        selected:
                            projection.kind == RoomSurfaceNavigatorKind.plan,
                        onPressed: controller.showPlan,
                      ),
                      _surfaceButton(
                        key: const ValueKey('room-surface-floor'),
                        label: 'Floor',
                        selected:
                            projection.kind == RoomSurfaceNavigatorKind.floor,
                        onPressed: controller.showFloor,
                      ),
                      _surfaceButton(
                        key: const ValueKey('room-surface-ceiling'),
                        label: 'Ceiling',
                        selected:
                            projection.kind == RoomSurfaceNavigatorKind.ceiling,
                        onPressed: controller.showCeiling,
                      ),
                    ],
                  ),
                ),
                if (projection.wallCount > 0)
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      key: const ValueKey('room-surface-wall-list'),
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      scrollDirection: Axis.horizontal,
                      itemCount: projection.wallCount,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => _surfaceButton(
                        key: ValueKey('room-surface-wall-$index'),
                        label: 'Wall ${index + 1}',
                        semanticsLabel:
                            projection.kind == RoomSurfaceNavigatorKind.wall &&
                                    projection.wallIndex == index
                                ? 'Wall ${index + 1}, current surface'
                                : 'Wall ${index + 1}',
                        selected:
                            projection.kind == RoomSurfaceNavigatorKind.wall &&
                                projection.wallIndex == index,
                        onPressed: () => controller.showWall(index),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _surfaceButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
    String? semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel ?? (selected ? '$label, current surface' : label),
      button: true,
      selected: selected,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  List<Offset> _normalizedRoomPoints(EditorController controller) {
    final space = controller.selectedSpace;
    if (space == null || space.boundary.vertices.length < 3) return const [];
    final bounds = space.boundary.bounds;
    final width = math.max(1, bounds.width);
    final height = math.max(1, bounds.height);
    return [
      for (final point in space.boundary.vertices)
        Offset(
          (point.x - bounds.left) / width,
          1 - (point.y - bounds.bottom) / height,
        ),
    ];
  }
}

final class _RoomSurfaceMiniPainter extends CustomPainter {
  const _RoomSurfaceMiniPainter({
    required this.points,
    required this.projection,
    required this.scheme,
  });

  final List<Offset> points;
  final RoomSurfaceNavigatorProjection projection;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;

    const padding = 16.0;
    const rise = 22.0;
    final width = math.max(1.0, size.width - padding * 2);
    final height = math.max(1.0, size.height - padding * 2 - rise);
    final floor = [
      for (final point in points)
        Offset(
          padding + point.dx * width,
          padding + rise + point.dy * height,
        ),
    ];
    final ceiling = [for (final point in floor) point - const Offset(0, rise)];

    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.surfaceContainerHighest;
    final selectedPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.primaryContainer;
    final ceilingPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.surface.withValues(alpha: 0.55);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = scheme.outline;
    final selectedOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = scheme.primary;

    Path polygon(List<Offset> values) => Path()..addPolygon(values, true);

    canvas.drawPath(
      polygon(floor),
      projection.kind == RoomSurfaceNavigatorKind.floor
          ? selectedPaint
          : basePaint,
    );
    canvas.drawPath(polygon(floor), outline);

    for (var i = 0; i < floor.length; i++) {
      final next = (i + 1) % floor.length;
      final wall = Path()
        ..addPolygon(
          [floor[i], floor[next], ceiling[next], ceiling[i]],
          true,
        );
      final selected = projection.kind == RoomSurfaceNavigatorKind.wall &&
          projection.wallIndex == i;
      canvas.drawPath(wall, selected ? selectedPaint : basePaint);
      canvas.drawPath(wall, selected ? selectedOutline : outline);
    }

    canvas.drawPath(
      polygon(ceiling),
      projection.kind == RoomSurfaceNavigatorKind.ceiling
          ? selectedPaint
          : ceilingPaint,
    );
    canvas.drawPath(
      polygon(ceiling),
      projection.kind == RoomSurfaceNavigatorKind.ceiling
          ? selectedOutline
          : outline,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomSurfaceMiniPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.projection.kind != projection.kind ||
      oldDelegate.projection.wallIndex != projection.wallIndex ||
      oldDelegate.scheme != scheme;
}
