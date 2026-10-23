import 'dart:convert';

import '../../domain/boundary_edge_identity_registry.dart';
import '../../domain/boundary_geometry_integrity.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_identity.dart';

/// Deterministic one-time migration from one legacy room polygon to canonical
/// P7A boundary topology.
///
/// The migration never uses wallIndex as durable identity. The old polygon
/// order is only an input to deterministic ID allocation during the one-time
/// conversion. Once created, BoundaryEdgeId is persisted and reused verbatim.
/// Generated ids are fixed-width opaque digests so their textual representation
/// does not encode project, space or geometry semantics.
abstract final class LegacyBoundaryPolygonMigration {
  static LegacyBoundaryMigrationResult migrate({
    required ProjectId projectId,
    required SpaceId spaceId,
    required Iterable<BoundaryPointMm> polygon,
  }) {
    final points = _normalizePolygon(polygon);

    final edgeIds = <BoundaryEdgeId>[];
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      final end = points[(index + 1) % points.length];
      final edgeId = BoundaryEdgeId(
        _deterministicId(
          projectId: projectId,
          spaceId: spaceId,
          points: points,
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
    BoundaryGeometryIntegrity.validateOrThrow(topology);

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
    required List<BoundaryPointMm> points,
    required int edgeOrdinal,
  }) {
    final components = <String>[
      'elecx-p7a-legacy-boundary-v2',
      projectId.value,
      spaceId.value,
      points.length.toString(),
      for (final point in points) ...[
        point.xMm.toString(),
        point.yMm.toString(),
      ],
      edgeOrdinal.toString(),
    ];
    final canonicalSeed = components.map(_lengthPrefixed).join();
    final bytes = utf8.encode(canonicalSeed);
    final digest = <int>[
      0x243f6a88,
      0x85a308d3,
      0x13198a2e,
      0x03707344,
    ].map((salt) => _fnv1a64Hex(bytes, salt)).join();
    return 'be_$digest';
  }

  static String _lengthPrefixed(String value) =>
      '${utf8.encode(value).length}:$value';

  static String _fnv1a64Hex(List<int> bytes, int salt) {
    final mask = (BigInt.one << 64) - BigInt.one;
    final prime = BigInt.from(0x100000001b3);
    var hash = BigInt.parse('cbf29ce484222325', radix: 16) ^ BigInt.from(salt);
    for (final byte in bytes) {
      hash ^= BigInt.from(byte);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
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
