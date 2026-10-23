import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoundaryConstructionRegistry', () {
    final spaceId = SpaceId('space-a');
    final edgeIds = [
      BoundaryEdgeId('edge-a'),
      BoundaryEdgeId('edge-b'),
      BoundaryEdgeId('edge-c'),
      BoundaryEdgeId('edge-d'),
    ];
    final edgeId = edgeIds.first;
    final host = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId);
    final points = const [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: {
        for (var index = 0; index < edgeIds.length; index++)
          edgeIds[index]: ProjectBoundaryEdge(
            id: edgeIds[index],
            spaceId: spaceId,
            start: points[index],
            end: points[(index + 1) % points.length],
          ),
      },
    );

    test('stores physical wall thickness/material by stable edge identity', () {
      final registry = const BoundaryConstructionRegistry.empty().put(
        host,
        BoundaryConstructionProfile(
          kind: BoundaryConstructionKind.wall,
          thicknessMm: 180,
          materialId: 'brick',
          fireRatingId: 'EI60',
        ),
      );

      registry.validateAgainst({spaceId: topology});
      expect(registry[host]!.thicknessMm, 180);
      expect(registry[host]!.materialId, 'brick');
      expect(registry[host]!.fireRatingId, 'EI60');
    });

    test('rejects construction attached to inactive edge', () {
      final registry = const BoundaryConstructionRegistry.empty().put(
        BoundaryEdgeHostRef(
          spaceId: spaceId,
          edgeId: BoundaryEdgeId('retired-edge'),
        ),
        BoundaryConstructionProfile(
          kind: BoundaryConstructionKind.wall,
          thicknessMm: 120,
          materialId: 'partition',
        ),
      );

      expect(
        () => registry.validateAgainst({spaceId: topology}),
        throwsA(isA<BoundaryConstructionRegistryException>()),
      );
    });

    test('does not allow a slab to masquerade as a wall BoundaryEdgeId', () {
      final registry = const BoundaryConstructionRegistry.empty().put(
        host,
        BoundaryConstructionProfile(
          kind: BoundaryConstructionKind.slab,
          thicknessMm: 220,
          materialId: 'reinforced-concrete',
        ),
      );

      expect(
        () => registry.validateAgainst({spaceId: topology}),
        throwsA(isA<BoundaryConstructionRegistryException>()),
      );
    });
  });
}
