import 'dart:math' as math;

import 'boundary_host_migration.dart';
import 'boundary_topology.dart';
import 'project_identity.dart';

enum BoundaryHostedRegistryIssueCode {
  missingSpaceTopology,
  missingBoundaryEdge,
  boundaryOwnerMismatch,
  geometryOutsideEdge,
  wallProfileMustUseDedicatedRegistry,
}

final class BoundaryHostedRegistryException implements Exception {
  const BoundaryHostedRegistryException({
    required this.code,
    required this.reference,
    required this.message,
  });

  final BoundaryHostedRegistryIssueCode code;
  final BoundaryHostedReference reference;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Canonical project-level ownership of engineering objects hosted by walls.
///
/// Object payloads may still live in discipline-specific models during the
/// migration, but durable wall ownership lives here exactly once. Legacy
/// wallIndex values are projections and are never accepted by this registry.
///
/// Wall-profile payloads are intentionally excluded. They are owned by
/// BoundaryWallProfileRegistry because split/merge transforms the profile
/// geometry itself rather than remapping one generic hosted reference.
final class BoundaryHostedObjectRegistry {
  BoundaryHostedObjectRegistry(Map<String, BoundaryHostedReference> references)
      : references = Map.unmodifiable(references),
        _legacyRouteAnchorAliases = Map.unmodifiable(
          _buildLegacyRouteAnchorAliases(references),
        ) {
    for (final entry in this.references.entries) {
      if (entry.key.trim().isEmpty) {
        throw ArgumentError('Hosted object registry key must be non-empty.');
      }
      if (entry.key != entry.value.objectKey) {
        throw ArgumentError(
          'Hosted object registry key ${entry.key} does not match '
          'reference key ${entry.value.objectKey}.',
        );
      }
    }
  }

  const BoundaryHostedObjectRegistry.empty()
      : references = const {},
        _legacyRouteAnchorAliases = const {};

  final Map<String, BoundaryHostedReference> references;
  final Map<String, BoundaryHostedReference?> _legacyRouteAnchorAliases;

  static String openingObjectKey(OpeningId openingId, SpaceId spaceId) =>
      'opening:${openingId.value}:${spaceId.value}';

  static String componentObjectKey(String componentId) =>
      'component:$componentId';

  static String cableSourceObjectKey(String routeId) => 'cable:$routeId:source';

  static String cableTargetObjectKey(String routeId) => 'cable:$routeId:target';

  /// Collision-free canonical key for a durable route anchor.
  ///
  /// Entity identifiers are opaque and may legally contain every historical
  /// separator (including `:anchor:`). Length prefixes define framing; callers
  /// must never parse semantic identity back out of this registry key.
  static String routeAnchorObjectKey(String routeId, RouteAnchorId anchorId) =>
      'route-anchor:${routeId.length}:$routeId:'
      '${anchorId.value.length}:${anchorId.value}';

  BoundaryHostedReference? operator [](String objectKey) {
    final exact = references[objectKey];
    if (exact != null) return exact;

    // P7A-6.2 compatibility boundary. Historical route-anchor keys used
    // `route:<routeId>:anchor:<anchorId>`, which cannot be parsed safely because
    // both identifiers are opaque. Canonical keys are decoded once when the
    // immutable registry is built, keeping compatibility lookup O(1).
    if (!objectKey.startsWith('route:') ||
        !_legacyRouteAnchorAliases.containsKey(objectKey)) {
      return null;
    }
    final legacy = _legacyRouteAnchorAliases[objectKey];
    if (legacy == null) {
      throw StateError(
        'Legacy route-anchor key $objectKey resolves to multiple canonical '
        'hosted references.',
      );
    }
    return legacy;
  }

  BoundaryHostedReference? openingHost(OpeningId openingId, SpaceId spaceId) =>
      references[openingObjectKey(openingId, spaceId)];

  Iterable<BoundaryHostedReference> forSpace(SpaceId spaceId) =>
      references.values.where((reference) => reference.host.spaceId == spaceId);

  BoundaryHostedObjectRegistry put(BoundaryHostedReference reference) =>
      BoundaryHostedObjectRegistry({
        ...references,
        reference.objectKey: reference,
      });

