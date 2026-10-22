import 'boundary_topology.dart';

enum BoundaryGeometryIssueCode {
  degenerateArea,
  selfIntersection,
}

final class BoundaryGeometryIssue {
  const BoundaryGeometryIssue({
    required this.code,
    required this.message,
    this.firstEdgeId,
    this.secondEdgeId,
  });

  final BoundaryGeometryIssueCode code;
  final String message;
  final Object? firstEdgeId;
  final Object? secondEdgeId;

  @override
  String toString() => '${code.name}: $message';
}

final class BoundaryGeometryIntegrityException implements Exception {
  BoundaryGeometryIntegrityException(Iterable<BoundaryGeometryIssue> issues)
      : issues = List.unmodifiable(issues);

  final List<BoundaryGeometryIssue> issues;

  @override
  String toString() => 'Invalid boundary geometry:\n${issues.join('\n')}';
}

/// Geometry-level integrity for one canonical exterior space loop.
///
/// [SpaceBoundaryTopology.validate] owns identity/order/closure checks. This
/// validator adds the persistence-critical geometric rules that a closed loop
/// must enclose non-zero area and must be a simple polygon. Integer millimetre
/// arithmetic keeps the result deterministic across every native target.
abstract final class BoundaryGeometryIntegrity {
  static List<BoundaryGeometryIssue> validate(SpaceBoundaryTopology topology) {
    if (topology.validate().isNotEmpty) {
      throw ArgumentError(
        'BoundaryGeometryIntegrity requires a structurally valid topology.',
      );
    }

    final edges = <ProjectBoundaryEdge>[
      for (final edgeId in topology.orderedEdgeIds) topology.edges[edgeId]!,
    ];
    final issues = <BoundaryGeometryIssue>[];

    var twiceSignedArea = 0;
    for (final edge in edges) {
      twiceSignedArea +=
          edge.start.xMm * edge.end.yMm - edge.end.xMm * edge.start.yMm;
    }
    if (twiceSignedArea == 0) {
      issues.add(
        const BoundaryGeometryIssue(
          code: BoundaryGeometryIssueCode.degenerateArea,
          message: 'Boundary exterior loop must enclose non-zero area.',
        ),
      );
    }

    for (var first = 0; first < edges.length; first++) {
      for (var second = first + 1; second < edges.length; second++) {
        if (_areAdjacent(first, second, edges.length)) continue;
        final a = edges[first];
        final b = edges[second];
        if (_segmentsIntersect(a.start, a.end, b.start, b.end)) {
          issues.add(
            BoundaryGeometryIssue(
              code: BoundaryGeometryIssueCode.selfIntersection,
              firstEdgeId: a.id,
              secondEdgeId: b.id,
              message: 'Non-adjacent boundary edges ${a.id} and ${b.id} '
                  'intersect or touch.',
            ),
          );
        }
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow(SpaceBoundaryTopology topology) {
    final issues = validate(topology);
    if (issues.isNotEmpty) {
      throw BoundaryGeometryIntegrityException(issues);
    }
  }

  static bool _areAdjacent(int first, int second, int count) =>
      second == first + 1 || (first == 0 && second == count - 1);

  static bool _segmentsIntersect(
    BoundaryPointMm a,
    BoundaryPointMm b,
    BoundaryPointMm c,
    BoundaryPointMm d,
  ) {
    final abC = _cross(a, b, c);
    final abD = _cross(a, b, d);
    final cdA = _cross(c, d, a);
    final cdB = _cross(c, d, b);

    if (abC == 0 && _onSegment(a, b, c)) return true;
    if (abD == 0 && _onSegment(a, b, d)) return true;
    if (cdA == 0 && _onSegment(c, d, a)) return true;
    if (cdB == 0 && _onSegment(c, d, b)) return true;

    return _oppositeSigns(abC, abD) && _oppositeSigns(cdA, cdB);
  }

  static int _cross(BoundaryPointMm a, BoundaryPointMm b, BoundaryPointMm c) =>
      (b.xMm - a.xMm) * (c.yMm - a.yMm) -
      (b.yMm - a.yMm) * (c.xMm - a.xMm);

  static bool _onSegment(
    BoundaryPointMm a,
    BoundaryPointMm b,
    BoundaryPointMm point,
  ) =>
      point.xMm >= _min(a.xMm, b.xMm) &&
      point.xMm <= _max(a.xMm, b.xMm) &&
      point.yMm >= _min(a.yMm, b.yMm) &&
      point.yMm <= _max(a.yMm, b.yMm);

  static bool _oppositeSigns(int left, int right) =>
      (left < 0 && right > 0) || (left > 0 && right < 0);

  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;
}
