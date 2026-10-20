import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);
  final route = ElectricalCableRoute(
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
        surface: surface,
        points: const [
          SurfacePointMm(100, 100),
          SurfacePointMm(1000, 100),
          SurfacePointMm(1000, 800),
        ],
      ),
    ],
  );

  final components = [
    ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(100, 100),
      label: 'Source',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.powerSource,
      ),
    ),
    ElectricalComponentPlacement(
      id: 'target',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1000, 800),
      label: 'Target',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    ),
  ];

  test('constraint payload round-trips for project persistence', () {
    final constraints = CableRouteConstraints(
      lockedSegments: {0},
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 1,
          point: SurfacePointMm(1000, 100),
        ),
      ],
    );

    final restored = CableRouteConstraints.fromJson(constraints.toJson());

    expect(restored.isSegmentLocked(0), isTrue);
    expect(restored.isWaypoint(0, 1), isTrue);
    expect(
      restored.mandatoryWaypoints.single.point,
      const SurfacePointMm(1000, 100),
    );
  });

  test('lock and waypoint mutations are undoable editor state', () {
    final session = EditorP2Session(
      initialState: EditorP2State(routes: [route]),
    );

    expect(session.toggleRouteSegmentLock(route.id, 0), isTrue);
    expect(
      session.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: 1,
        point: const SurfacePointMm(1000, 100),
      ),
      isTrue,
    );
    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isTrue);
    expect(session.routeConstraintsFor(route.id).isWaypoint(0, 1), isTrue);
    expect(session.history.undoDepth, 2);

    session.undo();
    expect(session.routeConstraintsFor(route.id).isWaypoint(0, 1), isFalse);
    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isTrue);
    session.redo();
    expect(session.routeConstraintsFor(route.id).isWaypoint(0, 1), isTrue);
  });

  test('constraint state survives session reopen from canonical snapshot', () {
    final session = EditorP2Session(
      initialState: EditorP2State(routes: [route]),
    );
    session.toggleRouteSegmentLock(route.id, 0);
    session.toggleRouteWaypoint(
      routeId: route.id,
      segmentIndex: 0,
      pointIndex: 1,
      point: const SurfacePointMm(1000, 100),
    );

    final reopened = EditorP2Session(initialState: session.state);
    final restored = reopened.routeConstraintsFor(route.id);

    expect(restored.isSegmentLocked(0), isTrue);
    expect(restored.isWaypoint(0, 1), isTrue);
    expect(reopened.history.undoDepth, 0);
  });

  test('constraint mutation rejects stale geometry references', () {
    final session = EditorP2Session(
      initialState: EditorP2State(routes: [route]),
    );

    expect(session.toggleRouteSegmentLock(route.id, 99), isFalse);
    expect(
      session.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: 1,
        point: const SurfacePointMm(999, 999),
      ),
      isFalse,
    );
    expect(session.history.undoDepth, 0);
  });

  test('reconcile tracks physical waypoint when its vertex index shifts', () {
    final constraints = CableRouteConstraints(
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 1,
          point: SurfacePointMm(1000, 100),
        ),
      ],
    );

    final reconciled = constraints.reconcile(const [
      [
        SurfacePointMm(100, 100),
        SurfacePointMm(500, 100),
        SurfacePointMm(1000, 100),
        SurfacePointMm(1000, 800),
      ],
    ]);

    expect(reconciled.mandatoryWaypoints, hasLength(1));
    expect(reconciled.mandatoryWaypoints.single.pointIndex, 2);
    expect(
      reconciled.mandatoryWaypoints.single.point,
      const SurfacePointMm(1000, 100),
    );
  });

  test('route replacement reconciles constraints in the same undo command', () {
    final session = EditorP2Session(
      initialState: EditorP2State(
        components: components,
        routes: [route],
        routeConstraints: {
          route.id: CableRouteConstraints(
            lockedSegments: {0},
            mandatoryWaypoints: const [
              CableMandatoryWaypoint(
                segmentIndex: 0,
                pointIndex: 1,
                point: SurfacePointMm(1000, 100),
              ),
            ],
          ),
        },
      ),
    );
    final replacement = ElectricalCableRoute(
      id: route.id,
      source: route.source,
      target: route.target,
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(100, 100),
            SurfacePointMm(500, 100),
            SurfacePointMm(1000, 100),
            SurfacePointMm(1000, 800),
          ],
        ),
      ],
      cableType: route.cableType,
      medium: route.medium,
      reservePercent: route.reservePercent,
    );

    expect(session.replaceCableRoute(route, replacement), isTrue);
    expect(session.routes.single.segments.single.points, hasLength(4));
    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isTrue);
    expect(
      session.routeConstraintsFor(route.id).mandatoryWaypoints.single.pointIndex,
      2,
    );

    session.undo();
    expect(session.routes.single.segments.single.points, hasLength(3));
    expect(
      session.routeConstraintsFor(route.id).mandatoryWaypoints.single.pointIndex,
      1,
    );

    session.redo();
    expect(session.routes.single.segments.single.points, hasLength(4));
    expect(
      session.routeConstraintsFor(route.id).mandatoryWaypoints.single.pointIndex,
      2,
    );
  });
}
