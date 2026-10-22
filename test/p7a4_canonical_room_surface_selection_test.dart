import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/canonical_room_boundary_projection.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_selection.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-4 stable room surface selection', () {
    test('active legacy ordinal projects to stable BoundaryEdgeId', () {
      final fixture = _Fixture();
      fixture.controller.showWall(2);

      final selection = fixture.adapter.current();

      expect(selection.kind, CanonicalRoomSurfaceKind.wall);
      expect(selection.boundaryEdgeId, fixture.edgeIds[2]);
      expect(selection.wallOrdinal, 2);
    });

    test('BoundaryEdgeId selection resolves ordinal only at legacy boundary',
        () {
      final fixture = _Fixture();

      expect(fixture.adapter.showBoundaryEdge(fixture.edgeIds[3]), isTrue);

      final selection = fixture.adapter.current();
      expect(selection.boundaryEdgeId, fixture.edgeIds[3]);
      expect(selection.wallOrdinal, 3);
      expect(fixture.controller.activeSurface?.wallIndex, 3);
    });

    test('unknown BoundaryEdgeId fails closed without changing surface', () {
      final fixture = _Fixture();
      fixture.controller.showWall(1);
      final before = fixture.controller.activeSurface;

      expect(
        fixture.adapter.showBoundaryEdge(BoundaryEdgeId('unknown-edge')),
        isFalse,
      );
      expect(fixture.controller.activeSurface, before);
    });

    test('next and previous rotate by canonical ordered edge identity', () {
      final fixture = _Fixture();
      fixture.adapter.showBoundaryEdge(fixture.edgeIds[1]);

      expect(fixture.adapter.nextWall(), isTrue);
      expect(fixture.adapter.current().boundaryEdgeId, fixture.edgeIds[2]);

      expect(fixture.adapter.previousWall(), isTrue);
      expect(fixture.adapter.current().boundaryEdgeId, fixture.edgeIds[1]);
    });

    test('stale legacy wall ordinal projects to Plan rather than another edge',
        () {
      final fixture = _Fixture();
      fixture.controller.restoreResumeState(
        selectedSpaceId: fixture.legacySpace.id,
        selectedOpeningId: null,
        activeSurface: null,
        viewMode: EditorViewMode.plan,
        snapEnabled: true,
        dimensionsVisible: true,
        floorGridMm: 500,
        zoom: 1,
        roomSequence: 1,
        openingSequence: 1,
      );

      expect(fixture.adapter.current().kind, CanonicalRoomSurfaceKind.plan);
      expect(fixture.adapter.current().boundaryEdgeId, isNull);
      expect(fixture.adapter.fallbackToPlanIfStale(), isFalse);
    });

    test('legacy polygon drift invalidates previously resolved edge mapping',
        () {
      final fixture = _Fixture();
      fixture.adapter.showBoundaryEdge(fixture.edgeIds[1]);
      final before = fixture.controller.activeSurface;

      final changedPolygon = MmPolygon(const [
        MmPoint(0, 0),
        MmPoint(4500, 0),
        MmPoint(4000, 3000),
        MmPoint(0, 3000),
      ]);
      fixture.controller.level = fixture.controller.level.copyWith(
        spaces: [
          fixture.legacySpace.copyWith(
            boundary: changedPolygon,
            referenceFrame: RoomReferenceFrame(
              origin: changedPolygon.bounds.center,
            ),
          ),
        ],
      );

      expect(fixture.adapter.isMaterializationCurrent, isFalse);
      expect(fixture.adapter.current().kind, CanonicalRoomSurfaceKind.plan);
      expect(
        fixture.adapter.showBoundaryEdge(fixture.edgeIds[2]),
        isFalse,
      );
      expect(fixture.adapter.nextWall(), isFalse);
      expect(fixture.adapter.previousWall(), isFalse);
      expect(fixture.controller.activeSurface, before);

      expect(fixture.adapter.fallbackToPlanIfStale(), isTrue);
      expect(fixture.controller.viewMode, EditorViewMode.plan);
      expect(fixture.controller.activeSurface, isNull);
      expect(fixture.adapter.fallbackToPlanIfStale(), isFalse);
    });
  });
}

final class _Fixture {
  _Fixture() {
    const points = [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final polygon = MmPolygon([
      for (final point in points) MmPoint(point.xMm, point.yMm),
    ]);
    legacySpace = EngineeringSpace(
      id: 'legacy-space',
      name: 'Room',
      type: SpaceType.room,
      boundary: polygon,
      referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
    );
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < points.length; index++) {
      final id = edgeIds[index];
      edges[id] = ProjectBoundaryEdge(
        id: id,
        spaceId: canonicalSpaceId,
        start: points[index],
        end: points[(index + 1) % points.length],
      );
    }
    final topology = SpaceBoundaryTopology(
      spaceId: canonicalSpaceId,
      orderedEdgeIds: edgeIds,
      edges: edges,
    );
    controller = EditorController.restored(
      level: BuildingLevel(
        id: 'level-legacy',
        name: 'Level',
        elevationMm: 0,
        spaces: [legacySpace],
      ),
      openings: const [],
    )..selectSpace(legacySpace.id);
    projection = CanonicalRoomBoundaryProjection.build(
      canonicalSpaceId: canonicalSpaceId,
      legacySpaceId: legacySpace.id,
      canonicalTopology: topology,
      legacySpace: legacySpace,
    );
    adapter = CanonicalRoomSurfaceSelectionAdapter(
      controller: controller,
      projection: projection,
    );
  }

  final SpaceId canonicalSpaceId = SpaceId('canonical-space');
  final List<BoundaryEdgeId> edgeIds = [
    BoundaryEdgeId('edge-a'),
    BoundaryEdgeId('edge-b'),
    BoundaryEdgeId('edge-c'),
    BoundaryEdgeId('edge-d'),
  ];
  late final EngineeringSpace legacySpace;
  late final EditorController controller;
  late final CanonicalRoomBoundaryProjection projection;
  late final CanonicalRoomSurfaceSelectionAdapter adapter;
}
