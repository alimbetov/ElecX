import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../engine/world_camera.dart';
import 'cad_visual_tokens.dart';
import 'site_map_interaction.dart';

class SiteMapCanvas extends StatefulWidget {
  const SiteMapCanvas({
    required this.entities,
    required this.interaction,
    required this.onEntityOpen,
    this.initialCamera,
    this.onCameraChanged,
    super.key,
  });

  final List<SiteMapEntity> entities;
  final SiteMapInteractionController interaction;
  final ValueChanged<SiteMapEntity> onEntityOpen;
  final WorldCamera? initialCamera;
  final ValueChanged<WorldCamera>? onCameraChanged;

  @override
  State<SiteMapCanvas> createState() => _SiteMapCanvasState();
}

class _SiteMapCanvasState extends State<SiteMapCanvas> {
  late WorldCamera _camera;
  Size _size = Size.zero;
  bool _fitted = false;
  Offset? _panStart;
  WorldCamera? _panCamera;

  @override
  void initState() {
    super.initState();
    _camera = widget.initialCamera ??
        const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 100);
    widget.interaction.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SiteMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interaction != widget.interaction) {
      oldWidget.interaction.removeListener(_refresh);
      widget.interaction.addListener(_refresh);
    }
    if (oldWidget.entities != widget.entities) {
      _fitted = false;
    }
  }

  @override
  void dispose() {
    widget.interaction.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_fitted && _size.width > 0 && _size.height > 0) {
          final bounds = _allBounds();
          if (bounds != null) {
            _camera = _camera.fitBounds(
              bounds: bounds,
              viewportWidthPx: _size.width,
              viewportHeightPx: _size.height,
              paddingPx: 72,
            );
          }
          _fitted = true;
        }
        final scheme = Theme.of(context).colorScheme;
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: MouseRegion(
            cursor: widget.interaction.hoveredNodeId == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onHover: (event) => _updateHover(event.localPosition),
            onExit: (_) => widget.interaction.hover(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _selectAt(details.localPosition),
              onDoubleTapDown: (details) => _openAt(details.localPosition),
              onPanStart: (details) {
                _panStart = details.localPosition;
                _panCamera = _camera;
              },
              onPanUpdate: (details) {
                final start = _panStart;
                final camera = _panCamera;
                if (start == null || camera == null) return;
                final delta = details.localPosition - start;
                _setCamera(camera.panPixels(delta.dx, delta.dy));
              },
              onPanEnd: (_) {
                _panStart = null;
                _panCamera = null;
              },
              child: CustomPaint(
                painter: _SiteMapPainter(
                  camera: _camera,
                  entities: widget.entities,
                  hoveredNodeId: widget.interaction.hoveredNodeId,
                  selectedNodeId: widget.interaction.selectedNodeId,
                  scheme: scheme,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _size.isEmpty) return;
    final factor = event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18;
    _setCamera(
      _camera.zoomAt(
        factor: factor,
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        cursorXpx: event.localPosition.dx,
        cursorYpx: event.localPosition.dy,
        minMmPerPixel: 5,
        maxMmPerPixel: 5000,
      ),
    );
  }

  void _setCamera(WorldCamera camera) {
    setState(() => _camera = camera);
    widget.onCameraChanged?.call(camera);
  }

  void _updateHover(Offset local) {
    final entity = _hit(local);
    widget.interaction.hover(entity?.navigatorNodeId);
  }

  void _selectAt(Offset local) {
    final entity = _hit(local);
    widget.interaction.select(entity?.navigatorNodeId);
  }

  void _openAt(Offset local) {
    final entity = _hit(local);
    if (entity == null) return;
    widget.interaction.select(entity.navigatorNodeId);
    widget.onEntityOpen(entity);
  }

  SiteMapEntity? _hit(Offset local) {
    if (_size.isEmpty) return null;
    final point = _camera.screenToWorld(
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      xPx: local.dx,
      yPx: local.dy,
    );
    for (final entity in widget.entities.reversed) {
      if (entity.contains(point)) return entity;
    }
    return null;
  }

  MmBounds? _allBounds() {
    MmBounds? result;
    for (final entity in widget.entities) {
      result = result == null
          ? entity.boundary.bounds
          : result.union(entity.boundary.bounds);
    }
    return result;
  }
}

class _SiteMapPainter extends CustomPainter {
  _SiteMapPainter({
    required this.camera,
    required this.entities,
    required this.hoveredNodeId,
    required this.selectedNodeId,
    required this.scheme,
  });

  final WorldCamera camera;
  final List<SiteMapEntity> entities;
  final String? hoveredNodeId;
  final String? selectedNodeId;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    for (final entity in entities) {
      final selected = entity.navigatorNodeId == selectedNodeId;
      final hovered = entity.navigatorNodeId == hoveredNodeId;
      final path = Path();
      final screenPoints = <Offset>[];
      for (var i = 0; i < entity.boundary.vertices.length; i++) {
        final screen = camera.worldToScreen(
          viewportWidthPx: size.width,
          viewportHeightPx: size.height,
          point: entity.boundary.vertices[i],
        );
        final point = Offset(screen.x, screen.y);
        screenPoints.add(point);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = selected
            ? CadVisualTokens.selectedFill(scheme)
            : hovered
                ? CadVisualTokens.hoverFill(scheme)
                : CadVisualTokens.ghostFill(scheme);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected
            ? CadVisualTokens.selectedGeometryStroke
            : hovered
                ? 1.8
                : CadVisualTokens.geometryStroke
        ..color = selected
            ? CadVisualTokens.selectedGeometry(scheme)
            : CadVisualTokens.geometry(scheme);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);

      if (!_labelFits(screenPoints)) continue;
      final center = camera.worldToScreen(
        viewportWidthPx: size.width,
        viewportHeightPx: size.height,
        point: entity.boundary.bounds.center,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: entity.label,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: selected || hovered ? 12 : 11,
            fontWeight:
                selected || hovered ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 180);
      painter.paint(
        canvas,
        Offset(center.x - painter.width / 2, center.y - painter.height / 2),
      );
    }
  }

  bool _labelFits(List<Offset> points) {
    if (points.isEmpty) return false;
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points.skip(1)) {
      minX = mathMin(minX, point.dx);
      maxX = mathMax(maxX, point.dx);
      minY = mathMin(minY, point.dy);
      maxY = mathMax(maxY, point.dy);
    }
    return maxX - minX >= 62 && maxY - minY >= 24;
  }

  double mathMin(double a, double b) => a < b ? a : b;

  double mathMax(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(covariant _SiteMapPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.hoveredNodeId != hoveredNodeId ||
      oldDelegate.selectedNodeId != selectedNodeId ||
      oldDelegate.entities != entities ||
      oldDelegate.scheme != scheme;
}
