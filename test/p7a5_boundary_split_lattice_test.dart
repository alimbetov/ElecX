import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_boundary_topology_migration_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 exact integer-mm split lattice', () {
    final spaceId = SpaceId('space');

    ProjectBoundaryEdge edge(BoundaryPointMm start, BoundaryPointMm end) =>
        ProjectBoundaryEdge(
          id: BoundaryEdgeId('edge'),
          spaceId: spaceId,
          start: start,
          end: end,
        );

    test('chooses an exact interior point for a diagonal lattice edge', () {
      final split = CanonicalBoundaryTopologyMigrationRuntime
          .representableInteriorSplitPoint(
        edge(
          const BoundaryPointMm(xMm: 0, yMm: 0),
          const BoundaryPointMm(xMm: 6000, yMm: 4000),
        ),
      );

      expect(split, const BoundaryPointMm(xMm: 3000, yMm: 2000));
    });

    test('keeps odd axis-aligned split exactly on the source edge', () {
      final split = CanonicalBoundaryTopologyMigrationRuntime
          .representableInteriorSplitPoint(
        edge(
          const BoundaryPointMm(xMm: 0, yMm: 0),
          const BoundaryPointMm(xMm: 5, yMm: 0),
        ),
      );

      expect(split, const BoundaryPointMm(xMm: 2, yMm: 0));
    });

    test('rejects a primitive diagonal with no interior integer-mm point', () {
      final split = CanonicalBoundaryTopologyMigrationRuntime
          .representableInteriorSplitPoint(
        edge(
          const BoundaryPointMm(xMm: 0, yMm: 0),
          const BoundaryPointMm(xMm: 4001, yMm: 3000),
        ),
      );

      expect(split, isNull);
    });
  });
}
