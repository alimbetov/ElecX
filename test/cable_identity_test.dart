import 'package:elecx/src/domain/cable_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const circuit = CircuitRef(
    id: 'circuit-light-01',
    name: 'LIGHT-01',
    boardId: 'DB-01',
    protectiveDeviceId: 'QF-07',
  );

  const cable = CableIdentity(
    id: 'cable-0017',
    routeId: 'route-0017',
    circuitId: 'circuit-light-01',
    designation: 'W-017',
    cableSpecId: 'vvgng-ls-3x1.5',
    endA: CableTerminationRef(
      componentId: 'DB-01',
      portId: 'outgoing',
      terminalId: 'QF-07:L',
    ),
    endB: CableTerminationRef(
      componentId: 'LIGHT-03',
      portId: 'power-in',
      terminalId: 'L',
    ),
  );

  test('both cable ends keep the same stable cable designation', () {
    final a = CableLabelComposer.compose(
      cable: cable,
      circuit: circuit,
      end: CableEnd.a,
      cableSpecDisplayName: 'VVGng-LS 3x1.5',
    );
    final b = CableLabelComposer.compose(
      cable: cable,
      circuit: circuit,
      end: CableEnd.b,
      cableSpecDisplayName: 'VVGng-LS 3x1.5',
    );

    expect(a.primaryText, 'W-017');
    expect(b.primaryText, 'W-017');
    expect(a.secondaryText, contains('DB-01'));
    expect(a.secondaryText, contains('QF-07'));
    expect(a.qrPayload, 'elecx://cable/cable-0017?end=a');
    expect(b.qrPayload, 'elecx://cable/cable-0017?end=b');
  });

  test('label preserves termination identity for installation traceability',
      () {
    final label = CableLabelComposer.compose(
      cable: cable,
      circuit: circuit,
      end: CableEnd.b,
    );

    expect(label.tertiaryText, contains('LIGHT-03:power-in'));
    expect(label.tertiaryText, contains('DB-01:outgoing'));
  });
}
