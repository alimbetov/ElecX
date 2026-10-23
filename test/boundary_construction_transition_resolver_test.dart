import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_construction_transition_resolver.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoundaryConstructionTransitionResolver', () {
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
    final level = BuildingLevel(
      id: 'level-1',
      name: 'L1',
      elevationMm: 0,
      spaces: [roomA, roomB],
    );
    final aEdges = [
      BoundaryEdgeId('a0'),
      BoundaryEdgeId('a1'),
      BoundaryEdgeId('a2'),
      BoundaryEdgeId('a3'),
    ];
    final bEdges = [
      BoundaryEdgeId('b0'),
      BoundaryEdgeId('b1'),
      BoundaryEdgeId('b2'),
      BoundaryEdgeId('b3'),
    ];
    final canonicalA = SpaceId('canonical-a');
    final canonicalB = SpaceId('canonical-b');

    List<BoundaryEdgeId>? edgeOrder(String spaceId) => switch (spaceId) {
          'room-a' => aEdges,
          'room-b' => bEdges,
          _ => null,
        };

    SpaceId? canonicalSpace(String legacySpaceId) => switch (legacySpaceId) {
          'room-a' => canonicalA,
          'room-b' => canonicalB,
          _ => null,
        };

    BoundaryConstructionRegistry registry({int bThicknessMm = 180}) =>
        BoundaryConstructionRegistry({
          BoundaryEdgeHostRef(spaceId: canonicalA, edgeId: aEdges[1]):
              BoundaryConstructionProfile(
            kind: BoundaryConstructionKind.wall,
            thicknessMm: 180,
            materialId: 'brick',
            fireRatingId: 'EI60',
          ),
          BoundaryEdgeHostRef(spaceId: canonicalB, edgeId: bEdges[3]):
              BoundaryConstructionProfile(
            kind: BoundaryConstructionKind.wall,
            thicknessMm: bThicknessMm,
            materialId: 'brick',
            fireRatingId: 'EI60',
          ),
        });

    test('resolves shared wall only from matching two-sided construction data',
        () {
      final fromSurface = RoomSurfaceRef.wall('room-a', 1);
      final toSurface = RoomSurfaceRef.wall('room-b', 3);
      const fromPoint = SurfacePointMm(1500, 1200);
      const toPoint = SurfacePointMm(1500, 1200);
      final result = BoundaryConstructionTransitionResolver.resolve(
        level: level,
        fromSpace: roomA,
        fromSurface: fromSurface,
        fromPoint: fromPoint,
        toSurface: toSurface,
        toPoint: toPoint,
        constructions: registry(),
        edgeOrderResolver: edgeOrder,
        canonicalSpaceIdResolver: canonicalSpace,
      );

      expect(result, isNotNull);
      expect(result!.kind, SurfaceTransitionKind.roomPenetration);
      expect(result.fromSurface, fromSurface);
      expect(result.fromPoint, fromPoint);
      expect(result.toSurface, toSurface);
      expect(result.toPoint, toPoint);
      expect(result.penetrationRequirement!.hostThicknessMm, 180);
      expect(result.penetrationRequirement!.materialId, 'brick');
    });

    test('rejects conflicting thickness across two faces of one wall', () {
      final result = BoundaryConstructionTransitionResolver.resolve(
        level: level,
        fromSpace: roomA,
        fromSurface: RoomSurfaceRef.wall('room-a', 1),
        fromPoint: const SurfacePointMm(1500, 1200),
        toSurface: RoomSurfaceRef.wall('room-b', 3),
        toPoint: const SurfacePointMm(1500, 1200),
        constructions: registry(bThicknessMm: 200),
        edgeOrderResolver: edgeOrder,
        canonicalSpaceIdResolver: canonicalSpace,
      );

      expect(result, isNull);
    });
  });
}
