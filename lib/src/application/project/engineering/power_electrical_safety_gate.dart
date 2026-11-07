import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/semantic_sha256.dart';
import 'canonical_power_evidence_preflight.dart';
import 'engineering_evidence_review_gate.dart';

/// Results of read-only preliminary calculations, NOT certification or Apply.
enum PowerSafetyVerdict { pass, fail, indeterminate }

enum PowerSafetyCheck {
  normativeApplicability,
  designCurrent,
  overloadRating,
  conventionalTrip,
  breakingCapacity,
  shortCircuitThermal,
  shortCircuitDisconnection,
  residualCurrentProtection,
  selectivity,
}

enum PowerSafetyClaimStatus { supported, contradicted, unknown }

/// Externally reviewed proof of RCD/RCBO protection or selectivity.
/// "supported" is a claim; the source must also match a trusted registry.
final class PowerSafetyClaim {
  const PowerSafetyClaim({
    required this.sourceId,
    required this.status,
  });

  final String sourceId;
  final PowerSafetyClaimStatus status;
}

/// Rule numbers are explicitly supplied by a versioned reviewed profile,
/// never guessed from the jurisdiction name or equipment type.
final class PowerSafetyRuleProfile {
  PowerSafetyRuleProfile({
    required this.normativeSourceId,
    required this.jurisdiction,
    required this.applicationScope,
    required this.maxConventionalTripToAmpacityRatio,
    required this.maxFaultDisconnectionTimeMs,
  }) {
    if (normativeSourceId.trim().isEmpty ||
        jurisdiction.trim().isEmpty ||
        applicationScope.trim().isEmpty ||
        !maxConventionalTripToAmpacityRatio.isFinite ||
        maxConventionalTripToAmpacityRatio <= 0 ||
        !maxFaultDisconnectionTimeMs.isFinite ||
        maxFaultDisconnectionTimeMs <= 0) {
      throw ArgumentError(
          'A complete, versioned normative profile is required.');
    }
  }

  final String normativeSourceId;
  final String jurisdiction;
  final String applicationScope;
  final double maxConventionalTripToAmpacityRatio;
  final double maxFaultDisconnectionTimeMs;
}

/// Inputs may be absent: absence means INDETERMINATE, never assumed success.
/// All source IDs must be pinned by the relevant v21 canonical selection.
final class PowerCircuitSafetyEvidence {
  PowerCircuitSafetyEvidence({
    required this.circuitId,
    required this.selectionFingerprint,
    required this.calculationSourceId,
    this.designCurrentA,
    this.prospectiveFaultCurrentKa,
    this.conventionalTripCurrentA,
    this.protectiveDeviceLetThroughA2s,
    this.cableShortCircuitWithstandA2s,
    this.faultDisconnectionTimeMs,
    this.residualCurrentProof,
    this.selectivityProof,
  }) {
    if (selectionFingerprint.trim().isEmpty ||
        calculationSourceId.trim().isEmpty) {
      throw ArgumentError('Frozen circuit evidence identity is required.');
    }
    for (final value in [
      designCurrentA,
      prospectiveFaultCurrentKa,
      conventionalTripCurrentA,
      protectiveDeviceLetThroughA2s,
      cableShortCircuitWithstandA2s,
      faultDisconnectionTimeMs,
    ]) {
      if (value != null && (!value.isFinite || value <= 0)) {
        throw ArgumentError(
            'Electrical safety inputs must be positive and finite.');
      }
    }
  }

  final CircuitId circuitId;
  final String selectionFingerprint;
  final String calculationSourceId;
  final double? designCurrentA;
  final double? prospectiveFaultCurrentKa;
  final double? conventionalTripCurrentA;
  final double? protectiveDeviceLetThroughA2s;
  final double? cableShortCircuitWithstandA2s;
  final double? faultDisconnectionTimeMs;
  final PowerSafetyClaim? residualCurrentProof;
  final PowerSafetyClaim? selectivityProof;
}

final class PowerCircuitSafetyAssessment {
  PowerCircuitSafetyAssessment({
    required this.circuitId,
    required Map<PowerSafetyCheck, PowerSafetyVerdict> checks,
  }) : checks = Map.unmodifiable(checks);

  final CircuitId circuitId;
  final Map<PowerSafetyCheck, PowerSafetyVerdict> checks;

