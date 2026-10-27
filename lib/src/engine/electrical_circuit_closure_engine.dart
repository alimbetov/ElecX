import '../domain/cable_spec.dart';
import '../domain/electrical_circuit_calculation.dart';
import '../domain/electrical_load_calculation.dart';
import '../domain/overcurrent_protection.dart';
import 'cable_sizing_engine.dart';
import 'overcurrent_protection_selection_engine.dart';

const String electricalCircuitClosureVersion = 'electrical.circuit-closure.v1';

final class ElectricalCircuitCableCandidate {
  ElectricalCircuitCableCandidate({
    required this.cable,
    required this.routeLengthMm,
    required this.maxVoltageDropRatio,
    required this.impedanceEvidence,
    required Iterable<SectionAmpacityEvidence> ampacitySections,
    required this.sourceId,
    required this.sourceRevision,
  }) : ampacitySections = List.unmodifiable(ampacitySections) {
    if (!routeLengthMm.isFinite || routeLengthMm < 0) {
      throw ArgumentError.value(routeLengthMm, 'routeLengthMm');
    }
    if (!maxVoltageDropRatio.isFinite ||
        maxVoltageDropRatio <= 0 ||
        maxVoltageDropRatio >= 1) {
      throw ArgumentError.value(maxVoltageDropRatio, 'maxVoltageDropRatio');
    }
    if (sourceId.trim().isEmpty || sourceRevision.trim().isEmpty) {
      throw ArgumentError('Cable candidate provenance must be non-empty.');
    }
  }

  final CableSpec cable;
  final double routeLengthMm;
  final double maxVoltageDropRatio;
  final CableImpedanceEvidence? impedanceEvidence;
  final List<SectionAmpacityEvidence> ampacitySections;
  final String sourceId;
  final String sourceRevision;
}

final class ElectricalCircuitClosurePolicy {
  ElectricalCircuitClosurePolicy({
    required this.circuitId,
    required Iterable<ElectricalCircuitCableCandidate> cableCandidates,
    required this.minimumConductorCount,
    required Set<ConductorMaterial> allowedConductorMaterials,
    required this.minimumCableRatedVoltageV,
    required this.prospectiveShortCircuitCurrentA,
    required Iterable<OvercurrentProtectiveDeviceSpec> protectionCandidates,
    required Set<OvercurrentDeviceKind> allowedProtectionKinds,
    required this.minimumProtectionPoleCount,
    required this.sourceId,
    required this.sourceRevision,
  })  : cableCandidates = List.unmodifiable(cableCandidates),
        allowedConductorMaterials = Set.unmodifiable(allowedConductorMaterials),
        protectionCandidates = List.unmodifiable(protectionCandidates),
        allowedProtectionKinds = Set.unmodifiable(allowedProtectionKinds) {
    if (circuitId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
          'Circuit closure policy identity/source is required.');
    }
    if (minimumConductorCount <= 0) {
      throw ArgumentError.value(minimumConductorCount, 'minimumConductorCount');
    }
    if (this.allowedConductorMaterials.isEmpty) {
      throw ArgumentError('At least one conductor material must be allowed.');
    }
    if (minimumCableRatedVoltageV <= 0) {
      throw ArgumentError.value(
        minimumCableRatedVoltageV,
        'minimumCableRatedVoltageV',
      );
    }
    if (!prospectiveShortCircuitCurrentA.isFinite ||
        prospectiveShortCircuitCurrentA <= 0) {
      throw ArgumentError.value(
        prospectiveShortCircuitCurrentA,
        'prospectiveShortCircuitCurrentA',
      );
    }
    if (this.allowedProtectionKinds.isEmpty) {
      throw ArgumentError(
          'At least one protection device kind must be allowed.');
    }
    if (minimumProtectionPoleCount <= 0) {
      throw ArgumentError.value(
        minimumProtectionPoleCount,
        'minimumProtectionPoleCount',
      );
    }
    _requireUniqueIds(
      values: this.cableCandidates.map((candidate) => candidate.cable.id),
      label: 'cable candidate',
    );
    _requireUniqueIds(
      values: this.protectionCandidates.map((candidate) => candidate.id),
      label: 'protection candidate',
    );
  }

  final String circuitId;
  final List<ElectricalCircuitCableCandidate> cableCandidates;
  final int minimumConductorCount;
  final Set<ConductorMaterial> allowedConductorMaterials;
  final int minimumCableRatedVoltageV;
  final double prospectiveShortCircuitCurrentA;
  final List<OvercurrentProtectiveDeviceSpec> protectionCandidates;
  final Set<OvercurrentDeviceKind> allowedProtectionKinds;
  final int minimumProtectionPoleCount;
  final String sourceId;
  final String sourceRevision;
}

