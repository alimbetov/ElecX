import '../../../domain/canonical_power_selection.dart';
import '../../../engine/power_evidence_selection_engine.dart';
import 'engineering_evidence_review_gate.dart';

/// Verifies *all* durable v21 source pins against an independently provided
/// trusted registry. A snapshot digest or an approval string is not sufficient
/// to grant normative authority.
final class CanonicalPowerEvidencePreflight {
  const CanonicalPowerEvidencePreflight._();

  static EngineeringEvidenceReviewResult evaluate({
    required CanonicalPowerSelectionRegistry selections,
    required TrustedEngineeringEvidenceRegistry registry,
    required String jurisdiction,
    required String applicationScope,
  }) {
    final sources = <String, CanonicalEngineeringSourceReference>{};
    var inconsistent = false;
    for (final selection in selections.byCircuit.values) {
      for (final source in selection.sources) {
        final previous = sources[source.sourceId];
        if (previous != null &&
            (previous.revision != source.revision ||
                previous.sha256 != source.sha256 ||
                previous.approvalId != source.approvalId)) {
          inconsistent = true;
        }
        sources[source.sourceId] = source;
      }
    }
    final reviewed = EngineeringEvidenceReviewGate.evaluate(
      requiredSources: [
        for (final source in sources.values)
          PowerEvidenceSourcePin(
            sourceId: source.sourceId,
            revision: source.revision,
            contentSha256: source.sha256,
            approvalId: source.approvalId,
          ),
      ],
      registry: registry,
      jurisdiction: jurisdiction,
      applicationScope: applicationScope,
    );
    if (!inconsistent) return reviewed;
    return EngineeringEvidenceReviewResult(
      registryRevision: reviewed.registryRevision,
      issues: [
        for (final issue in EngineeringEvidenceReviewIssue.values)
          if (issue == EngineeringEvidenceReviewIssue.mismatchedIdentity ||
              reviewed.issues.contains(issue))
            issue,
      ],
    );
  }
}
