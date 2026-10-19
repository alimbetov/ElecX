import 'dart:math' as math;

/// Orientation of the project coordinate system relative to true north.
///
/// [northAzimuthDegrees] is the clockwise angle from the plan +Y axis to true
/// north. Zero means plan-up is north. Keeping this at site/project level makes
/// every room, wall and window derive a consistent world orientation.
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

  /// Converts a plan-space clockwise azimuth (0 = plan-up) into true-world
  /// azimuth where 0 = north, 90 = east, 180 = south, 270 = west.
  double toTrueAzimuth(double planAzimuthDegrees) =>
      _normalize(planAzimuthDegrees + northAzimuthDegrees);

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
