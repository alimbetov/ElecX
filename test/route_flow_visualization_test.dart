import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/route_flow_visualization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AC uses non-directional oscillating glow', () {
    final a = RouteFlowVisualizationPolicy.frame(
      medium: RouteMediumProfile.acPower,
      phase: 0.0,
    );
    final b = RouteFlowVisualizationPolicy.frame(
      medium: RouteMediumProfile.acPower,
      phase: 0.125,
    );

    expect(a.forwardOffsets, isEmpty);
    expect(a.reverseOffsets, isEmpty);
    expect(a.glow, isNot(b.glow));
  });

  test('DC uses source-to-target directional pulses', () {
    final frame = RouteFlowVisualizationPolicy.frame(
      medium: RouteMediumProfile.dcPower,
      phase: 0.2,
    );

    expect(frame.forwardOffsets, hasLength(4));
    expect(frame.reverseOffsets, isEmpty);
  });

  test('Ethernet uses bidirectional packet pulses', () {
    final frame = RouteFlowVisualizationPolicy.frame(
      medium: RouteMediumProfile.ethernet,
      phase: 0.3,
    );

    expect(frame.forwardOffsets, hasLength(3));
    expect(frame.reverseOffsets, hasLength(3));
  });

  test('custom media stays extensible without enum growth', () {
    const custom = RouteMediumProfile(
      id: 'vendor.custom-bus',
      family: RouteMediumFamily.control,
      flowVisual: RouteFlowVisualKind.controlPulse,
      bidirectional: true,
      protocol: 'CustomBus',
    );

    final frame = RouteFlowVisualizationPolicy.frame(
      medium: custom,
      phase: 0.6,
    );
    expect(custom.id, 'vendor.custom-bus');
    expect(frame.forwardOffsets, isNotEmpty);
    expect(frame.reverseOffsets, isNotEmpty);
  });
}
