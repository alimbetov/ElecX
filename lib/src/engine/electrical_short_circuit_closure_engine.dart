import 'dart:math' as math;

import 'cable_sizing_engine.dart';
import 'electrical_circuit_closure_engine.dart';

const String electricalShortCircuitClosureVersion =
    'electrical.short-circuit-closure.v3';

/// One source-pinned fault-loop case.
///
/// The case carries the voltage and complex impedance evidence needed for a
/// phase-to-PE/PEN fault. D4 deliberately does not infer PE/PEN impedance from
/// the phase conductor or derive phase-to-earth voltage from a line voltage.
/// [cableId] binds the impedance evidence to the exact D3-selected cable.
final class FaultLoopCaseEvidence {
  FaultLoopCaseEvidence({
    required this.id,
    required this.cableId,
    required this.faultVoltageV,
    required this.sourceResistanceOhm,
    required this.sourceReactanceOhm,
    required this.phaseResistanceOhmPerKm,
    required this.phaseReactanceOhmPerKm,
    required this.protectiveResistanceOhmPerKm,
    required this.protectiveReactanceOhmPerKm,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (id.trim().isEmpty ||
        cableId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Fault-loop identity/cable/source must be non-empty.',
      );
    }
    if (!faultVoltageV.isFinite || faultVoltageV <= 0) {
      throw ArgumentError.value(faultVoltageV, 'faultVoltageV');
    }
    final impedanceValues = [
      sourceResistanceOhm,
      sourceReactanceOhm,
      phaseResistanceOhmPerKm,
      phaseReactanceOhmPerKm,
      protectiveResistanceOhmPerKm,
      protectiveReactanceOhmPerKm,
    ];
    if (impedanceValues.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError(
        'Fault-loop impedance values must be finite and >= 0.',
      );
    }
    if (impedanceValues.every((value) => value == 0)) {
      throw ArgumentError('Fault-loop impedance evidence cannot be all zero.');
    }
  }

  final String id;
  final String cableId;
  final double faultVoltageV;
  final double sourceResistanceOhm;
  final double sourceReactanceOhm;
  final double phaseResistanceOhmPerKm;
  final double phaseReactanceOhmPerKm;
  final double protectiveResistanceOhmPerKm;
  final double protectiveReactanceOhmPerKm;
  final String sourceId;
  final String sourceRevision;
}

/// Certified time-current upper bound.
///
/// The point means that for every fault current >= [minimumFaultCurrentA], the
/// protective device operates in no more than [maximumOperatingTimeS]. D4 does
/// not interpolate manufacturer curves between points.
final class TimeCurrentUpperBoundPoint {
  const TimeCurrentUpperBoundPoint({
    required this.minimumFaultCurrentA,
    required this.maximumOperatingTimeS,
  })  : assert(minimumFaultCurrentA > 0),
        assert(maximumOperatingTimeS > 0);

  final double minimumFaultCurrentA;
  final double maximumOperatingTimeS;
}

final class ProtectiveDeviceTimeCurrentEvidence {
  ProtectiveDeviceTimeCurrentEvidence({
    required this.deviceId,
    required Iterable<TimeCurrentUpperBoundPoint> points,
    required this.sourceId,
    required this.sourceRevision,
  }) : points = List.unmodifiable(
          points.toList()
            ..sort(
              (left, right) => left.minimumFaultCurrentA
                  .compareTo(right.minimumFaultCurrentA),
            ),
        ) {
    if (deviceId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Time-current evidence identity/source must be non-empty.',
      );
    }
    if (this.points.isEmpty) {
      throw ArgumentError('Time-current evidence must contain upper bounds.');
    }
    for (var index = 0; index < this.points.length; index++) {
      final point = this.points[index];
      if (!point.minimumFaultCurrentA.isFinite ||
          point.minimumFaultCurrentA <= 0 ||
          !point.maximumOperatingTimeS.isFinite ||
          point.maximumOperatingTimeS <= 0) {
        throw ArgumentError('Invalid time-current upper-bound point.');
      }
      if (index == 0) continue;
      final previous = this.points[index - 1];
      if (point.minimumFaultCurrentA <= previous.minimumFaultCurrentA) {
        throw ArgumentError(
          'Time-current thresholds must be strictly increasing.',
        );
      }
      if (point.maximumOperatingTimeS > previous.maximumOperatingTimeS) {
        throw ArgumentError(
          'Time-current upper bounds must be non-increasing with current.',
        );
      }
    }
  }

  final String deviceId;
  final List<TimeCurrentUpperBoundPoint> points;
  final String sourceId;
  final String sourceRevision;

  double? maximumOperatingTimeAt(double faultCurrentA) {
    TimeCurrentUpperBoundPoint? applicable;
    for (final point in points) {
      if (faultCurrentA < point.minimumFaultCurrentA) break;
      applicable = point;
    }
    return applicable?.maximumOperatingTimeS;
  }
}

