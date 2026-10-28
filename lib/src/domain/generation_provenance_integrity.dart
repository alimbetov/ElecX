import 'generation_provenance.dart';

/// Additive integrity checks for persisted P9 generation provenance.
///
/// The generated baseline fingerprint is the immutable hash of the original
/// generated payload. It intentionally is not recomputed from the current
/// canonical entity because manual overrides legitimately change that entity
/// while preserving the original baseline lineage.
abstract final class GenerationProvenanceIntegrityValidator {
  static final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');

  static List<GenerationProvenanceIssue> validate(
    GenerationProvenanceRegistry registry,
  ) {
    final issues = <GenerationProvenanceIssue>[];

    for (final provenance in registry.entities.values) {
      if (!_sha256.hasMatch(provenance.generatedBaselineFingerprint)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.invalidBaseline,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Generated baseline fingerprint must be a canonical '
                'lowercase SHA-256 value.',
          ),
        );
      }

      final manifest = registry.manifests[provenance.generationId];
      if (manifest != null &&
          manifest.removedGenerationKeys.contains(provenance.generationKey)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Active generationKey ${provenance.generationKey} is '
                'also recorded as removed in the generation manifest.',
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow(GenerationProvenanceRegistry registry) {
    final issues = validate(registry);
    if (issues.isNotEmpty) {
      throw GenerationProvenanceValidationException(issues);
    }
  }
}
