import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/canonical_room_boundary_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('self-intersecting canonical geometry cannot enter editor cutover', () {
    final spaceId = SpaceId('space');
    const points = [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 3000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
      BoundaryPointMm(xMm: 3000, yMm: 0),
    ];
    final ids = [
      BoundaryEdgeId('a'),
      BoundaryEdgeId('b'),
      BoundaryEdgeId('c'),
      BoundaryEdgeId('d'),
    ];
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      edges[id] = ProjectBoundaryEdge(
        id: id,
        spaceId: spaceId,
        start: points[index],
        end: points[(index + 1) % points.length],
      );
    }
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ids,
      edges: edges,
    );
    final polygon = MmPolygon([
      for (final point in points) MmPoint(point.xMm, point.yMm),
    ]);
    final legacySpace = EngineeringSpace(
      id: 'legacy-space',
      name: 'Room',
      type: SpaceType.room,
      boundary: polygon,
      referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
    );

    expect(
      () => CanonicalRoomBoundaryProjection.build(
        canonicalSpaceId: spaceId,
        legacySpaceId: legacySpace.id,
        canonicalTopology: topology,
        legacySpace: legacySpace,
      ),
      throwsA(
        isA<CanonicalRoomBoundaryProjectionException>().having(
          (error) => error.code,
          'code',
          CanonicalRoomBoundaryProjectionIssueCode.invalidCanonicalGeometry,
        ),
      ),
    );
  });
}
