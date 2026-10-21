import 'package:elecx/src/serialization/project/legacy_project_orientation_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyProjectOrientationBoundary', () {
    test('missing legacy orientation stays canonical unspecified', () {
      final metadata =
          LegacyProjectOrientationBoundary.canonicalMetadataFromUnprovenLegacy();

      expect(metadata.projectNorth, isNull);
    });

    test('legacy default zero is never promoted without provenance', () {
      final metadata =
          LegacyProjectOrientationBoundary.canonicalMetadataFromUnprovenLegacy(
        projectNorthDegrees: 0,
      );

      expect(metadata.projectNorth, isNull);
    });

    test('legacy non-zero value is also unproven and stays unspecified', () {
      final metadata =
          LegacyProjectOrientationBoundary.canonicalMetadataFromUnprovenLegacy(
        projectNorthDegrees: 90,
      );

      expect(metadata.projectNorth, isNull);
    });

    test('malformed legacy numeric values fail closed', () {
      expect(
        () => LegacyProjectOrientationBoundary
            .canonicalMetadataFromUnprovenLegacy(
          projectNorthDegrees: double.nan,
        ),
        throwsFormatException,
      );
      expect(
        () => LegacyProjectOrientationBoundary
            .canonicalMetadataFromUnprovenLegacy(
          projectNorthDegrees: double.infinity,
        ),
        throwsFormatException,
      );
    });
  });
}
