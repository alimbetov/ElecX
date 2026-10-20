import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transform commit records one accepted preview', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 300),
    );

    expect(controller.componentTransform.begin(), isTrue);
    expect(controller.componentTransform.nudge(dxMm: 100, dyMm: 0), isTrue);
    expect(controller.componentTransform.validate(), isTrue);
    expect(controller.componentTransform.commit(), isTrue);
    expect(controller.p2.selectedComponent!.position.xMm, 1100);
  });

  test('invalid transform preview can be cancelled exactly', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 300),
    );

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(-100, 300),
        isValid: false,
      ),
      isFalse,
    );
    expect(controller.componentTransform.commit(), isFalse);
    controller.componentTransform.cancel();
    expect(controller.p2.selectedComponent!.position.xMm, 1000);
  });
  test('connected route previews and commits atomically with component move',
      () {
    final surface = RoomSurfaceRef.wall('room-1', 0);
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 4000,
      heightMm: 2500,
      edgeClearanceMm: 0,
    );
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final routeBefore = p2.routes.single;
    p2.select(target.id, mode: SelectionMode.replace);
    final depthBefore = p2.history.undoDepth;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1900)),
      isTrue,
    );
    final previewRoute = p2.routes.single;
    expect(previewRoute.target, routeBefore.target);
    expect(previewRoute.segments.single.points.last,
        const SurfacePointMm(3000, 1900));
    expect(p2.history.undoDepth, depthBefore);

    expect(p2.commitMoveSelectedComponent(), isTrue);
    expect(p2.history.undoDepth, depthBefore + 1);
    expect(p2.selectedComponent!.position, const SurfacePointMm(3000, 1900));
    expect(p2.routes.single.segments.single.points.last,
        const SurfacePointMm(3000, 1900));

    p2.undo();
    expect(p2.selectedComponent!.position, target.position);
    expect(p2.routes.single.segments.single.points,
        routeBefore.segments.single.points);
  });

  test('cancel restores component routes and constraints exactly', () {
    final surface = RoomSurfaceRef.wall('room-1', 0);
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 4000,
      heightMm: 2500,
      edgeClearanceMm: 0,
    );
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final route = p2.routes.single;
    expect(
      p2.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: 1,
        point: route.segments.single.points[1],
      ),
      isTrue,
    );
    final before = p2.state;
    p2.select(target.id, mode: SelectionMode.replace);

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1900)),
      isTrue,
    );
    p2.cancelMoveSelectedComponent();

    expect(p2.selectedComponent!.position, target.position);
    expect(p2.routes.single.segments.single.points,
        before.routes.single.segments.single.points);
    expect(
      p2.routeConstraintsFor(route.id).mandatoryWaypoints.single.point,
      before.routeConstraints[route.id]!.mandatoryWaypoints.single.point,
    );
  });

  test('locked connected endpoint segment blocks component move commit', () {
    final surface = RoomSurfaceRef.wall('room-1', 0);
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 4000,
      heightMm: 2500,
      edgeClearanceMm: 0,
    );
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final route = p2.routes.single;
    expect(p2.toggleRouteSegmentLock(route.id, 0), isTrue);
    p2.select(target.id, mode: SelectionMode.replace);
    final before = p2.state;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1900)),
      isFalse,
    );
    expect(p2.movePreviewValid, isFalse);
    p2.cancelMoveSelectedComponent();
    expect(p2.selectedComponent!.position, target.position);
    expect(p2.routes.single.segments.single.points,
        before.routes.single.segments.single.points);
  });
}
