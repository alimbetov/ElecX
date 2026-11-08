import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/semantic_sha256.dart';
import 'engineering_evidence_review_gate.dart';
import 'power_electrical_safety_gate.dart';

/// Exact manufacturer article, not a generic MCB/RCD family label.
/// Identity is evidence, not a declaration of compliance.
final class ManufacturerProtectionArticle {
  ManufacturerProtectionArticle({
    required this.manufacturerId,
    required this.articleNumber,
    required this.deviceKind,
    required this.catalogRevision,
  }) {
    if (manufacturerId.trim().isEmpty ||
        articleNumber.trim().isEmpty ||
        deviceKind.trim().isEmpty ||
        catalogRevision.trim().isEmpty) {
      throw ArgumentError('Exact manufacturer article identity required.');
    }
  }

  final String manufacturerId;
  final String articleNumber;
  final String deviceKind;
  final String catalogRevision;

  List<String> get canonical => [
        manufacturerId,
        articleNumber,
        deviceKind,
        catalogRevision,
      ];
}

/// One independently reviewable manufacturer coordination table row.
/// Its numerical coverage is not inferred from device ratings or curves.
final class ManufacturerProtectionPairRecord {
  ManufacturerProtectionPairRecord({
    required this.downstream,
    required this.upstream,
    required this.sourceId,
    required this.documentRevision,
    required this.documentSha256,
    required this.tableId,
    required this.maximumCoveredFaultKa,
    required this.circuitId,
  }) {
    if (sourceId.trim().isEmpty ||
        documentRevision.trim().isEmpty ||
        tableId.trim().isEmpty ||
        circuitId.trim().isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(documentSha256) ||
        !maximumCoveredFaultKa.isFinite ||
        maximumCoveredFaultKa <= 0 ||
        downstream.manufacturerId != upstream.manufacturerId ||
        (downstream.manufacturerId == upstream.manufacturerId &&
            downstream.articleNumber == upstream.articleNumber)) {
      throw ArgumentError('Complete distinct manufacturer pair required.');
    }
  }

  final ManufacturerProtectionArticle downstream;
  final ManufacturerProtectionArticle upstream;
  final String sourceId;
  final String documentRevision;
  final String documentSha256;
  final String tableId;
  final double maximumCoveredFaultKa;
  final String circuitId;

  String get fingerprint => semanticSha256Hex(jsonEncode([
        'p12.manufacturer-coordination-row.v1',
        circuitId,
        downstream.canonical,
        upstream.canonical,
        sourceId,
        documentRevision,
        documentSha256.toLowerCase(),
        tableId,
        maximumCoveredFaultKa,
      ]));
}

enum ManufacturerPairCheck {
  exactCatalogArticles,
  pinnedManufacturerDocument,
  independentCoordinationAttestation,
  worstCaseFaultCoverage,
}

/// This is a read-only, fail-closed evidence preflight. Never permits Apply.
final class ManufacturerPairAssessment {
  ManufacturerPairAssessment(
      Map<ManufacturerPairCheck, PowerSafetyVerdict> checks)
      : checks = Map.unmodifiable(checks);

  final Map<ManufacturerPairCheck, PowerSafetyVerdict> checks;

  PowerSafetyVerdict get verdict {
    if (checks.values.contains(PowerSafetyVerdict.fail)) {
      return PowerSafetyVerdict.fail;
    }
    if (checks.length != ManufacturerPairCheck.values.length ||
        checks.values.any((v) => v != PowerSafetyVerdict.pass)) {
      return PowerSafetyVerdict.indeterminate;
    }
    return PowerSafetyVerdict.pass;
  }

  bool get readyToApply => false;
}

abstract final class ManufacturerPairEvidenceGate {
  static ManufacturerPairAssessment evaluate({
    required CanonicalPowerCircuitSelection selection,
    required ManufacturerProtectionPairRecord row,
    required TrustedEngineeringEvidenceRegistry registry,
    required String selectedDownstreamArticleNumber,
    required String selectedUpstreamArticleNumber,
    required String targetJurisdiction,
    required String targetApplicationScope,
    required double maximumProspectiveFaultKa,
  }) {
    final checks = <ManufacturerPairCheck, PowerSafetyVerdict>{
      for (final kind in ManufacturerPairCheck.values)
        kind: PowerSafetyVerdict.indeterminate,
    };
    final exact = row.circuitId == selection.circuitId.value &&
        row.downstream.articleNumber == selectedDownstreamArticleNumber &&
        row.upstream.articleNumber == selectedUpstreamArticleNumber &&
        row.downstream.articleNumber == selection.protectionCatalogId &&
        row.downstream.deviceKind.toLowerCase() ==
            selection.protectionRatings.deviceKind.toLowerCase();
    if (!exact) return ManufacturerPairAssessment(checks);
    checks[ManufacturerPairCheck.exactCatalogArticles] =
        PowerSafetyVerdict.pass;

    final pinned = selection.sources
        .where((source) => source.sourceId == row.sourceId)
        .toList();
    final evidence = registry.lookup(row.sourceId);
    if (pinned.length != 1 ||
        evidence == null ||
        registry.revision.trim().isEmpty ||
        evidence.sourceId != pinned.single.sourceId ||
        evidence.revision != pinned.single.revision ||
        evidence.contentSha256 != pinned.single.sha256 ||
        evidence.approvalId != pinned.single.approvalId ||
        evidence.contentSha256.toLowerCase() !=
            row.documentSha256.toLowerCase() ||
        evidence.jurisdiction != targetJurisdiction ||
        evidence.applicationScope != targetApplicationScope ||
        evidence.subjectCircuitId != selection.circuitId.value ||
        evidence.evidencePurpose != 'manufacturer-coordination' ||
        !evidence.isApproved ||
        evidence.isRevoked) {
      return ManufacturerPairAssessment(checks);
    }
    checks[ManufacturerPairCheck.pinnedManufacturerDocument] =
        PowerSafetyVerdict.pass;

    if (evidence.verifiedManufacturerPairFingerprint != row.fingerprint) {
      return ManufacturerPairAssessment(checks);
    }
    checks[ManufacturerPairCheck.independentCoordinationAttestation] =
        switch (evidence.verifiedSafetyFinding) {
      EngineeringVerifiedSafetyFinding.supported => PowerSafetyVerdict.pass,
      EngineeringVerifiedSafetyFinding.contradicted => PowerSafetyVerdict.fail,
      _ => PowerSafetyVerdict.indeterminate,
    };
    if (checks[ManufacturerPairCheck.independentCoordinationAttestation] !=
        PowerSafetyVerdict.pass) {
      return ManufacturerPairAssessment(checks);
    }

    if (!maximumProspectiveFaultKa.isFinite || maximumProspectiveFaultKa <= 0) {
      return ManufacturerPairAssessment(checks);
    }
    checks[ManufacturerPairCheck.worstCaseFaultCoverage] =
        row.maximumCoveredFaultKa >= maximumProspectiveFaultKa
            ? PowerSafetyVerdict.pass
            : PowerSafetyVerdict.fail;
    return ManufacturerPairAssessment(checks);
  }
}
