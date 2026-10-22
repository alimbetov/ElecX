import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wall = RoomSurfaceRef.wall('room-1', 0);
  final roomBoundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(5000, 4000),
  );
  final room = EngineeringSpace(
    id: 'room-1',
    name: 'Room 1',
    type: SpaceType.room,
    boundary: roomBoundary,
    referenceFrame: RoomReferenceFrame(origin: roomBoundary.bounds.center),
  );

  test('component placement is undoable and redoable', () {
    final session = EditorP2Session();
    addTearDown(session.dispose);

    final component = session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(1000, 300),
    );

    expect(session.components, hasLength(1));
    expect(session.selection.primaryId, component.id);
    expect(session.canUndo, isTrue);

    session.undo();
    expect(session.components, isEmpty);
    expect(session.selection.ids, isEmpty);

    session.redo();
    expect(session.components, hasLength(1));
  });

  test('locked electrical layer rejects component placement', () {
    final session = EditorP2Session();
    addTearDown(session.dispose);
    session.setLayerLocked(EditorLayerId.electrical, true);

    expect(
      () => session.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(1000, 300),
      ),
      throwsStateError,
    );
  });

  test('drag preview creates one history entry on commit', () {
    final session = EditorP2Session();
    addTearDown(session.dispose);
    session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(1000, 300),
    );
    final beforeDepth = session.history.undoDepth;

    expect(session.beginMoveSelectedComponent(), isTrue);
    session.previewMoveSelectedComponent(const SurfacePointMm(1100, 300));
    session.previewMoveSelectedComponent(const SurfacePointMm(1200, 300));
    session.previewMoveSelectedComponent(const SurfacePointMm(1300, 300));
    expect(session.history.undoDepth, beforeDepth);

    expect(session.commitMoveSelectedComponent(), isTrue);
    expect(session.history.undoDepth, beforeDepth + 1);
    expect(session.selectedComponent!.position.xMm, 1300);

    session.undo();
    expect(session.selectedComponent!.position.xMm, 1000);
  });

  test('two selected components on same surface can be auto-routed', () {
    final session = EditorP2Session();
    addTearDown(session.dispose);

    final board = session.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: wall,
      position: const SurfacePointMm(500, 1800),
    );
    final socket = session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(3000, 300),
    );
    session.select(board.id, mode: SelectionMode.replace);
    session.select(socket.id, mode: SelectionMode.add);

    expect(session.selection.ids, hasLength(2));
    expect(session.autoRouteSelectedPair(cableType: '3x2.5'), isTrue);
    expect(session.routes, hasLength(1));
    expect(session.routes.single.segments, isNotEmpty);
    expect(session.routes.single.source.componentId, board.id);
    expect(session.routes.single.target.componentId, socket.id);
  });

  test('same-surface AUTO uses project context to detour around opening', () {
    final context = RouteNormativeContext(
      surface: wall,
      widthMm: 3500,
      heightMm: 2500,
      edgeClearanceMm: 0,
      obstacles: const [
        RouteObstacleMm(
          id: 'window',
          leftMm: 1400,
          topMm: 700,
          rightMm: 2100,
          bottomMm: 1300,
        ),
      ],
    );
    final session = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(session.dispose);

    final source = session.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(500, 1000),
    );
    final target = session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(3000, 1000),
    );
    session.select(source.id, mode: SelectionMode.replace);
    session.select(target.id, mode: SelectionMode.add);

    expect(session.autoRouteSelectedPair(), isTrue);
    final route = session.routes.single;
    final points = route.segments.single.points;
    expect(points.length, greaterThanOrEqualTo(4));
    expect(
      NormativeRouteEngine.validate(points: points, context: context).isValid,
      isTrue,
    );
    expect(points.any((point) => point.yMm != 1000), isTrue);
  });

  test('wall source can auto-route to ceiling load through topology', () {
    final session = EditorP2Session();
    addTearDown(session.dispose);

    final source = session.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(500, 1800),
    );
    final target = session.placeComponent(
      type: ElectricalComponentType.lightingPoint,
      surface: RoomSurfaceRef.ceiling('room-1'),
      position: const SurfacePointMm(3000, 1500),
    );
    session.select(source.id, mode: SelectionMode.replace);
    session.select(target.id, mode: SelectionMode.add);

    expect(session.autoRouteSelectedPair(space: room), isTrue);
    expect(session.routes, hasLength(1));
    final surfaceTypes = session.routes.single.segments
        .map((segment) => segment.surface.type)
        .toSet();
    expect(surfaceTypes, contains(SurfacePlaneType.wall));
    expect(surfaceTypes, contains(SurfacePlaneType.ceiling));
  });

  test('cross-surface auto route requires room topology context', () {
    final session = EditorP2Session();
    addTearDown(session.dispose);

    final source = session.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(500, 1800),
    );
    final target = session.placeComponent(
      type: ElectricalComponentType.lightingPoint,
      surface: RoomSurfaceRef.ceiling('room-1'),
      position: const SurfacePointMm(3000, 1500),
    );
    session.select(source.id, mode: SelectionMode.replace);
    session.select(target.id, mode: SelectionMode.add);

    expect(session.autoRouteSelectedPair(), isFalse);
    expect(session.routes, isEmpty);
  });
}