  BoundaryHostedObjectRegistry putOpening({
    required OpeningId openingId,
    required BoundaryEdgeHostRef host,
    required int startOffsetMm,
    required int endOffsetMm,
  }) {
    final objectKey = openingObjectKey(openingId, host.spaceId);
    final existing = references[objectKey];
    if (existing != null && existing.host.spaceId != host.spaceId) {
      throw StateError(
        'Canonical opening key $objectKey is ambiguous across Spaces '
        '${existing.host.spaceId} and ${host.spaceId}.',
      );
    }
    return put(
      BoundaryHostedReference.interval(
        objectKey: objectKey,
        objectKind: BoundaryHostedObjectKind.opening,
        host: host,
        startOffsetMm: startOffsetMm,
        endOffsetMm: endOffsetMm,
      ),
    );
  }

  BoundaryHostedObjectRegistry remove(String objectKey) {
    if (!references.containsKey(objectKey)) return this;
    final next = Map<String, BoundaryHostedReference>.from(references)
      ..remove(objectKey);
    return BoundaryHostedObjectRegistry(next);
  }

  /// Validates that every canonical host points to an active edge owned by the
  /// declared Space and that its local geometry fits the active edge length.
  void validateAgainst(Map<SpaceId, SpaceBoundaryTopology> boundaries) {
    for (final reference in references.values) {
      if (reference.objectKind == BoundaryHostedObjectKind.wallProfile) {
        throw BoundaryHostedRegistryException(
          code: BoundaryHostedRegistryIssueCode
              .wallProfileMustUseDedicatedRegistry,
          reference: reference,
          message: 'Wall profile ${reference.objectKey} must be owned by '
              'BoundaryWallProfileRegistry, not the generic hosted-object '
              'registry.',
        );
      }
      final topology = boundaries[reference.host.spaceId];
      if (topology == null) {
        throw BoundaryHostedRegistryException(
          code: BoundaryHostedRegistryIssueCode.missingSpaceTopology,
          reference: reference,
          message: 'Hosted object ${reference.objectKey} references Space '
              '${reference.host.spaceId} without active boundary topology.',
        );
      }
      final edge = topology.edges[reference.host.edgeId];
      if (edge == null) {
        throw BoundaryHostedRegistryException(
          code: BoundaryHostedRegistryIssueCode.missingBoundaryEdge,
          reference: reference,
          message: 'Hosted object ${reference.objectKey} references inactive '
              'boundary edge ${reference.host.edgeId}.',
        );
      }
      if (edge.spaceId != reference.host.spaceId) {
        throw BoundaryHostedRegistryException(
          code: BoundaryHostedRegistryIssueCode.boundaryOwnerMismatch,
          reference: reference,
          message: 'Hosted object ${reference.objectKey} references edge '
              '${edge.id} owned by ${edge.spaceId}.',
        );
      }
      final length = _edgeLength(edge);
      final start = reference.startOffsetMm;
      final end = reference.endOffsetMm;
      if ((start != null && start > length + 0.5) ||
          (end != null && end > length + 0.5)) {
        throw BoundaryHostedRegistryException(
          code: BoundaryHostedRegistryIssueCode.geometryOutsideEdge,
          reference: reference,
          message: 'Hosted object ${reference.objectKey} exceeds active edge '
              '${edge.id} length ${length.toStringAsFixed(1)}mm.',
        );
      }
    }
  }

  /// Remaps every hosted reference owned by [before.spaceId] as one fail-closed
  /// operation. No registry instance is returned unless every host succeeds.
  BoundaryHostedObjectRegistry remapSpace({
    required SpaceBoundaryTopology before,
    required SpaceBoundaryTopology after,
    required BoundaryTopologyChangeSet lineage,
  }) {
    final source = forSpace(before.spaceId).toList(growable: false);
    if (source.isEmpty) return this;
    final remapped = BoundaryHostedObjectRemapper.remapAll(
      before: before,
      after: after,
      lineage: lineage,
      references: source,
    );
    final next = Map<String, BoundaryHostedReference>.from(references);
    for (final result in remapped) {
      next[result.source.objectKey] = _rebuild(result);
    }
    return BoundaryHostedObjectRegistry(next);
  }

