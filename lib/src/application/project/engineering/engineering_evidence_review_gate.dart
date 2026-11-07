import '../../engine/power_evidence_selection_engine.dart';

/// Review records must be loaded from a trusted, authenticated ingestion
/// boundary. Constructing one in application code is not proof of authenticity.
final class EngineeringEvidenceReviewRecord {
  const EngineeringEvidenceReviewRecord({
    required this.sourceId,
    required this.revision,
    required this.contentSha256,
    required this.approvalId,
    required this.jurisdiction,
    required this.applicationScope,
    required this.isApproved,
    required this.isRevoked,
  });

  final String sourceId;
  final String revision;
  final String contentSha256;
  final String approvalId;
  final String jurisdiction;
  final String applicationScope;
  final bool isApproved;
  final bool isRevoked;
}

/// The production implementation must be backed by a versioned, authenticated
/// evidence registry. In particular, the caller must not supply its own reviews.
abstract interface class TrustedEngineeringEvidenceRegistry {
  /// Immutable registry version, checked again at the commit boundary.
  String get revision;

  EngineeringEvidenceReviewRecord? lookup(String sourceId);
}

enum EngineeringEvidenceReviewIssue {
  missingSource,
  mismatchedIdentity,
  unapprovedSource,
  revokedSource,
  wrongJurisdiction,
  wrongApplicationScope,
  invalidRegistryRevision,
}

final class EngineeringEvidenceReviewResult {
  EngineeringEvidenceReviewResult({
    required this.registryRevision,
    required Iterable<EngineeringEvidenceReviewIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final String registryRevision;
  final List<EngineeringEvidenceReviewIssue> issues;

  bool get isQualified => issues.isEmpty;
}

/// Read-only authenticity/applicability preflight. This does NOT grant Apply:
/// board ratings, fault/thermal protection, topology, canonical versioning and
/// transactional revalidation are independent mandatory gates.
abstract final class EngineeringEvidenceReviewGate {
  static EngineeringEvidenceReviewResult evaluate({
    required Iterable<PowerEvidenceSourcePin> requiredSources,
    required TrustedEngineeringEvidenceRegistry registry,
    required String jurisdiction,
    required String applicationScope,
  }) {
    final issues = <EngineeringEvidenceReviewIssue>{};
    final revision = registry.revision.trim();
    if (revision.isEmpty ||
        jurisdiction.trim().isEmpty ||
        applicationScope.trim().isEmpty) {
      issues.add(EngineeringEvidenceReviewIssue.invalidRegistryRevision);
    }

    final pins = requiredSources.toList()
      ..sort((a, b) => a.sourceId.compareTo(b.sourceId));
    final visited = <String>{};
    for (final pin in pins) {
      if (!visited.add(pin.sourceId)) {
        issues.add(EngineeringEvidenceReviewIssue.mismatchedIdentity);
        continue;
      }
      final record = registry.lookup(pin.sourceId);
      if (record == null) {
        issues.add(EngineeringEvidenceReviewIssue.missingSource);
        continue;
      }
      if (record.sourceId != pin.sourceId ||
          record.revision != pin.revision ||
          record.contentSha256 != pin.contentSha256 ||
          record.approvalId != pin.approvalId) {
        issues.add(EngineeringEvidenceReviewIssue.mismatchedIdentity);
      }
      if (!record.isApproved) {
        issues.add(EngineeringEvidenceReviewIssue.unapprovedSource);
      }
      if (record.isRevoked) {
        issues.add(EngineeringEvidenceReviewIssue.revokedSource);
      }
      if (record.jurisdiction != jurisdiction) {
        issues.add(EngineeringEvidenceReviewIssue.wrongJurisdiction);
      }
      if (record.applicationScope != applicationScope) {
        issues.add(EngineeringEvidenceReviewIssue.wrongApplicationScope);
      }
    }
    return EngineeringEvidenceReviewResult(
      registryRevision: revision,
      issues: [
        for (final issue in EngineeringEvidenceReviewIssue.values)
          if (issues.contains(issue)) issue,
      ],
    );
  }
}
