import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../engine/cable_sizing_engine.dart';
import 'circuit_sizing_evidence.dart';

enum CircuitEngineeringReadiness {
  missingLoadPower,
  missingProtection,
  missingCableSpecification,
  sizingEvidenceRequired,
  sizingEvidenceStale,
  sizingIndeterminate,
  sizingFailed,
  sizingPassed,
}

final class CircuitEngineeringStatus {
  const CircuitEngineeringStatus({
    required this.readiness,
    required this.geometricLengthM,
    required this.installationLengthM,
    required this.loadPowerW,
    required this.nominalVoltageV,
    required this.estimatedCurrentA,
    this.sizingResult,
  });

  final CircuitEngineeringReadiness readiness;
  final double geometricLengthM;
  final double installationLengthM;
  final int? loadPowerW;
  final int nominalVoltageV;

  /// Preliminary P/U indication only. This is not design current: phase system,
  /// power factor, demand/diversity and normative evidence are not inferred.
  final double? estimatedCurrentA;
  final CableSizingResult? sizingResult;

  bool get hasLoadData => loadPowerW != null && loadPowerW! > 0;

  String get headline => switch (readiness) {
        CircuitEngineeringReadiness.missingLoadPower =>
          'Укажите мощность нагрузки',
        CircuitEngineeringReadiness.missingProtection =>
          'Назначьте защиту группы',
        CircuitEngineeringReadiness.missingCableSpecification =>
          'Укажите кабель',
        CircuitEngineeringReadiness.sizingEvidenceRequired =>
          'Нужны данные для расчёта кабеля',
        CircuitEngineeringReadiness.sizingEvidenceStale =>
          'Расчёт кабеля устарел',
        CircuitEngineeringReadiness.sizingIndeterminate =>
          'Расчёт кабеля: недостаточно evidence',
        CircuitEngineeringReadiness.sizingFailed => 'Расчёт кабеля: FAIL',
        CircuitEngineeringReadiness.sizingPassed => 'Расчёт кабеля: PASS',
      };

  String get detail => switch (readiness) {
        CircuitEngineeringReadiness.missingLoadPower =>
          'Без мощности нельзя даже предварительно оценить ток нагрузки.',
        CircuitEngineeringReadiness.missingProtection =>
          'Связность и нагрузка заданы, но защитный аппарат ещё не выбран инженером.',
        CircuitEngineeringReadiness.missingCableSpecification =>
          'Группа подключена и защищена, но марка/спецификация кабеля не назначена.',
        CircuitEngineeringReadiness.sizingEvidenceRequired =>
          'Для PASS требуются ampacity по участкам и impedance evidence. ElecX не подменяет их предположениями.',
        CircuitEngineeringReadiness.sizingEvidenceStale =>
          'Геометрия трассы или кабель изменились после расчёта. Обновите evidence.',
        CircuitEngineeringReadiness.sizingIndeterminate ||
        CircuitEngineeringReadiness.sizingFailed ||
        CircuitEngineeringReadiness.sizingPassed =>
          sizingResult?.reasons.join(' ') ?? 'Нет результата расчёта.',
      };

  static CircuitEngineeringStatus evaluate({
    required ElectricalComponentPlacement load,
    required ElectricalCableRoute route,
    required CircuitCableBundle bundle,
    CircuitSizingEvidence? sizingEvidence,
  }) {
    final power = load.ratedPowerW;
    final current =
        power == null || power <= 0 ? null : power / load.voltageV.toDouble();
    final cableSpec = bundle.cable.cableSpecId ?? route.cableType;
    CableSizingResult? sizingResult;
    late final CircuitEngineeringReadiness readiness;
    if (power == null || power <= 0) {
      readiness = CircuitEngineeringReadiness.missingLoadPower;
    } else if (bundle.protectiveDevice == null) {
      readiness = CircuitEngineeringReadiness.missingProtection;
    } else if (cableSpec == null || cableSpec.trim().isEmpty) {
      readiness = CircuitEngineeringReadiness.missingCableSpecification;
    } else if (sizingEvidence == null) {
      readiness = CircuitEngineeringReadiness.sizingEvidenceRequired;
    } else if (!sizingEvidence.matchesRoute(route) ||
        sizingEvidence.cable.id != cableSpec) {
      readiness = CircuitEngineeringReadiness.sizingEvidenceStale;
    } else {
      sizingResult = sizingEvidence.evaluate(route);
      final hasFailure =
          sizingResult.currentStatus == EngineeringCheckStatus.fail ||
              sizingResult.voltageDropStatus == EngineeringCheckStatus.fail;
      readiness = hasFailure
          ? CircuitEngineeringReadiness.sizingFailed
          : sizingResult.isIndeterminate
              ? CircuitEngineeringReadiness.sizingIndeterminate
              : CircuitEngineeringReadiness.sizingPassed;
    }
    return CircuitEngineeringStatus(
      readiness: readiness,
      geometricLengthM: route.geometricLengthMm / 1000,
      installationLengthM: route.installationLengthMm / 1000,
      loadPowerW: power,
      nominalVoltageV: load.voltageV,
      estimatedCurrentA: current,
      sizingResult: sizingResult,
    );
  }
}
