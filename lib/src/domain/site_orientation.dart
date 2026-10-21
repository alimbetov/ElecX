import 'dart:math' as math;

import 'site_true_north_reference.dart';

/// Transitional compatibility wrapper for the legacy site/daylight model.
///
/// Despite the historical name, this value represents a **true-north
/// reference**, not canonical P5D Project North. New canonical engineering
/// orientation must use `ProjectEngineeringNorth` from project_orientation.dart.
///
/// This wrapper remains temporarily so legacy ProjectSite/editor persistence and
/// existing visual components can keep their public shape while all true-north
/// calculations are routed through [SiteTrueNorthReference].
final class ProjectNorth {
  const ProjectNorth({this.northAzimuthDegrees = 0})
      : assert(northAzimuthDegrees >= 0),
        assert(northAzimuthDegrees < 360);

  final double northAzimuthDegrees;

  double get northAzimuthRadians => northAzimuthDegrees * math.pi / 180;

  ProjectNorth copyWith({double? northAzimuthDegrees}) => ProjectNorth(
        northAzimuthDegrees:
            _normalize(northAzimuthDegrees ?? this.northAzimuthDegrees),
      );

  /// Converts plan-space clockwise azimuth (0 = plan-up) into true-world
  /// azimuth. The authoritative compatibility semantics live in
  /// [SiteTrueNorthReference].
  double toTrueAzimuth(double planAzimuthDegrees) =>
      SiteTrueNorthReference.fromDegrees(northAzimuthDegrees)
          .toTrueAzimuth(planAzimuthDegrees);

  static double _normalize(double value) {
    var result = value % 360;
    if (result < 0) result += 360;
    return result;
  }
}

/// Optional inputs required for physical sun/daylight calculations. The
/// editor can still show compass/facade orientation without this context.
final class SolarSiteContext {
  const SolarSiteContext({
    required this.latitudeDegrees,
    required this.longitudeDegrees,
    required this.timeZoneOffsetMinutes,
  })  : assert(latitudeDegrees >= -90 && latitudeDegrees <= 90),
        assert(longitudeDegrees >= -180 && longitudeDegrees <= 180);

  final double latitudeDegrees;
  final double longitudeDegrees;
  final int timeZoneOffsetMinutes;
}
