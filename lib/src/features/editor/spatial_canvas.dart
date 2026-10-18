import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';

class SpatialCanvas extends StatelessWidget {
  const SpatialCanvas({required this.controller, super.key});

  final EditorController controller;

  static const int worldWidthMm = 12000;
  static const int worldHeightMm = 8000;

  MmPoint _toWorld(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unzoomed = center + (local - center) / controller.zoom;
    return MmPoint(
      (unzoomed.dx / size.width * worldWidthMm).round(),
      ((size.height - unzoomed.dy) / size.height * worldHeightMm).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy < 0) {
                controller.zoomIn();
              } else if (event.scrollDelta.dy > 0) {
                controller.zoomOut();
              }
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                controller.canvasTap(_toWorld(details.localPosition, size)),
            child: CustomPaint(
              painter: _SpatialPainter(controller),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _SpatialPainter extends CustomPainter {
  _SpatialPainter(this.controller);

  final EditorController controller;

  Offset p(MmPoint point, Size size) {
    final base = Offset(
      point.x / SpatialCanvas.worldWidthMm * size.width,
      size.height - point.y / SpatialCanvas.worldHeightMm * size.height,
    );
    final center = Offset(size.width / 2, size.height / 2);
    return center + (base - center) * controller.zoom;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F8FA),
    );
    _drawFloorGrid(canvas, size);
    for (final space in controller.level.spaces) {
      _drawSpace(
        canvas,
        size,
        space,
        selected: space.id == controller.selectedSpaceId,
      );
    }
    final draft = controller.draftStart;
    if (draft != null) {
      final offset = p(draft, size);
      canvas.drawCircle(offset, 5, Paint()..color = const Color(0xFFD66B2C));
    }
  }

  void _drawFloorGrid(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0xFFE5E8ED)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = const Color(0xFFCDD3DB)
      ..strokeWidth = 1.0;
    final step = controller.floorGridMm;
    for (var x = 0; x <= SpatialCanvas.worldWidthMm; x += step) {
      final paint = x % (step * 2) == 0 ? major : minor;
      final a = p(MmPoint(x, 0), size);
      final b = p(MmPoint(x, SpatialCanvas.worldHeightMm), size);
      canvas.drawLine(a, b, paint);
    }
    for (var y = 0; y <= SpatialCanvas.worldHeightMm; y += step) {
      final paint = y % (step * 2) == 0 ? major : minor;
      final a = p(MmPoint(0, y), size);
      final b = p(MmPoint(SpatialCanvas.worldWidthMm, y), size);
      canvas.drawLine(a, b, paint);
    }
  }

  void _drawSpace(
    Canvas canvas,
    Size size,
    EngineeringSpace space, {
    required bool selected,
  }) {
    final path = Path();
    final first = p(space.boundary.vertices.first, size);
    path.moveTo(first.dx, first.dy);
    for (final vertex in space.boundary.vertices.skip(1)) {
      final point = p(vertex, size);
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? const Color(0x1F246DB3)
            : const Color(0x0D263238),
    );

    if (selected) _drawRoomGrid(canvas, size, space, path);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.5
        ..color = selected
            ? const Color(0xFF246DB3)
            : const Color(0xFF53606D),
    );

