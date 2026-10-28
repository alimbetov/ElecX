import 'applied_engineering_proposal.dart';
import 'generation_provenance.dart';
import 'project_identity.dart';

enum AppliedEngineeringProposalLineageIssueCode {
  generationManifestMissing,
  generationManifestAmbiguous,
  candidateFingerprintMismatch,
  intentFingerprintMismatch,
}

final class AppliedEngineeringProposalLineageIssue {
  const AppliedEngineeringProposalLineageIssue({
    required this.code,
    required this.levelId,
    required this.message,
  });

  final AppliedEngineeringProposalLineageIssueCode code;
  final LevelId levelId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

final class AppliedEngineeringProposalLineageException implements Exception {
  AppliedEngineeringProposalLineageException(
    Iterable<AppliedEngineeringProposalLineageIssue> issues,
  ) : issues = List.unmodifiable(issues);

  final List<AppliedEngineeringProposalLineageIssue> issues;

  @override
  String toString() =>
      'Invalid applied engineering proposal lineage:\n${issues.join('\n')}';
}

/// Cross-registry invariant between P9.12 generation provenance and the frozen
/// P9.6 engineering proposal persisted for a generated apartment level.
///
/// P9 currently permits apartment generation only on an empty Level, therefore
/// an applied engineering proposal must resolve to exactly one generation
/// manifest for that Level. Candidate and normalized-intent fingerprints must
/// then match that exact manifest. This prevents a valid proposal from one
/// generated apartment being rebound to another provenance lineage.
abstract final class AppliedEngineeringProposalLineageValidator {
  static List<AppliedEngineeringProposalLineageIssue> validate({
    required GenerationProvenanceRegistry provenance,
    required AppliedEngineeringProposalRegistry proposals,
  }) {
    final issues = <AppliedEngineeringProposalLineageIssue>[];

    for (final proposal in proposals.byLevel.values) {
      final manifests = provenance.manifests.values
          .where((manifest) => manifest.levelId == proposal.levelId)
          .toList(growable: false);

      if (manifests.isEmpty) {
        issues.add(
          AppliedEngineeringProposalLineageIssue(
            code: AppliedEngineeringProposalLineageIssueCode
                .generationManifestMissing,
            levelId: proposal.levelId,
            message: 'Applied engineering proposal for ${proposal.levelId} '
                'has no generation manifest for the same Level.',
          ),
        );
        continue;
      }
      if (manifests.length != 1) {
        issues.add(
          AppliedEngineeringProposalLineageIssue(
            code: AppliedEngineeringProposalLineageIssueCode
                .generationManifestAmbiguous,
            levelId: proposal.levelId,
            message: 'Applied engineering proposal for ${proposal.levelId} '
                'resolves to ${manifests.length} generation manifests.',
          ),
        );
        continue;
      }

      final manifest = manifests.single;
      if (proposal.candidateFingerprint !=
          manifest.selectedCandidateFingerprint) {
        issues.add(
          AppliedEngineeringProposalLineageIssue(
            code: AppliedEngineeringProposalLineageIssueCode
                .candidateFingerprintMismatch,
            levelId: proposal.levelId,
            message: 'Applied engineering proposal candidate fingerprint does '
                'not match its generation manifest.',
          ),
        );
      }
      if (proposal.intentFingerprint != manifest.normalizedIntentFingerprint) {
        issues.add(
          AppliedEngineeringProposalLineageIssue(
            code:
                AppliedEngineeringProposalLineageIssueCode.intentFingerprintMismatch,
            levelId: proposal.levelId,
            message: 'Applied engineering proposal intent fingerprint does not '
                'match its generation manifest.',
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow({
    required GenerationProvenanceRegistry provenance,
    required AppliedEngineeringProposalRegistry proposals,
  }) {
    final issues = validate(provenance: provenance, proposals: proposals);
    if (issues.isNotEmpty) {
      throw AppliedEngineeringProposalLineageException(issues);
    }
  }
}