  PowerSafetyVerdict get verdict {
    if (checks.values.contains(PowerSafetyVerdict.fail)) {
      return PowerSafetyVerdict.fail;
    }
    if (checks.length != PowerSafetyCheck.values.length ||
        checks.values.contains(PowerSafetyVerdict.indeterminate)) {
      return PowerSafetyVerdict.indeterminate;
    }
    return PowerSafetyVerdict.pass;
  }
}

final class PowerElectricalSafetyReport {
  PowerElectricalSafetyReport({
    required this.evidenceRegistryRevision,
    required Iterable<EngineeringEvidenceReviewIssue> sourceIssues,
    required Map<CircuitId, PowerCircuitSafetyAssessment> circuits,
  })  : sourceIssues = List.unmodifiable(sourceIssues),
        circuits = Map.unmodifiable(circuits);

  final String evidenceRegistryRevision;
  final List<EngineeringEvidenceReviewIssue> sourceIssues;
  final Map<CircuitId, PowerCircuitSafetyAssessment> circuits;

  PowerSafetyVerdict get verdict {
    if (circuits.isEmpty ||
        sourceIssues.isNotEmpty ||
        circuits.values
            .any((c) => c.verdict == PowerSafetyVerdict.indeterminate)) {
      if (circuits.values.any((c) => c.verdict == PowerSafetyVerdict.fail)) {
        return PowerSafetyVerdict.fail;
      }
      return PowerSafetyVerdict.indeterminate;
    }
    if (circuits.values.any((c) => c.verdict == PowerSafetyVerdict.fail)) {
      return PowerSafetyVerdict.fail;
    }
    return PowerSafetyVerdict.pass;
  }

  /// This gate cannot grant Apply, even when all preliminary checks pass.
  /// Production release needs verified rule extraction, multiple supply/fault
  /// scenarios, coordination review and transaction-bound revalidation.
  bool get readyToApply => false;
}

