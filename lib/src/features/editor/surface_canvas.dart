import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/surface_navigation.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';

class SurfaceCanvas extends StatelessWidget {
  const SurfaceCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (surface == null || space == null) {
      return const Center(child: Text('Выберите поверхность помещения'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final projection = _SurfaceProjection(controller, size);
        return GestureDetector(
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
          child: CustomPaint(
            painter: _SurfacePainter(controller, projection),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
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
  _SurfaceProjection(this.controller, this.viewportSize) {
    final surface = controller.activeSurface!;
    final space = controller.selectedSpace!;
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall!;
      widthMm = wall.lengthMm;
      heightMm = wall.heightMm.toDouble();
    } else {
      final bounds = space.boundary.bounds;
      widthMm = bounds.width.toDouble();
      heightMm = bounds.height.toDouble();
      floorLeftMm = bounds.left;
      floorBottomMm = bounds.bottom;
    }

    const horizontalPadding = 88.0;
    const verticalPadding = 82.0;
    final fitX = (viewportSize.width - horizontalPadding * 2) / widthMm;
    final fitY = (viewportSize.height - verticalPadding * 2) / heightMm;
    pixelsPerMm = math.max(
      0.0001,
      math.min(fitX, fitY) * controller.zoom,
    );
    final drawingWidth = widthMm * pixelsPerMm;
    final drawingHeight = heightMm * pixelsPerMm;
    origin = Offset(
      (viewportSize.width - drawingWidth) / 2,
      (viewportSize.height + drawingHeight) / 2,
    );
  }

  final EditorController controller;
  final Size viewportSize;
  late final double widthMm;
  late final double heightMm;
  late final double pixelsPerMm;
  late final Offset origin;
  int floorLeftMm = 0;
  int floorBottomMm = 0;

  Offset surfaceToViewport(SurfacePointMm point) => Offset(
        origin.dx + point.xMm * pixelsPerMm,
        origin.dy - point.yMm * pixelsPerMm,
      );

  SurfacePointMm? viewportToSurface(Offset point) {
    final x = (point.dx - origin.dx) / pixelsPerMm;
    final y = (origin.dy - point.dy) / pixelsPerMm;
    if (x < 0 || y < 0 || x > widthMm || y > heightMm) return null;
    return SurfacePointMm(x.round(), y.round());
  }

  _WallEdgeHit? wallEdgeHit(
    Offset viewportPoint, {
    required double thresholdPx,
  }) {
    final local = viewportToSurface(viewportPoint);
    if (local == null) return null;

    final thresholdMm = thresholdPx / pixelsPerMm;
    final distances = <WallNavigationEdge, double>{
      WallNavigationEdge.start: local.xMm.toDouble(),
      WallNavigationEdge.end: widthMm - local.xMm,
      WallNavigationEdge.floor: local.yMm.toDouble(),
      WallNavigationEdge.ceiling: heightMm - local.yMm,
    };

    WallNavigationEdge? nearest;
    var nearestDistance = double.infinity;
    for (final entry in distances.entries) {
      if (entry.value < nearestDistance) {
        nearestDistance = entry.value;
        nearest = entry.key;
      }
    }
    if (nearest == null || nearestDistance > thresholdMm) return null;

    final clamped = switch (nearest) {
      WallNavigationEdge.start => SurfacePointMm(0, local.yMm),
      WallNavigationEdge.end => SurfacePointMm(widthMm.round(), local.yMm),
      WallNavigationEdge.floor => SurfacePointMm(local.xMm, 0),
      WallNavigationEdge.ceiling =>
        SurfacePointMm(local.xMm, heightMm.round()),
    };
    return _WallEdgeHit(nearest, clamped);
  }

  _HorizontalBoundaryHit? horizontalBoundaryHit(
    List<MmPoint> vertices,
    Offset viewportPoint, {
    required double thresholdPx,
  }) {
    if (vertices.length < 3) return null;

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

    if (nearestIndex == null ||
        nearestPoint == null ||
        nearestDistance > thresholdPx) {
      return null;
    }

    final local = viewportToSurface(nearestPoint);
    if (local == null) return null;
    return _HorizontalBoundaryHit(nearestIndex, local);
  }

  Offset _closestPointOnSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return a;
    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    return a + ab * t;
  }

  Offset floorPointToViewport(MmPoint point) => surfaceToViewport(
        SurfacePointMm(point.x - floorLeftMm, point.y - floorBottomMm),
      );
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(this.controller, this.projection);

  final EditorController controller;
  final _SurfaceProjection projection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F8FA),
    );
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
    final topLeft = projection.surfaceToViewport(
      SurfacePointMm(0, wall.heightMm),
    );
    final bottomRight = projection.surfaceToViewport(
      SurfacePointMm(wall.lengthMm.round(), 0),
    );
    final wallRect = Rect.fromPoints(topLeft, bottomRight);

    canvas.drawRect(wallRect, Paint()..color = Colors.white);
    _drawSurfaceGrid(
      canvas,
      wallRect,
      wall.lengthMm.round(),
      wall.heightMm,
    );

    for (final opening in controller.activeWallOpenings) {
      _drawOpening(canvas, opening);
    }

    canvas.drawRect(
      wallRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF263238),
    );

