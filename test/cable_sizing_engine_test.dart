import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cable = CableSpec(
    id: 'vvg-3x2.5',
    name: 'VVGng-LS 3x2.5',
    medium: RouteMediumProfile.acPower,
    outerDiameterMm: 10,
    segregationClass: CableSegregationClass.power,
    conductorMaterial: ConductorMaterial.copper,
    conductorCount: 3,
    conductorCrossSectionMm2: 2.5,
  );

  test('missing electrical evidence is indeterminate, never implicit pass', () {
    final result = CableSizingEngine.evaluate(
      const CableSizingRequest(
        cable: cable,
        requirement: CircuitElectricalRequirement(
          phaseSystem: CircuitPhaseSystem.singlePhaseAc,
          designCurrentA: 16,
          nominalVoltageV: 230,
          routeLengthMm: 20000,
          maxVoltageDropRatio: 0.03,
        ),
        electricalEvidence: null,
      ),
    );

    expect(result.isIndeterminate, isTrue);
    expect(result.isPass, isFalse);
  });

  test('worst thermal section governs ampacity', () {
    final result = CableSizingEngine.evaluate(
      CableSizingRequest(
        cable: cable,
        requirement: const CircuitElectricalRequirement(
          phaseSystem: CircuitPhaseSystem.singlePhaseAc,
          designCurrentA: 18,
          nominalVoltageV: 230,
          routeLengthMm: 10000,
          maxVoltageDropRatio: 0.05,
        ),
        electricalEvidence: const CableElectricalEvidence(
          baseAmpacityA: 25,
          resistanceOhmPerKm: 7.41,
          sourceKey: 'test-table',
        ),
        thermalSections: [
          ThermalSectionEvidence(
            sectionId: 'tray',
            factors: const [
              ThermalCorrectionFactor(id: 'ambient', factor: 0.95),
            ],
          ),
          ThermalSectionEvidence(
            sectionId: 'riser-group',
            factors: const [
              ThermalCorrectionFactor(id: 'grouping', factor: 0.70),
              ThermalCorrectionFactor(id: 'ambient', factor: 0.95),
            ],
          ),
        ],
      ),
    );

    expect(result.governingSectionId, 'riser-group');
    expect(result.governingAmpacityA, closeTo(16.625, 0.001));
    expect(result.currentStatus, EngineeringCheckStatus.fail);
  });

  test('correction factor above one is supported when evidence permits it', () {
    final result = CableSizingEngine.evaluate(
      CableSizingRequest(
        cable: cable,
        requirement: const CircuitElectricalRequirement(
          phaseSystem: CircuitPhaseSystem.singlePhaseAc,
          designCurrentA: 20,
          nominalVoltageV: 230,
          routeLengthMm: 5000,
          maxVoltageDropRatio: 0.05,
        ),
        electricalEvidence: const CableElectricalEvidence(
          baseAmpacityA: 20,
          resistanceOhmPerKm: 7.41,
        ),
        thermalSections: [
          ThermalSectionEvidence(
            sectionId: 'cool-section',
            factors: const [
              ThermalCorrectionFactor(id: 'ambient', factor: 1.05),
            ],
          ),
        ],
      ),
    );

    expect(result.currentStatus, EngineeringCheckStatus.pass);
    expect(result.governingAmpacityA, 20);
  });

  test('single phase voltage drop can reject otherwise adequate cable', () {
    final result = CableSizingEngine.evaluate(
      const CableSizingRequest(
        cable: cable,
        requirement: CircuitElectricalRequirement(
          phaseSystem: CircuitPhaseSystem.singlePhaseAc,
          designCurrentA: 16,
          nominalVoltageV: 230,
          routeLengthMm: 100000,
          maxVoltageDropRatio: 0.03,
        ),
        electricalEvidence: CableElectricalEvidence(
          baseAmpacityA: 25,
          resistanceOhmPerKm: 7.41,
        ),
      ),
    );

    expect(result.currentStatus, EngineeringCheckStatus.pass);
    expect(result.voltageDropStatus, EngineeringCheckStatus.fail);
    expect(result.isPass, isFalse);
  });

  test('three phase equation uses sqrt(3) multiplier', () {
    final result = CableSizingEngine.evaluate(
      const CableSizingRequest(
        cable: cable,
        requirement: CircuitElectricalRequirement(
          phaseSystem: CircuitPhaseSystem.threePhaseAc,
          designCurrentA: 10,
          nominalVoltageV: 400,
          routeLengthMm: 10000,
          maxVoltageDropRatio: 0.05,
          powerFactor: 1,
        ),
        electricalEvidence: CableElectricalEvidence(
          baseAmpacityA: 25,
          resistanceOhmPerKm: 1,
        ),
      ),
    );

    expect(result.voltageDropV, closeTo(0.173205, 0.0001));
  });
}
