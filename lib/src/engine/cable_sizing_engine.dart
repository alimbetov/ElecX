import 'dart:math' as math;

import '../domain/cable_spec.dart';

enum CircuitPhaseSystem { dc, singlePhaseAc, threePhaseAc }

enum EngineeringCheckStatus { pass, fail, indeterminate }

final class CircuitElectricalRequirement {
  const CircuitElectricalRequirement({
    required this.phaseSystem,
    required this.designCurrentA,
    required this.nominalVoltageV,
    required this.routeLengthMm,
    required this.maxVoltageDropRatio,
    this.powerFactor = 1.0,
  })  : assert(designCurrentA > 0),
        assert(nominalVoltageV > 0),
        assert(routeLengthMm >= 0),
        assert(maxVoltageDropRatio > 0 && maxVoltageDropRatio < 1),
        assert(powerFactor > 0 && powerFactor <= 1);

  final CircuitPhaseSystem phaseSystem;
  final double designCurrentA;
  final double nominalVoltageV;
  final double routeLengthMm;
  final double maxVoltageDropRatio;
  final double powerFactor;
}

final class CableElectricalEvidence {
  const CableElectricalEvidence({
    required this.baseAmpacityA,
    required this.resistanceOhmPerKm,
    this.reactanceOhmPerKm = 0,
    this.sourceKey,
  })  : assert(baseAmpacityA > 0),
        assert(resistanceOhmPerKm >= 0),
        assert(reactanceOhmPerKm >= 0);

  final double baseAmpacityA;
  final double resistanceOhmPerKm;
  final double reactanceOhmPerKm;
  final String? sourceKey;
}

final class ThermalDeratingFactor {
  const ThermalDeratingFactor({
    required this.id,
    required this.factor,
    this.reason,
  }) : assert(factor > 0 && factor <= 1);

  final String id;
  final double factor;
  final String? reason;
}

final class ThermalSectionEvidence {
  ThermalSectionEvidence({
    required this.sectionId,
    required Iterable<ThermalDeratingFactor> factors,
  }) : factors = List.unmodifiable(factors);

  final String sectionId;
  final List<ThermalDeratingFactor> factors;

  double get combinedFactor =>
      factors.fold<double>(1, (value, item) => value * item.factor);
}

final class CableSizingRequest {
  const CableSizingRequest({
    required this.cable,
    required this.requirement,
    required this.electricalEvidence,
    this.thermalSections = const [],
  });

  final CableSpec cable;
  final CircuitElectricalRequirement requirement;
  final CableElectricalEvidence? electricalEvidence;
  final List<ThermalSectionEvidence> thermalSections;
}

final class CableSizingResult {
  const CableSizingResult({
    required this.currentStatus,
    required this.voltageDropStatus,
    required this.baseAmpacityA,
    required this.governingAmpacityA,
    required this.governingSectionId,
    required this.voltageDropV,
    required this.voltageDropRatio,
    required this.reasons,
    required this.sourceKey,
  });

  final EngineeringCheckStatus currentStatus;
  final EngineeringCheckStatus voltageDropStatus;
  final double? baseAmpacityA;
  final double? governingAmpacityA;
  final String? governingSectionId;
  final double? voltageDropV;
  final double? voltageDropRatio;
  final List<String> reasons;
  final String? sourceKey;

  bool get isPass =>
      currentStatus == EngineeringCheckStatus.pass &&
      voltageDropStatus == EngineeringCheckStatus.pass;

  bool get isIndeterminate =>
      currentStatus == EngineeringCheckStatus.indeterminate ||
      voltageDropStatus == EngineeringCheckStatus.indeterminate;
}

abstract final class CableSizingEngine {
  static CableSizingResult evaluate(CableSizingRequest request) {
    final evidence = request.electricalEvidence;
    if (evidence == null) {
      return const CableSizingResult(
        currentStatus: EngineeringCheckStatus.indeterminate,
        voltageDropStatus: EngineeringCheckStatus.indeterminate,
        baseAmpacityA: null,
        governingAmpacityA: null,
        governingSectionId: null,
        voltageDropV: null,
        voltageDropRatio: null,
        reasons: ['Missing cable electrical evidence.'],
        sourceKey: null,
      );
    }

    var governingAmpacity = evidence.baseAmpacityA;
    String? governingSectionId;
    for (final section in request.thermalSections) {
      final adjusted = evidence.baseAmpacityA * section.combinedFactor;
      if (adjusted < governingAmpacity) {
        governingAmpacity = adjusted;
        governingSectionId = section.sectionId;
      }
    }

    final currentStatus = request.requirement.designCurrentA <= governingAmpacity
        ? EngineeringCheckStatus.pass
        : EngineeringCheckStatus.fail;

    final voltageDrop = _voltageDropV(
      requirement: request.requirement,
      evidence: evidence,
    );
    final voltageDropRatio = voltageDrop / request.requirement.nominalVoltageV;
    final voltageDropStatus =
        voltageDropRatio <= request.requirement.maxVoltageDropRatio
            ? EngineeringCheckStatus.pass
            : EngineeringCheckStatus.fail;

    final reasons = <String>[];
    if (currentStatus == EngineeringCheckStatus.fail) {
      reasons.add(
        'Design current ${request.requirement.designCurrentA.toStringAsFixed(2)} A exceeds governing ampacity ${governingAmpacity.toStringAsFixed(2)} A.',
      );
    }
    if (voltageDropStatus == EngineeringCheckStatus.fail) {
      reasons.add(
        'Voltage drop ${(voltageDropRatio * 100).toStringAsFixed(2)}% exceeds allowed ${(request.requirement.maxVoltageDropRatio * 100).toStringAsFixed(2)}%.',
      );
    }
    if (reasons.isEmpty) reasons.add('Cable satisfies current and voltage-drop checks.');

    return CableSizingResult(
      currentStatus: currentStatus,
      voltageDropStatus: voltageDropStatus,
      baseAmpacityA: evidence.baseAmpacityA,
      governingAmpacityA: governingAmpacity,
      governingSectionId: governingSectionId,
      voltageDropV: voltageDrop,
      voltageDropRatio: voltageDropRatio,
      reasons: List.unmodifiable(reasons),
      sourceKey: evidence.sourceKey,
    );
  }

  static double _voltageDropV({
    required CircuitElectricalRequirement requirement,
    required CableElectricalEvidence evidence,
  }) {
    final lengthKm = requirement.routeLengthMm / 1000000.0;
    final cosPhi = requirement.powerFactor;
    final sinPhi = math.sqrt(math.max(0, 1 - cosPhi * cosPhi));
    final impedanceTerm =
        evidence.resistanceOhmPerKm * cosPhi + evidence.reactanceOhmPerKm * sinPhi;

    return switch (requirement.phaseSystem) {
      CircuitPhaseSystem.threePhaseAc =>
        math.sqrt(3) * requirement.designCurrentA * lengthKm * impedanceTerm,
      CircuitPhaseSystem.dc || CircuitPhaseSystem.singlePhaseAc =>
        2 * requirement.designCurrentA * lengthKm * impedanceTerm,
    };
  }
}
