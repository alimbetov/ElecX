/// Canonical engineering orientation for ElecX project-space coordinates.
///
/// This value deliberately does not imply geographic, magnetic or device
/// north. It only answers where Project North points inside the canonical plan
/// XY frame (+X right, +Y up).
final class ProjectNorth {
  const ProjectNorth._(this.milliDegreesClockwiseFromPositiveY);

  static const int fullTurnMilliDegrees = 360000;

  /// Normalized canonical storage value in [0, 360000).
  final int milliDegreesClockwiseFromPositiveY;

  /// Creates a canonical Project North from a user/import angle.
  ///
  /// Finite values are rounded to the nearest milli-degree and normalized.
  factory ProjectNorth.fromDegrees(double degrees) {
    if (!degrees.isFinite) {
      throw ArgumentError.value(
        degrees,
        'degrees',
        'Project North must be finite.',
      );
    }
    return ProjectNorth._(_normalize((degrees * 1000).round()));
  }

  /// Creates Project North from already-normalized persisted canonical data.
  ///
  /// Persistence decoding is intentionally strict: malformed/out-of-range
  /// values fail rather than being silently normalized.
  factory ProjectNorth.fromNormalizedMilliDegrees(int milliDegrees) {
    if (milliDegrees < 0 || milliDegrees >= fullTurnMilliDegrees) {
      throw RangeError.range(
        milliDegrees,
        0,
        fullTurnMilliDegrees - 1,
        'milliDegrees',
        'Persisted Project North must already be normalized.',
      );
    }
    return ProjectNorth._(milliDegrees);
  }

  double get degrees => milliDegreesClockwiseFromPositiveY / 1000.0;

  static int _normalize(int value) {
    var result = value % fullTurnMilliDegrees;
    if (result < 0) result += fullTurnMilliDegrees;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectNorth &&
      other.milliDegreesClockwiseFromPositiveY ==
          milliDegreesClockwiseFromPositiveY;

  @override
  int get hashCode => milliDegreesClockwiseFromPositiveY.hashCode;

  @override
  String toString() => 'ProjectNorth(${degrees.toStringAsFixed(3)}°)';
}

/// Canonical root-level engineering metadata.
///
/// Null Project North means the engineer has not confirmed project orientation.
/// It must never be interpreted as an implicit 0°.
final class ProjectEngineeringMetadata {
  const ProjectEngineeringMetadata({this.projectNorth});

  final ProjectNorth? projectNorth;

  ProjectEngineeringMetadata copyWith({
    ProjectNorth? projectNorth,
    bool clearProjectNorth = false,
  }) =>
      ProjectEngineeringMetadata(
        projectNorth: clearProjectNorth ? null : projectNorth ?? this.projectNorth,
      );

  @override
  bool operator ==(Object other) =>
      other is ProjectEngineeringMetadata && other.projectNorth == projectNorth;

  @override
  int get hashCode => projectNorth.hashCode;
}
