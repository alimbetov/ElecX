import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/site_orientation.dart';

class ProjectCompassOverlay extends StatelessWidget {
  const ProjectCompassOverlay({
    required this.projectNorth,
    this.size = 74,
    this.onTap,
    super.key,
  });

  final ProjectNorth projectNorth;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compass = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ProjectCompassPainter(
          projectNorth: projectNorth,
          scheme: scheme,
        ),
      ),
    );
    if (onTap == null) return IgnorePointer(child: compass);
    return Tooltip(
      message:
          'Север проекта: ${projectNorth.northAzimuthDegrees.toStringAsFixed(1)}°',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: compass,
      ),
    );
  }
}

final class _ProjectCompassPainter extends CustomPainter {
  const _ProjectCompassPainter({
    required this.projectNorth,
    required this.scheme,
  });

  final ProjectNorth projectNorth;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = scheme.surfaceContainerHigh.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = scheme.outlineVariant,
    );

    final angle = -math.pi / 2 + projectNorth.northAzimuthRadians;
    final vector = Offset(math.cos(angle), math.sin(angle));
    final tip = center + vector * (radius - 10);
    final tail = center - vector * (radius * 0.42);
    final perpendicular = Offset(-vector.dy, vector.dx);
    final color = scheme.primary;

    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (tip - vector * 11 + perpendicular * 5).dx,
        (tip - vector * 11 + perpendicular * 5).dy,
      )
      ..lineTo(
        (tip - vector * 11 - perpendicular * 5).dx,
        (tip - vector * 11 - perpendicular * 5).dy,
      )
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);

    _label(canvas, 'N', tip + vector * 6, color, bold: true);
    _label(
      canvas,
      '${projectNorth.northAzimuthDegrees.toStringAsFixed(0)}°',
      center + Offset(0, radius * 0.45),
      scheme.onSurfaceVariant,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
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
  bool shouldRepaint(covariant _ProjectCompassPainter oldDelegate) =>
      oldDelegate.projectNorth.northAzimuthDegrees !=
          projectNorth.northAzimuthDegrees ||
      oldDelegate.scheme != scheme;
}
