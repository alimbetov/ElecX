import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'diagonal profile split fails closed when integer widths are non-additive',
      () {
    final spaceId = SpaceId('diagonal-profile-space');
    final source = BoundaryEdgeId('source');
    final first = BoundaryEdgeId('first');
    final second = BoundaryEdgeId('second');
    final sideB = BoundaryEdgeId('side-b');
    final sideC = BoundaryEdgeId('side-c');
    final sourceEdge = _edge(source, spaceId, 0, 0, 600, 600);
    final before = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [source, sideB, sideC],
      edges: {
        source: sourceEdge,
        sideB: _edge(sideB, spaceId, 600, 600, 0, 1200),
        sideC: _edge(sideC, spaceId, 0, 1200, 0, 0),
      },
    );
    final after = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [first, second, sideB, sideC],
      edges: {
        first: _edge(first, spaceId, 0, 0, 300, 300),
        second: _edge(second, spaceId, 300, 300, 600, 600),
        sideB: _edge(sideB, spaceId, 600, 600, 0, 1200),
        sideC: _edge(sideC, spaceId, 0, 1200, 0, 0),
      },
    );
    final sourceHost = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source);
    final registry = BoundaryWallProfileRegistry({
      sourceHost: WallProfile.rectangle(widthMm: 849, heightMm: 3000),
    });

    registry.validateAgainst({spaceId: before});
    final split = registry.split(
      spaceId: spaceId,
      sourceEdge: sourceEdge,
      firstResultEdgeId: first,
      secondResultEdgeId: second,
      splitPoint: const BoundaryPointMm(xMm: 300, yMm: 300),
    );

    expect(
      () => split.validateAgainst({spaceId: after}),
      throwsA(
        isA<BoundaryWallProfileRegistryException>().having(
          (error) => error.code,
          'code',
          BoundaryWallProfileRegistryIssueCode.profileWidthMismatch,
        ),
      ),
      reason: '849mm source profile cannot be represented losslessly as two '
          '424mm diagonal child profiles; no one-millimetre guess is allowed.',
    );
  });
}

ProjectBoundaryEdge _edge(
  BoundaryEdgeId id,
  SpaceId spaceId,
  int x1,
  int y1,
  int x2,
  int y2,
) =>
    ProjectBoundaryEdge(
      id: id,
      spaceId: spaceId,
      start: BoundaryPointMm(xMm: x1, yMm: y1),
      end: BoundaryPointMm(xMm: x2, yMm: y2),
    );