/// Adiabatic thermal-withstand evidence for the protective conductor involved
/// in the evaluated fault loop.
final class ProtectiveConductorThermalEvidence {
  ProtectiveConductorThermalEvidence({
    required this.cableId,
    required this.crossSectionMm2,
    required this.kCoefficientArootSPerMm2,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (cableId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Protective-conductor thermal evidence identity/source must be non-empty.',
      );
    }
    if (!crossSectionMm2.isFinite || crossSectionMm2 <= 0) {
      throw ArgumentError.value(crossSectionMm2, 'crossSectionMm2');
    }
    if (!kCoefficientArootSPerMm2.isFinite || kCoefficientArootSPerMm2 <= 0) {
      throw ArgumentError.value(
        kCoefficientArootSPerMm2,
        'kCoefficientArootSPerMm2',
      );
    }
  }

  final String cableId;
  final double crossSectionMm2;
  final double kCoefficientArootSPerMm2;
  final String sourceId;
  final String sourceRevision;

  double get thermalCapacityA2s =>
      math.pow(kCoefficientArootSPerMm2 * crossSectionMm2, 2).toDouble();
}

/// D4 policy for one D3-closed circuit.
///
/// The disconnection and thermal cases are intentionally independent. ADS is
/// evaluated with the minimum credible fault-current case, while thermal stress
/// can use a separate maximum-stress case. Reusing one implicit Ik for both is
/// not allowed by this model.
final class ElectricalShortCircuitClosurePolicy {
  ElectricalShortCircuitClosurePolicy({
    required this.circuitId,
    required this.disconnectionFaultCase,
    required this.thermalFaultCase,
    required this.requiredMaxDisconnectionTimeS,
    required this.timeCurrentEvidence,
    required this.thermalEvidence,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (circuitId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError('D4 policy identity/source must be non-empty.');
    }
    final requiredTime = requiredMaxDisconnectionTimeS;
    if (requiredTime != null && (!requiredTime.isFinite || requiredTime <= 0)) {
      throw ArgumentError.value(
        requiredMaxDisconnectionTimeS,
        'requiredMaxDisconnectionTimeS',
      );
    }
  }

  final String circuitId;
  final FaultLoopCaseEvidence? disconnectionFaultCase;
  final FaultLoopCaseEvidence? thermalFaultCase;
  final double? requiredMaxDisconnectionTimeS;
  final ProtectiveDeviceTimeCurrentEvidence? timeCurrentEvidence;
  final ProtectiveConductorThermalEvidence? thermalEvidence;
  final String sourceId;
  final String sourceRevision;
}

final class ElectricalShortCircuitClosureRequest {
  ElectricalShortCircuitClosureRequest({
    required this.d3Closure,
    required Iterable<ElectricalShortCircuitClosurePolicy> policies,
  }) : policies = List.unmodifiable(policies) {
    if (!d3Closure.isFullyClosed) {
      throw ArgumentError('D4 requires a fully closed D3 result.');
    }
    final expectedIds =
        d3Closure.outcomes.map((item) => item.circuitId).toSet();
    final actualIds = <String>{};
    for (final policy in this.policies) {
      if (!actualIds.add(policy.circuitId)) {
        throw ArgumentError('Duplicate D4 policy ${policy.circuitId}.');
      }
      if (!expectedIds.contains(policy.circuitId)) {
        throw ArgumentError(
          'D4 policy references unknown circuit ${policy.circuitId}.',
        );
      }
    }
    final missing = expectedIds.difference(actualIds).toList()..sort();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing D4 policy for circuit(s): ${missing.join(', ')}.',
      );
    }
  }

  final ElectricalCircuitClosureResult d3Closure;
  final List<ElectricalShortCircuitClosurePolicy> policies;
}