    _drawArchitecturalOpenings(canvas, size, space);
    _drawCenterLines(canvas, size, space);
    _drawLabel(canvas, size, space);
    if (selected && controller.dimensionsVisible) {
      _drawPlanDimensions(canvas, size, space);
    }
  }

  void _drawRoomGrid(
    Canvas canvas,
    Size size,
    EngineeringSpace space,
    Path clipPath,
  ) {
    final bounds = space.boundary.bounds;
    final step = space.grid.minorStepMm;
    final majorStep = space.grid.majorStepMm;
    final paintMinor = Paint()
      ..color = const Color(0xFFDFEAF4)
      ..strokeWidth = 0.65;
    final paintMajor = Paint()
      ..color = const Color(0xFFB8D0E5)
      ..strokeWidth = 0.9;
    canvas.save();
    canvas.clipPath(clipPath);
    final startX = (bounds.left / step).floor() * step;
    final startY = (bounds.bottom / step).floor() * step;
    for (var x = startX; x <= bounds.right; x += step) {
      canvas.drawLine(
        p(MmPoint(x, bounds.bottom), size),
        p(MmPoint(x, bounds.top), size),
        x % majorStep == 0 ? paintMajor : paintMinor,
      );
    }
    for (var y = startY; y <= bounds.top; y += step) {
      canvas.drawLine(
        p(MmPoint(bounds.left, y), size),
        p(MmPoint(bounds.right, y), size),
        y % majorStep == 0 ? paintMajor : paintMinor,
      );
    }
    canvas.restore();
  }

  void _drawArchitecturalOpenings(
    Canvas canvas,
    Size size,
    EngineeringSpace space,
  ) {
    final walls = RoomSurfaceResolver.walls(space);
    for (final opening in controller.openings) {
      if (opening.hostWall.spaceId != space.id ||
          opening.hostWall.wallIndex == null) {
        continue;
      }
      final index = opening.hostWall.wallIndex!;
      if (index < 0 || index >= walls.length) continue;
      final wall = walls[index];
      final a = RoomSurfaceResolver.wallLocalToPlan(
        wall,
        opening.offsetFromStartMm,
      );
      final b = RoomSurfaceResolver.wallLocalToPlan(
        wall,
        opening.offsetFromStartMm + opening.widthMm,
      );
      final pa = p(a, size);
      final pb = p(b, size);

      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = const Color(0xFFF7F8FA)
          ..strokeWidth = 6,
      );

      switch (opening.type) {
        case ArchitecturalOpeningType.door:
          _drawDoorSymbol(canvas, pa, pb);
        case ArchitecturalOpeningType.window:
          _drawWindowSymbol(canvas, pa, pb);
        case ArchitecturalOpeningType.passage:
        case ArchitecturalOpeningType.technicalOpening:
          canvas.drawLine(
            pa,
            pb,
            Paint()
              ..color = const Color(0xFF8B95A1)
              ..strokeWidth = 1.4,
          );
      }
    }
  }

  void _drawDoorSymbol(Canvas canvas, Offset hinge, Offset end) {
    final vector = end - hinge;
    final length = vector.distance;
    if (length == 0) return;
    final unit = vector / length;
    final normal = Offset(-unit.dy, unit.dx);
    final leafEnd = hinge + normal * length;
    final paint = Paint()
      ..color = const Color(0xFF4E5965)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(hinge, leafEnd, paint);
    final rect = Rect.fromCircle(center: hinge, radius: length);
    final startAngle = math.atan2(unit.dy, unit.dx);
    canvas.drawArc(rect, startAngle, math.pi / 2, false, paint);
  }

  void _drawWindowSymbol(Canvas canvas, Offset a, Offset b) {
    final vector = b - a;
    final length = vector.distance;
    if (length == 0) return;
    final unit = vector / length;
    final normal = Offset(-unit.dy, unit.dx) * 2.5;
    final paint = Paint()
      ..color = const Color(0xFF4C89A8)
      ..strokeWidth = 1.2;
    canvas.drawLine(a + normal, b + normal, paint);
    canvas.drawLine(a - normal, b - normal, paint);
  }

  void _drawCenterLines(Canvas canvas, Size size, EngineeringSpace space) {
    final bounds = space.boundary.bounds;
    final center = space.referenceFrame.origin;
    final paint = Paint()
      ..color = const Color(0xFFCC6A2E)
      ..strokeWidth = 1.2;
    _dashLine(
      canvas,
      p(MmPoint(bounds.left, center.y), size),
      p(MmPoint(bounds.right, center.y), size),
      paint,
    );
    _dashLine(
      canvas,
      p(MmPoint(center.x, bounds.bottom), size),
      p(MmPoint(center.x, bounds.top), size),
      paint,
    );
    canvas.drawCircle(p(center, size), 3.5, paint);
  }

  void _drawPlanDimensions(
    Canvas canvas,
    Size size,
    EngineeringSpace space,
  ) {
    final bounds = space.boundary.bounds;
    final bottomLeft = p(MmPoint(bounds.left, bounds.bottom), size);
    final bottomRight = p(MmPoint(bounds.right, bounds.bottom), size);
    final topRight = p(MmPoint(bounds.right, bounds.top), size);
    final paint = Paint()
      ..color = const Color(0xFF4B5563)
      ..strokeWidth = 0.9;

    final y = math.max(bottomLeft.dy, bottomRight.dy) + 28;
    canvas.drawLine(Offset(bottomLeft.dx, y), Offset(bottomRight.dx, y), paint);
    canvas.drawLine(bottomLeft, Offset(bottomLeft.dx, y + 4), paint);
    canvas.drawLine(bottomRight, Offset(bottomRight.dx, y + 4), paint);
    _dimensionTick(canvas, Offset(bottomLeft.dx, y), paint);
    _dimensionTick(canvas, Offset(bottomRight.dx, y), paint);
    _dimensionLabel(
      canvas,
      '${bounds.width} mm',
      Offset((bottomLeft.dx + bottomRight.dx) / 2, y - 10),
    );

    final x = topRight.dx + 32;
    canvas.drawLine(Offset(x, topRight.dy), Offset(x, bottomRight.dy), paint);
    canvas.drawLine(topRight, Offset(x + 4, topRight.dy), paint);
    canvas.drawLine(bottomRight, Offset(x + 4, bottomRight.dy), paint);
    _dimensionTick(canvas, Offset(x, topRight.dy), paint);
    _dimensionTick(canvas, Offset(x, bottomRight.dy), paint);
    _dimensionLabel(
      canvas,
      '${bounds.height} mm',
      Offset(x + 8, (topRight.dy + bottomRight.dy) / 2),
      centered: false,
    );
  }

  void _dimensionTick(Canvas canvas, Offset point, Paint paint) {
    canvas.drawLine(
      point + const Offset(-4, 4),
      point + const Offset(4, -4),
      paint,
    );
  }

  void _dimensionLabel(
    Canvas canvas,
    String text,
    Offset point, {
    bool centered = true,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered ? point - Offset(painter.width / 2, painter.height / 2) : point,
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

  void _drawLabel(Canvas canvas, Size size, EngineeringSpace space) {
    final center = p(space.boundary.bounds.center, size);
    final painter = TextPainter(
      text: TextSpan(
        text: space.name,
        style: const TextStyle(
          color: Color(0xFF263238),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2 + 18),
    );
  }

  @override
  bool shouldRepaint(covariant _SpatialPainter oldDelegate) => true;
}
