import 'project_identity.dart';

/// Platform-independent point used by canonical P7A boundary topology.
///
/// Coordinates are stored in millimetres and intentionally do not depend on
/// Flutter `Offset`, pointer input, screen pixels or platform presentation.
final class BoundaryPointMm {
  const BoundaryPointMm({required this.xMm, required this.yMm});

  final int xMm;
  final int yMm;

  @override
  bool operator ==(Object other) =>
      other is BoundaryPointMm && other.xMm == xMm && other.yMm == yMm;

  @override
  int get hashCode => Object.hash(xMm, yMm);

  @override
  String toString() => '($xMm,$yMm)mm';
}

/// One canonical logical boundary edge owned by exactly one [SpaceId].
///
/// [BoundaryEdgeId] is the durable engineering identity. Array/list position
/// is only a projection detail and must never be persisted as wall identity.
final class ProjectBoundaryEdge {
  ProjectBoundaryEdge({
    required this.id,
    required this.spaceId,
    required this.start,
    required this.end,
  }) {
    if (start == end) {
      throw ArgumentError.value(
        end,
        'end',
        'Boundary edge must have non-zero length.',
      );
    }
  }

  final BoundaryEdgeId id;
  final SpaceId spaceId;
  final BoundaryPointMm start;
  final BoundaryPointMm end;
}

enum BoundaryTopologyIssueCode {
  storeKeyIdMismatch,
  missingEdge,
  edgeSpaceMismatch,
  duplicateEdgeReference,
  unclaimedEdge,
  discontinuousLoop,
  openLoop,
}

final class BoundaryTopologyIssue {
  const BoundaryTopologyIssue({
    required this.code,
    required this.message,
    this.edgeId,
  });

  final BoundaryTopologyIssueCode code;
  final BoundaryEdgeId? edgeId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

final class BoundaryTopologyValidationException implements Exception {
  BoundaryTopologyValidationException(Iterable<BoundaryTopologyIssue> issues)
      : issues = List.unmodifiable(issues);

  final List<BoundaryTopologyIssue> issues;

  @override
  String toString() => 'Invalid boundary topology:\n${issues.join('\n')}';
}

/// Canonical ordered exterior boundary for one project space.
///
/// P7A v1 intentionally models one exterior loop per space. Stable edge
/// identity and lineage are established first; interior void/hole loops can be
/// added later without changing [BoundaryEdgeId] semantics.
final class SpaceBoundaryTopology {
  SpaceBoundaryTopology({
    required this.spaceId,
    required Iterable<BoundaryEdgeId> orderedEdgeIds,
    required Map<BoundaryEdgeId, ProjectBoundaryEdge> edges,
  })  : orderedEdgeIds = List.unmodifiable(orderedEdgeIds),
        edges = Map.unmodifiable(edges) {
    if (this.orderedEdgeIds.length < 3) {
      throw ArgumentError.value(
        this.orderedEdgeIds.length,
        'orderedEdgeIds',
        'A closed space boundary requires at least three edges.',
      );
    }
  }

  final SpaceId spaceId;
  final List<BoundaryEdgeId> orderedEdgeIds;
  final Map<BoundaryEdgeId, ProjectBoundaryEdge> edges;

