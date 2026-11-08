import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/semantic_sha256.dart';
import 'engineering_evidence_review_gate.dart';
import 'power_electrical_safety_gate.dart';

/// One source-of-supply case. Both extremes are required; an optimistic
/// nominal fault current is never sufficient for protection review.
final class PowerSupplyFaultScenario {
  PowerSupplyFaultScenario({
    required this.supplyId,
    required this.maximumProspectiveFaultKa,
    required this.minimumProspectiveFaultKa,
    required this.maximumLetThroughA2s,
    required this.cableWithstandA2s,
    required this.minimumFaultClearingTimeMs,
  }) {
    if (supplyId.trim().isEmpty ||
        !maximumProspectiveFaultKa.isFinite ||
        !minimumProspectiveFaultKa.isFinite ||
        !maximumLetThroughA2s.isFinite ||
        !cableWithstandA2s.isFinite ||
        !minimumFaultClearingTimeMs.isFinite ||
        minimumProspectiveFaultKa <= 0 ||
        maximumProspectiveFaultKa < minimumProspectiveFaultKa ||
        maximumLetThroughA2s <= 0 ||
        cableWithstandA2s <= 0 ||
        minimumFaultClearingTimeMs <= 0) {
      throw ArgumentError('Complete and ordered max/min fault evidence required.');
    }
  }

  final String supplyId;
  final double maximumProspectiveFaultKa;
  final double minimumProspectiveFaultKa;
  final double maximumLetThroughA2s;
  final double cableWithstandA2s;
  final double minimumFaultClearingTimeMs;

  List<Object> get canonical => [
        supplyId,
        maximumProspectiveFaultKa,
        minimumProspectiveFaultKa,
        maximumLetThroughA2s,
        cableWithstandA2s,
        minimumFaultClearingTimeMs,
      ];
}

/// Frozen collection of *all* known supply cases, not one favorable case.
/// The authenticated registry attests the complete numerical envelope.
final class PowerCircuitFaultEnvelope {
  PowerCircuitFaultEnvelope({
    required this.circuitId,
    required this.selectionFingerprint,
    required this.sourceId,
    required Iterable<PowerSupplyFaultScenario> scenarios,
  }) : scenarios = List.unmodifiable(
          scenarios.toList()..sort((a, b) => a.supplyId.compareTo(b.supplyId)),
        ) {
    if (selectionFingerprint.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        this.scenarios.isEmpty ||
        this.scenarios.map((s) => s.supplyId).toSet().length !=
            this.scenarios.length) {
      throw ArgumentError('Unique, non-empty supply fault scenarios required.');
    }
  }

  final CircuitId circuitId;
  final String selectionFingerprint;
  final String sourceId;
  final List<PowerSupplyFaultScenario> scenarios;

  String get fingerprint => semanticSha256Hex(jsonEncode([
        'p12a8.power-fault-envelope.v1',
        circuitId.value,
        selectionFingerprint,
        sourceId,
        [for (final item in scenarios) item.canonical],
      ]));
}

enum PowerFaultEnvelopeCheck {
  trustedEnvelope,
  completeSupplyCoverage,
  maximumBreakingCapacity,
  maximumBoardWithstand,
  maximumThermalEnergy,
  minimumFaultDisconnection,
}

/// Only read-only PREVIEW evidence; it never certifies protective coordination.
final class PowerFaultEnvelopeAssessment {
  PowerFaultEnvelopeAssessment(Map<PowerFaultEnvelopeCheck, PowerSafetyVerdict> results)
      : checks = Map.unmodifiable(results);

  final Map<PowerFaultEnvelopeCheck, PowerSafetyVerdict> checks;

  PowerSafetyVerdict get verdict {
    if (checks.values.contains(PowerSafetyVerdict.fail)) {
      return PowerSafetyVerdict.fail;
    }
    if (checks.length != PowerFaultEnvelopeCheck.values.length ||
        checks.values.contains(PowerSafetyVerdict.indeterminate)) {
      return PowerSafetyVerdict.indeterminate;
    }
    return PowerSafetyVerdict.pass;
  }

