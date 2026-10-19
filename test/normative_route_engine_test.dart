import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-101', 0);

  test('auto route prefers valid orthogonal candidate around obstacle', () {
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 2000,
      heightMm: 1600,
      edgeClearanceMm: 100,
      obstacles: const [
        RouteObstacleMm(
          id: 'window-1',
          leftMm: 800,
          topMm: 150,
          rightMm: 1200,
          bottomMm: 300,
        ),
      ],
    );

    final candidates = NormativeRouteEngine.buildCandidates(
      source: const SurfacePointMm(200, 200),
      target: const SurfacePointMm(1800, 1400),
      context: context,
    );

    expect(candidates, hasLength(2));
    expect(candidates.first.validation.isValid, isTrue);
    expect(candidates.last.validation.isValid, isFalse);
    expect(candidates.first.points[1].xMm, 200);
    expect(candidates.first.points[1].yMm, 1400);
  });

  test('manual diagonal preview is rejected by guardrails', () {
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 2000,
      heightMm: 1600,
      edgeClearanceMm: 100,
    );

    final result = NormativeRouteEngine.validate(
      points: const [
        SurfacePointMm(200, 200),
        SurfacePointMm(1800, 1400),
      ],
      context: context,
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.code == 'route.non-orthogonal'),
      isTrue,
    );
  });
}
