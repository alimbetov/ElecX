import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/surface_navigation.dart';
import '../../domain/surfaces.dart';
import '../../engine/adaptive_grid.dart';
import '../../engine/render_policy.dart';
import '../../engine/world_camera.dart';
import 'editor_controller.dart';

class SurfaceCanvas extends StatefulWidget {
  const SurfaceCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  State<SurfaceCanvas> createState() => _SurfaceCanvasState();
}

class _SurfaceCanvasState extends State<SurfaceCanvas> {
  WorldCamera? _camera;
  String? _surfaceId;
  Offset? _panAnchor;
  Size _size = Size.zero;

  EditorController get controller => widget.controller;

  void _ensureCamera(_SurfaceExtent extent) {
    final id = controller.activeSurface?.id;
    if (_camera != null && _surfaceId == id) return;
    _surfaceId = id;
    _camera = const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10);
    if (!_size.isEmpty) _fit(extent);
  }

  void _fit(_SurfaceExtent extent) {
    if (_size.isEmpty) return;
    final bounds = MmBounds(
      left: 0,
      bottom: 0,
      right: math.max(1, extent.widthMm),
      top: math.max(1, extent.heightMm),
    );
    setState(() {
      _camera = (_camera ?? const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10))
          .fitBounds(
        bounds: bounds,
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        paddingPx: 88,
      );
    });
  }

  void _zoomAt(Offset cursor, double factor) {
    final camera = _camera;
    if (camera == null || _size.isEmpty) return;
    setState(() {
      _camera = camera.zoomAt(
        factor: factor,
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        cursorXpx: cursor.dx,
        cursorYpx: cursor.dy,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (surface == null || space == null) {
      return const Center(child: Text('Выберите поверхность помещения'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final extent = _SurfaceExtent.fromController(controller);
        _ensureCamera(extent);
        final camera = _camera!;
        final projection = _SurfaceProjection(
          controller: controller,
          viewportSize: _size,
          camera: camera,
          extent: extent,
        );
        final lod = RenderPolicy.lodForWorldUnitsPerPixel(camera.mmPerPixel);

        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SurfacePainter(controller, projection, lod),
                ),
              ),
            ),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  _zoomAt(
                    event.localPosition,
                    event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18,
                  );
                },
                onPointerDown: (event) {
                  if (event.buttons == kMiddleMouseButton) {
                    _panAnchor = event.localPosition;
                  }
                },
                onPointerMove: (event) {
                  final anchor = _panAnchor;
                  if (anchor == null) return;
                  final delta = event.localPosition - anchor;
                  _panAnchor = event.localPosition;
                  setState(() {
                    _camera = _camera!.panPixels(delta.dx, delta.dy);
                  });
                },
                onPointerUp: (_) => _panAnchor = null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final point = projection.viewportToSurface(details.localPosition);
                    if (point == null) return;
                    if (surface.type == SurfacePlaneType.wall) {
                      final hit = projection.wallEdgeHit(
                        details.localPosition,
                        thresholdPx: 20,
                      );
                      if (hit != null) {
                        controller.navigateWallEdge(hit.edge, hit.point);
                        return;
                      }
                    } else {
                      final hit = projection.horizontalBoundaryHit(
                        space.boundary.vertices,
                        details.localPosition,
                        thresholdPx: 20,
                      );
                      if (hit != null) {
                        controller.navigateHorizontalBoundary(hit.edgeIndex, hit.point);
                        return;
                      }
                    }
                    controller.surfaceTap(point);
                  },
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Card(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Вписать поверхность',
                      onPressed: () => _fit(extent),
                      icon: const Icon(Icons.fit_screen),
                    ),
                    IconButton(
                      onPressed: () => _zoomAt(_size.center(Offset.zero), 0.8),
                      icon: const Icon(Icons.zoom_out),
                    ),
                    IconButton(
                      onPressed: () => _zoomAt(_size.center(Offset.zero), 1.25),
                      icon: const Icon(Icons.zoom_in),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text('${lod.name} · ${camera.mmPerPixel.toStringAsFixed(1)} mm/px'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _SurfaceExtent {
  const _SurfaceExtent({
    required this.widthMm,
    required this.heightMm,
    required this.floorLeftMm,
    required this.floorBottomMm,
  });

  factory _SurfaceExtent.fromController(EditorController controller) {
    final surface = controller.activeSurface!;
    final space = controller.selectedSpace!;
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall!;
      return _SurfaceExtent(
        widthMm: wall.lengthMm.round(),
        heightMm: wall.heightMm,
        floorLeftMm: 0,
        floorBottomMm: 0,
      );
    }
    final bounds = space.boundary.bounds;
    return _SurfaceExtent(
      widthMm: bounds.width,
      heightMm: bounds.height,
      floorLeftMm: bounds.left,
      floorBottomMm: bounds.bottom,
    );
  }

  final int widthMm;
  final int heightMm;
  final int floorLeftMm;
  final int floorBottomMm;
}

final class _WallEdgeHit {
  const _WallEdgeHit(this.edge, this.point);
  final WallNavigationEdge edge;
  final SurfacePointMm point;
}

final class _HorizontalBoundaryHit {
  const _HorizontalBoundaryHit(this.edgeIndex, this.point);
  final int edgeIndex;
  final SurfacePointMm point;
}

final class _SurfaceProjection {
  const _SurfaceProjection({
    required this.controller,
    required this.viewportSize,
    required this.camera,
    required this.extent,
  });

  final EditorController controller;
  final Size viewportSize;
  final WorldCamera camera;
  final _SurfaceExtent extent;

  double get widthMm => extent.widthMm.toDouble();
  double get heightMm => extent.heightMm.toDouble();
  double get pixelsPerMm => 1 / camera.mmPerPixel;

  Offset surfaceToViewport(SurfacePointMm point) {
    final screen = camera.worldToScreen(
      viewportWidthPx: viewportSize.width,
      viewportHeightPx: viewportSize.height,
      point: MmPoint(point.xMm, point.yMm),
    );
    return Offset(screen.x, screen.y);
  }

  SurfacePointMm? viewportToSurface(Offset point) {
    final world = camera.screenToWorld(
      viewportWidthPx: viewportSize.width,
      viewportHeightPx: viewportSize.height,
      xPx: point.dx,
      yPx: point.dy,
    );
    if (world.x < 0 || world.y < 0 || world.x > extent.widthMm || world.y > extent.heightMm) {
      return null;
    }
    return SurfacePointMm(world.x, world.y);
  }

  Rect get surfaceRect => Rect.fromPoints(
        surfaceToViewport(SurfacePointMm(0, extent.heightMm)),
        surfaceToViewport(SurfacePointMm(extent.widthMm, 0)),
      );

  _WallEdgeHit? wallEdgeHit(Offset viewportPoint, {required double thresholdPx}) {
    final local = viewportToSurface(viewportPoint);
    if (local == null) return null;
    final thresholdMm = thresholdPx * camera.mmPerPixel;
    final distances = <WallNavigationEdge, double>{
      WallNavigationEdge.start: local.xMm.toDouble(),
      WallNavigationEdge.end: widthMm - local.xMm,
      WallNavigationEdge.floor: local.yMm.toDouble(),
      WallNavigationEdge.ceiling: heightMm - local.yMm,
    };
    final entry = distances.entries.reduce((a, b) => a.value <= b.value ? a : b);
    if (entry.value > thresholdMm) return null;
    final point = switch (entry.key) {
      WallNavigationEdge.start => SurfacePointMm(0, local.yMm),
      WallNavigationEdge.end => SurfacePointMm(extent.widthMm, local.yMm),
      WallNavigationEdge.floor => SurfacePointMm(local.xMm, 0),
      WallNavigationEdge.ceiling => SurfacePointMm(local.xMm, extent.heightMm),
    };
    return _WallEdgeHit(entry.key, point);
  }

  _HorizontalBoundaryHit? horizontalBoundaryHit(
    List<MmPoint> vertices,
    Offset viewportPoint, {
    required double thresholdPx,
  }) {
    var nearestDistance = double.infinity;
    int? nearestIndex;
    Offset? nearestPoint;
    for (var i = 0; i < vertices.length; i++) {
      final a = floorPointToViewport(vertices[i]);
      final b = floorPointToViewport(vertices[(i + 1) % vertices.length]);
      final candidate = _closestPointOnSegment(viewportPoint, a, b);
      final distance = (viewportPoint - candidate).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
        nearestPoint = candidate;
      }
    }
    if (nearestIndex == null || nearestPoint == null || nearestDistance > thresholdPx) {
      return null;
    }
    final local = viewportToSurface(nearestPoint);
    return local == null ? null : _HorizontalBoundaryHit(nearestIndex, local);
  }

  Offset floorPointToViewport(MmPoint point) => surfaceToViewport(
        SurfacePointMm(
          point.x - extent.floorLeftMm,
          point.y - extent.floorBottomMm,
        ),
      );

  Offset _closestPointOnSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return a;
    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return a + ab * t;
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(this.controller, this.projection, this.lod);

  final EditorController controller;
  final _SurfaceProjection projection;
  final RenderLod lod;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F8FA));
    final surface = controller.activeSurface!;
    if (surface.type == SurfacePlaneType.wall) {
      _drawWall(canvas);
    } else {
      _drawHorizontalSurface(canvas, surface.type);
    }
    _drawRoute(canvas);
  }

  void _drawWall(Canvas canvas) {
    final wall = controller.activeWall!;
    final rect = projection.surfaceRect;
    canvas.drawRect(rect, Paint()..color = Colors.white);
    _drawAdaptiveGrid(canvas, rect);
    if (RenderPolicy.showOpenings(lod)) {
      for (final opening in controller.activeWallOpenings) {
        _drawOpening(canvas, opening);
      }
    }
    canvas.drawRect(
      rect,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF263238),
    );
    _drawNavigationEdges(canvas, rect);
    if (controller.dimensionsVisible && RenderPolicy.showFineDimensions(lod)) {
      _horizontalDimension(canvas, rect.left, rect.right, rect.bottom + 30, '${wall.lengthMm.round()} mm');
      _verticalDimension(canvas, rect.right + 34, rect.top, rect.bottom, '${wall.heightMm} mm');
    }
    _label(
      canvas,
      'Стена ${(wall.ref.wallIndex ?? 0) + 1} · ${wall.lengthMm.round()} × ${wall.heightMm} mm',
      Offset(rect.center.dx, rect.top - 34),
      centered: true,
      bold: true,
    );
  }

  void _drawHorizontalSurface(Canvas canvas, SurfacePlaneType type) {
    final space = controller.selectedSpace!;
    final path = Path();
    final first = projection.floorPointToViewport(space.boundary.vertices.first);
    path.moveTo(first.dx, first.dy);
    for (final vertex in space.boundary.vertices.skip(1)) {
      final point = projection.floorPointToViewport(vertex);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(path);
    _drawAdaptiveGrid(canvas, projection.surfaceRect);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF263238),
    );
    _label(
      canvas,
      type == SurfacePlaneType.floor ? 'ПОЛ · ${space.name}' : 'ПОТОЛОК · ${space.name}',
      Offset(projection.surfaceRect.center.dx, projection.surfaceRect.top - 34),
      centered: true,
      bold: true,
    );
  }

  void _drawAdaptiveGrid(Canvas canvas, Rect rect) {
    final spec = AdaptiveGridPolicy.forScale(projection.camera.mmPerPixel);
    final minor = Paint()..color = const Color(0xFFE8EBEF)..strokeWidth = 0.7;
    final major = Paint()..color = const Color(0xFFCDD3DB)..strokeWidth = 1.0;
    for (var x = 0; x <= projection.extent.widthMm; x += spec.minorStepMm) {
      final isMajor = x % spec.majorStepMm == 0;
      if (!isMajor && (!spec.showMinor || lod.index < RenderLod.room.index)) continue;
      final point = projection.surfaceToViewport(SurfacePointMm(x, 0));
      canvas.drawLine(Offset(point.dx, rect.top), Offset(point.dx, rect.bottom), isMajor ? major : minor);
    }
    for (var y = 0; y <= projection.extent.heightMm; y += spec.minorStepMm) {
      final isMajor = y % spec.majorStepMm == 0;
      if (!isMajor && (!spec.showMinor || lod.index < RenderLod.room.index)) continue;
      final point = projection.surfaceToViewport(SurfacePointMm(0, y));
      canvas.drawLine(Offset(rect.left, point.dy), Offset(rect.right, point.dy), isMajor ? major : minor);
    }
  }

  void _drawOpening(Canvas canvas, ArchitecturalOpening opening) {
    final a = projection.surfaceToViewport(SurfacePointMm(opening.offsetFromStartMm, opening.topMm));
    final b = projection.surfaceToViewport(
      SurfacePointMm(opening.offsetFromStartMm + opening.widthMm, opening.sillHeightMm),
    );
    final rect = Rect.fromPoints(a, b);
    canvas.drawRect(rect, Paint()..color = const Color(0xFFDDEFF7));
    canvas.drawRect(
      rect,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFF54606B),
    );
  }

  void _drawRoute(Canvas canvas) {
    final segment = controller.activeRouteSegment;
    if (segment == null || segment.points.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFFD66B2C)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset? previous;
    for (final point in segment.points) {
      final current = projection.surfaceToViewport(point);
      if (previous != null) canvas.drawLine(previous, current, paint);
      canvas.drawCircle(current, 4.2, paint);
      previous = current;
    }
  }

  void _drawNavigationEdges(Canvas canvas, Rect rect) {
    final paint = Paint()..color = const Color(0x33246DB3)..strokeWidth = 7;
    canvas.drawLine(rect.topLeft, rect.topRight, paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topLeft, rect.bottomLeft, paint);
    canvas.drawLine(rect.topRight, rect.bottomRight, paint);
  }

  void _horizontalDimension(Canvas canvas, double left, double right, double y, String text) {
    final paint = Paint()..color = const Color(0xFF4B5563)..strokeWidth = 0.9;
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    _label(canvas, text, Offset((left + right) / 2, y - 10), centered: true, small: true);
  }

  void _verticalDimension(Canvas canvas, double x, double top, double bottom, String text) {
    final paint = Paint()..color = const Color(0xFF4B5563)..strokeWidth = 0.9;
    canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    _label(canvas, text, Offset(x + 8, (top + bottom) / 2), small: true);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset point, {
    bool centered = false,
    bool bold = false,
    bool small = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF374151),
          fontSize: small ? 10 : 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered ? point - Offset(painter.width / 2, painter.height / 2) : point,
    );
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) =>
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.lod != lod ||
      oldDelegate.controller.activeSurface != controller.activeSurface ||
      oldDelegate.controller.routeSegments.length != controller.routeSegments.length;
}
