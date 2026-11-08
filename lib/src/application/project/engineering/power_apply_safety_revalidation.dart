import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation_reservation.dart';
import 'engineering_evidence_review_gate.dart';
import 'power_electrical_safety_gate.dart';
import 'power_fault_envelope_gate.dart';
import 'power_protection_device_gate.dart';

/// Integration boundary for a future *qualified* P12 Apply command.
/// It does not itself grant permission to commit EngineeringReservedProjectCommand:
/// that command intentionally remains PreviewOnlyReservedProjectCommand.
final class PowerApplySafetyRevalidation
    implements TransactionalEngineeringSafetyRevalidation {
  PowerApplySafetyRevalidation({
    required this.expectedRegistryRevision,
    required this.expectedEngineeringStateFingerprint,
    required this.expectedSelectionFingerprint,
    required this.targetJurisdiction,
    required this.targetApplicationScope,
    required this.profile,
    required this.protectionLimits,
    required this.registry,
    required Iterable<PowerCircuitSafetyEvidence> circuitEvidence,
    required Map<CircuitId, PowerCircuitFaultEnvelope> faultEnvelopes,
    required Map<CircuitId, ReviewedResidualDeviceCharacteristic>
        residualDevices,
    required Map<CircuitId, ReviewedProtectionCoordination> coordination,
    required Map<CircuitId, ReviewedEarthingDisconnectionEvidence> earthing,
  })  : circuitEvidence = List.unmodifiable(circuitEvidence),
        faultEnvelopes = Map.unmodifiable(faultEnvelopes),
        residualDevices = Map.unmodifiable(residualDevices),
        coordination = Map.unmodifiable(coordination),
        earthing = Map.unmodifiable(earthing);

  final String expectedRegistryRevision;
  final String expectedEngineeringStateFingerprint;
  final String expectedSelectionFingerprint;
  final String targetJurisdiction;
  final String targetApplicationScope;
  final PowerSafetyRuleProfile profile;
  final PowerProtectionDeviceLimits protectionLimits;
  final TrustedEngineeringEvidenceRegistry registry;
  final List<PowerCircuitSafetyEvidence> circuitEvidence;
  final Map<CircuitId, PowerCircuitFaultEnvelope> faultEnvelopes;
  final Map<CircuitId, ReviewedResidualDeviceCharacteristic> residualDevices;
  final Map<CircuitId, ReviewedProtectionCoordination> coordination;
  final Map<CircuitId, ReviewedEarthingDisconnectionEvidence> earthing;

  @override
  void revalidateEngineeringSafety({
    required ProjectAggregateRoot current,
    required ProjectAggregateRoot candidate,
  }) {
    if (expectedRegistryRevision.trim().isEmpty ||
        registry.revision != expectedRegistryRevision ||
        profile.jurisdiction != targetJurisdiction ||
        profile.applicationScope != targetApplicationScope ||
        current.engineeringMetadata.engineeringState.fingerprint !=
            expectedEngineeringStateFingerprint ||
        candidate.engineeringMetadata.engineeringState.fingerprint !=
            expectedEngineeringStateFingerprint ||
        candidate.engineeringMetadata.powerSelections.fingerprint !=
            expectedSelectionFingerprint) {
      throw StateError('Engineering safety baseline or registry has changed.');
    }

    final selections = candidate.engineeringMetadata.powerSelections;
    final ids = selections.byCircuit.keys.toSet();
    if (ids.isEmpty ||
        circuitEvidence.length != ids.length ||
        circuitEvidence.map((s) => s.circuitId).toSet().length != ids.length ||
        !ids.containsAll(circuitEvidence.map((s) => s.circuitId)) ||
        !_exactKeys(ids, faultEnvelopes.keys.toSet()) ||
        !_exactKeys(ids, residualDevices.keys.toSet()) ||
        !_exactKeys(ids, coordination.keys.toSet()) ||
        !_exactKeys(ids, earthing.keys.toSet())) {
      throw StateError('Incomplete safety evidence for canonical circuits.');
    }

    final quantitative = PowerElectricalSafetyGate.evaluate(
      selections: selections,
      evidence: circuitEvidence,
      profile: profile,
      registry: registry,
      targetJurisdiction: targetJurisdiction,
      targetApplicationScope: targetApplicationScope,
    );
    if (quantitative.verdict != PowerSafetyVerdict.pass) {
      throw StateError('Quantitative electrical safety gate is not qualified.');
    }

    for (final id in ids) {
      final selection = selections.byCircuit[id]!;
      final fault = PowerFaultEnvelopeGate.evaluateForEngineeringState(
        selection: selection,
        engineeringState: candidate.engineeringMetadata.engineeringState,
        envelope: faultEnvelopes[id]!,
        profile: profile,
        registry: registry,
      );
      if (fault.verdict != PowerSafetyVerdict.pass) {
        throw StateError(
            'Supply/fault safety gate is not qualified: ${id.value}.');
      }
      final devices = PowerProtectionDeviceGate.evaluate(
        selection: selection,
        faultEnvelope: faultEnvelopes[id]!,
        faultAssessment: fault,
        residualDevice: residualDevices[id]!,
        coordination: coordination[id]!,
        earthing: earthing[id]!,
        limits: protectionLimits,
        profile: profile,
        registry: registry,
      );
      if (devices.verdict != PowerSafetyVerdict.pass) {
        throw StateError(
            'RCD/ADS/selectivity gate is not qualified: ${id.value}.');
      }
    }

    // Catch registry mutation/revocation during the read-only revalidation.
    // Future production adapters must supply a transactionally consistent,
    // authenticated registry snapshot, not a mutable UI-owned instance.
    if (registry.revision != expectedRegistryRevision) {
      throw StateError('Engineering evidence registry changed during review.');
    }
  }

  static bool _exactKeys(Set<CircuitId> expected, Set<CircuitId> actual) =>
      expected.length == actual.length && expected.containsAll(actual);
}
