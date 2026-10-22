import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/project_save_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

ElectricalCableRoute _route({
  required ElectricalComponentPlacement source,
  required ElectricalComponentPlacement target,
  SurfacePointMm? first,
  SurfacePointMm? last,
  RoomSurfaceRef? firstSurface,
  RoomSurfaceRef? lastSurface,
}) {
  return ElectricalCableRoute(
    id: 'route-anchor',
    source: ElectricalEndpointRef(
      componentId: source.id,
      portId: source.ports
          .firstWhere(
            (port) => port.kind == ElectricalPortKind.powerOut,
          )
          .id,
    ),
    target: ElectricalEndpointRef(
      componentId: target.id,
      portId: target.ports
          .firstWhere(
            (port) => port.kind == ElectricalPortKind.powerIn,
          )
          .id,
    ),
    segments: [
      ElectricalRouteSegment(
        surface: firstSurface ?? source.surface,
        points: [first ?? source.position, const SurfacePointMm(1500, 1000)],
      ),
      ElectricalRouteSegment(
        surface: lastSurface ?? target.surface,
        points: [const SurfacePointMm(1500, 1000), last ?? target.position],
      ),
    ],
  );
}

void main() {
  test('F21 physical anchor validator rejects detached point and wrong surface',
      () {
    final wall = RoomSurfaceRef.wall('room-1', 0);
    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(200, 1000),
      label: 'Source',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.powerSource,
      ),
    );
    final target = ElectricalComponentPlacement(
      id: 'target',
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(2800, 1000),
      label: 'Target',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    );
    final components = [source, target];

    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: _route(source: source, target: target),
        components: components,
      ),
      isTrue,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: _route(
          source: source,
          target: target,
          first: const SurfacePointMm(300, 1000),
        ),
        components: components,
      ),
      isFalse,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: _route(
          source: source,
          target: target,
          lastSurface: RoomSurfaceRef.wall('room-1', 1),
        ),
        components: components,
      ),
      isFalse,
    );
  });

  test('F21 replace rejects detached geometry before history mutation', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.p2.select(source.id);
    controller.p2.select(target.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final before = controller.p2.routes.single;
    final undoDepth = controller.p2.history.undoDepth;
    final segment = before.segments.single;
    final detached = ElectricalCableRoute(
      id: before.id,
      source: before.source,
      target: before.target,
      segments: [
        ElectricalRouteSegment(
          surface: segment.surface,
          points: [
            const SurfacePointMm(300, 1000),
            ...segment.points.skip(1),
          ],
        ),
      ],
      cableType: before.cableType,
      medium: before.medium,
      reservePercent: before.reservePercent,
    );

    expect(controller.p2.replaceCableRoute(before, detached), isFalse);
    expect(controller.p2.history.undoDepth, undoDepth);
    expect(controller.p2.routes.single.segments.first.points.first,
        source.position);
  });

  test('F21 legacy direct move rejects connected component', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.p2.select(source.id);
    controller.p2.select(target.id, mode: SelectionMode.add);
    expect(controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
        isTrue);
    controller.p2.select(source.id);

    expect(
      controller.p2.moveSelectedComponent(const SurfacePointMm(500, 1000)),
      isFalse,
    );
    expect(controller.p2.selectedComponent!.position, source.position);
    expect(controller.p2.routes.single.segments.first.points.first,
        source.position);
  });

  test('F21 save diagnostics reject imported detached endpoint geometry', () {
    final controller = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(controller);
    addTearDown(() {
      workspace.dispose();
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    final broken = _route(
      source: source,
      target: target,
      first: const SurfacePointMm(300, 1000),
    );
    controller.p2.history.replaceState(
      controller.p2.state.copyWith(routes: [broken]),
      clearHistory: false,
    );

    final issues = EditorProjectSaveDiagnostics.validate(workspace);
    expect(
      issues.any((issue) =>
          issue.code == EditorProjectSaveIssueCode.disconnectedRoute &&
          issue.routeId == broken.id),
      isTrue,
    );
  });
}
