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
  })  : assert(rightMm >= leftMm),
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
    this.detourClearanceMm = 50,
    this.obstacles = const [],
    this.boundary = const [],
  })  : assert(widthMm > 0),
        assert(heightMm > 0),
        assert(edgeClearanceMm >= 0),
        assert(detourClearanceMm > 0);

  final RoomSurfaceRef surface;
  final int widthMm;
  final int heightMm;
  final int edgeClearanceMm;
  final int detourClearanceMm;
  final List<RouteObstacleMm> obstacles;
  final List<SurfacePointMm> boundary;
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

abstract final class NormativeRouteEngine {
  static List<RouteCandidate> buildCandidates({
    required SurfacePointMm source,
    required SurfacePointMm target,
    required RouteNormativeContext context,
  }) {
    final paths = <List<SurfacePointMm>>[
      [source, SurfacePointMm(target.xMm, source.yMm), target],
      [source, SurfacePointMm(source.xMm, target.yMm), target],
    ];

    final clearance = context.detourClearanceMm > context.edgeClearanceMm
        ? context.detourClearanceMm
        : context.edgeClearanceMm + 1;
    for (final obstacle in context.obstacles) {
      final above = obstacle.topMm - clearance;
      final below = obstacle.bottomMm + clearance;
      final left = obstacle.leftMm - clearance;
      final right = obstacle.rightMm + clearance;
      if (above >= 0) {
        paths.add([
          source,
          SurfacePointMm(source.xMm, above),
          SurfacePointMm(target.xMm, above),
          target,
        ]);
      }
      if (below <= context.heightMm) {
        paths.add([
          source,
          SurfacePointMm(source.xMm, below),
          SurfacePointMm(target.xMm, below),
          target,
        ]);
      }
      if (left >= 0) {
        paths.add([
          source,
          SurfacePointMm(left, source.yMm),
          SurfacePointMm(left, target.yMm),
          target,
        ]);
      }
      if (right <= context.widthMm) {
        paths.add([
          source,
          SurfacePointMm(right, source.yMm),
          SurfacePointMm(right, target.yMm),
          target,
        ]);
      }
    }

    final seen = <String>{};
    final candidates = <RouteCandidate>[];
    for (final path in paths) {
      final compact = _compact(path);
      final key = compact.map((p) => '${p.xMm},${p.yMm}').join(';');
      if (!seen.add(key)) continue;
      candidates.add(_candidate(compact, context));
    }
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
      return const RouteConstraintResult([
        RouteConstraintIssue(
          code: 'route.too-short',
          message: 'Маршрут должен содержать минимум две точки.',
          severity: RouteConstraintSeverity.error,
        ),
      ]);
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
            message:
                'Автоматическая трасса должна идти по ортогональным направлениям.',
            severity: RouteConstraintSeverity.error,
          ),
        );
        break;
      }
      if (context.boundary.length >= 3 &&
          !_segmentInsideBoundary(a, b, context.boundary)) {
        issues.add(
          const RouteConstraintIssue(
            code: 'route.outside-surface-boundary',
            message: 'Трасса выходит за фактический контур поверхности.',
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
    final validation = validate(points: points, context: context);
    final length = _length(points);
    final bends = points.length <= 2 ? 0 : points.length - 2;
    final warningPenalty = validation.issues
            .where((issue) => issue.severity == RouteConstraintSeverity.warning)
            .length *
        1000;
    final errorPenalty = validation.isValid ? 0 : 1000000;
    return RouteCandidate(
      points: List.unmodifiable(points),
      validation: validation,
      score: length + bends * 250 + warningPenalty + errorPenalty,
    );
  }

  static List<SurfacePointMm> _compact(List<SurfacePointMm> points) {
    final result = <SurfacePointMm>[];
    for (final point in points) {
      if (result.isNotEmpty && result.last == point) continue;
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

  static bool _segmentInsideBoundary(
    SurfacePointMm a,
    SurfacePointMm b,
    List<SurfacePointMm> boundary,
  ) {
    if (!_insideOrBoundary(a, boundary) || !_insideOrBoundary(b, boundary)) {
      return false;
    }
    for (var i = 0; i < boundary.length; i++) {
      final c = boundary[i];
      final d = boundary[(i + 1) % boundary.length];
      if (_properlyIntersects(a, b, c, d)) return false;
    }
    return true;
  }

  static bool _insideOrBoundary(
    SurfacePointMm point,
    List<SurfacePointMm> polygon,
  ) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if (_onSegment(a, point, b)) return true;
      final crosses = (a.yMm > point.yMm) != (b.yMm > point.yMm);
      if (!crosses) continue;
      final crossingX =
          (b.xMm - a.xMm) * (point.yMm - a.yMm) / (b.yMm - a.yMm) + a.xMm;
      if (point.xMm < crossingX) inside = !inside;
    }
    return inside;
  }

  static bool _properlyIntersects(
    SurfacePointMm a,
    SurfacePointMm b,
    SurfacePointMm c,
    SurfacePointMm d,
  ) {
    final abC = _cross(a, b, c);
    final abD = _cross(a, b, d);
    final cdA = _cross(c, d, a);
    final cdB = _cross(c, d, b);
    return ((abC > 0 && abD < 0) || (abC < 0 && abD > 0)) &&
        ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0));
  }

  static int _cross(SurfacePointMm a, SurfacePointMm b, SurfacePointMm p) =>
      (b.xMm - a.xMm) * (p.yMm - a.yMm) - (b.yMm - a.yMm) * (p.xMm - a.xMm);

  static bool _onSegment(
    SurfacePointMm a,
    SurfacePointMm p,
    SurfacePointMm b,
  ) {
    if (_cross(a, b, p) != 0) return false;
    final minX = a.xMm < b.xMm ? a.xMm : b.xMm;
    final maxX = a.xMm > b.xMm ? a.xMm : b.xMm;
    final minY = a.yMm < b.yMm ? a.yMm : b.yMm;
    final maxY = a.yMm > b.yMm ? a.yMm : b.yMm;
    return p.xMm >= minX && p.xMm <= maxX && p.yMm >= minY && p.yMm <= maxY;
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
