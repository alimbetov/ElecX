import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'project_compass_projection.dart';

/// P5D presentation-only compass overlay.
///
/// The widget consumes a resolved [CompassProjectionState]. It deliberately has
/// no dependency on the legacy `ProjectNorth`, canonical aggregate, workspace,
/// or camera. Projection semantics must be resolved before the widget boundary.
class ProjectCompassOverlay extends StatelessWidget {
  ProjectCompassOverlay({
    required this.state,
    this.size = 74,
    this.onTap,
    super.key,
  }) {
    if (!size.isFinite || size <= 0) {
      throw ArgumentError.value(
        size,
        'size',
        'Compass size must be finite and greater than zero.',
      );
    }
  }

  final CompassProjectionState state;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    if (state is CompassUnavailable) {
      return const SizedBox.shrink(key: ValueKey('project-compass-unavailable'));
    }

    final scheme = Theme.of(context).colorScheme;
    final label = _semanticLabel(state);
    final compass = Semantics(
      label: label,
      button: onTap != null,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          key: const ValueKey('project-compass-paint'),
          painter: _ProjectCompassPainter(
            state: state,
            scheme: scheme,
          ),
        ),
      ),
    );

    if (onTap == null) {
      // Read-only compass must not steal pointer/touch/wheel input from the
      // canvas underneath it.
      return IgnorePointer(
        key: const ValueKey('project-compass-read-only'),
        child: compass,
      );
    }

    return Tooltip(
      message: label,
      child: InkWell(
        key: const ValueKey('project-compass-action'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: compass,
      ),
    );
  }

  String _semanticLabel(CompassProjectionState state) {
    if (state is CompassNorthDefined) {
      return 'Compass, Project North '
          '${state.canonicalNorth.degrees.toStringAsFixed(1)} degrees clockwise '
          'from project up';
    }
    return 'Compass, Project North not set';
  }
}

final class _ProjectCompassPainter extends CustomPainter {
  const _ProjectCompassPainter({
    required this.state,
    required this.scheme,
  });

  final CompassProjectionState state;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.max(0.0, math.min(size.width, size.height) / 2 - 4);
    if (radius <= 0) return;

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

    final state = this.state;
    if (state is CompassNorthUnspecified) {
      _label(
        canvas,
        'NOT SET',
        center,
        scheme.onSurfaceVariant,
        fontSize: 8,
        bold: true,
      );
      return;
    }
    if (state is! CompassNorthDefined) {
      return;
    }

    final angle =
        -math.pi / 2 + state.screenDegreesClockwiseFromUp * math.pi / 180.0;
    final vector = Offset(math.cos(angle), math.sin(angle));
    final tip = center + vector * math.max(0.0, radius - 10);
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
      '${state.canonicalNorth.degrees.toStringAsFixed(0)}°',
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
    double fontSize = 10,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
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
  bool shouldRepaint(covariant _ProjectCompassPainter oldDelegate) {
    if (oldDelegate.scheme != scheme ||
        oldDelegate.state.runtimeType != state.runtimeType) {
      return true;
    }
    final current = state;
    final previous = oldDelegate.state;
    return current is CompassNorthDefined &&
        previous is CompassNorthDefined &&
        (current.screenMilliDegreesClockwiseFromUp !=
                previous.screenMilliDegreesClockwiseFromUp ||
            current.canonicalNorth != previous.canonicalNorth);
  }
}
