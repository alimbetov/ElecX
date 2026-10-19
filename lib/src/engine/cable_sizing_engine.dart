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

/// Cable impedance evidence used for voltage-drop calculations. It is kept
/// separate from ampacity because installation method affects ampacity by
/// route section while conductor impedance is cable evidence.
final class CableImpedanceEvidence {
  const CableImpedanceEvidence({
    required this.resistanceOhmPerKm,
    this.reactanceOhmPerKm = 0,
    this.sourceKey,
  })  : assert(resistanceOhmPerKm >= 0),
        assert(reactanceOhmPerKm >= 0);

  final double resistanceOhmPerKm;
  final double reactanceOhmPerKm;
  final String? sourceKey;
}

/// Named correction factor supplied by the normative/installation profile.
/// A factor below 1 derates ampacity; a factor above 1 is allowed when the
/// referenced profile explicitly permits an uplift relative to base conditions.
final class ThermalCorrectionFactor {
  const ThermalCorrectionFactor({
    required this.id,
    required this.factor,
    this.reason,
  }) : assert(factor > 0);

  final String id;
  final double factor;
  final String? reason;
}

/// Ampacity evidence for one concrete installation section.
/// Base ampacity is section-specific because installation method/base condition
/// may differ between wall, tray, riser, duct, underground and other sections.
final class SectionAmpacityEvidence {
  SectionAmpacityEvidence({
    required this.sectionId,
    required this.baseAmpacityA,
    required Iterable<ThermalCorrectionFactor> factors,
    this.sourceKey,
  })  : assert(baseAmpacityA > 0),
        factors = List.unmodifiable(factors);

  final String sectionId;
  final double baseAmpacityA;
  final List<ThermalCorrectionFactor> factors;
  final String? sourceKey;

  double get combinedFactor =>
      factors.fold<double>(1, (value, item) => value * item.factor);

  double get adjustedAmpacityA => baseAmpacityA * combinedFactor;
}

final class CableSizingRequest {
  const CableSizingRequest({
    required this.cable,
    required this.requirement,
    required this.impedanceEvidence,
    required this.ampacitySections,
  });

  final CableSpec cable;
  final CircuitElectricalRequirement requirement;
  final CableImpedanceEvidence? impedanceEvidence;
  final List<SectionAmpacityEvidence> ampacitySections;
}

final class CableSizingResult {
  const CableSizingResult({
    required this.currentStatus,
    required this.voltageDropStatus,
    required this.governingAmpacityA,
    required this.governingSectionId,
    required this.voltageDropV,
    required this.voltageDropRatio,
    required this.reasons,
    required this.ampacitySourceKey,
    required this.impedanceSourceKey,
  });

  final EngineeringCheckStatus currentStatus;
  final EngineeringCheckStatus voltageDropStatus;
  final double? governingAmpacityA;
  final String? governingSectionId;
  final double? voltageDropV;
  final double? voltageDropRatio;
  final List<String> reasons;
  final String? ampacitySourceKey;
  final String? impedanceSourceKey;

  bool get isPass =>
      currentStatus == EngineeringCheckStatus.pass &&
      voltageDropStatus == EngineeringCheckStatus.pass;

  bool get isIndeterminate =>
      currentStatus == EngineeringCheckStatus.indeterminate ||
      voltageDropStatus == EngineeringCheckStatus.indeterminate;
}

abstract final class CableSizingEngine {
  static CableSizingResult evaluate(CableSizingRequest request) {
    final impedance = request.impedanceEvidence;
    final ampacitySections = request.ampacitySections;

    final currentStatus = ampacitySections.isEmpty
        ? EngineeringCheckStatus.indeterminate
        : _currentStatus(request.requirement, ampacitySections);
    final governing = _governingSection(ampacitySections);

    final voltageDrop = impedance == null
        ? null
        : _voltageDropV(
            requirement: request.requirement,
            evidence: impedance,
          );
    final voltageDropRatio = voltageDrop == null
        ? null
        : voltageDrop / request.requirement.nominalVoltageV;
    final voltageDropStatus = voltageDropRatio == null
        ? EngineeringCheckStatus.indeterminate
        : voltageDropRatio <= request.requirement.maxVoltageDropRatio
            ? EngineeringCheckStatus.pass
            : EngineeringCheckStatus.fail;

    final reasons = <String>[];
    if (ampacitySections.isEmpty) {
      reasons.add('Missing section ampacity evidence.');
    } else if (currentStatus == EngineeringCheckStatus.fail) {
      reasons.add(
        'Design current ${request.requirement.designCurrentA.toStringAsFixed(2)} A exceeds governing ampacity ${governing!.adjustedAmpacityA.toStringAsFixed(2)} A on section ${governing.sectionId}.',
      );
    }
    if (impedance == null) {
      reasons.add('Missing cable impedance evidence.');
    } else if (voltageDropStatus == EngineeringCheckStatus.fail) {
      reasons.add(
        'Voltage drop ${(voltageDropRatio! * 100).toStringAsFixed(2)}% exceeds allowed ${(request.requirement.maxVoltageDropRatio * 100).toStringAsFixed(2)}%.',
      );
    }
    if (reasons.isEmpty) reasons.add('Cable satisfies current and voltage-drop checks.');

    return CableSizingResult(
      currentStatus: currentStatus,
      voltageDropStatus: voltageDropStatus,
      governingAmpacityA: governing?.adjustedAmpacityA,
      governingSectionId: governing?.sectionId,
      voltageDropV: voltageDrop,
      voltageDropRatio: voltageDropRatio,
      reasons: List.unmodifiable(reasons),
      ampacitySourceKey: governing?.sourceKey,
      impedanceSourceKey: impedance?.sourceKey,
    );
  }

  static EngineeringCheckStatus _currentStatus(
    CircuitElectricalRequirement requirement,
    List<SectionAmpacityEvidence> sections,
  ) {
    final governing = _governingSection(sections)!;
    return requirement.designCurrentA <= governing.adjustedAmpacityA
        ? EngineeringCheckStatus.pass
        : EngineeringCheckStatus.fail;
  }

  static SectionAmpacityEvidence? _governingSection(
    List<SectionAmpacityEvidence> sections,
  ) {
    if (sections.isEmpty) return null;
    var governing = sections.first;
    for (final section in sections.skip(1)) {
      if (section.adjustedAmpacityA < governing.adjustedAmpacityA) {
        governing = section;
      }
    }
    return governing;
  }

  static double _voltageDropV({
    required CircuitElectricalRequirement requirement,
    required CableImpedanceEvidence evidence,
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
