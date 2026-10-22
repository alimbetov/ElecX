import 'dart:math' as math;

import 'boundary_topology.dart';
import 'project_identity.dart';

/// Durable host identity for any engineering object attached to a room wall.
///
/// The pair is intentionally independent from wall order. [edgeId] is the
/// engineering identity; a wall ordinal may only be derived at a legacy/UI
/// boundary.
final class BoundaryEdgeHostRef {
  const BoundaryEdgeHostRef({required this.spaceId, required this.edgeId});

  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;

  @override
  bool operator ==(Object other) =>
      other is BoundaryEdgeHostRef &&
      other.spaceId == spaceId &&
      other.edgeId == edgeId;

  @override
  int get hashCode => Object.hash(spaceId, edgeId);
}

enum BoundaryHostedObjectKind {
  opening,
  wallProfile,
  component,
  cableEndpoint,
  routeAnchor,
}

enum BoundaryHostGeometryKind { point, interval, wholeEdge }

/// Geometry needed to migrate one hosted object through topology lineage.
///
/// Offsets are measured in millimetres from the canonical edge start. Point
/// hosts use [startOffsetMm]. Interval hosts use both offsets. Whole-edge hosts
/// deliberately carry no guessed local geometry.
final class BoundaryHostedReference {
  BoundaryHostedReference.point({
    required this.objectKey,
    required this.objectKind,
    required this.host,
    required int offsetMm,
  })  : geometryKind = BoundaryHostGeometryKind.point,
        startOffsetMm = offsetMm,
        endOffsetMm = null {
    if (offsetMm < 0) {
      throw ArgumentError.value(offsetMm, 'offsetMm');
    }
  }

  BoundaryHostedReference.interval({
    required this.objectKey,
    required this.objectKind,
    required this.host,
    required int startOffsetMm,
    required int endOffsetMm,
  })  : geometryKind = BoundaryHostGeometryKind.interval,
        startOffsetMm = startOffsetMm,
        endOffsetMm = endOffsetMm {
    if (startOffsetMm < 0 || endOffsetMm <= startOffsetMm) {
      throw ArgumentError('Hosted interval must be positive and ordered.');
    }
  }

  BoundaryHostedReference.wholeEdge({
    required this.objectKey,
    required this.objectKind,
    required this.host,
  })  : geometryKind = BoundaryHostGeometryKind.wholeEdge,
        startOffsetMm = null,
        endOffsetMm = null;

  final String objectKey;
  final BoundaryHostedObjectKind objectKind;
  final BoundaryEdgeHostRef host;
  final BoundaryHostGeometryKind geometryKind;
  final int? startOffsetMm;
  final int? endOffsetMm;
}

final class BoundaryHostedRemap {
  const BoundaryHostedRemap({
    required this.source,
    required this.host,
    this.startOffsetMm,
    this.endOffsetMm,
  });

  final BoundaryHostedReference source;
  final BoundaryEdgeHostRef host;
  final int? startOffsetMm;
  final int? endOffsetMm;
}

enum BoundaryHostMigrationIssueCode {
  sourceEdgeMissing,
  sourceOwnerMismatch,
  sourceOffsetOutsideEdge,
  resultEdgeMissing,
  resultOwnerMismatch,
  removedHost,
  ambiguousPointRemap,
  intervalCrossesResultEdges,
  wholeEdgeRequiresDomainTransform,
}

final class BoundaryHostMigrationException implements Exception {
  const BoundaryHostMigrationException({
    required this.code,
    required this.reference,
    required this.message,
  });

