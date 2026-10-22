/// Canonical engineering orientation for ElecX project-space coordinates.
///
/// This value deliberately does not imply geographic, magnetic or device
/// north. It only answers where Project North points inside the canonical plan
/// XY frame (+X right, +Y up).
final class ProjectEngineeringNorth {
  const ProjectEngineeringNorth._(this.milliDegreesClockwiseFromPositiveY);

  static const int fullTurnMilliDegrees = 360000;
  static const double fullTurnDegrees = 360.0;

  /// Normalized canonical storage value in [0, 360000).
  final int milliDegreesClockwiseFromPositiveY;

  /// Creates canonical Project North from a user/import angle.
  ///
  /// Input is normalized in degree space before milli-degree quantization. This
  /// keeps extreme-but-finite values away from the integer storage boundary and
  /// makes wrap-around rounding deterministic.
  factory ProjectEngineeringNorth.fromDegrees(double degrees) {
    if (!degrees.isFinite) {
      throw ArgumentError.value(
        degrees,
        'degrees',
        'Project North must be finite.',
      );
    }

    var normalizedDegrees = degrees % fullTurnDegrees;
    if (normalizedDegrees < 0) normalizedDegrees += fullTurnDegrees;

    final milliDegrees = (normalizedDegrees * 1000).round();
    return ProjectEngineeringNorth._(_normalizeMilliDegrees(milliDegrees));
  }

  /// Creates Project North from already-normalized persisted canonical data.
  ///
  /// Persistence decoding is intentionally strict: malformed/out-of-range
  /// values fail rather than being silently normalized.
  factory ProjectEngineeringNorth.fromNormalizedMilliDegrees(int milliDegrees) {
    if (milliDegrees < 0 || milliDegrees >= fullTurnMilliDegrees) {
      throw RangeError.range(
        milliDegrees,
        0,
        fullTurnMilliDegrees - 1,
        'milliDegrees',
        'Persisted Project North must already be normalized.',
      );
    }
    return ProjectEngineeringNorth._(milliDegrees);
  }

  double get degrees => milliDegreesClockwiseFromPositiveY / 1000.0;

  static int _normalizeMilliDegrees(int value) {
    var result = value % fullTurnMilliDegrees;
    if (result < 0) result += fullTurnMilliDegrees;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectEngineeringNorth &&
      other.milliDegreesClockwiseFromPositiveY ==
          milliDegreesClockwiseFromPositiveY;

  @override
  int get hashCode => milliDegreesClockwiseFromPositiveY.hashCode;

  @override
  String toString() =>
      'ProjectEngineeringNorth(${degrees.toStringAsFixed(3)}°)';
}

/// Canonical root-level engineering metadata.
///
/// Null Project North means the engineer has not confirmed project orientation.
/// It must never be interpreted as an implicit 0°.
final class ProjectEngineeringMetadata {
  const ProjectEngineeringMetadata({this.projectNorth});

  final ProjectEngineeringNorth? projectNorth;

  ProjectEngineeringMetadata copyWith({
    ProjectEngineeringNorth? projectNorth,
    bool clearProjectNorth = false,
  }) {
    if (clearProjectNorth && projectNorth != null) {
      throw ArgumentError(
        'projectNorth and clearProjectNorth cannot be supplied together.',
      );
    }
    return ProjectEngineeringMetadata(
      projectNorth:
          clearProjectNorth ? null : projectNorth ?? this.projectNorth,
    );
  }

  ProjectEngineeringMetadata withProjectNorth(ProjectEngineeringNorth north) =>
      ProjectEngineeringMetadata(projectNorth: north);

  ProjectEngineeringMetadata withoutProjectNorth() =>
      const ProjectEngineeringMetadata();

  @override
  bool operator ==(Object other) =>
      other is ProjectEngineeringMetadata && other.projectNorth == projectNorth;

  @override
  int get hashCode => projectNorth.hashCode;
}
