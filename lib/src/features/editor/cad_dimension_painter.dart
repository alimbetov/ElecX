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
    bool lightweight = false,
    bool boxedLabel = false,
    double opacity = 1.0,
  }) {
    final color = active ? scheme.primary : scheme.outline;
    final alpha = opacity.clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..color = color.withValues(
        alpha: (lightweight ? 0.65 : (active ? 0.92 : 0.78)) * alpha,
      )
      ..strokeWidth = lightweight ? 0.8 : (active ? 1.25 : 0.9)
      ..style = PaintingStyle.stroke;
    final extension = Paint()
      ..color = color.withValues(alpha: (lightweight ? 0.45 : 0.78) * alpha)
      ..strokeWidth = lightweight ? 0.6 : paint.strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawLine(geometryStart, dimensionStart, extension);
    canvas.drawLine(geometryEnd, dimensionEnd, extension);
    canvas.drawLine(dimensionStart, dimensionEnd, paint);

    _arrowHead(
      canvas,
      from: dimensionStart,
      toward: dimensionEnd,
      paint: paint,
      size: lightweight ? 4.0 : 7.0,
    );
    _arrowHead(
      canvas,
      from: dimensionEnd,
      toward: dimensionStart,
      paint: paint,
      size: lightweight ? 4.0 : 7.0,
    );

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
          color: (active ? scheme.primary : scheme.onSurface)
              .withValues(alpha: alpha),
          fontSize: 10.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          backgroundColor: boxedLabel
              ? null
              : scheme.surface.withValues(alpha: 0.90 * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelAt = midpoint + normal * 10;
    final box = Rect.fromCenter(
      center: labelAt,
      width: text.width + 10,
      height: text.height + 5,
    );
    if (boxedLabel) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()..color = scheme.surface.withValues(alpha: 0.9 * alpha),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()
          ..color = color.withValues(alpha: 0.4 * alpha)
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke,
      );
    }
    text.paint(canvas, labelAt - Offset(text.width / 2, text.height / 2));
  }

  static void _arrowHead(
    Canvas canvas, {
    required Offset from,
    required Offset toward,
    required Paint paint,
    double size = 7.0,
  }) {
    final delta = toward - from;
    final length = delta.distance;
    if (length < 1) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    final tip = from;
    final base = from + direction * size;
    canvas.drawLine(tip, base + normal * (size * 0.45), paint);
    canvas.drawLine(tip, base - normal * 3.2, paint);
  }

  static Offset unitNormal(Offset start, Offset end) {
    final delta = end - start;
    final length = math.max(1.0, delta.distance);
    return Offset(-delta.dy / length, delta.dx / length);
  }
}