  final BoundaryHostMigrationIssueCode code;
  final BoundaryHostedReference reference;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// P7A-5 fail-closed geometry-aware host remapper.
///
/// [remapAll] is atomic from the caller's perspective: every reference is
/// resolved into a new immutable list or the method throws before exposing any
/// partial result.
abstract final class BoundaryHostedObjectRemapper {
  static List<BoundaryHostedRemap> remapAll({
    required SpaceBoundaryTopology before,
    required SpaceBoundaryTopology after,
    required BoundaryTopologyChangeSet lineage,
    required Iterable<BoundaryHostedReference> references,
  }) {
    before.validateOrThrow();
    after.validateOrThrow();
    if (before.spaceId != after.spaceId) {
      throw ArgumentError('Boundary host migration cannot change Space owner.');
    }

    final result = <BoundaryHostedRemap>[];
    for (final reference in references) {
      result.add(
        _remapOne(
          before: before,
          after: after,
          lineage: lineage,
          reference: reference,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static BoundaryHostedRemap _remapOne({
    required SpaceBoundaryTopology before,
    required SpaceBoundaryTopology after,
    required BoundaryTopologyChangeSet lineage,
    required BoundaryHostedReference reference,
  }) {
    if (reference.host.spaceId != before.spaceId) {
      throw BoundaryHostMigrationException(
        code: BoundaryHostMigrationIssueCode.sourceOwnerMismatch,
        reference: reference,
        message: 'Hosted object ${reference.objectKey} belongs to '
            '${reference.host.spaceId}, expected ${before.spaceId}.',
      );
    }
    final source = before.edges[reference.host.edgeId];
    if (source == null) {
      throw BoundaryHostMigrationException(
        code: BoundaryHostMigrationIssueCode.sourceEdgeMissing,
        reference: reference,
        message: 'Source edge ${reference.host.edgeId} is not active.',
      );
    }

    final decision = lineage.hostRemapFor(source.id);
    if (decision.kind == BoundaryHostRemapKind.removed) {
      throw BoundaryHostMigrationException(
        code: BoundaryHostMigrationIssueCode.removedHost,
        reference: reference,
        message: 'Hosted object ${reference.objectKey} cannot survive removal '
            'of ${source.id} without an explicit domain removal policy.',
      );
    }

    if (reference.geometryKind == BoundaryHostGeometryKind.wholeEdge) {
      if (decision.kind != BoundaryHostRemapKind.preserved) {
        throw BoundaryHostMigrationException(
          code: BoundaryHostMigrationIssueCode.wholeEdgeRequiresDomainTransform,
          reference: reference,
          message: '${reference.objectKind.name} ${reference.objectKey} covers '
              'the whole source edge and requires a domain-specific transform.',
        );
      }
      return BoundaryHostedRemap(
        source: reference,
        host: BoundaryEdgeHostRef(
          spaceId: after.spaceId,
          edgeId: decision.candidateEdgeIds.single,
        ),
      );
    }

    final startOffset = reference.startOffsetMm!;
    _requireOffsetOnSource(source, startOffset, reference);
    final startPoint = _pointAtOffset(source, startOffset);
    final startMatches = _candidateMatches(
      after: after,
      candidateIds: decision.candidateEdgeIds,
      point: startPoint,
      reference: reference,
    );

    if (reference.geometryKind == BoundaryHostGeometryKind.point) {
      if (startMatches.length != 1) {
        throw BoundaryHostMigrationException(
          code: BoundaryHostMigrationIssueCode.ambiguousPointRemap,
          reference: reference,
          message: 'Point host ${reference.objectKey} resolves to '
              '${startMatches.length} candidate edges.',
        );
      }
      final match = startMatches.single;
      return BoundaryHostedRemap(
        source: reference,
        host:
            BoundaryEdgeHostRef(spaceId: after.spaceId, edgeId: match.edge.id),
        startOffsetMm: match.offsetMm,
      );
    }

    final endOffset = reference.endOffsetMm!;
    _requireOffsetOnSource(source, endOffset, reference);
    final endPoint = _pointAtOffset(source, endOffset);
    final endMatches = _candidateMatches(
      after: after,
      candidateIds: decision.candidateEdgeIds,
      point: endPoint,
      reference: reference,
    );
    final commonIds = startMatches.map((match) => match.edge.id).toSet()
      ..retainAll(endMatches.map((match) => match.edge.id));
    if (commonIds.length != 1) {
      throw BoundaryHostMigrationException(
        code: BoundaryHostMigrationIssueCode.intervalCrossesResultEdges,
        reference: reference,
        message: 'Hosted interval ${reference.objectKey} is not contained by '
            'exactly one result edge.',
      );
    }
    final resultId = commonIds.single;
    final mappedStart =
        startMatches.singleWhere((match) => match.edge.id == resultId);
    final mappedEnd =
        endMatches.singleWhere((match) => match.edge.id == resultId);
    final low = math.min(mappedStart.offsetMm, mappedEnd.offsetMm);
    final high = math.max(mappedStart.offsetMm, mappedEnd.offsetMm);
    return BoundaryHostedRemap(
      source: reference,
      host: BoundaryEdgeHostRef(spaceId: after.spaceId, edgeId: resultId),
      startOffsetMm: low,
      endOffsetMm: high,
    );
  }

  static void _requireOffsetOnSource(
    ProjectBoundaryEdge edge,
    int offsetMm,
    BoundaryHostedReference reference,
  ) {
    final length = _edgeLength(edge);
    if (offsetMm > length + 0.5) {
      throw BoundaryHostMigrationException(
        code: BoundaryHostMigrationIssueCode.sourceOffsetOutsideEdge,
        reference: reference,
        message: 'Offset ${offsetMm}mm exceeds source edge ${edge.id} length '
            '${length.toStringAsFixed(1)}mm.',
      );
    }
  }

  static _BoundaryPointDouble _pointAtOffset(
    ProjectBoundaryEdge edge,
    int offsetMm,
  ) {
    final length = _edgeLength(edge);
    final roundedLength = length.round();
    final t = offsetMm == roundedLength
        ? 1.0
        : (length == 0 ? 0.0 : offsetMm / length)
            .clamp(0.0, 1.0)
            .toDouble();
    return _BoundaryPointDouble(
      x: edge.start.xMm + (edge.end.xMm - edge.start.xMm) * t,
      y: edge.start.yMm + (edge.end.yMm - edge.start.yMm) * t,
    );
  }

  static List<_EdgePointMatch> _candidateMatches({
    required SpaceBoundaryTopology after,
    required Iterable<BoundaryEdgeId> candidateIds,
    required _BoundaryPointDouble point,
    required BoundaryHostedReference reference,
  }) {
    final matches = <_EdgePointMatch>[];
    for (final id in candidateIds) {
      final edge = after.edges[id];
      if (edge == null) {
        throw BoundaryHostMigrationException(
          code: BoundaryHostMigrationIssueCode.resultEdgeMissing,
          reference: reference,
          message: 'Lineage result edge $id is missing from result topology.',
        );
      }
      if (edge.spaceId != after.spaceId) {
        throw BoundaryHostMigrationException(
          code: BoundaryHostMigrationIssueCode.resultOwnerMismatch,
          reference: reference,
          message: 'Lineage result edge $id has a different Space owner.',
        );
      }
      final match = _projectPoint(edge, point);
      if (match != null) matches.add(match);
    }
    return matches;
  }

  static _EdgePointMatch? _projectPoint(
    ProjectBoundaryEdge edge,
    _BoundaryPointDouble point,
  ) {
    final dx = (edge.end.xMm - edge.start.xMm).toDouble();
    final dy = (edge.end.yMm - edge.start.yMm).toDouble();
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return null;
    final px = point.x - edge.start.xMm;
    final py = point.y - edge.start.yMm;
    final t = (px * dx + py * dy) / lengthSquared;
    const epsilon = 1e-9;
    if (t < -epsilon || t > 1 + epsilon) return null;
    final clamped = t.clamp(0.0, 1.0);
    final projectedX = edge.start.xMm + dx * clamped;
    final projectedY = edge.start.yMm + dy * clamped;
    final distance = math.sqrt(
      math.pow(point.x - projectedX, 2) + math.pow(point.y - projectedY, 2),
    );
    if (distance > epsilon) return null;
    return _EdgePointMatch(
      edge: edge,
      offsetMm: (_edgeLength(edge) * clamped).round(),
    );
  }

  static double _edgeLength(ProjectBoundaryEdge edge) {
    final dx = (edge.end.xMm - edge.start.xMm).toDouble();
    final dy = (edge.end.yMm - edge.start.yMm).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}

final class _BoundaryPointDouble {
  const _BoundaryPointDouble({required this.x, required this.y});

  final double x;
  final double y;
}

final class _EdgePointMatch {
  const _EdgePointMatch({required this.edge, required this.offsetMm});

  final ProjectBoundaryEdge edge;
  final int offsetMm;
}
