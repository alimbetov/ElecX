import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../engine/world_camera.dart';
import 'cad_dimension_painter.dart';
import 'wall_distance_guide_calculator.dart';

/// Transient drawing state; no dimensions or hold state are persisted.
class DynamicWallDimensionsOverlay extends StatefulWidget {
  const DynamicWallDimensionsOverlay({
    required this.selectionId,
    required this.sceneId,
    required this.guides,
    required this.camera,
    required this.viewport,
    required this.held,
    super.key,
  });

  final String? selectionId;
  final String sceneId;
  final List<WallDistanceGuide> guides;
  final WorldCamera camera;
  final Size viewport;
  final ValueListenable<bool> held;

  @override
  State<DynamicWallDimensionsOverlay> createState() =>
      _DynamicWallDimensionsOverlayState();
}

class _DynamicWallDimensionsOverlayState
    extends State<DynamicWallDimensionsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _opacity;
  Timer? _pendingHide;
  List<WallDistanceGuide> _lastValid = const [];

  bool get _hasSelection =>
      widget.selectionId != null && widget.guides.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _opacity = AnimationController(
      vsync: this,
      value: _hasSelection ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _lastValid = widget.guides;
    _opacity.addStatusListener(_onOpacityStatus);
    widget.held.addListener(_heldChanged);
  }

  void _onOpacityStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        !_hasSelection &&
        !widget.held.value &&
        _lastValid.isNotEmpty &&
        mounted) {
      setState(() => _lastValid = const []);
    }
  }

  void _heldChanged() {
    if (!mounted) return;
    if (widget.held.value) {
      _pendingHide?.cancel();
      _opacity.animateTo(
        1.0,
        duration: const Duration(milliseconds: 150),
      );
    } else if (!_hasSelection) {
      _hide(afterHold: true);
    }
  }

  void _hide({bool afterHold = false}) {
    _pendingHide?.cancel();
    if (widget.held.value) return;
    _pendingHide = Timer(
      Duration(milliseconds: afterHold ? 150 : 200),
      () {
        if (!mounted || widget.held.value || _hasSelection) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _opacity.value = 0;
        } else {
          _opacity.animateTo(
            0.0,
            duration: Duration(milliseconds: afterHold ? 700 : 350),
          );
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant DynamicWallDimensionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.held != widget.held) {
      oldWidget.held.removeListener(_heldChanged);
      widget.held.addListener(_heldChanged);
    }
    if (widget.sceneId != oldWidget.sceneId) {
      _pendingHide?.cancel();
      _lastValid = const [];
      _opacity.value = 0;
    }
    if (_hasSelection) {
      _pendingHide?.cancel();
      _lastValid = widget.guides;
      if (MediaQuery.disableAnimationsOf(context)) {
        _opacity.value = 1;
      } else if (_opacity.status != AnimationStatus.forward &&
          _opacity.value < 1.0) {
        _opacity.animateTo(
          1.0,
          duration: const Duration(milliseconds: 150),
        );
      }
    } else if (oldWidget.selectionId != widget.selectionId ||
        oldWidget.guides.isNotEmpty) {
      _hide();
    }
  }

  @override
  void dispose() {
    _pendingHide?.cancel();
    widget.held.removeListener(_heldChanged);
    _opacity.removeStatusListener(_onOpacityStatus);
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guides = _hasSelection ? widget.guides : _lastValid;
    if (guides.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, _) => RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('dynamic-wall-dimensions'),
            painter: _DynamicDimensionsPainter(
              guides: guides,
              camera: widget.camera,
              viewport: widget.viewport,
              scheme: Theme.of(context).colorScheme,
              opacity: _opacity.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _DynamicDimensionsPainter extends CustomPainter {
  const _DynamicDimensionsPainter({
    required this.guides,
    required this.camera,
    required this.viewport,
    required this.scheme,
    required this.opacity,
  });

  final List<WallDistanceGuide> guides;
  final WorldCamera camera;
  final Size viewport;
  final ColorScheme scheme;
  final double opacity;

  Offset _screenPoint(WallDistanceGuide guide, {required bool end}) {
    final point = end ? guide.end : guide.start;
    final location = camera.worldToScreen(
      viewportWidthPx: viewport.width,
      viewportHeightPx: viewport.height,
      point: point,
    );
    return Offset(location.x, location.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final guide in guides) {
      final start = _screenPoint(guide, end: false);
      final end = _screenPoint(guide, end: true);
      if ((end - start).distance < 36) continue;
      final offset = switch (guide.direction) {
        WallGuideDirection.left ||
        WallGuideDirection.right =>
          const Offset(0, -17),
        WallGuideDirection.down || WallGuideDirection.up => const Offset(17, 0),
      };
      CadDimensionPainter.drawLinear(
        canvas,
        geometryStart: start,
        geometryEnd: end,
        dimensionStart: start + offset,
        dimensionEnd: end + offset,
        label: '${guide.distanceMm.round()} мм',
        scheme: scheme,
        lightweight: true,
        boxedLabel: true,
        opacity: opacity,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DynamicDimensionsPainter old) =>
      !listEquals(guides, old.guides) ||
      camera != old.camera ||
      viewport != old.viewport ||
      scheme != old.scheme ||
      opacity != old.opacity;
}