final class FaultLoopCalculationResult {
  const FaultLoopCalculationResult({
    required this.caseId,
    required this.routeLengthMm,
    required this.loopResistanceOhm,
    required this.loopReactanceOhm,
    required this.loopImpedanceOhm,
    required this.faultCurrentA,
  });

  final String caseId;
  final double routeLengthMm;
  final double loopResistanceOhm;
  final double loopReactanceOhm;
  final double loopImpedanceOhm;
  final double faultCurrentA;
}

final class ElectricalShortCircuitClosureOutcome {
  ElectricalShortCircuitClosureOutcome({
    required this.d3Outcome,
    required this.policy,
    required this.disconnectionFault,
    required this.thermalFault,
    required this.disconnectionOperatingTimeS,
    required this.thermalOperatingTimeS,
    required this.faultEnergyA2s,
    required this.thermalCapacityA2s,
    required this.upstreamConsistencyStatus,
    required this.disconnectionStatus,
    required this.thermalStatus,
    required Iterable<String> reasons,
  }) : reasons = List.unmodifiable(reasons);

  final ElectricalCircuitClosureOutcome d3Outcome;
  final ElectricalShortCircuitClosurePolicy policy;
  final FaultLoopCalculationResult? disconnectionFault;
  final FaultLoopCalculationResult? thermalFault;
  final double? disconnectionOperatingTimeS;
  final double? thermalOperatingTimeS;
  final double? faultEnergyA2s;
  final double? thermalCapacityA2s;
  final EngineeringCheckStatus upstreamConsistencyStatus;
  final EngineeringCheckStatus disconnectionStatus;
  final EngineeringCheckStatus thermalStatus;
  final List<String> reasons;

  String get circuitId => d3Outcome.circuitId;

  bool get isClosed =>
      upstreamConsistencyStatus == EngineeringCheckStatus.pass &&
      disconnectionStatus == EngineeringCheckStatus.pass &&
      thermalStatus == EngineeringCheckStatus.pass;
}

final class ElectricalShortCircuitClosureResult {
  ElectricalShortCircuitClosureResult({
    required Iterable<ElectricalShortCircuitClosureOutcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes) {
    if (this.outcomes.isEmpty) {
      throw ArgumentError('D4 result must contain circuit outcomes.');
    }
    final ids = <String>{};
    for (final outcome in this.outcomes) {
      if (!ids.add(outcome.circuitId)) {
        throw ArgumentError('Duplicate D4 outcome ${outcome.circuitId}.');
      }
    }
  }

  final List<ElectricalShortCircuitClosureOutcome> outcomes;

  bool get isFullyClosed => outcomes.every((outcome) => outcome.isClosed);
}

abstract final class ElectricalShortCircuitClosureEngine {
  static ElectricalShortCircuitClosureResult close(
    ElectricalShortCircuitClosureRequest request,
  ) {
    final policies = {
      for (final policy in request.policies) policy.circuitId: policy,
    };
    final d3Outcomes = request.d3Closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));

