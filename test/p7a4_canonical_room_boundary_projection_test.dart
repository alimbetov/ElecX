import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/canonical_room_boundary_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-4 canonical room boundary projection', () {
    test('maps stable BoundaryEdgeId values to transient wall ordinals', () {
      final fixture = _Fixture.rectangle();

      final projection = fixture.buildProjection();

      expect(projection.wallCount, 4);
      expect(projection.orderedEdgeIds, fixture.edgeIds);
      for (var ordinal = 0; ordinal < fixture.edgeIds.length; ordinal++) {
        final edgeId = fixture.edgeIds[ordinal];
        expect(projection.edgeIdAtOrdinal(ordinal), edgeId);
        expect(projection.ordinalForEdgeId(edgeId), ordinal);
        expect(projection.wallForEdgeId(edgeId)?.wallOrdinal, ordinal);
      }
    });

    test('supports rooms with more than four walls', () {
      final fixture = _Fixture(
        points: const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 2000, yMm: 0),
          BoundaryPointMm(xMm: 3000, yMm: 1000),
          BoundaryPointMm(xMm: 2500, yMm: 2500),
          BoundaryPointMm(xMm: 1000, yMm: 3000),
          BoundaryPointMm(xMm: 0, yMm: 1500),
        ],
      );

      final projection = fixture.buildProjection();

      expect(projection.wallCount, 6);
      expect(projection.orderedEdgeIds, fixture.edgeIds);
    });

    test('same count but changed legacy geometry fails closed', () {
      final fixture = _Fixture.rectangle();
      final changedLegacy = fixture.legacySpaceWithPoints(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4500, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ]);

      expect(
        () => CanonicalRoomBoundaryProjection.build(
          canonicalSpaceId: fixture.spaceId,
          legacySpaceId: fixture.legacySpaceId,
          canonicalTopology: fixture.topology,
          legacySpace: changedLegacy,
        ),
        throwsA(
          isA<CanonicalRoomBoundaryProjectionException>()
              .having(
                (error) => error.code,
                'code',
                CanonicalRoomBoundaryProjectionIssueCode.edgeGeometryMismatch,
              )
              .having((error) => error.wallOrdinal, 'wallOrdinal', 0),
        ),
      );
    });

    test('reordered stable ids cannot silently bind to legacy wall ordinal',
        () {
      final fixture = _Fixture.rectangle();
      final reordered = SpaceBoundaryTopology(
        spaceId: fixture.spaceId,
        orderedEdgeIds: [
          fixture.edgeIds[1],
          fixture.edgeIds[2],
          fixture.edgeIds[3],
          fixture.edgeIds[0],
        ],
        edges: fixture.topology.edges,
      );

      expect(
        () => CanonicalRoomBoundaryProjection.build(
          canonicalSpaceId: fixture.spaceId,
          legacySpaceId: fixture.legacySpaceId,
          canonicalTopology: reordered,
          legacySpace: fixture.legacySpace,
        ),
        throwsA(isA<CanonicalRoomBoundaryProjectionException>()),
      );
    });

    test('wall count drift fails closed', () {
      final fixture = _Fixture.rectangle();
      final legacyTriangle = fixture.legacySpaceWithPoints(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ]);

      expect(
        () => CanonicalRoomBoundaryProjection.build(
          canonicalSpaceId: fixture.spaceId,
          legacySpaceId: fixture.legacySpaceId,
          canonicalTopology: fixture.topology,
          legacySpace: legacyTriangle,
        ),
        throwsA(
          isA<CanonicalRoomBoundaryProjectionException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomBoundaryProjectionIssueCode.wallCountMismatch,
          ),
        ),
      );
    });

    test('canonical and legacy owner mismatches fail closed', () {
      final fixture = _Fixture.rectangle();

      expect(
        () => CanonicalRoomBoundaryProjection.build(
          canonicalSpaceId: SpaceId('other-space'),
          legacySpaceId: fixture.legacySpaceId,
          canonicalTopology: fixture.topology,
          legacySpace: fixture.legacySpace,
        ),
        throwsA(
          isA<CanonicalRoomBoundaryProjectionException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomBoundaryProjectionIssueCode.canonicalSpaceMismatch,
          ),
        ),
      );
      expect(
        () => CanonicalRoomBoundaryProjection.build(
          canonicalSpaceId: fixture.spaceId,
          legacySpaceId: 'other-legacy-space',
          canonicalTopology: fixture.topology,
          legacySpace: fixture.legacySpace,
        ),
        throwsA(
          isA<CanonicalRoomBoundaryProjectionException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomBoundaryProjectionIssueCode.legacySpaceMismatch,
          ),
        ),
      );
    });
  });
}

final class _Fixture {
  _Fixture({required this.points})
      : edgeIds = [
          for (var index = 0; index < points.length; index++)
            BoundaryEdgeId('edge-$index'),
        ] {
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < points.length; index++) {
      final edgeId = edgeIds[index];
      edges[edgeId] = ProjectBoundaryEdge(
        id: edgeId,
        spaceId: spaceId,
        start: points[index],
        end: points[(index + 1) % points.length],
      );
    }
    topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: edges,
    );
    legacySpace = legacySpaceWithPoints(points);
  }

  factory _Fixture.rectangle() => _Fixture(points: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ]);

  final SpaceId spaceId = SpaceId('space-canonical');
  final String legacySpaceId = 'space-legacy';
  final List<BoundaryPointMm> points;
  final List<BoundaryEdgeId> edgeIds;
  late final SpaceBoundaryTopology topology;
  late final EngineeringSpace legacySpace;

  EngineeringSpace legacySpaceWithPoints(List<BoundaryPointMm> source) {
    final polygon = MmPolygon([
      for (final point in source) MmPoint(point.xMm, point.yMm),
    ]);
    return EngineeringSpace(
      id: legacySpaceId,
      name: 'Room',
      type: SpaceType.room,
      boundary: polygon,
      referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
    );
  }

  CanonicalRoomBoundaryProjection buildProjection() =>
      CanonicalRoomBoundaryProjection.build(
        canonicalSpaceId: spaceId,
        legacySpaceId: legacySpaceId,
        canonicalTopology: topology,
        legacySpace: legacySpace,
      );
}
