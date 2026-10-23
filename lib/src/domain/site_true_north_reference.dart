/// Explicit geospatial/true-north compatibility reference.
///
/// This preserves the legacy daylight conversion semantics while keeping them
/// separate from canonical engineering Project North. P5D must not infer or
/// fabricate this value from the canonical compass orientation.
final class SiteTrueNorthReference {
  const SiteTrueNorthReference._(this.degreesClockwiseFromProjectPositiveY);

  final double degreesClockwiseFromProjectPositiveY;

  factory SiteTrueNorthReference.fromDegrees(double degrees) {
    if (!degrees.isFinite) {
      throw ArgumentError.value(
        degrees,
        'degrees',
        'True-north reference must be finite.',
      );
    }
    return SiteTrueNorthReference._(_normalize(degrees));
  }

  /// Converts plan-space clockwise azimuth (0 = project +Y) into true-world
  /// azimuth. This intentionally preserves the existing daylight sign rule.
  double toTrueAzimuth(double planAzimuthDegrees) {
    if (!planAzimuthDegrees.isFinite) {
      throw ArgumentError.value(
        planAzimuthDegrees,
        'planAzimuthDegrees',
        'Plan azimuth must be finite.',
      );
    }
    return _normalize(
      planAzimuthDegrees - degreesClockwiseFromProjectPositiveY,
    );
  }

  static double _normalize(double value) {
    var result = value % 360;
    if (result < 0) result += 360;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is SiteTrueNorthReference &&
      other.degreesClockwiseFromProjectPositiveY ==
          degreesClockwiseFromProjectPositiveY;

  @override
  int get hashCode => degreesClockwiseFromProjectPositiveY.hashCode;
}
