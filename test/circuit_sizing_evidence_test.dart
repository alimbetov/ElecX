import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/features/editor/circuit_sizing_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);
  ElectricalCableRoute route({int endX = 10000}) => ElectricalCableRoute(
    id: 'route-1',
    source: const ElectricalEndpointRef(
      componentId: 'board-1',
      portId: 'power-out',
    ),
    target: const ElectricalEndpointRef(
      componentId: 'load-1',
      portId: 'power-in',
    ),
    segments: [
      ElectricalRouteSegment(
        surface: surface,
        points: [const SurfacePointMm(0, 1000), SurfacePointMm(endX, 1000)],
      ),
    ],
    cableType: 'cable-3x2.5',
    medium: RouteMediumProfile.acPower,
  );

  CableSpec cable() => const CableSpec(
    id: 'cable-3x2.5',
    name: '3x2.5',
    medium: RouteMediumProfile.acPower,
    outerDiameterMm: 10,
    segregationClass: CableSegregationClass.power,
    conductorMaterial: ConductorMaterial.copper,
    conductorCount: 3,
    conductorCrossSectionMm2: 2.5,
    ratedVoltageV: 230,
  );

  test('complete evidence produces actual CableSizingEngine PASS', () {
    final actualRoute = route();
    final evidence = CircuitSizingEvidence(
      routeId: actualRoute.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(
        actualRoute,
      ),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 10,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 1,
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'whole-route',
          baseAmpacityA: 20,
          factors: const [ThermalCorrectionFactor(id: 'k', factor: 1)],
          sourceKey: 'engineer-table-A',
        ),
      ],
      impedanceEvidence: const CableImpedanceEvidence(
        resistanceOhmPerKm: 7.5,
        sourceKey: 'manufacturer-R',
      ),
    );
    final result = evidence.evaluate(actualRoute);
    expect(result.currentStatus, EngineeringCheckStatus.pass);
    expect(result.voltageDropStatus, EngineeringCheckStatus.pass);
    expect(result.isPass, isTrue);
  });

  test('missing impedance remains INDETERMINATE, never implicit PASS', () {
    final actualRoute = route();
    final evidence = CircuitSizingEvidence(
      routeId: actualRoute.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(
        actualRoute,
      ),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 10,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 1,
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'whole-route',
          baseAmpacityA: 20,
          factors: const [],
        ),
      ],
    );
    final result = evidence.evaluate(actualRoute);
    expect(result.currentStatus, EngineeringCheckStatus.pass);
    expect(result.voltageDropStatus, EngineeringCheckStatus.indeterminate);
    expect(result.isPass, isFalse);
  });

  test('route geometry mutation makes saved sizing evidence stale', () {
    final original = route();
    final evidence = CircuitSizingEvidence(
      routeId: original.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(original),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 10,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 1,
      ampacitySections: const [],
    );
    expect(evidence.matchesRoute(original), isTrue);
    expect(evidence.matchesRoute(route(endX: 12000)), isFalse);
  });

  test('evidence JSON round-trip preserves sources and cable spec', () {
    final actualRoute = route();
    final source = CircuitSizingEvidence(
      routeId: actualRoute.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(
        actualRoute,
      ),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 12,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 0.95,
      designCurrentSourceKey: 'load-study-1',
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'wall',
          baseAmpacityA: 24,
          factors: const [ThermalCorrectionFactor(id: 'temp', factor: 0.9)],
          sourceKey: 'table-1',
        ),
      ],
      impedanceEvidence: const CableImpedanceEvidence(
        resistanceOhmPerKm: 7.41,
        reactanceOhmPerKm: 0.08,
        sourceKey: 'datasheet-1',
      ),
    );
    final restored = CircuitSizingEvidence.fromJson(source.toJson());
    expect(restored.cable.conductorCrossSectionMm2, 2.5);
    expect(restored.designCurrentSourceKey, 'load-study-1');
    expect(restored.ampacitySections.single.sourceKey, 'table-1');
    expect(restored.impedanceEvidence!.sourceKey, 'datasheet-1');
  });
}
