import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static bool hasStaleWallSelection({
    required EditorController controller,
    required SpaceId? canonicalSpaceId,
    required String? legacySpaceId,
  }) {
    if (canonicalSpaceId == null || legacySpaceId == null) return false;
    if (controller.selectedSpaceId != legacySpaceId) return false;
    final space = controller.selectedSpace;
    final active = controller.activeSurface;
    if (space == null ||
        active == null ||
        active.spaceId != legacySpaceId ||
        active.type != SurfacePlaneType.wall) {
      return false;
    }
    final wallIndex = active.wallIndex;
    return wallIndex == null ||
        wallIndex < 0 ||
        wallIndex >= space.boundary.vertices.length;
  }
}

class RoomSurfaceNavigator extends StatefulWidget {
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
  State<RoomSurfaceNavigator> createState() => _RoomSurfaceNavigatorState();
}

class _RoomSurfaceNavigatorState extends State<RoomSurfaceNavigator> {
  final FocusNode _miniViewFocusNode = FocusNode(
    debugLabel: 'Room Surface Navigator mini-view',
  );
  _RoomSurfaceMiniTarget? _hoveredTarget;
  bool _staleFallbackScheduled = false;

  EditorController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant RoomSurfaceNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canonicalSpaceId != widget.canonicalSpaceId ||
        oldWidget.legacySpaceId != widget.legacySpaceId) {
      _hoveredTarget = null;
      _staleFallbackScheduled = false;
    }
  }

  @override
  void dispose() {
    _miniViewFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (RoomSurfaceNavigatorProjection.hasStaleWallSelection(
          controller: controller,
          canonicalSpaceId: widget.canonicalSpaceId,
          legacySpaceId: widget.legacySpaceId,
        )) {
          _scheduleStaleWallFallback();
          return const SizedBox.shrink();
        }
        _staleFallbackScheduled = false;

        final projection = RoomSurfaceNavigatorProjection.fromEditor(
          controller: controller,
          canonicalSpaceId: widget.canonicalSpaceId,
          legacySpaceId: widget.legacySpaceId,
        );
        if (projection == null) return const SizedBox.shrink();

        final space = controller.selectedSpace!;
        final bounds = space.boundary.bounds;
        final roomSummary =
            '${space.name} · ${_formatMeters(bounds.width)} × ${_formatMeters(bounds.height)} m';

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
                isThreeLine: true,
                title: const Text('ROOM SURFACES'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      roomSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Current surface: ${projection.currentLabel}'),
                  ],
                ),
                trailing: IconButton(
                  key: const ValueKey('room-surface-collapse'),
                  tooltip: widget.collapsed
                      ? 'Развернуть навигатор поверхностей'
                      : 'Свернуть навигатор поверхностей',
                  onPressed: widget.onToggleCollapsed,
                  icon: Icon(
                    widget.collapsed
                        ? Icons.expand_less_outlined
                        : Icons.expand_more_outlined,
                  ),
                ),
              ),
              if (!widget.collapsed) _expandedBody(context, projection),
            ],
          ),
        );
      },
    );
  }

  Widget _expandedBody(
    BuildContext context,
    RoomSurfaceNavigatorProjection projection,
  ) {
    final normalizedPoints = _normalizedRoomPoints();
    final walls = controller.selectedWalls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: Semantics(
            label:
                'Room surface preview, ${projection.currentLabel}, canonical room ${projection.canonicalSpaceId.value}',
            hint:
                'Click a visible surface. With keyboard focus use left and right for walls, up for ceiling, down for floor.',
            focusable: true,
            child: Focus(
              key: const ValueKey('room-surface-mini-focus'),
              focusNode: _miniViewFocusNode,
              onKeyEvent: _handleMiniViewKey,
              child: SizedBox(
                height: 124,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final geometry = _RoomSurfaceMiniGeometry.build(
                      normalizedPoints,
                      size,
                    );
                    return MouseRegion(
                      onHover: (event) => _setHoveredTarget(
                        geometry.targetAt(event.localPosition),
                      ),
                      onExit: (_) => _setHoveredTarget(null),
                      child: GestureDetector(
                        key: const ValueKey('room-surface-mini-view'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          _miniViewFocusNode.requestFocus();
                          final target = geometry.targetAt(
                            details.localPosition,
                          );
                          if (target != null) _activateTarget(target);
                        },
                        child: CustomPaint(
                          painter: _RoomSurfaceMiniPainter(
                            geometry: geometry,
                            projection: projection,
                            hoveredTarget: _hoveredTarget,
                            scheme: Theme.of(context).colorScheme,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
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
                selected: projection.kind == RoomSurfaceNavigatorKind.plan,
                onPressed: controller.showPlan,
              ),
              _surfaceButton(
                key: const ValueKey('room-surface-floor'),
                label: 'Floor',
                selected: projection.kind == RoomSurfaceNavigatorKind.floor,
                onPressed: controller.showFloor,
              ),
              _surfaceButton(
                key: const ValueKey('room-surface-ceiling'),
                label: 'Ceiling',
                selected: projection.kind == RoomSurfaceNavigatorKind.ceiling,
                onPressed: controller.showCeiling,
              ),
            ],
          ),
        ),
        if (projection.wallCount > 0)
          SizedBox(
            height: 58,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('room-surface-wall-prev'),
                  tooltip: 'Предыдущая стена',
                  onPressed: controller.previousWall,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('room-surface-wall-list'),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    scrollDirection: Axis.horizontal,
                    itemCount: projection.wallCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final length = index < walls.length
                          ? _formatMeters(walls[index].lengthMm)
                          : null;
                      final selected =
                          projection.kind == RoomSurfaceNavigatorKind.wall &&
                              projection.wallIndex == index;
                      return Tooltip(
                        message: length == null
                            ? 'Wall ${index + 1}'
                            : 'Wall ${index + 1} · $length m',
                        child: _surfaceButton(
                          key: ValueKey('room-surface-wall-$index'),
                          label: length == null
                              ? 'W${index + 1}'
                              : 'W${index + 1} · ${length}m',
                          semanticsLabel: selected
                              ? 'Wall ${index + 1}, current surface'
                              : 'Wall ${index + 1}',
                          selected: selected,
                          onPressed: () => controller.showWall(index),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  key: const ValueKey('room-surface-wall-next'),
                  tooltip: 'Следующая стена',
                  onPressed: controller.nextWall,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            '2.5D: click surface · keyboard: ←/→ walls, ↑ ceiling, ↓ floor',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  void _scheduleStaleWallFallback() {
    if (_staleFallbackScheduled) return;
    _staleFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staleFallbackScheduled = false;
      if (!mounted) return;
      if (RoomSurfaceNavigatorProjection.hasStaleWallSelection(
        controller: controller,
        canonicalSpaceId: widget.canonicalSpaceId,
        legacySpaceId: widget.legacySpaceId,
      )) {
        controller.showPlan();
      }
    });
  }

  KeyEventResult _handleMiniViewKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      controller.previousWall();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      controller.nextWall();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      controller.showCeiling();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      controller.showFloor();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _setHoveredTarget(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setHoveredTarget(_RoomSurfaceMiniTarget? target) {
    if (_hoveredTarget == target || !mounted) return;
    setState(() => _hoveredTarget = target);
  }

  void _activateTarget(_RoomSurfaceMiniTarget target) {
    switch (target.kind) {
      case _RoomSurfaceMiniTargetKind.floor:
        controller.showFloor();
      case _RoomSurfaceMiniTargetKind.ceiling:
        controller.showCeiling();
      case _RoomSurfaceMiniTargetKind.wall:
        final wallIndex = target.wallIndex;
        if (wallIndex != null) controller.showWall(wallIndex);
    }
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
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  List<Offset> _normalizedRoomPoints() {
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

  static String _formatMeters(num millimeters) =>
      (millimeters / 1000).toStringAsFixed(2);
}

enum _RoomSurfaceMiniTargetKind { floor, ceiling, wall }

final class _RoomSurfaceMiniTarget {
  const _RoomSurfaceMiniTarget._(this.kind, [this.wallIndex]);

  const _RoomSurfaceMiniTarget.floor()
      : this._(_RoomSurfaceMiniTargetKind.floor);
  const _RoomSurfaceMiniTarget.ceiling()
      : this._(_RoomSurfaceMiniTargetKind.ceiling);
  const _RoomSurfaceMiniTarget.wall(int wallIndex)
      : this._(_RoomSurfaceMiniTargetKind.wall, wallIndex);

  final _RoomSurfaceMiniTargetKind kind;
  final int? wallIndex;

  @override
  bool operator ==(Object other) =>
      other is _RoomSurfaceMiniTarget &&
      other.kind == kind &&
      other.wallIndex == wallIndex;

  @override
  int get hashCode => Object.hash(kind, wallIndex);
}

final class _RoomSurfaceMiniGeometry {
  const _RoomSurfaceMiniGeometry({
    required this.floor,
    required this.ceiling,
    required this.walls,
  });

  factory _RoomSurfaceMiniGeometry.build(List<Offset> points, Size size) {
    if (points.length < 3) {
      return const _RoomSurfaceMiniGeometry(
        floor: <Offset>[],
        ceiling: <Offset>[],
        walls: <Path>[],
      );
    }
    const padding = 18.0;
    const rise = 28.0;
    const skew = 16.0;
    final width = math.max(1.0, size.width - padding * 2 - skew);
    final height = math.max(1.0, size.height - padding * 2 - rise);
    final floor = [
      for (final point in points)
        Offset(
          padding + point.dx * width,
          padding + rise + point.dy * height,
        ),
    ];
    final ceiling = [
      for (final point in floor) point + const Offset(skew, -rise),
    ];
    final walls = <Path>[];
    for (var i = 0; i < floor.length; i++) {
      final next = (i + 1) % floor.length;
      walls.add(
        Path()
          ..addPolygon(
            [floor[i], floor[next], ceiling[next], ceiling[i]],
            true,
          ),
      );
    }
    return _RoomSurfaceMiniGeometry(
      floor: floor,
      ceiling: ceiling,
      walls: walls,
    );
  }

  final List<Offset> floor;
  final List<Offset> ceiling;
  final List<Path> walls;

  Path get floorPath => Path()..addPolygon(floor, true);
  Path get ceilingPath => Path()..addPolygon(ceiling, true);

  _RoomSurfaceMiniTarget? targetAt(Offset point) {
    for (var index = walls.length - 1; index >= 0; index--) {
      if (walls[index].contains(point)) {
        return _RoomSurfaceMiniTarget.wall(index);
      }
    }

    final inFloor = floor.isNotEmpty && floorPath.contains(point);
    final inCeiling = ceiling.isNotEmpty && ceilingPath.contains(point);
    if (inFloor && inCeiling) {
      final floorDistance = (point - _center(floor)).distanceSquared;
      final ceilingDistance = (point - _center(ceiling)).distanceSquared;
      return floorDistance <= ceilingDistance
          ? const _RoomSurfaceMiniTarget.floor()
          : const _RoomSurfaceMiniTarget.ceiling();
    }
    if (inCeiling) return const _RoomSurfaceMiniTarget.ceiling();
    if (inFloor) return const _RoomSurfaceMiniTarget.floor();
    return null;
  }

  static Offset _center(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    var dx = 0.0;
    var dy = 0.0;
    for (final point in points) {
      dx += point.dx;
      dy += point.dy;
    }
    return Offset(dx / points.length, dy / points.length);
  }
}

final class _RoomSurfaceMiniPainter extends CustomPainter {
  const _RoomSurfaceMiniPainter({
    required this.geometry,
    required this.projection,
    required this.hoveredTarget,
    required this.scheme,
  });

  final _RoomSurfaceMiniGeometry geometry;
  final RoomSurfaceNavigatorProjection projection;
  final _RoomSurfaceMiniTarget? hoveredTarget;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.floor.length < 3) return;

    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.surfaceContainerHighest;
    final selectedPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.primaryContainer;
    final hoverPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.secondaryContainer;
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
    final hoverOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = scheme.secondary;

    final floorSelected = projection.kind == RoomSurfaceNavigatorKind.floor;
    final floorHovered =
        hoveredTarget?.kind == _RoomSurfaceMiniTargetKind.floor;
    canvas.drawPath(
      geometry.floorPath,
      floorSelected
          ? selectedPaint
          : floorHovered
              ? hoverPaint
              : basePaint,
    );
    canvas.drawPath(
      geometry.floorPath,
      floorSelected
          ? selectedOutline
          : floorHovered
              ? hoverOutline
              : outline,
    );

    for (var i = 0; i < geometry.walls.length; i++) {
      final selected = projection.kind == RoomSurfaceNavigatorKind.wall &&
          projection.wallIndex == i;
      final hovered = hoveredTarget?.kind == _RoomSurfaceMiniTargetKind.wall &&
          hoveredTarget?.wallIndex == i;
      canvas.drawPath(
        geometry.walls[i],
        selected
            ? selectedPaint
            : hovered
                ? hoverPaint
                : basePaint,
      );
      canvas.drawPath(
        geometry.walls[i],
        selected
            ? selectedOutline
            : hovered
                ? hoverOutline
                : outline,
      );
      _paintWallLabel(
        canvas,
        geometry.walls[i].getBounds().center,
        'W${i + 1}',
        selected || hovered,
      );
    }

    final ceilingSelected = projection.kind == RoomSurfaceNavigatorKind.ceiling;
    final ceilingHovered =
        hoveredTarget?.kind == _RoomSurfaceMiniTargetKind.ceiling;
    canvas.drawPath(
      geometry.ceilingPath,
      ceilingSelected
          ? selectedPaint
          : ceilingHovered
              ? hoverPaint
              : ceilingPaint,
    );
    canvas.drawPath(
      geometry.ceilingPath,
      ceilingSelected
          ? selectedOutline
          : ceilingHovered
              ? hoverOutline
              : outline,
    );
  }

  void _paintWallLabel(
    Canvas canvas,
    Offset center,
    String label,
    bool emphasized,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
          fontSize: 9,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomSurfaceMiniPainter oldDelegate) =>
      oldDelegate.geometry.floor != geometry.floor ||
      oldDelegate.geometry.ceiling != geometry.ceiling ||
      oldDelegate.projection.kind != projection.kind ||
      oldDelegate.projection.wallIndex != projection.wallIndex ||
      oldDelegate.hoveredTarget != hoveredTarget ||
      oldDelegate.scheme != scheme;
}
