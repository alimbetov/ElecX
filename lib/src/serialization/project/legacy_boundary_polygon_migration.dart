import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/boundary_edge_identity_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_identity.dart';

/// Deterministic one-time migration from one legacy room polygon to canonical
/// P7A boundary topology.
///
/// The migration never uses wallIndex as durable identity. The old polygon
/// order is only an input to deterministic ID allocation during the one-time
/// conversion. Once created, BoundaryEdgeId is persisted and reused verbatim.
/// Generated ids are opaque SHA-256 digests so their textual representation
/// does not encode project, space or geometry semantics.
abstract final class LegacyBoundaryPolygonMigration {
  static LegacyBoundaryMigrationResult migrate({
    required ProjectId projectId,
    required SpaceId spaceId,
    required Iterable<BoundaryPointMm> polygon,
  }) {
    final points = _normalizePolygon(polygon);
    final polygonSeed =
        points.map((point) => '${point.xMm},${point.yMm}').join(';');

    final edgeIds = <BoundaryEdgeId>[];
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      final end = points[(index + 1) % points.length];
      final edgeId = BoundaryEdgeId(
        _deterministicId(
          projectId: projectId,
          spaceId: spaceId,
          polygonSeed: polygonSeed,
          edgeOrdinal: index,
        ),
      );
      edgeIds.add(edgeId);
      edges[edgeId] = ProjectBoundaryEdge(
        id: edgeId,
        spaceId: spaceId,
        start: start,
        end: end,
      );
    }

    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: edges,
    );
    topology.validateOrThrow();

    final registry = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(<SpaceId, SpaceBoundaryTopology>{
      spaceId: topology,
    });

    return LegacyBoundaryMigrationResult(
      topology: topology,
      identityRegistry: registry,
    );
  }

  static List<BoundaryPointMm> _normalizePolygon(
    Iterable<BoundaryPointMm> polygon,
  ) {
    final points = polygon.toList(growable: true);
    if (points.length >= 2 && points.first == points.last) {
      points.removeLast();
    }
    if (points.length < 3) {
      throw ArgumentError.value(
        points.length,
        'polygon',
        'Legacy polygon requires at least three vertices.',
      );
    }
    for (var index = 0; index < points.length; index++) {
      final next = points[(index + 1) % points.length];
      if (points[index] == next) {
        throw ArgumentError(
          'Legacy polygon contains a zero-length edge at vertex $index.',
        );
      }
    }
    if (points.toSet().length < 3) {
      throw ArgumentError('Legacy polygon requires three distinct vertices.');
    }
    return List<BoundaryPointMm>.unmodifiable(points);
  }

  static String _deterministicId({
    required ProjectId projectId,
    required SpaceId spaceId,
    required String polygonSeed,
    required int edgeOrdinal,
  }) {
    final seed = [
      'elecx-p7a-legacy-boundary-v1',
      projectId.value,
      spaceId.value,
      polygonSeed,
      edgeOrdinal.toString(),
    ].join('|');
    final digest = sha256.convert(utf8.encode(seed));
    return 'be_${digest.toString()}';
  }
}

final class LegacyBoundaryMigrationResult {
  const LegacyBoundaryMigrationResult({
    required this.topology,
    required this.identityRegistry,
  });

  final SpaceBoundaryTopology topology;
  final BoundaryEdgeIdentityRegistry identityRegistry;
}
