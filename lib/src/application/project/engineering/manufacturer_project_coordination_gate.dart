import 'dart:convert';

import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/semantic_sha256.dart';
import 'engineering_evidence_review_gate.dart';
import 'manufacturer_evidence_ingestion.dart';
import 'manufacturer_protection_pair_gate.dart';
import 'power_electrical_safety_gate.dart';
import 'power_fault_envelope_gate.dart';

/// Project-level R1 preflight. This binds reviewed manufacturer articles to
/// the *persisted* v22 group RCD and actual canonical P11 circuit identities.
/// Neither an admission receipt nor an in-memory catalog authorizes Apply.
final class ManufacturerProjectCoordinationAssessment {
  ManufacturerProjectCoordinationAssessment(
    Map<CircuitId, PowerSafetyVerdict> values,
  ) : circuits = Map.unmodifiable(values);

  final Map<CircuitId, PowerSafetyVerdict> circuits;

  PowerSafetyVerdict get verdict {
    if (circuits.values.contains(PowerSafetyVerdict.fail)) {
      return PowerSafetyVerdict.fail;
    }
    if (circuits.isEmpty ||
        circuits.values.contains(PowerSafetyVerdict.indeterminate)) {
      return PowerSafetyVerdict.indeterminate;
    }
    return PowerSafetyVerdict.pass;
  }

  bool get readyToApply => false;
}

abstract final class ManufacturerProjectCoordinationGate {
  static ManufacturerProjectCoordinationAssessment evaluate({
    required ProjectAggregateRoot project,
    required TrustedEngineeringEvidenceRegistry registry,
    required String expectedRegistryRevision,
    required String expectedEngineeringStateFingerprint,
    required String expectedPowerSelectionFingerprint,
    required String expectedResidualProtectionFingerprint,
    required Map<CircuitId, ManufacturerEvidenceAdmission> admissions,
    required Map<CircuitId, PowerCircuitFaultEnvelope> faultEnvelopes,
    required String jurisdiction,
    required String applicationScope,
  }) {
    final metadata = project.engineeringMetadata;
    final assignments = metadata.residualProtection.assignments;
    final covered = <CircuitId, String>{};
    for (final assignment in assignments) {
      for (final id in assignment.protectedCircuitIds) {
        covered[id] = assignment.upstreamResidualCatalogId;
      }
    }
    final checks = <CircuitId, PowerSafetyVerdict>{
      for (final id in covered.keys) id: PowerSafetyVerdict.indeterminate,
    };
    if (registry.revision != expectedRegistryRevision ||
        expectedRegistryRevision.trim().isEmpty ||
        metadata.engineeringState.fingerprint !=
            expectedEngineeringStateFingerprint ||
        metadata.powerSelections.fingerprint !=
            expectedPowerSelectionFingerprint ||
        metadata.residualProtection.fingerprint !=
            expectedResidualProtectionFingerprint ||
        checks.isEmpty ||
        admissions.length != checks.length ||
        faultEnvelopes.length != checks.length ||
        !checks.keys.toSet().containsAll(admissions.keys) ||
        !checks.keys.toSet().containsAll(faultEnvelopes.keys)) {
      return ManufacturerProjectCoordinationAssessment(checks);
    }

    for (final entry in covered.entries) {
      final id = entry.key;
      final selected = metadata.powerSelections.byCircuit[id];
      final admission = admissions[id];
      final fault = faultEnvelopes[id];
      if (selected == null || admission == null || fault == null ||
          fault.circuitId != id ||
          fault.selectionFingerprint !=
              semanticSha256Hex(jsonEncode(selected.toCanonicalJson())) ||
          admission.registryRevision != expectedRegistryRevision ||
          admission.catalog.rows.length != 1 ||
          admission.documentSha256 !=
              admission.catalog.rows.single.documentSha256.toLowerCase()) {
        continue;
      }
      final row = admission.catalog.rows.single;
      if (row.upstream.articleNumber != entry.value ||
          row.downstream.articleNumber != selected.protectionCatalogId) {
        continue;
      }
      final maxFault = fault.scenarios
          .map((scenario) => scenario.maximumProspectiveFaultKa)
          .reduce((a, b) => a > b ? a : b);
      final assessment = ManufacturerPairEvidenceGate.evaluate(
        selection: selected,
        row: row,
        registry: registry,
        selectedDownstreamArticleNumber: selected.protectionCatalogId,
        selectedUpstreamArticleNumber: entry.value,
        targetJurisdiction: jurisdiction,
        targetApplicationScope: applicationScope,
        maximumProspectiveFaultKa: maxFault,
      );
      checks[id] = assessment.verdict;
    }
    if (registry.revision != expectedRegistryRevision) {
      return ManufacturerProjectCoordinationAssessment({
        for (final id in checks.keys) id: PowerSafetyVerdict.indeterminate,
      });
    }
    return ManufacturerProjectCoordinationAssessment(checks);
  }
}