    return ElectricalShortCircuitClosureResult(
      outcomes: [
        for (final d3Outcome in d3Outcomes)
          _closeCircuit(
            d3Outcome: d3Outcome,
            policy: policies[d3Outcome.circuitId]!,
          ),
      ],
    );
  }

  static ElectricalShortCircuitClosureOutcome _closeCircuit({
    required ElectricalCircuitClosureOutcome d3Outcome,
    required ElectricalShortCircuitClosurePolicy policy,
  }) {
    final reasons = <String>[];
    final selectedCable = d3Outcome.selectedCable!;
    final selectedDevice = d3Outcome.selectedProtection!;
    final selectedCableId = selectedCable.cable.id;
    final routeLengthMm = selectedCable.routeLengthMm;

    final disconnectionFaultCase = policy.disconnectionFaultCase;
    final thermalFaultCase = policy.thermalFaultCase;
    final disconnectionFault = disconnectionFaultCase == null
        ? null
        : _calculateFaultLoop(disconnectionFaultCase, routeLengthMm);
    final thermalFault = thermalFaultCase == null
        ? null
        : _calculateFaultLoop(thermalFaultCase, routeLengthMm);

    final disconnectionFaultMatchesCable = disconnectionFaultCase != null &&
        disconnectionFaultCase.cableId == selectedCableId;
    final thermalFaultMatchesCable =
        thermalFaultCase != null && thermalFaultCase.cableId == selectedCableId;

    if (disconnectionFault == null) {
      reasons.add('missing-disconnection-fault-loop-evidence');
    } else if (!disconnectionFaultMatchesCable) {
      reasons.add(
        'disconnection-fault-loop-cable-does-not-match-selected-cable',
      );
    }
    if (thermalFault == null) {
      reasons.add('missing-thermal-fault-loop-evidence');
    } else if (!thermalFaultMatchesCable) {
      reasons.add('thermal-fault-loop-cable-does-not-match-selected-cable');
    }

    final timeCurrent = policy.timeCurrentEvidence;
    if (timeCurrent == null) {
      reasons.add('missing-time-current-evidence');
    } else if (timeCurrent.deviceId != selectedDevice.id) {
      reasons.add('time-current-device-does-not-match-selected-protection');
    }

    final thermalEvidence = policy.thermalEvidence;
    final selectedConductorCrossSectionMm2 =
        selectedCable.cable.conductorCrossSectionMm2;
    var thermalEvidenceMatchesCable = false;
    if (thermalEvidence == null) {
      reasons.add('missing-protective-conductor-thermal-evidence');
    } else if (thermalEvidence.cableId != selectedCableId) {
      reasons.add('thermal-evidence-cable-does-not-match-selected-cable');
    } else if (selectedConductorCrossSectionMm2 == null) {
      reasons.add('selected-cable-conductor-cross-section-is-unknown');
    } else if (thermalEvidence.crossSectionMm2 >
        selectedConductorCrossSectionMm2 + 1e-9) {
      reasons.add(
        'thermal-evidence-cross-section-exceeds-selected-cable-conductor',
      );
    } else {
      thermalEvidenceMatchesCable = true;
    }

    final d3ProspectiveCurrentA =
        d3Outcome.policy.prospectiveShortCircuitCurrentA;
    final upstreamConsistencyStatus = disconnectionFault == null ||
            thermalFault == null ||
            !disconnectionFaultMatchesCable ||
            !thermalFaultMatchesCable
        ? EngineeringCheckStatus.indeterminate
        : disconnectionFault.faultCurrentA > d3ProspectiveCurrentA + 1e-9 ||
                thermalFault.faultCurrentA > d3ProspectiveCurrentA + 1e-9
            ? EngineeringCheckStatus.fail
            : EngineeringCheckStatus.pass;
    if (upstreamConsistencyStatus == EngineeringCheckStatus.fail) {
      reasons.add('d4-fault-current-exceeds-d3-upstream-prospective-current');
    }

    double? disconnectionOperatingTimeS;
    var disconnectionStatus = EngineeringCheckStatus.indeterminate;
    if (disconnectionFault != null &&
        disconnectionFaultMatchesCable &&
        timeCurrent != null &&
        timeCurrent.deviceId == selectedDevice.id &&
        policy.requiredMaxDisconnectionTimeS != null) {
      disconnectionOperatingTimeS = timeCurrent.maximumOperatingTimeAt(
        disconnectionFault.faultCurrentA,
      );
      if (disconnectionOperatingTimeS == null) {
        reasons.add('fault-current-below-time-current-evidence-range');
      } else if (disconnectionOperatingTimeS <=
          policy.requiredMaxDisconnectionTimeS!) {
        disconnectionStatus = EngineeringCheckStatus.pass;
      } else {
        disconnectionStatus = EngineeringCheckStatus.fail;
        reasons.add('required-disconnection-time-exceeded');
      }
    } else if (policy.requiredMaxDisconnectionTimeS == null) {
      reasons.add('missing-required-disconnection-time');
    }

    double? thermalOperatingTimeS;
    double? faultEnergyA2s;
    double? thermalCapacityA2s;
    var thermalStatus = EngineeringCheckStatus.indeterminate;
    if (thermalFault != null &&
        thermalFaultMatchesCable &&
        timeCurrent != null &&
        timeCurrent.deviceId == selectedDevice.id &&
        thermalEvidence != null &&
        thermalEvidenceMatchesCable) {
      thermalOperatingTimeS = timeCurrent.maximumOperatingTimeAt(
        thermalFault.faultCurrentA,
      );
      if (thermalOperatingTimeS == null) {
        reasons.add('thermal-fault-current-below-time-current-evidence-range');
      } else {
        faultEnergyA2s = math.pow(thermalFault.faultCurrentA, 2).toDouble() *
            thermalOperatingTimeS;
        thermalCapacityA2s = thermalEvidence.thermalCapacityA2s;
        if (faultEnergyA2s <= thermalCapacityA2s) {
          thermalStatus = EngineeringCheckStatus.pass;
        } else {
          thermalStatus = EngineeringCheckStatus.fail;
          reasons.add('protective-conductor-thermal-withstand-exceeded');
        }
      }
    }

    if (reasons.isEmpty) {
      reasons.add('short-circuit-and-disconnection-closure-proven');
    }

    return ElectricalShortCircuitClosureOutcome(
      d3Outcome: d3Outcome,
      policy: policy,
      disconnectionFault: disconnectionFault,
      thermalFault: thermalFault,
      disconnectionOperatingTimeS: disconnectionOperatingTimeS,
      thermalOperatingTimeS: thermalOperatingTimeS,
      faultEnergyA2s: faultEnergyA2s,
      thermalCapacityA2s: thermalCapacityA2s,
      upstreamConsistencyStatus: upstreamConsistencyStatus,
      disconnectionStatus: disconnectionStatus,
      thermalStatus: thermalStatus,
      reasons: reasons,
    );
  }

  static FaultLoopCalculationResult _calculateFaultLoop(
    FaultLoopCaseEvidence evidence,
    double routeLengthMm,
  ) {
    final routeLengthKm = routeLengthMm / 1000000.0;
    final resistance = evidence.sourceResistanceOhm +
        routeLengthKm *
            (evidence.phaseResistanceOhmPerKm +
                evidence.protectiveResistanceOhmPerKm);
    final reactance = evidence.sourceReactanceOhm +
        routeLengthKm *
            (evidence.phaseReactanceOhmPerKm +
                evidence.protectiveReactanceOhmPerKm);
    final impedance =
        math.sqrt(resistance * resistance + reactance * reactance);
    if (!impedance.isFinite || impedance <= 0) {
      throw StateError('Fault-loop impedance must be finite and > 0.');
    }
    final faultCurrentA = evidence.faultVoltageV / impedance;
    if (!faultCurrentA.isFinite || faultCurrentA <= 0) {
      throw StateError('Fault current must be finite and > 0.');
    }
    return FaultLoopCalculationResult(
      caseId: evidence.id,
      routeLengthMm: routeLengthMm,
      loopResistanceOhm: resistance,
      loopReactanceOhm: reactance,
      loopImpedanceOhm: impedance,
      faultCurrentA: faultCurrentA,
    );
  }
}