  bool sameAs(BoundaryHostedObjectRegistry other) {
    if (identical(this, other)) return true;
    if (references.length != other.references.length) return false;
    for (final entry in references.entries) {
      final right = other.references[entry.key];
      if (right == null || !_sameReference(entry.value, right)) return false;
    }
    return true;
  }

  static Map<String, BoundaryHostedReference?> _buildLegacyRouteAnchorAliases(
    Map<String, BoundaryHostedReference> references,
  ) {
    final aliases = <String, BoundaryHostedReference?>{};
    for (final reference in references.values) {
      if (reference.objectKind != BoundaryHostedObjectKind.routeAnchor) {
        continue;
      }
      final identity = _decodeRouteAnchorObjectKey(reference.objectKey);
      if (identity == null) continue;
      final alias = 'route:${identity.routeId}:anchor:${identity.anchorId}';
      if (aliases.containsKey(alias)) {
        final existing = aliases[alias];
        if (existing == null || existing.objectKey != reference.objectKey) {
          aliases[alias] = null;
        }
      } else {
        aliases[alias] = reference;
      }
    }
    return aliases;
  }

  static ({String routeId, String anchorId})? _decodeRouteAnchorObjectKey(
    String key,
  ) {
    const prefix = 'route-anchor:';
    if (!key.startsWith(prefix)) return null;
    var cursor = prefix.length;

    final routeLengthEnd = key.indexOf(':', cursor);
    if (routeLengthEnd < 0) return null;
    final routeLength = int.tryParse(key.substring(cursor, routeLengthEnd));
    if (routeLength == null || routeLength < 0) return null;
    final routeStart = routeLengthEnd + 1;
    final routeEnd = routeStart + routeLength;
    if (routeEnd >= key.length || key[routeEnd] != ':') return null;
    final routeId = key.substring(routeStart, routeEnd);

    cursor = routeEnd + 1;
    final anchorLengthEnd = key.indexOf(':', cursor);
    if (anchorLengthEnd < 0) return null;
    final anchorLength = int.tryParse(key.substring(cursor, anchorLengthEnd));
    if (anchorLength == null || anchorLength < 0) return null;
    final anchorStart = anchorLengthEnd + 1;
    final anchorEnd = anchorStart + anchorLength;
    if (anchorEnd != key.length) return null;
    final anchorId = key.substring(anchorStart, anchorEnd);
    return (routeId: routeId, anchorId: anchorId);
  }

  static BoundaryHostedReference _rebuild(BoundaryHostedRemap result) =>
      switch (result.source.geometryKind) {
        BoundaryHostGeometryKind.point => BoundaryHostedReference.point(
            objectKey: result.source.objectKey,
            objectKind: result.source.objectKind,
            host: result.host,
            offsetMm: result.startOffsetMm!,
          ),
        BoundaryHostGeometryKind.interval => BoundaryHostedReference.interval(
            objectKey: result.source.objectKey,
            objectKind: result.source.objectKind,
            host: result.host,
            startOffsetMm: result.startOffsetMm!,
            endOffsetMm: result.endOffsetMm!,
          ),
        BoundaryHostGeometryKind.wholeEdge => BoundaryHostedReference.wholeEdge(
            objectKey: result.source.objectKey,
            objectKind: result.source.objectKind,
            host: result.host,
          ),
      };

  static bool _sameReference(
    BoundaryHostedReference left,
    BoundaryHostedReference right,
  ) =>
      left.objectKey == right.objectKey &&
      left.objectKind == right.objectKind &&
      left.host == right.host &&
      left.geometryKind == right.geometryKind &&
      left.startOffsetMm == right.startOffsetMm &&
      left.endOffsetMm == right.endOffsetMm;

  static double _edgeLength(ProjectBoundaryEdge edge) {
    final dx = (edge.end.xMm - edge.start.xMm).toDouble();
    final dy = (edge.end.yMm - edge.start.yMm).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}