  List<BoundaryTopologyIssue> validate() {
    final issues = <BoundaryTopologyIssue>[];

    for (final entry in edges.entries) {
      if (entry.key != entry.value.id) {
        issues.add(
          BoundaryTopologyIssue(
            code: BoundaryTopologyIssueCode.storeKeyIdMismatch,
            edgeId: entry.value.id,
            message: 'Edge store key ${entry.key} does not match '
                'entity id ${entry.value.id}.',
          ),
        );
      }
      if (entry.value.spaceId != spaceId) {
        issues.add(
          BoundaryTopologyIssue(
            code: BoundaryTopologyIssueCode.edgeSpaceMismatch,
            edgeId: entry.value.id,
            message: 'Edge ${entry.value.id} belongs to space '
                '${entry.value.spaceId}, not $spaceId.',
          ),
        );
      }
    }

    final claimed = <BoundaryEdgeId>{};
    final resolved = <ProjectBoundaryEdge>[];

    for (final edgeId in orderedEdgeIds) {
      if (!claimed.add(edgeId)) {
        issues.add(
          BoundaryTopologyIssue(
            code: BoundaryTopologyIssueCode.duplicateEdgeReference,
            edgeId: edgeId,
            message: 'Boundary edge $edgeId is referenced more than once.',
          ),
        );
      }

      final edge = edges[edgeId];
      if (edge == null) {
        issues.add(
          BoundaryTopologyIssue(
            code: BoundaryTopologyIssueCode.missingEdge,
            edgeId: edgeId,
            message: 'Boundary references missing edge $edgeId.',
          ),
        );
        continue;
      }
      resolved.add(edge);
    }

    for (final edgeId in edges.keys) {
      if (!claimed.contains(edgeId)) {
        issues.add(
          BoundaryTopologyIssue(
            code: BoundaryTopologyIssueCode.unclaimedEdge,
            edgeId: edgeId,
            message: 'Edge $edgeId exists in the space store but is not '
                'part of the ordered exterior boundary.',
          ),
        );
      }
    }

    if (resolved.length == orderedEdgeIds.length && resolved.isNotEmpty) {
      for (var index = 0; index < resolved.length - 1; index++) {
        final current = resolved[index];
        final next = resolved[index + 1];
        if (current.end != next.start) {
          issues.add(
            BoundaryTopologyIssue(
              code: BoundaryTopologyIssueCode.discontinuousLoop,
              edgeId: next.id,
              message: 'Edge ${current.id} ends at ${current.end}, but '
                  '${next.id} starts at ${next.start}.',
            ),
          );
        }
      }

      final last = resolved.last;
      final first = resolved.first;
      if (last.end != first.start) {
        issues.add(
          BoundaryTopologyIssue(
            code: BoundaryTopologyIssueCode.openLoop,
            edgeId: last.id,
            message: 'Boundary does not close: ${last.id} ends at '
                '${last.end}, first edge ${first.id} starts at ${first.start}.',
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }

  void validateOrThrow() {
    final issues = validate();
    if (issues.isNotEmpty) {
      throw BoundaryTopologyValidationException(issues);
    }
  }
}

enum BoundaryEdgeLineageKind { preserved, split, merged, created, removed }

/// Explicit identity outcome for one topology mutation.
///
/// The shape of each lineage record is constrained so downstream host migration
/// never has to infer identity from edge order or geometry array indexes.
final class BoundaryEdgeLineage {
  BoundaryEdgeLineage._({
    required this.kind,
    required Iterable<BoundaryEdgeId> sourceEdgeIds,
    required Iterable<BoundaryEdgeId> resultEdgeIds,
  })  : sourceEdgeIds = List.unmodifiable(sourceEdgeIds),
        resultEdgeIds = List.unmodifiable(resultEdgeIds) {
    _validateShape();
  }

  factory BoundaryEdgeLineage.preserved(BoundaryEdgeId edgeId) =>
      BoundaryEdgeLineage._(
        kind: BoundaryEdgeLineageKind.preserved,
        sourceEdgeIds: [edgeId],
        resultEdgeIds: [edgeId],
      );

  factory BoundaryEdgeLineage.split({
    required BoundaryEdgeId sourceEdgeId,
    required Iterable<BoundaryEdgeId> resultEdgeIds,
  }) =>
      BoundaryEdgeLineage._(
        kind: BoundaryEdgeLineageKind.split,
        sourceEdgeIds: [sourceEdgeId],
        resultEdgeIds: resultEdgeIds,
      );

  factory BoundaryEdgeLineage.merged({
    required Iterable<BoundaryEdgeId> sourceEdgeIds,
    required BoundaryEdgeId resultEdgeId,
  }) =>
      BoundaryEdgeLineage._(
        kind: BoundaryEdgeLineageKind.merged,
        sourceEdgeIds: sourceEdgeIds,
        resultEdgeIds: [resultEdgeId],
      );

  factory BoundaryEdgeLineage.created(
    Iterable<BoundaryEdgeId> resultEdgeIds,
  ) =>
      BoundaryEdgeLineage._(
        kind: BoundaryEdgeLineageKind.created,
        sourceEdgeIds: const [],
        resultEdgeIds: resultEdgeIds,
      );

  factory BoundaryEdgeLineage.removed(
    Iterable<BoundaryEdgeId> sourceEdgeIds,
  ) =>
      BoundaryEdgeLineage._(
        kind: BoundaryEdgeLineageKind.removed,
        sourceEdgeIds: sourceEdgeIds,
        resultEdgeIds: const [],
      );

  final BoundaryEdgeLineageKind kind;
  final List<BoundaryEdgeId> sourceEdgeIds;
  final List<BoundaryEdgeId> resultEdgeIds;

  void _validateShape() {
    if (sourceEdgeIds.toSet().length != sourceEdgeIds.length ||
        resultEdgeIds.toSet().length != resultEdgeIds.length) {
      throw ArgumentError(
        'A lineage record cannot contain duplicate edge ids.',
      );
    }

    switch (kind) {
      case BoundaryEdgeLineageKind.preserved:
        if (sourceEdgeIds.length != 1 ||
            resultEdgeIds.length != 1 ||
            sourceEdgeIds.single != resultEdgeIds.single) {
          throw ArgumentError(
            'Preserved lineage requires exactly one unchanged edge identity.',
          );
        }
      case BoundaryEdgeLineageKind.split:
        if (sourceEdgeIds.length != 1 || resultEdgeIds.length < 2) {
          throw ArgumentError(
            'Split lineage requires one source and at least two result edges.',
          );
        }
      case BoundaryEdgeLineageKind.merged:
        if (sourceEdgeIds.length < 2 || resultEdgeIds.length != 1) {
          throw ArgumentError(
            'Merged lineage requires at least two sources and one result edge.',
          );
        }
      case BoundaryEdgeLineageKind.created:
        if (sourceEdgeIds.isNotEmpty || resultEdgeIds.isEmpty) {
          throw ArgumentError(
            'Created lineage requires no sources and at least one result edge.',
          );
        }
      case BoundaryEdgeLineageKind.removed:
        if (sourceEdgeIds.isEmpty || resultEdgeIds.isNotEmpty) {
          throw ArgumentError(
            'Removed lineage requires at least one source and no result edges.',
          );
        }
    }
  }
}

enum BoundaryHostRemapKind {
  preserved,
  requiresGeometricRemap,
  removed,
}

/// Fail-closed decision for objects hosted on a pre-mutation boundary edge.
///
/// Split/merge operations never silently choose a replacement edge. The caller
/// must use geometry-aware host migration to select/validate the candidate.
final class BoundaryHostRemapDecision {
  const BoundaryHostRemapDecision({
    required this.kind,
    required this.sourceEdgeId,
    required this.candidateEdgeIds,
  });

  final BoundaryHostRemapKind kind;
  final BoundaryEdgeId sourceEdgeId;
  final List<BoundaryEdgeId> candidateEdgeIds;
}

/// Complete identity lineage emitted by one atomic boundary topology mutation.
final class BoundaryTopologyChangeSet {
  BoundaryTopologyChangeSet(Iterable<BoundaryEdgeLineage> lineage)
      : lineage = List.unmodifiable(lineage) {
    _validateUniqueness();
  }

  final List<BoundaryEdgeLineage> lineage;

  void _validateUniqueness() {
    final seenSources = <BoundaryEdgeId>{};
    final seenResults = <BoundaryEdgeId>{};

    for (final record in lineage) {
      for (final edgeId in record.sourceEdgeIds) {
        if (!seenSources.add(edgeId)) {
          throw ArgumentError(
            'Source boundary edge $edgeId appears in multiple lineage records.',
          );
        }
      }
      for (final edgeId in record.resultEdgeIds) {
        if (!seenResults.add(edgeId)) {
          throw ArgumentError(
            'Result boundary edge $edgeId appears in multiple lineage records.',
          );
        }
      }
    }
  }

  BoundaryHostRemapDecision hostRemapFor(BoundaryEdgeId sourceEdgeId) {
    BoundaryEdgeLineage? match;
    for (final record in lineage) {
      if (record.sourceEdgeIds.contains(sourceEdgeId)) {
        match = record;
        break;
      }
    }

    if (match == null) {
      throw StateError(
        'No boundary lineage exists for pre-mutation edge $sourceEdgeId.',
      );
    }

    switch (match.kind) {
      case BoundaryEdgeLineageKind.preserved:
        return BoundaryHostRemapDecision(
          kind: BoundaryHostRemapKind.preserved,
          sourceEdgeId: sourceEdgeId,
          candidateEdgeIds: List.unmodifiable(match.resultEdgeIds),
        );
      case BoundaryEdgeLineageKind.split:
      case BoundaryEdgeLineageKind.merged:
        return BoundaryHostRemapDecision(
          kind: BoundaryHostRemapKind.requiresGeometricRemap,
          sourceEdgeId: sourceEdgeId,
          candidateEdgeIds: List.unmodifiable(match.resultEdgeIds),
        );
      case BoundaryEdgeLineageKind.removed:
        return BoundaryHostRemapDecision(
          kind: BoundaryHostRemapKind.removed,
          sourceEdgeId: sourceEdgeId,
          candidateEdgeIds: const [],
        );
      case BoundaryEdgeLineageKind.created:
        throw StateError(
          'Created lineage cannot own a pre-mutation source edge.',
        );
    }
  }
}