  bool get readyToApply => false;
}

/// The caller must supply an independent exhaustive list of expected supply
/// IDs sourced from the canonical topology, not derived from the envelope.
/// The trusted registry must attest the exact envelope fingerprint.
abstract final class PowerFaultEnvelopeGate {
  static PowerFaultEnvelopeAssessment evaluate({
    required CanonicalPowerCircuitSelection selection,
    required PowerCircuitFaultEnvelope envelope,
    required Iterable<String> expectedSupplyIds,
    required PowerSafetyRuleProfile profile,
    required TrustedEngineeringEvidenceRegistry registry,
  }) {
    final results = <PowerFaultEnvelopeCheck, PowerSafetyVerdict>{
      for (final check in PowerFaultEnvelopeCheck.values)
        check: PowerSafetyVerdict.indeterminate,
    };
    final expected = expectedSupplyIds.toSet();
    final observed = envelope.scenarios.map((s) => s.supplyId).toSet();
    if (expected.isEmpty ||
        expected.length != expectedSupplyIds.length ||
        expected.any((s) => s.trim().isEmpty) ||
        expected.length != observed.length ||
        !expected.containsAll(observed)) {
      return PowerFaultEnvelopeAssessment(results);
    }
    results[PowerFaultEnvelopeCheck.completeSupplyCoverage] =
        PowerSafetyVerdict.pass;

    final selectedFingerprint =
        semanticSha256Hex(jsonEncode(selection.toCanonicalJson()));
    final pinned = {
      for (final source in selection.sources) source.sourceId: source
    };
    final pinnedSource = pinned[envelope.sourceId];
    final record = registry.lookup(envelope.sourceId);
    final matched = envelope.circuitId == selection.circuitId &&
        envelope.selectionFingerprint == selectedFingerprint &&
        pinnedSource != null &&
        record != null &&
        record.sourceId == pinnedSource.sourceId &&
        record.revision == pinnedSource.revision &&
        record.contentSha256 == pinnedSource.sha256 &&
        record.approvalId == pinnedSource.approvalId &&
        record.isApproved &&
        !record.isRevoked &&
        record.jurisdiction == profile.jurisdiction &&
        record.applicationScope == profile.applicationScope &&
        record.subjectCircuitId == selection.circuitId.value &&
        record.evidencePurpose == 'fault-envelope' &&
        record.verifiedCalculationFingerprint == envelope.fingerprint &&
        registry.revision.trim().isNotEmpty;
    if (!matched) return PowerFaultEnvelopeAssessment(results);

    results[PowerFaultEnvelopeCheck.trustedEnvelope] = PowerSafetyVerdict.pass;
    final maximum = envelope.scenarios
        .map((s) => s.maximumProspectiveFaultKa)
        .reduce((a, b) => a > b ? a : b);
    results[PowerFaultEnvelopeCheck.maximumBreakingCapacity] =
        maximum <= selection.protectionRatings.breakingCapacityKa
            ? PowerSafetyVerdict.pass
            : PowerSafetyVerdict.fail;
    results[PowerFaultEnvelopeCheck.maximumBoardWithstand] =
        maximum <= selection.boardRatings.shortCircuitWithstandKa
            ? PowerSafetyVerdict.pass
            : PowerSafetyVerdict.fail;
    results[PowerFaultEnvelopeCheck.maximumThermalEnergy] =
        envelope.scenarios.every(
          (s) => s.maximumLetThroughA2s <= s.cableWithstandA2s,
        )
            ? PowerSafetyVerdict.pass
            : PowerSafetyVerdict.fail;

    // The minimum fault current determines whether automatic disconnection
    // is sufficiently fast for each supply case, not the maximum fault alone.
    results[PowerFaultEnvelopeCheck.minimumFaultDisconnection] =
        envelope.scenarios.every(
          (s) => s.minimumFaultClearingTimeMs <=
              profile.maxFaultDisconnectionTimeMs,
        )
            ? PowerSafetyVerdict.pass
            : PowerSafetyVerdict.fail;
    return PowerFaultEnvelopeAssessment(results);
  }
}