/// Explicitly provisional safety checks over existing P11/v21 equipment.
/// A registry verifies source pins; it does not certify numerical rule content.
abstract final class PowerElectricalSafetyGate {
  static PowerElectricalSafetyReport evaluate({
    required CanonicalPowerSelectionRegistry selections,
    required Iterable<PowerCircuitSafetyEvidence> evidence,
    required PowerSafetyRuleProfile profile,
    required TrustedEngineeringEvidenceRegistry registry,
    required String targetJurisdiction,
    required String targetApplicationScope,
  }) {
    final reviewed = CanonicalPowerEvidencePreflight.evaluate(
      selections: selections,
      registry: registry,
      jurisdiction: targetJurisdiction,
      applicationScope: targetApplicationScope,
    );
    final evidenceList = evidence.toList();
    final evidenceByCircuit = <CircuitId, PowerCircuitSafetyEvidence>{};
    final duplicateCircuits = <CircuitId>{};
    for (final item in evidenceList) {
      if (evidenceByCircuit.containsKey(item.circuitId)) {
        duplicateCircuits.add(item.circuitId);
      }
      evidenceByCircuit[item.circuitId] = item;
    }
    final unknown = evidenceByCircuit.keys
        .where((id) => !selections.byCircuit.containsKey(id));
    if (unknown.isNotEmpty || duplicateCircuits.isNotEmpty) {
      throw ArgumentError('Duplicate or unknown safety evidence circuit ID.');
    }

    final result = <CircuitId, PowerCircuitSafetyAssessment>{};
    final ids = selections.byCircuit.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final id in ids) {
      final selection = selections.byCircuit[id]!;
      final input = evidenceByCircuit[id];
      final pins = {for (final pin in selection.sources) pin.sourceId};
      final profileMatches =
          profile.jurisdiction == targetJurisdiction &&
              profile.applicationScope == targetApplicationScope &&
              selection.normativeSourceId == profile.normativeSourceId &&
              pins.contains(profile.normativeSourceId) &&
              reviewed.isQualified;
      final matchedSelection = input != null &&
          input.selectionFingerprint ==
              semanticSha256Hex(jsonEncode(selection.toCanonicalJson())) &&
          pins.contains(input.calculationSourceId) &&
          reviewed.isQualified;
      final sourceValid = matchedSelection &&
          _reviewedSource(input.calculationSourceId, registry, profile);
      final checks = <PowerSafetyCheck, PowerSafetyVerdict>{
        PowerSafetyCheck.normativeApplicability: profileMatches
            ? PowerSafetyVerdict.pass
            : PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.designCurrent: PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.overloadRating: PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.conventionalTrip: PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.breakingCapacity: PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.shortCircuitThermal: PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.shortCircuitDisconnection:
            PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.residualCurrentProtection:
            PowerSafetyVerdict.indeterminate,
        PowerSafetyCheck.selectivity: PowerSafetyVerdict.indeterminate,
      };
      if (input != null && sourceValid) {
        final ib = input.designCurrentA;
        final iz = selection.cableRatings.governingAmpacityA;
        final rated = selection.protectionRatings.ratedCurrentA;
        if (ib != null) {
          checks[PowerSafetyCheck.designCurrent] =
              ib <= iz ? PowerSafetyVerdict.pass : PowerSafetyVerdict.fail;
          checks[PowerSafetyCheck.overloadRating] = ib <= rated && rated <= iz
              ? PowerSafetyVerdict.pass
              : PowerSafetyVerdict.fail;
        }
        final i2 = input.conventionalTripCurrentA;
        if (i2 != null) {
          checks[PowerSafetyCheck.conventionalTrip] =
              i2 <= profile.maxConventionalTripToAmpacityRatio * iz
                  ? PowerSafetyVerdict.pass
                  : PowerSafetyVerdict.fail;
        }
        final fault = input.prospectiveFaultCurrentKa;
        if (fault != null) {
          checks[PowerSafetyCheck.breakingCapacity] =
              fault <= selection.protectionRatings.breakingCapacityKa
                  ? PowerSafetyVerdict.pass
                  : PowerSafetyVerdict.fail;
        }
        final deviceEnergy = input.protectiveDeviceLetThroughA2s;
        final cableEnergy = input.cableShortCircuitWithstandA2s;
        if (deviceEnergy != null && cableEnergy != null) {
          checks[PowerSafetyCheck.shortCircuitThermal] =
              deviceEnergy <= cableEnergy
                  ? PowerSafetyVerdict.pass
                  : PowerSafetyVerdict.fail;
        }
        final faultTime = input.faultDisconnectionTimeMs;
        if (faultTime != null) {
          checks[PowerSafetyCheck.shortCircuitDisconnection] =
              faultTime <= profile.maxFaultDisconnectionTimeMs
                  ? PowerSafetyVerdict.pass
                  : PowerSafetyVerdict.fail;
        }
        checks[PowerSafetyCheck.residualCurrentProtection] = _claim(
          input.residualCurrentProof,
          pins,
          registry,
          profile,
          id,
          'rcd-protection',
        );
        checks[PowerSafetyCheck.selectivity] = _claim(
          input.selectivityProof,
          pins,
          registry,
          profile,
          id,
          'selectivity-coordination',
        );
      }
      result[id] = PowerCircuitSafetyAssessment(
        circuitId: id,
        checks: checks,
      );
    }
    return PowerElectricalSafetyReport(
      evidenceRegistryRevision: reviewed.registryRevision,
      sourceIssues: reviewed.issues,
      circuits: result,
    );
  }

  static PowerSafetyVerdict _claim(
    PowerSafetyClaim? claim,
    Set<String> pinnedSources,
    TrustedEngineeringEvidenceRegistry registry,
    PowerSafetyRuleProfile profile,
    CircuitId circuitId,
    String requiredPurpose,
  ) {
    if (claim == null ||
        !pinnedSources.contains(claim.sourceId) ||
        !_reviewedSource(claim.sourceId, registry, profile)) {
      return PowerSafetyVerdict.indeterminate;
    }
    final reviewed = registry.lookup(claim.sourceId);
    if (reviewed == null ||
        reviewed.evidencePurpose != requiredPurpose ||
        reviewed.subjectCircuitId != circuitId.value) {
      return PowerSafetyVerdict.indeterminate;
    }
    return switch (claim.status) {
      PowerSafetyClaimStatus.supported => PowerSafetyVerdict.pass,
      PowerSafetyClaimStatus.contradicted => PowerSafetyVerdict.fail,
      PowerSafetyClaimStatus.unknown => PowerSafetyVerdict.indeterminate,
    };
  }

  static bool _reviewedSource(
    String sourceId,
    TrustedEngineeringEvidenceRegistry registry,
    PowerSafetyRuleProfile profile,
  ) {
    final record = registry.lookup(sourceId);
    return record != null &&
        record.sourceId == sourceId &&
        record.isApproved &&
        !record.isRevoked &&
        record.jurisdiction == profile.jurisdiction &&
        record.applicationScope == profile.applicationScope;
  }
}
