/// Compatibility assessment for the transitional editor JSON schema v1..v4.
///
/// P2D-2 deliberately does not perform a lossy conversion into the smaller P1
/// aggregate. Legacy documents contain geometry, openings, resume/editor state
/// and engineering P2 state that the current canonical aggregate cannot yet
/// represent. Until those domains land in P6/P7/P11+, known legacy documents
/// remain owned by the legacy runtime and migration fails closed.
enum LegacyProjectCompatibilityStatus {
  legacyRuntimeRequired,
  unsupportedSchema,
  malformed,
}

final class LegacyProjectCompatibilityAssessment {
  LegacyProjectCompatibilityAssessment({
    required this.status,
    required this.schemaVersion,
    required Iterable<String> reasons,
    this.projectId,
  }) : reasons = List<String>.unmodifiable(reasons);

  final LegacyProjectCompatibilityStatus status;
  final int? schemaVersion;
  final String? projectId;
  final List<String> reasons;

  bool get canMigrateLosslessly => false;
}

final class LosslessLegacyMigrationUnavailable implements Exception {
  LosslessLegacyMigrationUnavailable(this.assessment);

  final LegacyProjectCompatibilityAssessment assessment;

  @override
  String toString() => 'Lossless legacy project migration is not available: '
      '${assessment.reasons.join(' ')}';
}

abstract final class LegacyV4ProjectCompatibilityBoundary {
  static const int latestKnownLegacySchemaVersion = 4;

  static LegacyProjectCompatibilityAssessment assess(
    Map<String, Object?> source,
  ) {
    final rawVersion = source['schemaVersion'];
    if (rawVersion is! int || rawVersion < 1) {
      return LegacyProjectCompatibilityAssessment(
        status: LegacyProjectCompatibilityStatus.malformed,
        schemaVersion: rawVersion is int ? rawVersion : null,
        reasons: const <String>[
          'Legacy schemaVersion must be a positive integer.',
        ],
      );
    }

    if (rawVersion > latestKnownLegacySchemaVersion) {
      return LegacyProjectCompatibilityAssessment(
        status: LegacyProjectCompatibilityStatus.unsupportedSchema,
        schemaVersion: rawVersion,
        reasons: <String>[
          'Legacy schema $rawVersion is newer than the latest explicitly '
              'understood legacy schema $latestKnownLegacySchemaVersion.',
        ],
      );
    }

    final projectId = _legacyProjectId(source, rawVersion);
    if (projectId == null || projectId.trim().isEmpty) {
      return LegacyProjectCompatibilityAssessment(
        status: LegacyProjectCompatibilityStatus.malformed,
        schemaVersion: rawVersion,
        reasons: const <String>[
          'Legacy document does not expose a valid project identity.',
        ],
      );
    }

    return LegacyProjectCompatibilityAssessment(
      status: LegacyProjectCompatibilityStatus.legacyRuntimeRequired,
      schemaVersion: rawVersion,
      projectId: projectId,
      reasons: const <String>[
        'Legacy editor documents persist full room geometry and wall profiles.',
        'Legacy editor documents persist openings keyed by levelNumber.',
        'Legacy editor documents persist resume/navigation state including '
            'wall-index surface identity.',
        'Legacy editor documents persist engineering P2 components, routes, '
            'circuits and sizing evidence.',
        'The current P1 canonical aggregate does not yet model all of those '
            'fields, so conversion would be lossy.',
      ],
    );
  }

  static Never requireLosslessMigration(Map<String, Object?> source) {
    throw LosslessLegacyMigrationUnavailable(assess(source));
  }

  static String? _legacyProjectId(Map<String, Object?> source, int version) {
    if (version == 1) {
      final value = source['projectId'];
      return value is String ? value : null;
    }
    final metadata = source['metadata'];
    if (metadata is! Map) return null;
    final value = metadata['projectId'];
    return value is String ? value : null;
  }
}
