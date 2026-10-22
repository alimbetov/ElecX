import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectEngineeringNorth', () {
    test('normalizes user input into canonical milli-degrees', () {
      expect(
        ProjectEngineeringNorth.fromDegrees(0)
            .milliDegreesClockwiseFromPositiveY,
        0,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(360)
            .milliDegreesClockwiseFromPositiveY,
        0,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(-90)
            .milliDegreesClockwiseFromPositiveY,
        270000,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(32.5004)
            .milliDegreesClockwiseFromPositiveY,
        32500,
      );
    });

    test('rounding at the full-turn boundary is deterministic', () {
      expect(
        ProjectEngineeringNorth.fromDegrees(359.9994)
            .milliDegreesClockwiseFromPositiveY,
        359999,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(359.9995)
            .milliDegreesClockwiseFromPositiveY,
        0,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(-0.0004)
            .milliDegreesClockwiseFromPositiveY,
        0,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(-0.0006)
            .milliDegreesClockwiseFromPositiveY,
        359999,
      );
      expect(
        ProjectEngineeringNorth.fromDegrees(720.0004)
            .milliDegreesClockwiseFromPositiveY,
        0,
      );
    });

    test('rejects non-finite user input', () {
      expect(
        () => ProjectEngineeringNorth.fromDegrees(double.nan),
        throwsArgumentError,
      );
      expect(
        () => ProjectEngineeringNorth.fromDegrees(double.infinity),
        throwsArgumentError,
      );
      expect(
        () => ProjectEngineeringNorth.fromDegrees(double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('strict persisted constructor rejects unnormalized values', () {
      expect(
        ProjectEngineeringNorth.fromNormalizedMilliDegrees(359999).degrees,
        359.999,
      );
      expect(
        () => ProjectEngineeringNorth.fromNormalizedMilliDegrees(-1),
        throwsRangeError,
      );
      expect(
        () => ProjectEngineeringNorth.fromNormalizedMilliDegrees(360000),
        throwsRangeError,
      );
    });

    test('equality is deterministic and integer based', () {
      final a = ProjectEngineeringNorth.fromDegrees(32.5);
      final b = ProjectEngineeringNorth.fromNormalizedMilliDegrees(32500);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ProjectEngineeringMetadata', () {
    test('unspecified north is distinct from explicit zero degrees', () {
      const unspecified = ProjectEngineeringMetadata();
      final zero = ProjectEngineeringMetadata(
        projectNorth: ProjectEngineeringNorth.fromDegrees(0),
      );

      expect(unspecified.projectNorth, isNull);
      expect(zero.projectNorth, isNotNull);
      expect(unspecified, isNot(zero));
    });

    test('copyWith can set and explicitly clear Project North', () {
      const initial = ProjectEngineeringMetadata();
      final withNorth = initial.copyWith(
        projectNorth: ProjectEngineeringNorth.fromDegrees(90),
      );
      final cleared = withNorth.copyWith(clearProjectNorth: true);

      expect(withNorth.projectNorth?.milliDegreesClockwiseFromPositiveY, 90000);
      expect(cleared.projectNorth, isNull);
    });

    test('copyWith rejects contradictory set and clear request', () {
      const initial = ProjectEngineeringMetadata();
      expect(
        () => initial.copyWith(
          projectNorth: ProjectEngineeringNorth.fromDegrees(90),
          clearProjectNorth: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
