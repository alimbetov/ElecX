import '../../domain/project_orientation.dart';

/// Fail-closed boundary between transitional legacy orientation data and the
/// canonical P5D engineering orientation model.
///
/// Legacy editor schemas persisted `projectNorthDegrees` without provenance:
/// they cannot distinguish an engineer-confirmed value from the historical
/// implicit/default value. P5D therefore never promotes those values into
/// canonical Project Engineering North.
abstract final class LegacyProjectOrientationBoundary {
  static ProjectEngineeringMetadata canonicalMetadataFromUnprovenLegacy({
    double? projectNorthDegrees,
  }) {
    if (projectNorthDegrees != null && !projectNorthDegrees.isFinite) {
      throw const FormatException(
        'Legacy projectNorthDegrees must be finite when present.',
      );
    }

    // Presence of a numeric legacy value is not evidence of user confirmation.
    // Until a source schema carries explicit provenance, fail closed.
    return const ProjectEngineeringMetadata();
  }
}
