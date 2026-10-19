import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/route_engine.dart';
import 'package:elecx/src/engine/routing_constraints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keep-out zone removes crossing edge but preserves alternative path',
    () {
      final surface = RoomSurfaceRef.wall('room', 0);
      final graph = RoutingGraph(
        nodes: {
          'a': RouteNode(
            id: 'a',
            surface: surface,
            point: const SurfacePointMm(0, 0),
          ),
          'b': RouteNode(
            id: 'b',
            surface: surface,
            point: const SurfacePointMm(1000, 0),
          ),
          'c': RouteNode(
            id: 'c',
            surface: surface,
            point: const SurfacePointMm(0, 1000),
          ),
          'd': RouteNode(
            id: 'd',
            surface: surface,
            point: const SurfacePointMm(1000, 1000),
          ),
        },
        edges: const [
          RouteEdge(from: 'a', to: 'b', cost: 1000),
          RouteEdge(from: 'b', to: 'a', cost: 1000),
          RouteEdge(from: 'a', to: 'c', cost: 1000),
          RouteEdge(from: 'c', to: 'a', cost: 1000),
          RouteEdge(from: 'c', to: 'd', cost: 1000),
          RouteEdge(from: 'd', to: 'c', cost: 1000),
          RouteEdge(from: 'd', to: 'b', cost: 1000),
          RouteEdge(from: 'b', to: 'd', cost: 1000),
        ],
      );

      final constrained = RoutingConstraintEngine.constrain(
        graph: graph,
        zones: [
          SurfaceKeepOutZone(
            id: 'blocked-lower-middle',
            surface: surface,
            bounds: const MmBounds(
              left: 400,
              bottom: -100,
              right: 600,
              top: 100,
            ),
          ),
        ],
      );

      expect(
        constrained.edges.any(
          (edge) =>
              (edge.from == 'a' && edge.to == 'b') ||
              (edge.from == 'b' && edge.to == 'a'),
        ),
        isFalse,
      );

      final solution = RouteEngine.solve(
        graph: constrained,
        startNodeId: 'a',
        endNodeId: 'b',
      );
      expect(solution, isNotNull);
      expect(solution!.nodeIds, ['a', 'c', 'd', 'b']);
    },
  );

  test('route violations return each keep-out zone once', () {
    final surface = RoomSurfaceRef.ceiling('room');
    final zone = SurfaceKeepOutZone(
      id: 'service-zone',
      surface: surface,
      bounds: const MmBounds(left: 400, bottom: 400, right: 600, top: 600),
    );

    final violations = RoutingConstraintEngine.routeViolations(
      surface: surface,
      points: const [
        SurfacePointMm(0, 500),
        SurfacePointMm(500, 500),
        SurfacePointMm(1000, 500),
      ],
      zones: [zone],
    );

    expect(violations.map((item) => item.id), ['service-zone']);
  });
}