final class ElectricalCircuitClosureRequest {
  ElectricalCircuitClosureRequest({
    required this.calculation,
    required Iterable<ElectricalCircuitClosurePolicy> policies,
  }) : policies = List.unmodifiable(policies) {
    final expectedIds =
        calculation.circuits.map((circuit) => circuit.id).toSet();
    final actualIds = <String>{};
    for (final policy in this.policies) {
      if (!actualIds.add(policy.circuitId)) {
        throw ArgumentError('Duplicate closure policy ${policy.circuitId}.');
      }
      if (!expectedIds.contains(policy.circuitId)) {
        throw ArgumentError(
          'Closure policy references unknown circuit ${policy.circuitId}.',
        );
      }
    }
    final missing = expectedIds.difference(actualIds).toList()..sort();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing closure policy for circuit(s): ${missing.join(', ')}.',
      );
    }
  }

  final ElectricalCircuitCalculationResult calculation;
  final List<ElectricalCircuitClosurePolicy> policies;
}

final class CableCandidateEvaluation {
  CableCandidateEvaluation({
    required this.candidate,
    required Iterable<String> structuralRejections,
    required this.sizing,
  }) : structuralRejections = List.unmodifiable(structuralRejections);

  final ElectricalCircuitCableCandidate candidate;
  final List<String> structuralRejections;
  final CableSizingResult sizing;

  bool get isCompliant => structuralRejections.isEmpty && sizing.isPass;
}

enum ElectricalCircuitClosureStatus {
  closed,
  noCompliantCable,
  noCompliantProtection,
}

final class ElectricalCircuitClosureOutcome {
  ElectricalCircuitClosureOutcome({
    required this.circuit,
    required this.policy,
    required Iterable<CableCandidateEvaluation> cableEvaluations,
    required this.selectedCable,
    required this.selectedCableSizing,
    required this.protectionSelection,
    required Map<String, List<String>> protectionPolicyRejections,
    required this.status,
  })  : cableEvaluations = List.unmodifiable(cableEvaluations),
        protectionPolicyRejections = Map.unmodifiable({
          for (final entry in protectionPolicyRejections.entries)
            entry.key: List.unmodifiable(entry.value),
        }) {
    if (status == ElectricalCircuitClosureStatus.closed &&
        (selectedCable == null ||
            selectedCableSizing == null ||
            protectionSelection?.isSelected != true)) {
      throw ArgumentError(
          'Closed circuit must carry cable/protection evidence.');
    }
  }

  final CalculatedElectricalCircuit circuit;
  final ElectricalCircuitClosurePolicy policy;
  final List<CableCandidateEvaluation> cableEvaluations;
  final ElectricalCircuitCableCandidate? selectedCable;
  final CableSizingResult? selectedCableSizing;
  final OvercurrentProtectionSelectionResult? protectionSelection;
  final Map<String, List<String>> protectionPolicyRejections;
  final ElectricalCircuitClosureStatus status;

  String get circuitId => circuit.id;
  bool get isClosed => status == ElectricalCircuitClosureStatus.closed;

  OvercurrentProtectiveDeviceSpec? get selectedProtection =>
      protectionSelection?.selected;
}

final class ElectricalCircuitClosureResult {
  ElectricalCircuitClosureResult({
    required Iterable<ElectricalCircuitClosureOutcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes) {
    if (this.outcomes.isEmpty) {
      throw ArgumentError('Circuit closure result must not be empty.');
    }
    _requireUniqueIds(
      values: this.outcomes.map((outcome) => outcome.circuitId),
      label: 'closure outcome',
    );
  }

  final List<ElectricalCircuitClosureOutcome> outcomes;

  bool get isFullyClosed => outcomes.every((outcome) => outcome.isClosed);
}

abstract final class ElectricalCircuitClosureEngine {
  static ElectricalCircuitClosureResult close(
    ElectricalCircuitClosureRequest request,
  ) {
    final policies = {
      for (final policy in request.policies) policy.circuitId: policy,
    };
    final circuits = request.calculation.circuits.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final outcomes = <ElectricalCircuitClosureOutcome>[];

    for (final circuit in circuits) {
      final policy = policies[circuit.id]!;
      outcomes.add(_closeCircuit(circuit: circuit, policy: policy));
    }

    return ElectricalCircuitClosureResult(outcomes: outcomes);
  }

