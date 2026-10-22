import 'dart:math' as math;

import 'boundary_host_migration.dart';
import 'boundary_topology.dart';
import 'boundary_wall_profile_migration.dart';
import 'project_identity.dart';
import 'wall_profile.dart';

enum BoundaryWallProfileRegistryIssueCode {
  missingSpaceTopology,
  missingBoundaryEdge,
  boundaryOwnerMismatch,
  profileWidthMismatch,
}

final class BoundaryWallProfileRegistryException implements Exception {
  const BoundaryWallProfileRegistryException({
    required this.code,
    required this.host,
    required this.message,
  });

  final BoundaryWallProfileRegistryIssueCode code;
  final BoundaryEdgeHostRef host;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Canonical payload registry for non-default wall elevation profiles.
///
/// The key is the same stable `(SpaceId, BoundaryEdgeId)` host identity used by
/// P7A-5 hosted objects. Absence means the discipline/default rectangular wall
/// profile applies; no ordinal key is accepted here.
final class BoundaryWallProfileRegistry {
  BoundaryWallProfileRegistry(Map<BoundaryEdgeHostRef, WallProfile> profiles)
      : profiles = Map.unmodifiable(profiles);

  const BoundaryWallProfileRegistry.empty() : profiles = const {};

  final Map<BoundaryEdgeHostRef, WallProfile> profiles;

  WallProfile? operator [](BoundaryEdgeHostRef host) => profiles[host];

  Map<BoundaryEdgeId, WallProfile> forSpace(SpaceId spaceId) =>
      Map.unmodifiable({
        for (final entry in profiles.entries)
          if (entry.key.spaceId == spaceId) entry.key.edgeId: entry.value,
      });

  BoundaryWallProfileRegistry put(
    BoundaryEdgeHostRef host,
    WallProfile profile,
  ) =>
      BoundaryWallProfileRegistry({...profiles, host: profile});

  BoundaryWallProfileRegistry remove(BoundaryEdgeHostRef host) {
    if (!profiles.containsKey(host)) return this;
    final next = Map<BoundaryEdgeHostRef, WallProfile>.from(profiles)
      ..remove(host);
    return BoundaryWallProfileRegistry(next);
  }

  void validateAgainst(Map<SpaceId, SpaceBoundaryTopology> boundaries) {
    for (final entry in profiles.entries) {
      final host = entry.key;
      final topology = boundaries[host.spaceId];
      if (topology == null) {
        throw BoundaryWallProfileRegistryException(
          code: BoundaryWallProfileRegistryIssueCode.missingSpaceTopology,
          host: host,
          message: 'Wall profile references Space ${host.spaceId} without '
              'active boundary topology.',
        );
      }
      final edge = topology.edges[host.edgeId];
      if (edge == null) {
        throw BoundaryWallProfileRegistryException(
          code: BoundaryWallProfileRegistryIssueCode.missingBoundaryEdge,
          host: host,
          message: 'Wall profile references inactive edge ${host.edgeId}.',
        );
      }
      if (edge.spaceId != host.spaceId) {
        throw BoundaryWallProfileRegistryException(
          code: BoundaryWallProfileRegistryIssueCode.boundaryOwnerMismatch,
          host: host,
          message: 'Wall profile edge ${edge.id} is owned by ${edge.spaceId}.',
        );
      }
      final length = _edgeLength(edge).round();
      if (entry.value.maxX != length) {
        throw BoundaryWallProfileRegistryException(
          code: BoundaryWallProfileRegistryIssueCode.profileWidthMismatch,
          host: host,
          message: 'Wall profile width ${entry.value.maxX}mm does not match '
              'edge length ${length}mm.',
        );
      }
    }
  }

  BoundaryWallProfileRegistry split({
    required SpaceId spaceId,
    required ProjectBoundaryEdge sourceEdge,
    required BoundaryEdgeId firstResultEdgeId,
    required BoundaryEdgeId secondResultEdgeId,
    required BoundaryPointMm splitPoint,
  }) {
    final host = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: sourceEdge.id);
    final profile = profiles[host];
    if (profile == null) return this;
    final sourceLength = _edgeLength(sourceEdge).round();
    final splitOffset = _distance(sourceEdge.start, splitPoint).round();
    final migrated = BoundaryWallProfileMigration.split(
      sourceEdgeId: sourceEdge.id,
      firstResultEdgeId: firstResultEdgeId,
      secondResultEdgeId: secondResultEdgeId,
      sourceLengthMm: sourceLength,
      splitOffsetMm: splitOffset,
      profiles: {sourceEdge.id: profile},
    );
    final next = Map<BoundaryEdgeHostRef, WallProfile>.from(profiles)
      ..remove(host);
    for (final entry in migrated.entries) {
      next[BoundaryEdgeHostRef(spaceId: spaceId, edgeId: entry.key)] =
          entry.value;
    }
    return BoundaryWallProfileRegistry(next);
  }

  BoundaryWallProfileRegistry merge({
    required SpaceId spaceId,
    required ProjectBoundaryEdge firstSourceEdge,
    required ProjectBoundaryEdge secondSourceEdge,
    required BoundaryEdgeId resultEdgeId,
  }) {
    final firstHost =
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: firstSourceEdge.id);
    final secondHost =
        BoundaryEdgeHostRef(spaceId: spaceId, edgeId: secondSourceEdge.id);
    final first = profiles[firstHost];
    final second = profiles[secondHost];
    if (first == null && second == null) return this;
    final migrated = BoundaryWallProfileMigration.merge(
      firstSourceEdgeId: firstSourceEdge.id,
      secondSourceEdgeId: secondSourceEdge.id,
      resultEdgeId: resultEdgeId,
      firstLengthMm: _edgeLength(firstSourceEdge).round(),
      secondLengthMm: _edgeLength(secondSourceEdge).round(),
      profiles: {
        if (first != null) firstSourceEdge.id: first,
        if (second != null) secondSourceEdge.id: second,
      },
    );
    final next = Map<BoundaryEdgeHostRef, WallProfile>.from(profiles)
      ..remove(firstHost)
      ..remove(secondHost);
    final result = migrated[resultEdgeId];
    if (result != null) {
      next[BoundaryEdgeHostRef(spaceId: spaceId, edgeId: resultEdgeId)] =
          result;
    }
    return BoundaryWallProfileRegistry(next);
  }

  bool sameAs(BoundaryWallProfileRegistry other) {
    if (identical(this, other)) return true;
    if (profiles.length != other.profiles.length) return false;
    for (final entry in profiles.entries) {
      final right = other.profiles[entry.key];
      if (right == null || !_sameProfile(entry.value, right)) return false;
    }
    return true;
  }

  static bool _sameProfile(WallProfile left, WallProfile right) {
    if (left.vertices.length != right.vertices.length) return false;
    for (var index = 0; index < left.vertices.length; index++) {
      final a = left.vertices[index];
      final b = right.vertices[index];
      if (a.xMm != b.xMm || a.yMm != b.yMm) return false;
    }
    return true;
  }

  static double _edgeLength(ProjectBoundaryEdge edge) =>
      _distance(edge.start, edge.end);

  static double _distance(BoundaryPointMm a, BoundaryPointMm b) {
    final dx = (b.xMm - a.xMm).toDouble();
    final dy = (b.yMm - a.yMm).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}
