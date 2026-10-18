import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared CAD-style temporary dimension drawing.
///
/// Callers provide screen-space geometry so the same visual language can be
/// reused by Plan, Room World and individual surface editors.
abstract final class CadDimensionPainter {
  static void drawLinear(
    Canvas canvas, {
    required Offset geometryStart,
    required Offset geometryEnd,
    required Offset dimensionStart,
    required Offset dimensionEnd,
    required String label,
    required ColorScheme scheme,
    bool active = false,
  }) {
    final color = active ? scheme.primary : scheme.outline;
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 0.92 : 0.78)
      ..strokeWidth = active ? 1.25 : 0.9
      ..style = PaintingStyle.stroke;

    canvas.drawLine(geometryStart, dimensionStart, paint);
    canvas.drawLine(geometryEnd, dimensionEnd, paint);
    canvas.drawLine(dimensionStart, dimensionEnd, paint);

    _arrowHead(canvas, from: dimensionStart, toward: dimensionEnd, paint: paint);
    _arrowHead(canvas, from: dimensionEnd, toward: dimensionStart, paint: paint);

    final midpoint = Offset(
      (dimensionStart.dx + dimensionEnd.dx) / 2,
      (dimensionStart.dy + dimensionEnd.dy) / 2,
    );
    final delta = dimensionEnd - dimensionStart;
    final length = delta.distance;
    final normal = length < 1
        ? const Offset(0, -1)
        : Offset(-delta.dy / length, delta.dx / length);

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: active ? scheme.primary : scheme.onSurface,
          fontSize: 10.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          backgroundColor: scheme.surface.withValues(alpha: 0.90),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelAt = midpoint + normal * 10;
    text.paint(
      canvas,
      labelAt - Offset(text.width / 2, text.height / 2),
    );
  }

  static void _arrowHead(
    Canvas canvas, {
    required Offset from,
    required Offset toward,
    required Paint paint,
  }) {
    final delta = toward - from;
    final length = delta.distance;
    if (length < 1) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    const size = 7.0;
    final tip = from;
    final base = from + direction * size;
    canvas.drawLine(tip, base + normal * 3.2, paint);
    canvas.drawLine(tip, base - normal * 3.2, paint);
  }

  static Offset unitNormal(Offset start, Offset end) {
    final delta = end - start;
    final length = math.max(1.0, delta.distance);
    return Offset(-delta.dy / length, delta.dx / length);
  }
}
