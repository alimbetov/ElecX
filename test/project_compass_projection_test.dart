import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/project_compass_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectCompassProjection', () {
    test('returns unspecified when canonical Project North is not set', () {
      expect(
        ProjectCompassProjection.forPlan(null),
        isA<CompassNorthUnspecified>(),
      );
    });

    test('projects cardinal canonical directions directly to the screen', () {
      final cases = <double, int>{
        0: 0,
        90: 90000,
        180: 180000,
        270: 270000,
      };

      for (final entry in cases.entries) {
        final north = ProjectEngineeringNorth.fromDegrees(entry.key);
        final projected = ProjectCompassProjection.forPlan(north);

        expect(projected, isA<CompassNorthDefined>());
        final defined = projected as CompassNorthDefined;
        expect(defined.canonicalNorth, north);
        expect(
          defined.screenMilliDegreesClockwiseFromUp,
          entry.value,
        );
      }
    });

    test('preserves milli-degree precision in direct projection', () {
      final north = ProjectEngineeringNorth.fromDegrees(32.501);
      final projected = ProjectCompassProjection.forPlan(north);

      expect(
        (projected as CompassNorthDefined).screenMilliDegreesClockwiseFromUp,
        32501,
      );
    });

    test('defined projection rejects malformed screen angles at runtime', () {
      final north = ProjectEngineeringNorth.fromDegrees(0);

      expect(
        () => CompassNorthDefined(
          canonicalNorth: north,
          screenMilliDegreesClockwiseFromUp: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => CompassNorthDefined(
          canonicalNorth: north,
          screenMilliDegreesClockwiseFromUp: 360000,
        ),
        throwsArgumentError,
      );
    });

    test('unsupported projection is explicit and fail closed', () {
      expect(
        ProjectCompassProjection.unavailable,
        isA<CompassUnavailable>(),
      );
    });
  });
}
