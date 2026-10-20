import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/cable_route_edit_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-101', 0);
  final context = RouteNormativeContext(
    surface: surface,
    widthMm: 2000,
    heightMm: 1600,
    edgeClearanceMm: 100,
  );

  ElectricalCableRoute routeWith(List<SurfacePointMm> points) =>
      ElectricalCableRoute(
        id: 'route-1',
        source: const ElectricalEndpointRef(
          componentId: 'board-1',
          portId: 'power-out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'socket-1',
          portId: 'power-in',
        ),
        segments: [ElectricalRouteSegment(surface: surface, points: points)],
      );

  test('auto route previews valid geometry and commits once', () {
    final route = routeWith(const [
      SurfacePointMm(200, 200),
      SurfacePointMm(1800, 1400),
    ]);
    var commits = 0;
    ElectricalCableRoute? committed;
    final session = CableRouteEditSession(
      onCommit: (before, after) {
        commits++;
        committed = after;
        return true;
      },
    );
    addTearDown(session.dispose);

    expect(
      session.start(route: route, segmentIndex: 0, context: context),
      isTrue,
    );
    expect(session.autoRoute(), isTrue);
    expect(session.validate(), isTrue);
    expect(session.commit(), isTrue);
    expect(commits, 1);
    expect(committed!.segments.single.points, hasLength(3));
  });

  test('manual guardrails expose invalid preview but block commit', () {
    final route = routeWith(const [
      SurfacePointMm(200, 200),
      SurfacePointMm(200, 1400),
      SurfacePointMm(1800, 1400),
    ]);
    final session = CableRouteEditSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        segmentIndex: 0,
        mode: CableRoutingMode.manualGuardrails,
        context: context,
      ),
      isTrue,
    );
    expect(
      session.preview(const [
        SurfacePointMm(200, 200),
        SurfacePointMm(1800, 1400),
      ]),
      isFalse,
    );
    expect(session.validate(), isFalse);
    expect(session.commit(), isFalse);
  });

  test('locked segment cannot start an edit session', () {
    final route = routeWith(const [
      SurfacePointMm(200, 200),
      SurfacePointMm(200, 1400),
      SurfacePointMm(1800, 1400),
    ]);
    final session = CableRouteEditSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        segmentIndex: 0,
        context: context,
        constraints: CableRouteConstraints(lockedSegments: {0}),
      ),
      isFalse,
    );
    expect(session.active, isFalse);
  });

  test('segment edit cannot silently move connected endpoints', () {
    final route = routeWith(const [
      SurfacePointMm(200, 200),
      SurfacePointMm(200, 800),
      SurfacePointMm(1800, 800),
      SurfacePointMm(1800, 1400),
    ]);
    final session = CableRouteEditSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);
    expect(
      session.start(route: route, segmentIndex: 0, context: context),
      isTrue,
    );

    expect(
      session.preview(const [
        SurfacePointMm(300, 200),
        SurfacePointMm(300, 800),
        SurfacePointMm(1800, 800),
        SurfacePointMm(1800, 1400),
      ]),
      isFalse,
    );
    expect(
      session.previewState!.validation.issues.any(
        (issue) => issue.code == 'route.endpoint-moved',
      ),
      isTrue,
    );
    expect(session.commit(), isFalse);
  });

  test('mandatory waypoint is a hard preview constraint', () {
    final route = routeWith(const [
      SurfacePointMm(200, 200),
      SurfacePointMm(200, 800),
      SurfacePointMm(800, 800),
      SurfacePointMm(800, 1400),
      SurfacePointMm(1800, 1400),
    ]);
    final constraints = CableRouteConstraints(
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 2,
          point: SurfacePointMm(800, 800),
        ),
      ],
    );
    final session = CableRouteEditSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);
    expect(
      session.start(
        route: route,
        segmentIndex: 0,
        context: context,
        constraints: constraints,
      ),
      isTrue,
    );

    expect(
      session.preview(const [
        SurfacePointMm(200, 200),
        SurfacePointMm(200, 1000),
        SurfacePointMm(1800, 1000),
        SurfacePointMm(1800, 1400),
      ]),
      isFalse,
    );
    expect(
      session.previewState!.validation.issues.any(
        (issue) => issue.code == 'route.mandatory-waypoint-missing',
      ),
      isTrue,
    );
    expect(session.commit(), isFalse);
  });

  test('auto route preserves mandatory waypoint as an intermediate anchor', () {
    final route = routeWith(const [
      SurfacePointMm(200, 200),
      SurfacePointMm(200, 800),
      SurfacePointMm(800, 800),
      SurfacePointMm(800, 1400),
      SurfacePointMm(1800, 1400),
    ]);
    final constraints = CableRouteConstraints(
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 2,
          point: SurfacePointMm(800, 800),
        ),
      ],
    );
    ElectricalCableRoute? committed;
    final session = CableRouteEditSession(
      onCommit: (_, after) {
        committed = after;
        return true;
      },
    );
    addTearDown(session.dispose);
    expect(
      session.start(
        route: route,
        segmentIndex: 0,
        context: context,
        constraints: constraints,
      ),
      isTrue,
    );

    expect(session.autoRoute(), isTrue);
    expect(session.validate(), isTrue);
    final points = session.previewState!.route.segments.single.points;
    expect(points, contains(const SurfacePointMm(800, 800)));
    expect(points.first, route.segments.single.points.first);
    expect(points.last, route.segments.single.points.last);
    expect(session.commit(), isTrue);
    expect(
      committed!.segments.single.points,
      contains(const SurfacePointMm(800, 800)),
    );
  });
}
