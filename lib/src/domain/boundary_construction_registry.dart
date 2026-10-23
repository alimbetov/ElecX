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
  int get hashCode => Object.hash(kind, thicknessMm, materialId, fireRatingId);
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

  /// Migrates physical construction ownership through one explicit topology
  /// lineage operation.
  ///
  /// Split duplicates one physical construction profile onto every collinear
  /// result edge. Merge is accepted only when every source edge has an explicit
  /// and identical profile; mixing explicit/implicit or conflicting physical
  /// data is rejected instead of guessing the resulting wall construction.
  BoundaryConstructionRegistry remapSpace({
    required SpaceBoundaryTopology before,
    required SpaceBoundaryTopology after,
    required BoundaryTopologyChangeSet lineage,
  }) {
    if (before.spaceId != after.spaceId) {
      throw const BoundaryConstructionRegistryException(
        'Boundary construction migration cannot change Space owner.',
      );
    }
    before.validateOrThrow();
    after.validateOrThrow();

    final next = Map<BoundaryEdgeHostRef, BoundaryConstructionProfile>.from(
      profiles,
    );
    BoundaryEdgeHostRef host(BoundaryEdgeId edgeId) =>
        BoundaryEdgeHostRef(spaceId: before.spaceId, edgeId: edgeId);

    for (final record in lineage.lineage) {
      switch (record.kind) {
        case BoundaryEdgeLineageKind.preserved:
          final sourceId = record.sourceEdgeIds.single;
          if (before.edges[sourceId] == null || after.edges[sourceId] == null) {
            throw BoundaryConstructionRegistryException(
              'Preserved construction edge $sourceId is not active on both '
              'sides of topology migration.',
            );
          }
        case BoundaryEdgeLineageKind.split:
          final sourceId = record.sourceEdgeIds.single;
          final sourceHost = host(sourceId);
          final profile = next.remove(sourceHost);
          if (profile == null) continue;
          for (final resultId in record.resultEdgeIds) {
            next[host(resultId)] = profile;
          }
        case BoundaryEdgeLineageKind.merged:
          final sourceProfiles = <BoundaryConstructionProfile?>[
            for (final sourceId in record.sourceEdgeIds) next[host(sourceId)],
          ];
          final explicit = sourceProfiles
              .whereType<BoundaryConstructionProfile>()
              .toList(growable: false);
          if (explicit.isEmpty) {
            for (final sourceId in record.sourceEdgeIds) {
              next.remove(host(sourceId));
            }
            continue;
          }
          if (explicit.length != sourceProfiles.length) {
            throw const BoundaryConstructionRegistryException(
              'Cannot merge explicitly defined construction with an implicit '
              'construction profile.',
            );
          }
          final first = explicit.first;
          if (explicit.any((profile) => profile != first)) {
            throw const BoundaryConstructionRegistryException(
              'Cannot merge boundary edges with conflicting physical '
              'construction profiles.',
            );
          }
          for (final sourceId in record.sourceEdgeIds) {
            next.remove(host(sourceId));
          }
          next[host(record.resultEdgeIds.single)] = first;
        case BoundaryEdgeLineageKind.created:
          // New construction is intentionally unknown until explicitly authored.
          continue;
        case BoundaryEdgeLineageKind.removed:
          for (final sourceId in record.sourceEdgeIds) {
            next.remove(host(sourceId));
          }
      }
    }

    final result = BoundaryConstructionRegistry(next);
    result.validateAgainst({before.spaceId: after});
    return result;
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
