import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_editor_ui_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:flutter_test/flutter_test.dart';

ElectricalCableRoute _route(String id, int y) => ElectricalCableRoute(
      id: id,
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: RoomSurfaceRef.wall('room-101', 1),
          points: [SurfacePointMm(100, y), SurfacePointMm(1000, y)],
        ),
      ],
    );

void main() {
  test('F09 selecting another route clears stale cable geometry focus', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.restoreP2State(
      EditorP2State(routes: [_route('route-a', 500), _route('route-b', 800)]),
    );

    controller.routeSelection.select('route-a');
    controller.cableUi.focusGeometry(routeId: 'route-a', segmentIndex: 0);
    expect(controller.cableUi.activeRouteId, 'route-a');
    expect(controller.cableUi.activeSegmentIndex, 0);

    controller.routeSelection.select('route-b');
    expect(controller.routeSelection.selectedRouteId, 'route-b');
    expect(controller.cableUi.activeRouteId, isNull);
    expect(controller.cableUi.activeSegmentIndex, isNull);

    controller.cableUi.toggleActiveSegmentLock();
    expect(
        controller.p2.routeConstraintsFor('route-a').lockedSegments, isEmpty);
    expect(
        controller.p2.routeConstraintsFor('route-b').lockedSegments, isEmpty);
  });
}
