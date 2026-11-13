import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../domain/canonical_power_selection.dart';
import 'engineering_evidence_review_gate.dart';
import 'manufacturer_protection_pair_gate.dart';
import 'power_electrical_safety_gate.dart';

/// Implementations must validate publisher identity using an independently
/// configured trust anchor. A URL or a SHA-256 checksum alone proves neither
/// publisher authenticity nor engineering correctness.
abstract interface class ManufacturerPublisherProvenanceVerifier {
  bool verifiesPublisher({
    required Uri documentUri,
    required Uint8List documentBytes,
    required String manufacturerId,
    required String documentSha256,
  });
}

/// Admission receipt is only a proof of successful preflight at the exact
/// trusted registry revision; it never grants engineering Apply.
final class ManufacturerEvidenceAdmission {
  ManufacturerEvidenceAdmission._({
    required this.catalog,
    required this.documentSha256,
    required this.registryRevision,
    required this.publisherUri,
  });

  final ManufacturerCoordinationCatalogSnapshot catalog;
  final String documentSha256;
  final String registryRevision;
  final Uri publisherUri;

  bool get readyToApply => false;
}

/// Deterministic, fail-closed importer. The manufacturer PDF/datasheet bytes
/// are never silently parsed as a selectivity table: a qualified reviewer must
/// separately attest the exact structured table row and revision.
abstract final class ManufacturerEvidenceIngestion {
  static ManufacturerEvidenceAdmission admit({
    required Uint8List documentBytes,
    required Uri publisherUri,
    required ManufacturerProtectionPairRecord reviewedRow,
    required CanonicalPowerCircuitSelection selection,
    required TrustedEngineeringEvidenceRegistry registry,
    required ManufacturerPublisherProvenanceVerifier publisherVerifier,
    required String expectedRegistryRevision,
    required String selectedDownstreamArticleNumber,
    required String selectedUpstreamArticleNumber,
    required String jurisdiction,
    required String applicationScope,
    required double maximumProspectiveFaultKa,
  }) {
    if (documentBytes.isEmpty ||
        publisherUri.scheme != 'https' ||
        publisherUri.host.isEmpty ||
        expectedRegistryRevision.trim().isEmpty ||
        registry.revision != expectedRegistryRevision) {
      throw StateError('Manufacturer document provenance is incomplete.');
    }

    final digest = sha256.convert(documentBytes).toString();
    if (digest != reviewedRow.documentSha256.toLowerCase()) {
      throw StateError('Manufacturer document byte hash differs from review.');
    }
    if (!publisherVerifier.verifiesPublisher(
      documentUri: publisherUri,
      documentBytes: Uint8List.fromList(documentBytes),
      manufacturerId: reviewedRow.downstream.manufacturerId,
      documentSha256: digest,
    )) {
      throw StateError('Manufacturer publisher identity is not authenticated.');
    }

    final assessment = ManufacturerPairEvidenceGate.evaluate(
      selection: selection,
      row: reviewedRow,
      registry: registry,
      selectedDownstreamArticleNumber: selectedDownstreamArticleNumber,
      selectedUpstreamArticleNumber: selectedUpstreamArticleNumber,
      targetJurisdiction: jurisdiction,
      targetApplicationScope: applicationScope,
      maximumProspectiveFaultKa: maximumProspectiveFaultKa,
    );
    if (assessment.verdict != PowerSafetyVerdict.pass ||
        registry.revision != expectedRegistryRevision) {
      throw StateError('Manufacturer coordination row is not qualified.');
    }

    return ManufacturerEvidenceAdmission._(
      catalog: ManufacturerCoordinationCatalogSnapshot(
        revision: expectedRegistryRevision,
        rows: [reviewedRow],
      ),
      documentSha256: digest,
      registryRevision: expectedRegistryRevision,
      publisherUri: publisherUri,
    );
  }
}
