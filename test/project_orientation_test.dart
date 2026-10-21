import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectNorth', () {
    test('normalizes user input into canonical milli-degrees', () {
      expect(
        ProjectNorth.fromDegrees(0).milliDegreesClockwiseFromPositiveY,
        0,
      );
      expect(
        ProjectNorth.fromDegrees(360).milliDegreesClockwiseFromPositiveY,
        0,
      );
      expect(
        ProjectNorth.fromDegrees(-90).milliDegreesClockwiseFromPositiveY,
        270000,
      );
      expect(
        ProjectNorth.fromDegrees(32.5004).milliDegreesClockwiseFromPositiveY,
        32500,
      );
    });

    test('rejects non-finite user input', () {
      expect(
        () => ProjectNorth.fromDegrees(double.nan),
        throwsArgumentError,
      );
      expect(
        () => ProjectNorth.fromDegrees(double.infinity),
        throwsArgumentError,
      );
      expect(
        () => ProjectNorth.fromDegrees(double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('strict persisted constructor rejects unnormalized values', () {
      expect(
        ProjectNorth.fromNormalizedMilliDegrees(359999).degrees,
        359.999,
      );
      expect(
        () => ProjectNorth.fromNormalizedMilliDegrees(-1),
        throwsRangeError,
      );
      expect(
        () => ProjectNorth.fromNormalizedMilliDegrees(360000),
        throwsRangeError,
      );
    });

    test('equality is deterministic and integer based', () {
      final a = ProjectNorth.fromDegrees(32.5);
      final b = ProjectNorth.fromNormalizedMilliDegrees(32500);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ProjectEngineeringMetadata', () {
    test('unspecified north is distinct from explicit zero degrees', () {
      const unspecified = ProjectEngineeringMetadata();
      final zero = ProjectEngineeringMetadata(
        projectNorth: ProjectNorth.fromDegrees(0),
      );

      expect(unspecified.projectNorth, isNull);
      expect(zero.projectNorth, isNotNull);
      expect(unspecified, isNot(zero));
    });

    test('copyWith can set and explicitly clear Project North', () {
      const initial = ProjectEngineeringMetadata();
      final withNorth = initial.copyWith(
        projectNorth: ProjectNorth.fromDegrees(90),
      );
      final cleared = withNorth.copyWith(clearProjectNorth: true);

      expect(withNorth.projectNorth?.milliDegreesClockwiseFromPositiveY, 90000);
      expect(cleared.projectNorth, isNull);
    });
  });
}