    _drawNavigationEdges(canvas, wallRect);

    if (controller.dimensionsVisible) {
      _drawWallDimensions(canvas, wallRect, wall);
    }

    _label(
      canvas,
      'Стена ${(wall.ref.wallIndex ?? 0) + 1} · '
      '${wall.lengthMm.round()} × ${wall.heightMm} mm',
      Offset(wallRect.center.dx, wallRect.top - 38),
      centered: true,
      bold: true,
    );
  }

  void _drawNavigationEdges(Canvas canvas, Rect wallRect) {
    final paint = Paint()
      ..color = const Color(0x33246DB3)
      ..strokeWidth = 7;
    canvas.drawLine(wallRect.topLeft, wallRect.topRight, paint);
    canvas.drawLine(wallRect.bottomLeft, wallRect.bottomRight, paint);
    canvas.drawLine(wallRect.topLeft, wallRect.bottomLeft, paint);
    canvas.drawLine(wallRect.topRight, wallRect.bottomRight, paint);

    _label(
      canvas,
      'ПОТОЛОК ↑',
      Offset(wallRect.center.dx, wallRect.top + 13),
      centered: true,
      small: true,
    );
    _label(
      canvas,
      '↓ ПОЛ',
      Offset(wallRect.center.dx, wallRect.bottom - 13),
      centered: true,
      small: true,
    );
    _label(
      canvas,
      '← соседняя стена',
      Offset(wallRect.left + 10, wallRect.center.dy),
      small: true,
    );
    _label(
      canvas,
      'соседняя стена →',
      Offset(wallRect.right - 104, wallRect.center.dy),
      small: true,
    );
  }

  void _drawHorizontalSurface(Canvas canvas, SurfacePlaneType type) {
    final space = controller.selectedSpace!;
    final path = Path();
    final first = projection.floorPointToViewport(space.boundary.vertices.first);
    path.moveTo(first.dx, first.dy);
    for (final vertex in space.boundary.vertices.skip(1)) {
      final p = projection.floorPointToViewport(vertex);
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(path);
    final bounds = space.boundary.bounds;
    final rect = Rect.fromPoints(
      projection.floorPointToViewport(MmPoint(bounds.left, bounds.top)),
      projection.floorPointToViewport(MmPoint(bounds.right, bounds.bottom)),
    );
    _drawSurfaceGrid(canvas, rect, bounds.width, bounds.height);
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0x33246DB3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF263238),
    );

    final center = projection.floorPointToViewport(space.referenceFrame.origin);
    _dashLine(
      canvas,
      Offset(rect.left, center.dy),
      Offset(rect.right, center.dy),
      Paint()
        ..color = const Color(0xFFCC6A2E)
        ..strokeWidth = 1.2,
    );
    _dashLine(
      canvas,
      Offset(center.dx, rect.top),
      Offset(center.dx, rect.bottom),
      Paint()
        ..color = const Color(0xFFCC6A2E)
        ..strokeWidth = 1.2,
    );

    if (controller.dimensionsVisible) {
      _drawRectDimensions(canvas, rect, bounds.width, bounds.height);
    }

    _label(
      canvas,
      type == SurfacePlaneType.floor
          ? 'ПОЛ · ${space.name}'
          : 'ПОТОЛОК · ${space.name}',
      Offset(rect.center.dx, rect.top - 38),
      centered: true,
      bold: true,
    );
    _label(
      canvas,
      'Нажмите у границы для перехода на стену',
      Offset(rect.center.dx, rect.bottom + 56),
      centered: true,
      small: true,
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
      if (previous != null) {
        canvas.drawLine(previous, current, paint);
      }
      canvas.drawCircle(current, 4.5, paint);
      previous = current;
    }

    final local = segment.points.last;
    final last = projection.surfaceToViewport(local);
    canvas.drawLine(
      Offset(
        last.dx,
        projection.origin.dy -
            projection.heightMm * projection.pixelsPerMm,
      ),
      Offset(last.dx, projection.origin.dy),
      Paint()
        ..color = const Color(0x44D66B2C)
        ..strokeWidth = 0.9,
    );
    canvas.drawLine(
      Offset(projection.origin.dx, last.dy),
      Offset(
        projection.origin.dx + projection.widthMm * projection.pixelsPerMm,
        last.dy,
      ),
      Paint()
        ..color = const Color(0x44D66B2C)
        ..strokeWidth = 0.9,
    );

    if (controller.dimensionsVisible) {
      _drawLiveRouteDimensions(canvas, local, last);
    }
  }

  void _drawLiveRouteDimensions(
    Canvas canvas,
    SurfacePointMm local,
    Offset point,
  ) {
    final left = projection.origin.dx;
    final right = left + projection.widthMm * projection.pixelsPerMm;
    final bottom = projection.origin.dy;
    final top = bottom - projection.heightMm * projection.pixelsPerMm;
    final paint = Paint()
      ..color = const Color(0xFF6B7280)
      ..strokeWidth = 0.8;

    final horizontalY = math.min(point.dy + 18, bottom - 8);
    canvas.drawLine(Offset(left, horizontalY), Offset(point.dx, horizontalY), paint);
    canvas.drawLine(Offset(point.dx, horizontalY), Offset(right, horizontalY), paint);
    _tick(canvas, Offset(left, horizontalY), paint);
    _tick(canvas, Offset(point.dx, horizontalY), paint);
    _tick(canvas, Offset(right, horizontalY), paint);
    _label(
      canvas,
      '${local.xMm} mm',
      Offset((left + point.dx) / 2, horizontalY - 10),
      centered: true,
      small: true,
    );
    _label(
      canvas,
      '${projection.widthMm.round() - local.xMm} mm',
      Offset((point.dx + right) / 2, horizontalY - 10),
      centered: true,
      small: true,
    );

    final verticalX = math.min(point.dx + 18, right - 8);
    canvas.drawLine(Offset(verticalX, point.dy), Offset(verticalX, bottom), paint);
    canvas.drawLine(Offset(verticalX, top), Offset(verticalX, point.dy), paint);
    _tick(canvas, Offset(verticalX, top), paint);
    _tick(canvas, Offset(verticalX, point.dy), paint);
    _tick(canvas, Offset(verticalX, bottom), paint);
    _label(
      canvas,
      '${local.yMm} mm',
      Offset(verticalX + 6, (point.dy + bottom) / 2),
      small: true,
    );
    _label(
      canvas,
      '${projection.heightMm.round() - local.yMm} mm',
      Offset(verticalX + 6, (top + point.dy) / 2),
      small: true,
    );
  }

  void _drawOpening(Canvas canvas, ArchitecturalOpening opening) {
    final left = projection.surfaceToViewport(
      SurfacePointMm(opening.offsetFromStartMm, opening.topMm),
    );
    final right = projection.surfaceToViewport(
      SurfacePointMm(
        opening.offsetFromStartMm + opening.widthMm,
        opening.sillHeightMm,
      ),
    );
    final rect = Rect.fromPoints(left, right);
    final fill = switch (opening.type) {
      ArchitecturalOpeningType.door => const Color(0xFFEDE4D3),
      ArchitecturalOpeningType.window => const Color(0xFFDDEFF7),
      ArchitecturalOpeningType.passage => const Color(0xFFF3F4F6),
      ArchitecturalOpeningType.technicalOpening => const Color(0xFFE8E8EA),
    };
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF54606B),
    );
    final name = switch (opening.type) {
      ArchitecturalOpeningType.door => 'Дверь',
      ArchitecturalOpeningType.window => 'Окно',
      ArchitecturalOpeningType.passage => 'Проём',
      ArchitecturalOpeningType.technicalOpening => 'Тех. проём',
    };
    _label(
      canvas,
      '$name ${opening.widthMm}×${opening.heightMm}',
      rect.center,
      centered: true,
    );
  }

  void _drawSurfaceGrid(
    Canvas canvas,
    Rect rect,
    int widthMm,
    int heightMm,
  ) {
    final step = controller.selectedSpace?.grid.minorStepMm ?? 100;
    final majorStep = step * 10;
    final minor = Paint()
      ..color = const Color(0xFFE8EBEF)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = const Color(0xFFCDD3DB)
      ..strokeWidth = 1.0;

    for (var x = 0; x <= widthMm; x += step) {
      final p = projection.surfaceToViewport(SurfacePointMm(x, 0));
      canvas.drawLine(
        Offset(p.dx, rect.top),
        Offset(p.dx, rect.bottom),
        x % majorStep == 0 ? major : minor,
      );
    }
    for (var y = 0; y <= heightMm; y += step) {
      final p = projection.surfaceToViewport(SurfacePointMm(0, y));
      canvas.drawLine(
        Offset(rect.left, p.dy),
        Offset(rect.right, p.dy),
        y % majorStep == 0 ? major : minor,
      );
    }
  }

  void _drawWallDimensions(
    Canvas canvas,
    Rect wallRect,
    RoomWallSurface wall,
  ) {
    _horizontalDimension(
      canvas,
      wallRect.left,
      wallRect.right,
      wallRect.bottom + 30,
      '${wall.lengthMm.round()} mm',
      extensionTop: wallRect.bottom,
    );
    _verticalDimension(
      canvas,
      wallRect.right + 34,
      wallRect.top,
      wallRect.bottom,
      '${wall.heightMm} mm',
      extensionLeft: wallRect.right,
    );

    for (final opening in controller.activeWallOpenings) {
      final start = projection.surfaceToViewport(
        SurfacePointMm(opening.offsetFromStartMm, 0),
      ).dx;
      final end = projection.surfaceToViewport(
        SurfacePointMm(opening.offsetFromStartMm + opening.widthMm, 0),
      ).dx;
      _horizontalDimension(
        canvas,
        wallRect.left,
        start,
        wallRect.bottom + 58,
        '${opening.offsetFromStartMm}',
        extensionTop: wallRect.bottom,
        small: true,
      );
      _horizontalDimension(
        canvas,
        start,
        end,
        wallRect.bottom + 58,
        '${opening.widthMm}',
        extensionTop: wallRect.bottom,
        small: true,
      );
      final rightRemaining = wall.lengthMm.round() -
          opening.offsetFromStartMm -
          opening.widthMm;
      _horizontalDimension(
        canvas,
        end,
        wallRect.right,
        wallRect.bottom + 58,
        '$rightRemaining',
        extensionTop: wallRect.bottom,
        small: true,
      );
    }
  }

  void _drawRectDimensions(
    Canvas canvas,
    Rect rect,
    int widthMm,
    int heightMm,
  ) {
    _horizontalDimension(
      canvas,
      rect.left,
      rect.right,
      rect.bottom + 30,
      '$widthMm mm',
      extensionTop: rect.bottom,
    );
    _verticalDimension(
      canvas,
      rect.right + 34,
      rect.top,
      rect.bottom,
      '$heightMm mm',
      extensionLeft: rect.right,
    );
  }

  void _horizontalDimension(
    Canvas canvas,
    double left,
    double right,
    double y,
    String text, {
    required double extensionTop,
    bool small = false,
  }) {
    final paint = Paint()
      ..color = const Color(0xFF4B5563)
      ..strokeWidth = 0.9;
    canvas.drawLine(
      Offset(left, extensionTop + 4),
      Offset(left, y + 4),
      paint,
    );
    canvas.drawLine(
      Offset(right, extensionTop + 4),
      Offset(right, y + 4),
      paint,
    );
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    _tick(canvas, Offset(left, y), paint);
    _tick(canvas, Offset(right, y), paint);
    _label(
      canvas,
      text,
      Offset((left + right) / 2, y - 10),
      centered: true,
      small: small,
    );
  }

  void _verticalDimension(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    String text, {
    required double extensionLeft,
  }) {
    final paint = Paint()
      ..color = const Color(0xFF4B5563)
      ..strokeWidth = 0.9;
    canvas.drawLine(
      Offset(extensionLeft + 4, top),
      Offset(x + 4, top),
      paint,
    );
    canvas.drawLine(
      Offset(extensionLeft + 4, bottom),
      Offset(x + 4, bottom),
      paint,
    );
    canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    _tick(canvas, Offset(x, top), paint);
    _tick(canvas, Offset(x, bottom), paint);
    _label(canvas, text, Offset(x + 8, (top + bottom) / 2), small: true);
  }

  void _tick(Canvas canvas, Offset point, Paint paint) {
    canvas.drawLine(
      point + const Offset(-4, 4),
      point + const Offset(4, -4),
      paint,
    );
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    final vector = b - a;
    final length = vector.distance;
    if (length == 0) return;
    final direction = vector / length;
    for (var d = 0.0; d < length; d += dash + gap) {
      canvas.drawLine(
        a + direction * d,
        a + direction * math.min(d + dash, length),
        paint,
      );
    }
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
      centered
          ? point - Offset(painter.width / 2, painter.height / 2)
          : point,
    );
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) => true;
}
