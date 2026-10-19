import '../domain/surfaces.dart';

enum CableRoutingMode { auto, assisted, manualGuardrails }

enum RouteConstraintSeverity { info, warning, error }

final class RouteConstraintIssue {
  const RouteConstraintIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final RouteConstraintSeverity severity;
}

final class RouteConstraintResult {
  const RouteConstraintResult(this.issues);

  final List<RouteConstraintIssue> issues;

  bool get isValid =>
      !issues.any((issue) => issue.severity == RouteConstraintSeverity.error);

  bool get hasWarnings =>
      issues.any((issue) => issue.severity == RouteConstraintSeverity.warning);
}

final class RouteObstacleMm {
  const RouteObstacleMm({
    required this.id,
    required this.leftMm,
    required this.topMm,
    required this.rightMm,
    required this.bottomMm,
  }) : assert(rightMm >= leftMm),
       assert(bottomMm >= topMm);

  final String id;
  final int leftMm;
  final int topMm;
  final int rightMm;
  final int bottomMm;

  bool contains(SurfacePointMm point) =>
      point.xMm >= leftMm &&
      point.xMm <= rightMm &&
      point.yMm >= topMm &&
      point.yMm <= bottomMm;
}

final class RouteNormativeContext {
  const RouteNormativeContext({
    required this.surface,
    required this.widthMm,
    required this.heightMm,
    this.edgeClearanceMm = 100,
    this.obstacles = const [],
  }) : assert(widthMm > 0),
       assert(heightMm > 0),
       assert(edgeClearanceMm >= 0);

  final RoomSurfaceRef surface;
  final int widthMm;
  final int heightMm;
  final int edgeClearanceMm;
  final List<RouteObstacleMm> obstacles;
}

final class RouteCandidate {
  const RouteCandidate({
    required this.points,
    required this.validation,
    required this.score,
  });

  final List<SurfacePointMm> points;
  final RouteConstraintResult validation;
  final double score;
}

/// First-stage deterministic normative router.
///
/// The engine intentionally separates geometry from the future ELV7 normative
/// registry. It currently enforces orthogonal routing, surface bounds and
/// declared architectural obstacles. ELV7 can contribute additional rule
/// evaluators without changing the editor transaction model.
abstract final class NormativeRouteEngine {
  static List<RouteCandidate> buildCandidates({
    required SurfacePointMm source,
    required SurfacePointMm target,
    required RouteNormativeContext context,
  }) {
    final horizontalFirst = <SurfacePointMm>[
      source,
      SurfacePointMm(target.xMm, source.yMm),
      target,
    ];
    final verticalFirst = <SurfacePointMm>[
      source,
      SurfacePointMm(source.xMm, target.yMm),
      target,
    ];

    final candidates = <RouteCandidate>[
      _candidate(horizontalFirst, context),
      _candidate(verticalFirst, context),
    ];
    candidates.sort((a, b) {
      if (a.validation.isValid != b.validation.isValid) {
        return a.validation.isValid ? -1 : 1;
      }
      return a.score.compareTo(b.score);
    });
    return List.unmodifiable(candidates);
  }

  static RouteConstraintResult validate({
    required List<SurfacePointMm> points,
    required RouteNormativeContext context,
  }) {
    final issues = <RouteConstraintIssue>[];
    if (points.length < 2) {
      issues.add(
        const RouteConstraintIssue(
          code: 'route.too-short',
          message: 'Маршрут должен содержать минимум две точки.',
          severity: RouteConstraintSeverity.error,
        ),
      );
      return RouteConstraintResult(List.unmodifiable(issues));
    }

    for (final point in points) {
      if (point.xMm < context.edgeClearanceMm ||
          point.xMm > context.widthMm - context.edgeClearanceMm ||
          point.yMm < context.edgeClearanceMm ||
          point.yMm > context.heightMm - context.edgeClearanceMm) {
        issues.add(
          const RouteConstraintIssue(
            code: 'route.edge-clearance',
            message: 'Трасса выходит за допустимую зону поверхности.',
            severity: RouteConstraintSeverity.error,
          ),
        );
        break;
      }
    }

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a.xMm != b.xMm && a.yMm != b.yMm) {
        issues.add(
          const RouteConstraintIssue(
            code: 'route.non-orthogonal',
            message: 'Автоматическая трасса должна идти по ортогональным направлениям.',
            severity: RouteConstraintSeverity.error,
          ),
        );
        break;
      }
      for (final obstacle in context.obstacles) {
        if (_segmentIntersectsObstacle(a, b, obstacle)) {
          issues.add(
            RouteConstraintIssue(
              code: 'route.obstacle.${obstacle.id}',
              message:
                  'Трасса пересекает архитектурное препятствие ${obstacle.id}.',
              severity: RouteConstraintSeverity.error,
            ),
          );
          break;
        }
      }
    }

    if (points.length > 4) {
      issues.add(
        const RouteConstraintIssue(
          code: 'route.excessive-bends',
          message: 'Маршрут содержит лишние повороты.',
          severity: RouteConstraintSeverity.warning,
        ),
      );
    }

    return RouteConstraintResult(List.unmodifiable(issues));
  }

  static RouteCandidate _candidate(
    List<SurfacePointMm> points,
    RouteNormativeContext context,
  ) {
    final compact = _compact(points);
    final validation = validate(points: compact, context: context);
    final length = _length(compact);
    final bends = compact.length <= 2 ? 0 : compact.length - 2;
    final warningPenalty =
        validation.issues
            .where((issue) => issue.severity == RouteConstraintSeverity.warning)
            .length *
        1000;
    final errorPenalty = validation.isValid ? 0 : 1000000;
    return RouteCandidate(
      points: List.unmodifiable(compact),
      validation: validation,
      score: length + bends * 250 + warningPenalty + errorPenalty,
    );
  }

  static List<SurfacePointMm> _compact(List<SurfacePointMm> points) {
    final result = <SurfacePointMm>[];
    for (final point in points) {
      if (result.isNotEmpty &&
          result.last.xMm == point.xMm &&
          result.last.yMm == point.yMm) {
        continue;
      }
      result.add(point);
    }
    return result;
  }

  static double _length(List<SurfacePointMm> points) {
    var value = 0.0;
    for (var i = 1; i < points.length; i++) {
      value += (points[i].xMm - points[i - 1].xMm).abs();
      value += (points[i].yMm - points[i - 1].yMm).abs();
    }
    return value;
  }

  static bool _segmentIntersectsObstacle(
    SurfacePointMm a,
    SurfacePointMm b,
    RouteObstacleMm obstacle,
  ) {
    if (a.xMm == b.xMm) {
      if (a.xMm < obstacle.leftMm || a.xMm > obstacle.rightMm) return false;
      final minY = a.yMm < b.yMm ? a.yMm : b.yMm;
      final maxY = a.yMm > b.yMm ? a.yMm : b.yMm;
      return maxY >= obstacle.topMm && minY <= obstacle.bottomMm;
    }
    if (a.yMm == b.yMm) {
      if (a.yMm < obstacle.topMm || a.yMm > obstacle.bottomMm) return false;
      final minX = a.xMm < b.xMm ? a.xMm : b.xMm;
      final maxX = a.xMm > b.xMm ? a.xMm : b.xMm;
      return maxX >= obstacle.leftMm && minX <= obstacle.rightMm;
    }
    return true;
  }
}
