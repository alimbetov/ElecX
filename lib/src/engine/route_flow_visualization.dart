import 'dart:math' as math;

import '../domain/route_medium.dart';

final class RouteFlowFrame {
  const RouteFlowFrame({
    required this.glow,
    this.forwardOffsets = const [],
    this.reverseOffsets = const [],
  });

  /// 0..1 intensity multiplier for the selected-route halo.
  final double glow;

  /// Normalized 0..1 positions moving source -> target.
  final List<double> forwardOffsets;

  /// Normalized 0..1 positions moving target -> source.
  final List<double> reverseOffsets;
}

/// Converts engineering route-medium semantics into a deterministic animation
/// frame. It deliberately models visualization semantics, not electron physics.
abstract final class RouteFlowVisualizationPolicy {
  static RouteFlowFrame frame({
    required RouteMediumProfile medium,
    required double phase,
  }) {
    final p = phase - phase.floorToDouble();
    switch (medium.flowVisual) {
      case RouteFlowVisualKind.acOscillation:
        final glow = 0.55 + 0.35 * (0.5 + 0.5 * math.sin(p * math.pi * 4));
        return RouteFlowFrame(glow: glow);
      case RouteFlowVisualKind.directionalPulse:
        return RouteFlowFrame(
          glow: 0.82,
          forwardOffsets: _movingOffsets(p, count: 4),
        );
      case RouteFlowVisualKind.bidirectionalPackets:
        return RouteFlowFrame(
          glow: 0.78,
          forwardOffsets: _movingOffsets(p, count: 3),
          reverseOffsets: _movingOffsets(1 - p, count: 3),
        );
      case RouteFlowVisualKind.opticalPulse:
        return RouteFlowFrame(
          glow: 0.92,
          forwardOffsets: _movingOffsets(p, count: 2),
          reverseOffsets: medium.bidirectional
              ? _movingOffsets(1 - p, count: 2)
              : const [],
        );
      case RouteFlowVisualKind.controlPulse:
        return RouteFlowFrame(
          glow: 0.72,
          forwardOffsets: _movingOffsets(p, count: 2),
          reverseOffsets: medium.bidirectional
              ? _movingOffsets(1 - p, count: 2)
              : const [],
        );
      case RouteFlowVisualKind.neutralPulse:
        final glow = 0.6 + 0.22 * (0.5 + 0.5 * math.sin(p * math.pi * 2));
        return RouteFlowFrame(glow: glow);
    }
  }

  static List<double> _movingOffsets(double phase, {required int count}) =>
      List<double>.generate(
        count,
        (index) => (phase + index / count) % 1.0,
        growable: false,
      );
}
