import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProjectBoundaryEdge edge({
    required String id,
    required SpaceId spaceId,
    required BoundaryPointMm start,
    required BoundaryPointMm end,
  }) =>
      ProjectBoundaryEdge(
        id: BoundaryEdgeId(id),
        spaceId: spaceId,
        start: start,
        end: end,
      );

  group('P7A stable boundary topology', () {
    test('closed rectangle validates using stable edge identities', () {
      final spaceId = SpaceId('space-room-a');
      final e1 = edge(
        id: 'edge-north',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 0),
      );
      final e2 = edge(
        id: 'edge-east',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 4000, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
      );
      final e3 = edge(
        id: 'edge-south',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
        end: const BoundaryPointMm(xMm: 0, yMm: 3000),
      );
      final e4 = edge(
        id: 'edge-west',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 3000),
        end: const BoundaryPointMm(xMm: 0, yMm: 0),
      );

      final topology = SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [e1.id, e2.id, e3.id, e4.id],
        edges: {e1.id: e1, e2.id: e2, e3.id: e3, e4.id: e4},
      );

      expect(topology.validate(), isEmpty);
      expect(topology.orderedEdgeIds[2], BoundaryEdgeId('edge-south'));
    });

    test('discontinuous and open loops fail closed', () {
      final spaceId = SpaceId('space-room-b');
      final e1 = edge(
        id: 'edge-1',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 0),
        end: const BoundaryPointMm(xMm: 1000, yMm: 0),
      );
      final e2 = edge(
        id: 'edge-2',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 1200, yMm: 0),
        end: const BoundaryPointMm(xMm: 1200, yMm: 1000),
      );
      final e3 = edge(
        id: 'edge-3',
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 1200, yMm: 1000),
        end: const BoundaryPointMm(xMm: 100, yMm: 100),
      );

      final topology = SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [e1.id, e2.id, e3.id],
        edges: {e1.id: e1, e2.id: e2, e3.id: e3},
      );

      final codes = topology.validate().map((issue) => issue.code).toSet();
      expect(codes, contains(BoundaryTopologyIssueCode.discontinuousLoop));
      expect(codes, contains(BoundaryTopologyIssueCode.openLoop));
      expect(
        topology.validateOrThrow,
        throwsA(isA<BoundaryTopologyValidationException>()),
      );
    });

    test('preserved edge keeps identity and allows direct host retention', () {
      final source = BoundaryEdgeId('edge-stable');
      final changeSet = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.preserved(source),
      ]);

      final decision = changeSet.hostRemapFor(source);

      expect(decision.kind, BoundaryHostRemapKind.preserved);
      expect(decision.candidateEdgeIds, [source]);
    });

    test('split edge requires explicit geometry-aware host remap', () {
      final source = BoundaryEdgeId('edge-old');
      final first = BoundaryEdgeId('edge-new-a');
      final second = BoundaryEdgeId('edge-new-b');
      final changeSet = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(
          sourceEdgeId: source,
          resultEdgeIds: [first, second],
        ),
      ]);

      final decision = changeSet.hostRemapFor(source);

      expect(decision.kind, BoundaryHostRemapKind.requiresGeometricRemap);
      expect(decision.candidateEdgeIds, [first, second]);
    });

    test('merge never silently reuses a replacement identity', () {
      final first = BoundaryEdgeId('edge-old-a');
      final second = BoundaryEdgeId('edge-old-b');
      final result = BoundaryEdgeId('edge-merged');
      final changeSet = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.merged(
          sourceEdgeIds: [first, second],
          resultEdgeId: result,
        ),
      ]);

      expect(
        changeSet.hostRemapFor(first).kind,
        BoundaryHostRemapKind.requiresGeometricRemap,
      );
      expect(changeSet.hostRemapFor(first).candidateEdgeIds, [result]);
      expect(
        changeSet.hostRemapFor(second).kind,
        BoundaryHostRemapKind.requiresGeometricRemap,
      );
    });

    test('removed edge detaches hosted references instead of reindexing', () {
      final removed = BoundaryEdgeId('edge-removed');
      final changeSet = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.removed([removed]),
      ]);

      final decision = changeSet.hostRemapFor(removed);

      expect(decision.kind, BoundaryHostRemapKind.removed);
      expect(decision.candidateEdgeIds, isEmpty);
    });

    test('duplicate source lineage is rejected', () {
      final source = BoundaryEdgeId('edge-source');

      expect(
        () => BoundaryTopologyChangeSet([
          BoundaryEdgeLineage.split(
            sourceEdgeId: source,
            resultEdgeIds: [
              BoundaryEdgeId('edge-a'),
              BoundaryEdgeId('edge-b'),
            ],
          ),
          BoundaryEdgeLineage.removed([source]),
        ]),
        throwsArgumentError,
      );
    });

    test('unknown pre-mutation host edge fails closed', () {
      final changeSet = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.created([BoundaryEdgeId('edge-created')]),
      ]);

      expect(
        () => changeSet.hostRemapFor(BoundaryEdgeId('edge-unknown')),
        throwsStateError,
      );
    });
  });
}
