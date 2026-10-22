import 'boundary_topology.dart';
import 'project_identity.dart';

/// Durable ownership ledger for every BoundaryEdgeId ever issued in a project.
///
/// Active edges and tombstoned edges share the same registry. Removing a space
/// or boundary never removes the historical owner entry, so a retired edge id
/// cannot later be reassigned to a different SpaceId after save/reopen.
final class BoundaryEdgeIdentityRegistry {
  BoundaryEdgeIdentityRegistry(Map<BoundaryEdgeId, SpaceId> owners)
      : owners = Map.unmodifiable(owners);

  const BoundaryEdgeIdentityRegistry.empty() : owners = const {};

  final Map<BoundaryEdgeId, SpaceId> owners;

  SpaceId? ownerOf(BoundaryEdgeId edgeId) => owners[edgeId];

  bool contains(BoundaryEdgeId edgeId) => owners.containsKey(edgeId);

  bool get isEmpty => owners.isEmpty;
  bool get isNotEmpty => owners.isNotEmpty;

  BoundaryEdgeIdentityRegistry registerActiveBoundaries(
    Map<SpaceId, SpaceBoundaryTopology> boundaries,
  ) {
    final next = Map<BoundaryEdgeId, SpaceId>.from(owners);
    for (final topology in boundaries.values) {
      for (final edgeId in topology.edges.keys) {
        final previousOwner = next[edgeId];
        if (previousOwner != null && previousOwner != topology.spaceId) {
          throw BoundaryEdgeIdentityOwnershipException(
            edgeId: edgeId,
            expectedSpaceId: previousOwner,
            actualSpaceId: topology.spaceId,
          );
        }
        next.putIfAbsent(edgeId, () => topology.spaceId);
      }
    }
    return BoundaryEdgeIdentityRegistry(next);
  }

  bool sameAs(BoundaryEdgeIdentityRegistry other) {
    if (owners.length != other.owners.length) return false;
    for (final entry in owners.entries) {
      if (other.owners[entry.key] != entry.value) return false;
    }
    return true;
  }
}

final class BoundaryEdgeIdentityOwnershipException implements Exception {
  const BoundaryEdgeIdentityOwnershipException({
    required this.edgeId,
    required this.expectedSpaceId,
    required this.actualSpaceId,
  });

  final BoundaryEdgeId edgeId;
  final SpaceId expectedSpaceId;
  final SpaceId actualSpaceId;

  @override
  String toString() => 'Boundary edge $edgeId is permanently owned by '
      '$expectedSpaceId and cannot be reassigned to $actualSpaceId.';
}
