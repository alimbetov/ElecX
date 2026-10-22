import 'package:elecx/src/domain/site_true_north_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteTrueNorthReference', () {
    test('preserves legacy daylight azimuth sign convention', () {
      final reference = SiteTrueNorthReference.fromDegrees(30);

      expect(reference.toTrueAzimuth(0), 330);
      expect(reference.toTrueAzimuth(30), 0);
      expect(reference.toTrueAzimuth(90), 60);
    });

    test('normalizes explicit true-north input independently of Project North',
        () {
      final reference = SiteTrueNorthReference.fromDegrees(390);

      expect(reference.degreesClockwiseFromProjectPositiveY, 30);
    });

    test('rejects non-finite values', () {
      expect(
        () => SiteTrueNorthReference.fromDegrees(double.nan),
        throwsArgumentError,
      );
      expect(
        () => SiteTrueNorthReference.fromDegrees(double.infinity),
        throwsArgumentError,
      );
      expect(
        () => SiteTrueNorthReference.fromDegrees(0).toTrueAzimuth(double.nan),
        throwsArgumentError,
      );
    });
  });
}
