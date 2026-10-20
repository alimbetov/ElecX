import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';

enum CircuitEngineeringReadiness {
  missingLoadPower,
  missingProtection,
  missingCableSpecification,
  sizingEvidenceRequired,
}

final class CircuitEngineeringStatus {
  const CircuitEngineeringStatus({
    required this.readiness,
    required this.geometricLengthM,
    required this.installationLengthM,
    required this.loadPowerW,
    required this.nominalVoltageV,
    required this.estimatedCurrentA,
  });

  final CircuitEngineeringReadiness readiness;
  final double geometricLengthM;
  final double installationLengthM;
  final int? loadPowerW;
  final int nominalVoltageV;

  /// Preliminary P/U indication only. This is not design current: phase system,
  /// power factor, demand/diversity and normative evidence are not inferred.
  final double? estimatedCurrentA;

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
      };

  static CircuitEngineeringStatus evaluate({
    required ElectricalComponentPlacement load,
    required ElectricalCableRoute route,
    required CircuitCableBundle bundle,
  }) {
    final power = load.ratedPowerW;
    final current =
        power == null || power <= 0 ? null : power / load.voltageV.toDouble();
    final cableSpec = bundle.cable.cableSpecId ?? route.cableType;
    final readiness = power == null || power <= 0
        ? CircuitEngineeringReadiness.missingLoadPower
        : bundle.protectiveDevice == null
            ? CircuitEngineeringReadiness.missingProtection
            : cableSpec == null || cableSpec.trim().isEmpty
                ? CircuitEngineeringReadiness.missingCableSpecification
                : CircuitEngineeringReadiness.sizingEvidenceRequired;
    return CircuitEngineeringStatus(
      readiness: readiness,
      geometricLengthM: route.geometricLengthMm / 1000,
      installationLengthM: route.installationLengthMm / 1000,
      loadPowerW: power,
      nominalVoltageV: load.voltageV,
      estimatedCurrentA: current,
    );
  }
}
