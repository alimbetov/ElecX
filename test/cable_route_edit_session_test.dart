import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/cable_route_edit_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto route previews valid geometry and commits once', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'board-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'socket-1',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(200, 200),
            SurfacePointMm(1800, 1400),
          ],
        ),
      ],
    );
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
      session.start(
        route: route,
        segmentIndex: 0,
        context: RouteNormativeContext(
          surface: surface,
          widthMm: 2000,
          heightMm: 1600,
          edgeClearanceMm: 100,
        ),
      ),
      isTrue,
    );
    expect(session.autoRoute(), isTrue);
    expect(session.validate(), isTrue);
    expect(session.commit(), isTrue);
    expect(commits, 1);
    expect(committed!.segments.single.points, hasLength(3));
  });

  test('manual guardrails expose invalid preview but block commit', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'board-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'socket-1',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(200, 200),
            SurfacePointMm(200, 1400),
            SurfacePointMm(1800, 1400),
          ],
        ),
      ],
    );
    final session = CableRouteEditSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        segmentIndex: 0,
        mode: CableRoutingMode.manualGuardrails,
        context: RouteNormativeContext(
          surface: surface,
          widthMm: 2000,
          heightMm: 1600,
          edgeClearanceMm: 100,
        ),
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
}
