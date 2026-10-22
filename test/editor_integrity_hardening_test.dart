import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wall = RoomSurfaceRef.wall('room', 0);

  ElectricalComponentPlacement component(
    String id,
    ElectricalComponentType type,
    SurfacePointMm point,
  ) => ElectricalComponentPlacement(
    id: id,
    type: type,
    surface: wall,
    position: point,
    label: id,
    ports: ElectricalComponentDefaults.portsFor(type),
  );

  test('route connectivity rejects powerOut to controlIn', () {
    final source = component(
      'source',
      ElectricalComponentType.powerSource,
      const SurfacePointMm(100, 100),
    );
    final target = component(
      'target',
      ElectricalComponentType.lightingPoint,
      const SurfacePointMm(900, 900),
    );
    final route = ElectricalCableRoute(
      id: 'r',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target',
        portId: 'control-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [SurfacePointMm(100, 100), SurfacePointMm(900, 100)],
        ),
      ],
    );
    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: route,
        components: [source, target],
      ),
      isFalse,
    );
  });

  test('restored state advances generated component and route ids', () {
    final source = component(
      'component-7',
      ElectricalComponentType.powerSource,
      const SurfacePointMm(100, 100),
    );
    final target = component(
      'component-9',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(900, 100),
    );
    final route = ElectricalCableRoute(
      id: 'route-12',
      source: const ElectricalEndpointRef(
        componentId: 'component-7',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'component-9',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [SurfacePointMm(100, 100), SurfacePointMm(900, 100)],
        ),
      ],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(
        components: [source, target],
        routes: [route],
      ),
    );
    addTearDown(session.dispose);
    final placed = session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(1200, 100),
    );
    expect(placed.id, 'component-10');
  });

  test('restored state rejects duplicate ids immediately', () {
    final a = component(
      'component-1',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(100, 100),
    );
    final b = component(
      'component-1',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(200, 100),
    );
    expect(
      () => EditorP2Session(initialState: EditorP2State(components: [a, b])),
      throwsArgumentError,
    );
  });

  test('write API cannot mutate a locked segment or drop waypoint', () {
    final source = component(
      'source',
      ElectricalComponentType.powerSource,
      const SurfacePointMm(100, 100),
    );
    final target = component(
      'target',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(900, 900),
    );
    final before = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [
            SurfacePointMm(100, 100),
            SurfacePointMm(100, 500),
            SurfacePointMm(900, 500),
            SurfacePointMm(900, 900),
          ],
        ),
      ],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(
        components: [source, target],
        routes: [before],
        routeConstraints: {
          'route-1': CableRouteConstraints(
            lockedSegments: const {0},
            mandatoryWaypoints: const [
              CableMandatoryWaypoint(
                segmentIndex: 0,
                pointIndex: 1,
                point: SurfacePointMm(100, 500),
              ),
            ],
          ),
        },
      ),
    );
    addTearDown(session.dispose);
    final after = ElectricalCableRoute(
      id: before.id,
      source: before.source,
      target: before.target,
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [
            SurfacePointMm(100, 100),
            SurfacePointMm(500, 100),
            SurfacePointMm(500, 900),
            SurfacePointMm(900, 900),
          ],
        ),
      ],
    );
    expect(session.replaceCableRoute(before, after), isFalse);
    expect(
      session.routes.single.segments.single.points,
      before.segments.single.points,
    );
  });

  test('concave surface boundary rejects route that exits and re-enters', () {
    final context = RouteNormativeContext(
      surface: RoomSurfaceRef.floor('room'),
      widthMm: 4000,
      heightMm: 4000,
      edgeClearanceMm: 0,
      boundary: const [
        SurfacePointMm(0, 0),
        SurfacePointMm(4000, 0),
        SurfacePointMm(4000, 1000),
        SurfacePointMm(1000, 1000),
        SurfacePointMm(1000, 4000),
        SurfacePointMm(0, 4000),
      ],
    );
    final result = NormativeRouteEngine.validate(
      points: const [
        SurfacePointMm(500, 3500),
        SurfacePointMm(3500, 3500),
        SurfacePointMm(3500, 500),
      ],
      context: context,
    );
    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) => issue.code == 'route.outside-surface-boundary',
      ),
      isTrue,
    );
  });

  test('auto route finds an orthogonal detour around centered obstacle', () {
    final context = RouteNormativeContext(
      surface: wall,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
      obstacles: const [
        RouteObstacleMm(
          id: 'window',
          leftMm: 1200,
          topMm: 700,
          rightMm: 1800,
          bottomMm: 1300,
        ),
      ],
    );
    final candidates = NormativeRouteEngine.buildCandidates(
      source: const SurfacePointMm(500, 1000),
      target: const SurfacePointMm(2500, 1000),
      context: context,
    );
    expect(candidates.first.validation.isValid, isTrue);
    expect(candidates.first.points.length, greaterThanOrEqualTo(4));
  });
}
