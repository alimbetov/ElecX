import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringNode node({
  required String id,
  required EngineeringSystemClass systemClass,
  required EngineeringPortSpec port,
}) => EngineeringNode(
  id: id,
  componentTypeId: '$id-type',
  discipline: EngineeringDiscipline.lowVoltage,
  systemClass: systemClass,
  surface: RoomSurfaceRef.wall('room-1', 0),
  position: const SurfacePointMm(1000, 1000),
  ports: [port],
);

void main() {
  test('system class dispatches to discipline-specific calculation kind', () {
    expect(
      EngineeringSystemPolicy.calculationFor(EngineeringSystemClass.powerAc),
      EngineeringCalculationKind.powerCableSizing,
    );
    expect(
      EngineeringSystemPolicy.calculationFor(
        EngineeringSystemClass.structuredCabling,
      ),
      EngineeringCalculationKind.copperLinkLength,
    );
    expect(
      EngineeringSystemPolicy.calculationFor(EngineeringSystemClass.cctv),
      EngineeringCalculationKind.poePowerBudget,
    );
    expect(
      EngineeringSystemPolicy.calculationFor(EngineeringSystemClass.fireAlarm),
      EngineeringCalculationKind.fireLoopElectrical,
    );
    expect(
      EngineeringSystemPolicy.calculationFor(EngineeringSystemClass.fiberOptic),
      EngineeringCalculationKind.fiberOpticalBudget,
    );
  });

  test('compatible PoE ports can be connected', () {
    final source = node(
      id: 'switch',
      systemClass: EngineeringSystemClass.poeNetwork,
      port: EngineeringPortSpec(
        id: 'poe-out',
        direction: EngineeringPortDirection.output,
        allowedConnections: {EngineeringConnectionType.poe},
      ),
    );
    final camera = node(
      id: 'camera',
      systemClass: EngineeringSystemClass.cctv,
      port: EngineeringPortSpec(
        id: 'poe-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: {EngineeringConnectionType.poe},
      ),
    );

    expect(
      EngineeringGraphValidator.canConnect(
        from: source,
        fromPortId: 'poe-out',
        to: camera,
        toPortId: 'poe-in',
        type: EngineeringConnectionType.poe,
      ),
      isTrue,
    );
  });

  test('incompatible power and fiber ports are rejected', () {
    final power = node(
      id: 'panel',
      systemClass: EngineeringSystemClass.powerAc,
      port: EngineeringPortSpec(
        id: 'ac-out',
        direction: EngineeringPortDirection.output,
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
      ),
    );
    final fiber = node(
      id: 'fiber-terminal',
      systemClass: EngineeringSystemClass.fiberOptic,
      port: EngineeringPortSpec(
        id: 'fiber-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: {EngineeringConnectionType.fiber},
      ),
    );

    expect(
      EngineeringGraphValidator.canConnect(
        from: power,
        fromPortId: 'ac-out',
        to: fiber,
        toPortId: 'fiber-in',
        type: EngineeringConnectionType.acSinglePhase,
      ),
      isFalse,
    );
  });
}
