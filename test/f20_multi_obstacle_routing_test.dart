import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-f20', 0);

  test('F20 finds an orthogonal path requiring multiple obstacle detours', () {
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
      detourClearanceMm: 50,
      obstacles: [
        RouteObstacleMm(
          id: 'lower-block',
          leftMm: 800,
          topMm: 0,
          rightMm: 1200,
          bottomMm: 1300,
        ),
        RouteObstacleMm(
          id: 'upper-block',
          leftMm: 1800,
          topMm: 700,
          rightMm: 2200,
          bottomMm: 2000,
        ),
      ],
    );
    const source = SurfacePointMm(200, 1000);
    const target = SurfacePointMm(2800, 1000);

    final candidates = NormativeRouteEngine.buildCandidates(
      source: source,
      target: target,
      context: context,
    );
    final best = candidates.firstWhere(
      (candidate) => candidate.validation.isValid,
    );

    expect(best.points.first, source);
    expect(best.points.last, target);
    expect(best.points.length, greaterThanOrEqualTo(6));
    expect(
      NormativeRouteEngine.validate(
        points: best.points,
        context: context,
      ).isValid,
      isTrue,
    );
    expect(best.points.any((point) => point.yMm >= 1350), isTrue);
    expect(best.points.any((point) => point.yMm <= 650), isTrue);
  });

  test(
    'F20 returns no valid candidate when obstacles form a complete barrier',
    () {
      final context = RouteNormativeContext(
        surface: surface,
        widthMm: 3000,
        heightMm: 2000,
        edgeClearanceMm: 0,
        detourClearanceMm: 50,
        obstacles: [
          RouteObstacleMm(
            id: 'barrier',
            leftMm: 1400,
            topMm: 0,
            rightMm: 1600,
            bottomMm: 2000,
          ),
        ],
      );
      final candidates = NormativeRouteEngine.buildCandidates(
        source: const SurfacePointMm(200, 1000),
        target: const SurfacePointMm(2800, 1000),
        context: context,
      );
      expect(
        candidates.where((candidate) => candidate.validation.isValid),
        isEmpty,
      );
    },
  );

  test('F20 keeps simple direct routing optimal when no detour is needed', () {
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
    );
    final candidates = NormativeRouteEngine.buildCandidates(
      source: const SurfacePointMm(200, 500),
      target: const SurfacePointMm(2800, 500),
      context: context,
    );
    final best = candidates.first;
    expect(best.validation.isValid, isTrue);
    expect(best.points, const [
      SurfacePointMm(200, 500),
      SurfacePointMm(2800, 500),
    ]);
  });
}
