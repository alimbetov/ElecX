import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoundaryConstructionRegistry topology migration', () {
    final spaceId = SpaceId('space-a');
    final source = BoundaryEdgeId('source');
    final a = BoundaryEdgeId('a');
    final b = BoundaryEdgeId('b');

    BoundaryConstructionProfile wall({int thicknessMm = 180}) =>
        BoundaryConstructionProfile(
          kind: BoundaryConstructionKind.wall,
          thicknessMm: thicknessMm,
          materialId: 'brick',
          fireRatingId: 'EI60',
        );

    test('split inherits one physical construction onto both result edges', () {
      final before = _topology(
        spaceId,
        [source, BoundaryEdgeId('e1'), BoundaryEdgeId('e2')],
      );
      final after = _topology(
        spaceId,
        [a, b, BoundaryEdgeId('e1'), BoundaryEdgeId('e2')],
      );
      final registry = BoundaryConstructionRegistry({
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source): wall(),
      });
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(
          sourceEdgeId: source,
          resultEdgeIds: [a, b],
        ),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('e1')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('e2')),
      ]);

      final migrated = registry.remapSpace(
        before: before,
        after: after,
        lineage: lineage,
      );

      expect(
        migrated[BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source)],
        isNull,
      );
      expect(
        migrated[BoundaryEdgeHostRef(spaceId: spaceId, edgeId: a)],
        wall(),
      );
      expect(
        migrated[BoundaryEdgeHostRef(spaceId: spaceId, edgeId: b)],
        wall(),
      );
    });

    test('merge preserves identical explicit construction', () {
      final e1 = BoundaryEdgeId('e1');
      final e2 = BoundaryEdgeId('e2');
      final e3 = BoundaryEdgeId('e3');
      final e4 = BoundaryEdgeId('e4');
      final result = BoundaryEdgeId('merged');
      final before = _topology(spaceId, [e1, e2, e3, e4]);
      final after = _topology(spaceId, [result, e3, e4]);
      final registry = BoundaryConstructionRegistry({
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: e1): wall(),
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: e2): wall(),
      });
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.merged(
          sourceEdgeIds: [e1, e2],
          resultEdgeId: result,
        ),
        BoundaryEdgeLineage.preserved(e3),
        BoundaryEdgeLineage.preserved(e4),
      ]);

      final migrated = registry.remapSpace(
        before: before,
        after: after,
        lineage: lineage,
      );

      expect(
        migrated[BoundaryEdgeHostRef(spaceId: spaceId, edgeId: result)],
        wall(),
      );
    });

    test('merge rejects conflicting physical construction', () {
      final e1 = BoundaryEdgeId('e1');
      final e2 = BoundaryEdgeId('e2');
      final e3 = BoundaryEdgeId('e3');
      final e4 = BoundaryEdgeId('e4');
      final result = BoundaryEdgeId('merged');
      final before = _topology(spaceId, [e1, e2, e3, e4]);
      final after = _topology(spaceId, [result, e3, e4]);
      final registry = BoundaryConstructionRegistry({
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: e1): wall(),
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: e2):
            wall(thicknessMm: 200),
      });
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.merged(
          sourceEdgeIds: [e1, e2],
          resultEdgeId: result,
        ),
        BoundaryEdgeLineage.preserved(e3),
        BoundaryEdgeLineage.preserved(e4),
      ]);

      expect(
        () => registry.remapSpace(
          before: before,
          after: after,
          lineage: lineage,
        ),
        throwsA(isA<BoundaryConstructionRegistryException>()),
      );
    });

    test('merge rejects explicit plus unknown construction', () {
      final e1 = BoundaryEdgeId('e1');
      final e2 = BoundaryEdgeId('e2');
      final e3 = BoundaryEdgeId('e3');
      final e4 = BoundaryEdgeId('e4');
      final result = BoundaryEdgeId('merged');
      final before = _topology(spaceId, [e1, e2, e3, e4]);
      final after = _topology(spaceId, [result, e3, e4]);
      final registry = BoundaryConstructionRegistry({
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: e1): wall(),
      });
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.merged(
          sourceEdgeIds: [e1, e2],
          resultEdgeId: result,
        ),
        BoundaryEdgeLineage.preserved(e3),
        BoundaryEdgeLineage.preserved(e4),
      ]);

      expect(
        () => registry.remapSpace(
          before: before,
          after: after,
          lineage: lineage,
        ),
        throwsA(isA<BoundaryConstructionRegistryException>()),
      );
    });
  });
}

SpaceBoundaryTopology _topology(
  SpaceId spaceId,
  List<BoundaryEdgeId> ids,
) {
  final points = switch (ids.length) {
    3 => const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 0),
        BoundaryPointMm(xMm: 0, yMm: 2000),
      ],
    4 => const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 1500, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 0),
        BoundaryPointMm(xMm: 0, yMm: 2000),
      ],
    _ => throw ArgumentError('Fixture supports only 3 or 4 boundary edges.'),
  };
  final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
  for (var index = 0; index < ids.length; index++) {
    edges[ids[index]] = ProjectBoundaryEdge(
      id: ids[index],
      spaceId: spaceId,
      start: points[index],
      end: points[(index + 1) % points.length],
    );
  }
  return SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: ids,
    edges: edges,
  );
}