  static ElectricalCircuitClosureOutcome _closeCircuit({
    required CalculatedElectricalCircuit circuit,
    required ElectricalCircuitClosurePolicy policy,
  }) {
    final evaluations = <CableCandidateEvaluation>[
      for (final candidate in policy.cableCandidates)
        _evaluateCable(circuit: circuit, policy: policy, candidate: candidate),
    ];
    final compliant = evaluations.where((item) => item.isCompliant).toList()
      ..sort(_compareCableEvaluations);

    if (compliant.isEmpty) {
      return ElectricalCircuitClosureOutcome(
        circuit: circuit,
        policy: policy,
        cableEvaluations: evaluations,
        selectedCable: null,
        selectedCableSizing: null,
        protectionSelection: null,
        protectionPolicyRejections: const {},
        status: ElectricalCircuitClosureStatus.noCompliantCable,
      );
    }

    final selectedCableEvaluation = compliant.first;
    final cableAmpacityA = selectedCableEvaluation.sizing.governingAmpacityA!;
    final policyRejections = <String, List<String>>{};
    final protectionCandidates = <OvercurrentProtectiveDeviceSpec>[];
    for (final candidate in policy.protectionCandidates) {
      final reasons = <String>[];
      if (candidate.poleCount < policy.minimumProtectionPoleCount) {
        reasons.add('pole-count-below-policy-minimum');
      }
      if (reasons.isEmpty) {
        protectionCandidates.add(candidate);
      } else {
        policyRejections[candidate.id] = reasons;
      }
    }

    final protectionSelection = OvercurrentProtectionSelectionEngine.select(
      OvercurrentProtectionRequest(
        designCurrentA: circuit.calculation.designCurrentA,
        cableAmpacityA: cableAmpacityA,
        prospectiveShortCircuitCurrentA: policy.prospectiveShortCircuitCurrentA,
        candidates: protectionCandidates,
        allowedKinds: policy.allowedProtectionKinds,
      ),
    );

    return ElectricalCircuitClosureOutcome(
      circuit: circuit,
      policy: policy,
      cableEvaluations: evaluations,
      selectedCable: selectedCableEvaluation.candidate,
      selectedCableSizing: selectedCableEvaluation.sizing,
      protectionSelection: protectionSelection,
      protectionPolicyRejections: policyRejections,
      status: protectionSelection.isSelected
          ? ElectricalCircuitClosureStatus.closed
          : ElectricalCircuitClosureStatus.noCompliantProtection,
    );
  }

  static CableCandidateEvaluation _evaluateCable({
    required CalculatedElectricalCircuit circuit,
    required ElectricalCircuitClosurePolicy policy,
    required ElectricalCircuitCableCandidate candidate,
  }) {
    final cable = candidate.cable;
    final calculation = circuit.calculation;
    final structuralRejections = <String>[];
    if (!cable.isPower) {
      structuralRejections.add('cable-not-power-rated');
    }
    if (cable.conductorCrossSectionMm2 == null) {
      structuralRejections.add('missing-conductor-cross-section');
    }
    if (cable.conductorCount == null ||
        cable.conductorCount! < policy.minimumConductorCount) {
      structuralRejections.add('conductor-count-below-policy-minimum');
    }
    if (!policy.allowedConductorMaterials.contains(cable.conductorMaterial)) {
      structuralRejections.add('conductor-material-not-allowed');
    }
    if (cable.ratedVoltageV == null ||
        cable.ratedVoltageV! < policy.minimumCableRatedVoltageV) {
      structuralRejections.add('cable-rated-voltage-below-policy-minimum');
    }
    if (cable.ratedVoltageV == null ||
        cable.ratedVoltageV! < calculation.nominalVoltageV) {
      structuralRejections.add('cable-rated-voltage-below-circuit-voltage');
    }

    final reactivePowerKind = calculation.designReactivePowerVar < 0
        ? ElectricalReactivePowerKind.leading
        : ElectricalReactivePowerKind.lagging;
    final sizing = CableSizingEngine.evaluate(
      CableSizingRequest(
        cable: cable,
        requirement: CircuitElectricalRequirement(
          phaseSystem: switch (circuit.phaseSystem) {
            ElectricalLoadPhaseSystem.singlePhaseAc =>
              CircuitPhaseSystem.singlePhaseAc,
            ElectricalLoadPhaseSystem.threePhaseAc =>
              CircuitPhaseSystem.threePhaseAc,
          },
          designCurrentA: calculation.designCurrentA,
          nominalVoltageV: calculation.nominalVoltageV,
          routeLengthMm: candidate.routeLengthMm,
          maxVoltageDropRatio: candidate.maxVoltageDropRatio,
          powerFactor: calculation.equivalentPowerFactor,
          reactivePowerKind: reactivePowerKind,
        ),
        impedanceEvidence: candidate.impedanceEvidence,
        ampacitySections: candidate.ampacitySections,
      ),
    );

    return CableCandidateEvaluation(
      candidate: candidate,
      structuralRejections: structuralRejections,
      sizing: sizing,
    );
  }

  static int _compareCableEvaluations(
    CableCandidateEvaluation left,
    CableCandidateEvaluation right,
  ) {
    final leftCable = left.candidate.cable;
    final rightCable = right.candidate.cable;
    final byCrossSection = leftCable.conductorCrossSectionMm2!
        .compareTo(rightCable.conductorCrossSectionMm2!);
    if (byCrossSection != 0) return byCrossSection;
    final byOuterDiameter =
        leftCable.outerDiameterMm.compareTo(rightCable.outerDiameterMm);
    if (byOuterDiameter != 0) return byOuterDiameter;
    return leftCable.id.compareTo(rightCable.id);
  }
}

void _requireUniqueIds({
  required Iterable<String> values,
  required String label,
}) {
  final ids = <String>{};
  for (final id in values) {
    if (!ids.add(id)) {
      throw ArgumentError('Duplicate $label id $id.');
    }
  }
}
