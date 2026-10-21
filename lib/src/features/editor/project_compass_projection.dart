import '../../domain/project_orientation.dart';

/// Presentation-only state for the P5D compass.
///
/// The widget consumes this resolved state and never reads the canonical
/// aggregate, legacy workspace, true-north compatibility model, or camera
/// directly.
sealed class CompassProjectionState {
  const CompassProjectionState();
}

/// Projection cannot be proven for the current editor mode/view.
///
/// P5D treats this fail-closed: the overlay must not render a directional
/// arrow that could be semantically false.
final class CompassUnavailable extends CompassProjectionState {
  const CompassUnavailable();
}

/// Canonical Project North has not been established by the engineer.
final class CompassNorthUnspecified extends CompassProjectionState {
  const CompassNorthUnspecified();
}

/// Canonical Project North has a deterministic screen projection.
final class CompassNorthDefined extends CompassProjectionState {
  const CompassNorthDefined({
    required this.canonicalNorth,
    required this.screenMilliDegreesClockwiseFromUp,
  }) : assert(
          screenMilliDegreesClockwiseFromUp >= 0 &&
              screenMilliDegreesClockwiseFromUp < 360000,
        );

  final ProjectEngineeringNorth canonicalNorth;
  final int screenMilliDegreesClockwiseFromUp;

  double get screenDegreesClockwiseFromUp =>
      screenMilliDegreesClockwiseFromUp / 1000.0;
}

/// P5D v1 direct projection policy.
///
/// The current WorldCamera has pan/zoom but no viewport rotation. Therefore
/// canonical clockwise-from-+Y Project North maps directly to clockwise-from-up
/// screen orientation for supported plan views.
abstract final class ProjectCompassProjection {
  static CompassProjectionState forPlan(ProjectEngineeringNorth? north) {
    if (north == null) {
      return const CompassNorthUnspecified();
    }
    return CompassNorthDefined(
      canonicalNorth: north,
      screenMilliDegreesClockwiseFromUp:
          north.milliDegreesClockwiseFromPositiveY,
    );
  }

  static const CompassProjectionState unavailable = CompassUnavailable();
}
