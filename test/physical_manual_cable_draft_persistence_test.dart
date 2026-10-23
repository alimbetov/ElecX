import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surface_routing.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual cross-room draft commits route and penetration atomically', () {
    final editor = _editorWithAdjacentRooms();
    addTearDown(() {
      editor.disposeP2State();
      editor.dispose();
    });
    final wallA = RoomSurfaceRef.wall('room-a', 1);
    final wallB = RoomSurfaceRef.wall('room-b', 3);
    final source = editor.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wallA,
      position: const SurfacePointMm(100, 1200),
    );
    final target = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(900, 1200),
    );
    expect(source.id, isNot(target.id));

    editor.setTool(EditorTool.cableRoute);
    editor.routeSegments.addAll([
      const SurfaceRouteSegmentDraft(
        surface: RoomSurfaceRef.wall('room-a', 1),
        points: [
          SurfacePointMm(100, 1200),
          SurfacePointMm(1500, 1200),
        ],
      ),
      const SurfaceRouteSegmentDraft(
        surface: RoomSurfaceRef.wall('room-b', 3),
        points: [
          SurfacePointMm(1500, 1200),
          SurfacePointMm(900, 1200),
        ],
      ),
    ]);

    final committed = editor.finishPhysicalManualCableDraft(
      routeId: 'route-physical',
      resolveTransition: (fromSurface, fromPoint, toSurface, toPoint) =>
          SurfaceTransitionCandidate(
        id: 'shared-wall',
        kind: SurfaceTransitionKind.roomPenetration,
        fromSurface: fromSurface,
        fromPoint: fromPoint,
        toSurface: toSurface,
        toPoint: toPoint,
        penetrationRequirement: const BoundaryPenetrationRequirement(
          hostKind: BoundaryPenetrationHostKind.wall,
          hostThicknessMm: 180,
          materialId: 'brick',
        ),
      ),
    );

    expect(committed, isTrue);
    expect(editor.routeSegments, isEmpty);
    expect(editor.tool, EditorTool.select);
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.routes.single.id, 'route-physical');
    expect(editor.p2.routes.single.penetrations, hasLength(1));
    expect(
      editor.p2.routes.single.penetrations.single.exitAnchor.isContinuationStart,
      isTrue,
    );

    editor.p2.undo();
    expect(editor.p2.routes, isEmpty);
    editor.p2.redo();
    expect(editor.p2.routes.single.penetrations.single.hostThicknessMm, 180);
  });

  test('failed physical transition preserves the unfinished draft', () {
    final editor = _editorWithAdjacentRooms();
    addTearDown(() {
      editor.disposeP2State();
      editor.dispose();
    });
    final wallA = RoomSurfaceRef.wall('room-a', 1);
    final wallB = RoomSurfaceRef.wall('room-b', 3);
    editor.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wallA,
      position: const SurfacePointMm(100, 1200),
    );
    editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(900, 1200),
    );
    editor.setTool(EditorTool.cableRoute);
    editor.routeSegments.addAll([
      const SurfaceRouteSegmentDraft(
        surface: RoomSurfaceRef.wall('room-a', 1),
        points: [
          SurfacePointMm(100, 1200),
          SurfacePointMm(1500, 1200),
        ],
      ),
      const SurfaceRouteSegmentDraft(
        surface: RoomSurfaceRef.wall('room-b', 3),
        points: [
          SurfacePointMm(1500, 1200),
          SurfacePointMm(900, 1200),
        ],
      ),
    ]);

    expect(
      editor.finishPhysicalManualCableDraft(
        routeId: 'route-physical',
        resolveTransition: (_, __, ___, ____) => null,
      ),
      isFalse,
    );
    expect(editor.routeSegments, hasLength(2));
    expect(editor.tool, EditorTool.cableRoute);
    expect(editor.p2.routes, isEmpty);
  });
}

EditorController _editorWithAdjacentRooms() {
  final editor = EditorController.blank();
  final roomA = EngineeringSpace(
    id: 'room-a',
    name: 'A',
    type: SpaceType.room,
    boundary: MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    ),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
  );
  final roomB = EngineeringSpace(
    id: 'room-b',
    name: 'B',
    type: SpaceType.room,
    boundary: MmPolygon.rectangle(
      const MmPoint(4000, 0),
      const MmPoint(8000, 3000),
    ),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(6000, 1500)),
  );
  editor.level = BuildingLevel(
    id: 'level-1',
    name: 'L1',
    elevationMm: 0,
    spaces: [roomA, roomB],
  );
  editor.selectedSpaceId = roomA.id;
  return editor;
}
