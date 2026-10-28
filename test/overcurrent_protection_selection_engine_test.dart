import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/engine/overcurrent_protection_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c10 = OvercurrentProtectiveDeviceSpec(
    id: 'mcb-c10-6ka',
    kind: OvercurrentDeviceKind.mcb,
    ratedCurrentA: 10,
    breakingCapacityKa: 6,
    poleCount: 1,
    tripCurve: OvercurrentTripCurve.c,
    sourceId: 'catalog',
    sourceRevision: '1',
  );
  const c16 = OvercurrentProtectiveDeviceSpec(
    id: 'mcb-c16-6ka',
    kind: OvercurrentDeviceKind.mcb,
    ratedCurrentA: 16,
    breakingCapacityKa: 6,
    poleCount: 1,
    tripCurve: OvercurrentTripCurve.c,
    sourceId: 'catalog',
    sourceRevision: '1',
  );
  const c20 = OvercurrentProtectiveDeviceSpec(
    id: 'mcb-c20-6ka',
    kind: OvercurrentDeviceKind.mcb,
    ratedCurrentA: 20,
    breakingCapacityKa: 6,
    poleCount: 1,
    tripCurve: OvercurrentTripCurve.c,
    sourceId: 'catalog',
    sourceRevision: '1',
  );

  test('selects smallest In satisfying Ib <= In <= Iz', () {
    final result = OvercurrentProtectionSelectionEngine.select(
      OvercurrentProtectionRequest(
        designCurrentA: 11.1,
        cableAmpacityA: 21,
        prospectiveShortCircuitCurrentA: 3500,
        candidates: const [c20, c10, c16],
      ),
    );

    expect(result.isSelected, isTrue);
    expect(result.selected!.id, c16.id);
    expect(
      result.rejections[c10.id],
      contains('rated-current-below-design-current'),
    );
  });

  test('rejects device whose In exceeds cable ampacity', () {
    final result = OvercurrentProtectionSelectionEngine.select(
      OvercurrentProtectionRequest(
        designCurrentA: 18,
        cableAmpacityA: 19,
        prospectiveShortCircuitCurrentA: 3500,
        candidates: const [c20],
      ),
    );

    expect(result.isSelected, isFalse);
    expect(
      result.rejections[c20.id],
      contains('rated-current-exceeds-cable-ampacity'),
    );
  });

  test('breaking capacity must cover prospective short-circuit current', () {
    final result = OvercurrentProtectionSelectionEngine.select(
      OvercurrentProtectionRequest(
        designCurrentA: 12,
        cableAmpacityA: 25,
        prospectiveShortCircuitCurrentA: 7000,
        candidates: const [c16, c20],
      ),
    );

    expect(result.isSelected, isFalse);
    expect(
      result.rejections[c16.id],
      contains('breaking-capacity-below-prospective-short-circuit-current'),
    );
  });

  test('selection is deterministic for equal ratings', () {
    const second = OvercurrentProtectiveDeviceSpec(
      id: 'mcb-c16-10ka',
      kind: OvercurrentDeviceKind.mcb,
      ratedCurrentA: 16,
      breakingCapacityKa: 10,
      poleCount: 1,
      tripCurve: OvercurrentTripCurve.c,
      sourceId: 'catalog',
      sourceRevision: '1',
    );
    final result = OvercurrentProtectionSelectionEngine.select(
      OvercurrentProtectionRequest(
        designCurrentA: 12,
        cableAmpacityA: 25,
        prospectiveShortCircuitCurrentA: 3000,
        candidates: const [second, c16],
      ),
    );

    expect(result.selected!.id, c16.id);
  });
}
