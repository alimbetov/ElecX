import 'electrical_circuit_calculation.dart';
import 'electrical_circuit_synthesis.dart';
import 'electrical_load_calculation.dart';

/// Explicit, evidence-pinned inputs for the read-only P12A POWER starter slice.
///
/// The caller owns the project/board semantic identity, engineering values and
/// normative policies. No residential voltage, power or protection values are
/// inferred from a room name or hidden generator preset.
final class PowerStarterGenerationRequest {
  PowerStarterGenerationRequest({
    required this.projectId,
    required this.boardGenerationKey,
    required this.catalogSnapshotId,
    required this.voltageEvidenceId,
    required this.voltageEvidenceRevision,
    required this.nominalVoltageV,
    required Iterable<CircuitSynthesisLoad> loads,
    required this.groupingPolicy,
    required this.dedicatedCircuitPolicy,
    required this.diversityPolicy,
    required this.reservePolicy,
  }) : loads = List.unmodifiable(loads) {
    for (final value in [
      projectId,
      boardGenerationKey,
      catalogSnapshotId,
      voltageEvidenceId,
      voltageEvidenceRevision,
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError('POWER input identity/evidence must be non-empty.');
      }
    }
    if (!nominalVoltageV.isFinite || nominalVoltageV <= 0) {
      throw ArgumentError.value(nominalVoltageV, 'nominalVoltageV');
    }
    // Reuse the existing duplicate-load and policy validation boundary.
    ElectricalCircuitSynthesisRequest(
      loads: this.loads,
      groupingPolicy: groupingPolicy,
      dedicatedCircuitPolicy: dedicatedCircuitPolicy,
    );
  }

  final String projectId;
  final String boardGenerationKey;
  final String catalogSnapshotId;
  final String voltageEvidenceId;
  final String voltageEvidenceRevision;
  final double nominalVoltageV;
  final List<CircuitSynthesisLoad> loads;
  final CircuitGroupingPolicy groupingPolicy;
  final DedicatedCircuitPolicy dedicatedCircuitPolicy;
  final ElectricalDiversityPolicy diversityPolicy;
  final ElectricalReservePolicy reservePolicy;
}

enum PowerStarterIssueCode {
  boardCatalogSelectionRequired,
  protectiveDeviceEvidenceRequired,
  cableSelectionEvidenceRequired,
  physicalRouteNotYetAvailable,
}

final class PowerStarterIssue {
  const PowerStarterIssue({
    required this.code,
    required this.explanation,
  });

  final PowerStarterIssueCode code;
  final String explanation;
}

/// One ID-free circuit candidate backed by the existing deterministic
/// synthesis and load calculation. The generation key is not a persistent ID.
final class PowerStarterCircuitProposal {
  const PowerStarterCircuitProposal({
    required this.generationKey,
    required this.calculated,
  });

  final String generationKey;
  final CalculatedElectricalCircuit calculated;

  List<String> get loadIds => calculated.circuit.loadIds;
}

/// Pure preview data only: not a ready-to-apply ProjectChangeSet.
///
/// Equipment selection, protective-device coordination, cable sizing and
/// physical routing are deliberately INDETERMINATE until their independent
/// catalog/normative/host evidence is supplied by later P12/P13/P14 slices.
final class PowerStarterCandidate {
  PowerStarterCandidate({
    required this.projectId,
    required this.boardGenerationKey,
    required this.fingerprint,
    required Iterable<PowerStarterCircuitProposal> circuits,
    required Iterable<PowerStarterIssue> issues,
  })  : circuits = List.unmodifiable(circuits),
        issues = List.unmodifiable(issues);

  final String projectId;
  final String boardGenerationKey;
  final String fingerprint;
  final List<PowerStarterCircuitProposal> circuits;
  final List<PowerStarterIssue> issues;

  int get connectedPowerW => circuits.fold<int>(
        0,
        (sum, item) => sum + item.calculated.calculation.connectedPowerW,
      );

  double get designPowerW => circuits.fold<double>(
        0,
        (sum, item) => sum + item.calculated.calculation.designPowerW,
      );

  /// P12A.5 never allocates canonical IDs or mutates a project.
  bool get readyToApply => false;
}
