import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/wall_profile.dart';
import '../../engine/wall_profile_plan_projection.dart';
import 'editable_spatial_canvas.dart' as editable;
import 'editor_controller.dart';
import 'room_world_overlay.dart';

/// Plan-canvas host that keeps direct editing intact and adds high-level
/// navigation gestures plus a profile-aware wall summary.
class SpatialCanvas extends StatefulWidget {
  const SpatialCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  State<SpatialCanvas> createState() => _SpatialCanvasState();
}

class _SpatialCanvasState extends State<SpatialCanvas> {
  Offset? _pointerDown;
  bool _pointerMoved = false;
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  EditorController get controller => widget.controller;

  void _pointerDownHandler(PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton) return;
    _pointerDown = event.localPosition;
    _pointerMoved = false;
  }

  void _pointerMoveHandler(PointerMoveEvent event) {
    final start = _pointerDown;
    if (start == null) return;
    if ((event.localPosition - start).distance > 8) {
      _pointerMoved = true;
    }
  }

  void _pointerUpHandler(PointerUpEvent event) {
    final start = _pointerDown;
    _pointerDown = null;
    if (start == null || _pointerMoved) return;
    if (controller.tool != EditorTool.select ||
        controller.selectedSpace == null ||
        controller.selectedOpening != null) {
      _lastTapAt = null;
      _lastTapPosition = null;
      return;
    }

    final now = DateTime.now();
    final previousAt = _lastTapAt;
    final previousPosition = _lastTapPosition;
    final isDoubleTap = previousAt != null &&
        now.difference(previousAt) <= const Duration(milliseconds: 360) &&
        previousPosition != null &&
        (event.localPosition - previousPosition).distance <= 24;

    if (isDoubleTap) {
      _lastTapAt = null;
      _lastTapPosition = null;
      showRoomWorldOverlay(context, controller);
      return;
    }

    _lastTapAt = now;
    _lastTapPosition = event.localPosition;
  }

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    final profiles = space?.wallProfiles.entries.toList(growable: false) ?? const [];

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _pointerDownHandler,
            onPointerMove: _pointerMoveHandler,
            onPointerUp: _pointerUpHandler,
            onPointerCancel: (_) {
              _pointerDown = null;
              _pointerMoved = false;
            },
            child: editable.SpatialCanvas(controller: controller),
          ),
        ),
        if (profiles.isNotEmpty)
          Positioned(
            left: 10,
            top: 10,
            child: _ProfiledWallsStrip(
              controller: controller,
              profiles: profiles,
            ),
          ),
      ],
    );
  }
}

class _ProfiledWallsStrip extends StatelessWidget {
  const _ProfiledWallsStrip({
    required this.controller,
    required this.profiles,
  });

  final EditorController controller;
  final List<MapEntry<int, WallProfile>> profiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_tree_outlined, size: 16),
            const SizedBox(width: 6),
            Text(
              'ПРОФИЛЬ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 6),
            for (final entry in profiles) ...[
              _ProfileWallButton(
                wallIndex: entry.key,
                profile: entry.value,
                selected: controller.activeSurface?.wallIndex == entry.key,
                onPressed: () => controller.showWall(entry.key),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileWallButton extends StatelessWidget {
  const _ProfileWallButton({
    required this.wallIndex,
    required this.profile,
    required this.selected,
    required this.onPressed,
  });

  final int wallIndex;
  final WallProfile profile;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'W${wallIndex + 1}: нестандартный профиль стены',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 30,
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? scheme.secondaryContainer : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 18,
                child: CustomPaint(
                  painter: _ProfileSparklinePainter(
                    profile: profile,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'W${wallIndex + 1}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSparklinePainter extends CustomPainter {
  const _ProfileSparklinePainter({
    required this.profile,
    required this.color,
  });

  final WallProfile profile;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final contour = WallProfilePlanProjection.topContour(profile);
    if (contour.isEmpty || profile.maxX <= 0 || profile.maxY <= 0) return;

    final path = Path();
    for (var i = 0; i < contour.length; i++) {
      final point = contour[i];
      final x = point.xMm / profile.maxX * size.width;
      final depthRatio = point.depthFromTopMm / math.max(1, profile.maxY);
      final y = 2 + depthRatio * math.max(1, size.height - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..color = color,
    );

    if (WallProfilePlanProjection.hasVerticalVariation(profile)) {
      canvas.drawCircle(
        const Offset(3, 15),
        2.2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileSparklinePainter oldDelegate) =>
      oldDelegate.profile != profile || oldDelegate.color != color;
}
