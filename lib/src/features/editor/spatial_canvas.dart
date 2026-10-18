import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import 'editor_controller.dart';

class SpatialCanvas extends StatelessWidget {
  const SpatialCanvas({required this.controller, super.key});

  final EditorController controller;

  static const int worldWidthMm = 12000;
  static const int worldHeightMm = 8000;

  MmPoint _toWorld(Offset local, Size size) => MmPoint(
        (local.dx / size.width * worldWidthMm).round(),
        ((size.height - local.dy) / size.height * worldHeightMm).round(),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => controller.canvasTap(_toWorld(details.localPosition, size)),
          child: CustomPaint(
            painter: _SpatialPainter(controller),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _SpatialPainter extends CustomPainter {
  _SpatialPainter(this.controller);

  final EditorController controller;

  Offset p(MmPoint point, Size size) => Offset(
        point.x / SpatialCanvas.worldWidthMm * size.width,
        size.height - point.y / SpatialCanvas.worldHeightMm * size.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F8FA));
    _drawFloorGrid(canvas, size);
    for (final space in controller.level.spaces) {
      _drawSpace(canvas, size, space, selected: space.id == controller.selectedSpaceId);
    }
    final draft = controller.draftStart;
    if (draft != null) {
      final offset = p(draft, size);
      canvas.drawCircle(offset, 5, Paint()..color = const Color(0xFFD66B2C));
    }
  }

  void _drawFloorGrid(Canvas canvas, Size size) {
    final minor = Paint()..color = const Color(0xFFE5E8ED)..strokeWidth = 0.7;
    final major = Paint()..color = const Color(0xFFCDD3DB)..strokeWidth = 1.0;
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

  void _drawSpace(Canvas canvas, Size size, EngineeringSpace space, {required bool selected}) {
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
      Paint()..color = selected ? const Color(0x1F246DB3) : const Color(0x0D263238),
    );

    if (selected) _drawRoomGrid(canvas, size, space, path);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.5
        ..color = selected ? const Color(0xFF246DB3) : const Color(0xFF53606D),
    );

    _drawCenterLines(canvas, size, space);
    _drawLabel(canvas, size, space);
  }

  void _drawRoomGrid(Canvas canvas, Size size, EngineeringSpace space, Path clipPath) {
    final bounds = space.boundary.bounds;
    final step = space.grid.minorStepMm;
    final majorStep = space.grid.majorStepMm;
    final paintMinor = Paint()..color = const Color(0xFFDFEAF4)..strokeWidth = 0.65;
    final paintMajor = Paint()..color = const Color(0xFFB8D0E5)..strokeWidth = 0.9;
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

  void _drawCenterLines(Canvas canvas, Size size, EngineeringSpace space) {
    final bounds = space.boundary.bounds;
    final center = space.referenceFrame.origin;
    final paint = Paint()
      ..color = const Color(0xFFCC6A2E)
      ..strokeWidth = 1.2;
    _dashLine(canvas, p(MmPoint(bounds.left, center.y), size), p(MmPoint(bounds.right, center.y), size), paint);
    _dashLine(canvas, p(MmPoint(center.x, bounds.bottom), size), p(MmPoint(center.x, bounds.top), size), paint);
    canvas.drawCircle(p(center, size), 3.5, paint);
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    final vector = b - a;
    final length = vector.distance;
    if (length == 0) return;
    final direction = vector / length;
    for (var d = 0.0; d < length; d += dash + gap) {
      canvas.drawLine(a + direction * d, a + direction * math.min(d + dash, length), paint);
    }
  }

  void _drawLabel(Canvas canvas, Size size, EngineeringSpace space) {
    final center = p(space.boundary.bounds.center, size);
    final painter = TextPainter(
      text: TextSpan(
        text: space.name,
        style: const TextStyle(color: Color(0xFF263238), fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2 + 18));
  }

  @override
  bool shouldRepaint(covariant _SpatialPainter oldDelegate) => true;
}
