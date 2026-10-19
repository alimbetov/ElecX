import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/channel_aware_route_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final host = RouteHostRef.indoor(RoomSurfaceRef.wall('room-1', 0));

  ChannelRouteState state(
    String id, {
    required String channel,
    String node = 'n',
  }) =>
      ChannelRouteState(
        id: id,
        routeNodeId: node,
        host: host,
        installationPathSpecId: 'tray-1',
        pathSectionId: 'section-1',
        channelId: channel,
      );

  test('hard feasibility removes cheaper but invalid channel path', () {
    final graph = ChannelRoutingGraph(
      states: {
        'start': state('start', channel: 'power', node: 'start'),
        'cheap': state('cheap', channel: 'blocked-data', node: 'mid-a'),
        'valid': state('valid', channel: 'power', node: 'mid-b'),
        'end': state('end', channel: 'power', node: 'end'),
      },
      edges: const [
        ChannelRouteEdge(from: 'start', to: 'cheap', lengthMm: 1000),
        ChannelRouteEdge(from: 'cheap', to: 'end', lengthMm: 1000),
        ChannelRouteEdge(from: 'start', to: 'valid', lengthMm: 2000),
        ChannelRouteEdge(from: 'valid', to: 'end', lengthMm: 2000),
      ],
    );

    final solution = ChannelAwareRouteEngine.solve(
      graph: graph,
      startStateId: 'start',
      endStateId: 'end',
      isFeasible: (_, to, __) => to.channelId != 'blocked-data',
    );

    expect(solution?.stateIds, ['start', 'valid', 'end']);
    expect(solution?.cost.lengthMm, 4000);
  });

  test('cost vector preserves engineering reasons behind ranking', () {
    final graph = ChannelRoutingGraph(
      states: {
        'start': state('start', channel: 'power', node: 'start'),
        'short': state('short', channel: 'power', node: 'mid-a'),
        'maint': state('maint', channel: 'power', node: 'mid-b'),
        'end': state('end', channel: 'power', node: 'end'),
      },
      edges: const [
        ChannelRouteEdge(
          from: 'start',
          to: 'short',
          lengthMm: 1000,
          maintainabilityPenalty: 5000,
        ),
        ChannelRouteEdge(from: 'short', to: 'end', lengthMm: 1000),
        ChannelRouteEdge(from: 'start', to: 'maint', lengthMm: 1500),
        ChannelRouteEdge(from: 'maint', to: 'end', lengthMm: 1500),
      ],
    );

    final solution = ChannelAwareRouteEngine.solve(
      graph: graph,
      startStateId: 'start',
      endStateId: 'end',
      isFeasible: (_, __, ___) => true,
      weights: const ChannelRouteCostWeights(
        length: 1,
        maintainability: 1,
        transitions: 0,
        bends: 0,
        material: 0,
        labor: 0,
        normativeRisk: 0,
      ),
    );

    expect(solution?.stateIds, ['start', 'maint', 'end']);
    expect(solution?.cost.lengthMm, 3000);
    expect(solution?.cost.maintainabilityPenalty, 0);
  });

  test('solver reports no solution when hard constraints close all channels', () {
    final graph = ChannelRoutingGraph(
      states: {
        'start': state('start', channel: 'power', node: 'start'),
        'end': state('end', channel: 'power', node: 'end'),
      },
      edges: const [
        ChannelRouteEdge(from: 'start', to: 'end', lengthMm: 1000),
      ],
    );

    final solution = ChannelAwareRouteEngine.solve(
      graph: graph,
      startStateId: 'start',
      endStateId: 'end',
      isFeasible: (_, __, ___) => false,
    );

    expect(solution, isNull);
  });
}
