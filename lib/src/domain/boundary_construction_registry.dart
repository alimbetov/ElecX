import 'boundary_host_migration.dart';
import 'boundary_topology.dart';
import 'project_identity.dart';

enum BoundaryConstructionKind { wall, slab }

/// Physical construction data used by routing and normative validation.
///
/// This is deliberately separate from WallProfile: a profile describes the
/// visible elevation face, while this object describes the material crossed by
/// a cable penetration.
final class BoundaryConstructionProfile {
  BoundaryConstructionProfile({
    required this.kind,
    required this.thicknessMm,
    required this.materialId,
    this.fireRatingId,
  }) {
    if (thicknessMm <= 0) {
      throw ArgumentError.value(
        thicknessMm,
        'thicknessMm',
        'Construction thickness must be positive.',
      );
    }
    if (materialId.trim().isEmpty) {
      throw ArgumentError('materialId must be non-empty.');
    }
    if (fireRatingId != null && fireRatingId!.trim().isEmpty) {
      throw ArgumentError('fireRatingId must be null or non-empty.');
    }
  }

  final BoundaryConstructionKind kind;
  final int thicknessMm;
  final String materialId;
  final String? fireRatingId;

  @override
  bool operator ==(Object other) =>
      other is BoundaryConstructionProfile &&
      other.kind == kind &&
      other.thicknessMm == thicknessMm &&
      other.materialId == materialId &&
      other.fireRatingId == fireRatingId;

  @override
  int get hashCode =>
      Object.hash(kind, thicknessMm, materialId, fireRatingId);
}

final class BoundaryConstructionRegistryException implements Exception {
  const BoundaryConstructionRegistryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Canonical physical construction ownership by stable boundary identity.
final class BoundaryConstructionRegistry {
  BoundaryConstructionRegistry(
    Map<BoundaryEdgeHostRef, BoundaryConstructionProfile> profiles,
  ) : profiles = Map.unmodifiable(profiles);

  const BoundaryConstructionRegistry.empty() : profiles = const {};

  final Map<BoundaryEdgeHostRef, BoundaryConstructionProfile> profiles;

  BoundaryConstructionProfile? operator [](BoundaryEdgeHostRef host) =>
      profiles[host];

  BoundaryConstructionRegistry put(
    BoundaryEdgeHostRef host,
    BoundaryConstructionProfile profile,
  ) =>
      BoundaryConstructionRegistry({...profiles, host: profile});

  BoundaryConstructionRegistry remove(BoundaryEdgeHostRef host) {
    if (!profiles.containsKey(host)) return this;
    final next = Map<BoundaryEdgeHostRef, BoundaryConstructionProfile>.from(
      profiles,
    )..remove(host);
    return BoundaryConstructionRegistry(next);
  }

  void validateAgainst(Map<SpaceId, SpaceBoundaryTopology> boundaries) {
    for (final entry in profiles.entries) {
      final topology = boundaries[entry.key.spaceId];
      if (topology == null) {
        throw BoundaryConstructionRegistryException(
          'Construction host ${entry.key.spaceId}/${entry.key.edgeId} has no '
          'active space topology.',
        );
      }
      final edge = topology.edges[entry.key.edgeId];
      if (edge == null) {
        throw BoundaryConstructionRegistryException(
          'Construction host ${entry.key.edgeId} is not an active boundary.',
        );
      }
      if (edge.spaceId != entry.key.spaceId) {
        throw BoundaryConstructionRegistryException(
          'Construction host ${entry.key.edgeId} belongs to ${edge.spaceId}, '
          'not ${entry.key.spaceId}.',
        );
      }
      if (entry.value.kind != BoundaryConstructionKind.wall) {
        throw BoundaryConstructionRegistryException(
          'BoundaryEdgeId ${entry.key.edgeId} currently supports only wall '
          'construction profiles. Slabs require a stable SlabId host.',
        );
      }
    }
  }

  bool sameAs(BoundaryConstructionRegistry other) {
    if (identical(this, other)) return true;
    if (profiles.length != other.profiles.length) return false;
    for (final entry in profiles.entries) {
      if (other.profiles[entry.key] != entry.value) return false;
    }
    return true;
  }
}
