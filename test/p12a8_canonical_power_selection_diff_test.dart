import 'package:elecx/src/application/project/engineering/canonical_power_selection_diff.dart';
import 'package:elecx/src/domain/canonical_power_selection.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const changedDigest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

CanonicalPowerCircuitSelection selection(
  String circuit, {
  String cable = 'cable-1',
  String fingerprint = digest,
}) =>
    CanonicalPowerCircuitSelection(
      circuitId: CircuitId(circuit),
      generationKey: 'generation-$circuit',
      boardComponentId: ComponentId('board-1'),
      boardCatalogTypeId: 'board-type',
      catalogSnapshotId: 'catalog-1',
      boardRatings: CanonicalBoardElectricalRatings(
        ratedBusbarCurrentA: 63,
        shortCircuitWithstandKa: 6,
        ratedVoltageV: 230,
        ipRating: 'IP40',
        manufacturerSourceId: 'board',
      ),
      cableCatalogId: cable,
      cableRatings: CanonicalCableElectricalRatings(
        conductorCrossSectionMm2: 2.5,
        conductorCount: 3,
        ratedVoltageV: 450,
        governingAmpacityA: 25,
        calculatedVoltageDropRatio: 0.01,
      ),
      cableSourceId: 'cable',
      protectionCatalogId: 'breaker-b16',
      protectionRatings: CanonicalProtectionElectricalRatings(
        ratedCurrentA: 16,
        breakingCapacityKa: 6,
        poleCount: 1,
        deviceKind: 'mcb',
        tripCharacteristic: 'B',
      ),
      protectionSourceId: 'breaker',
      normativeSourceId: 'norm',
      routeEvidenceSourceId: 'route',
      faultCurrentEvidenceSourceId: 'fault',
      routeLengthMm: 12000,
      evidenceFingerprint: fingerprint,
      sources: [
        for (final id in ['board', 'cable', 'breaker', 'norm', 'route', 'fault'])
          CanonicalEngineeringSourceReference(
            sourceId: id,
            revision: 'v1',
            sha256: digest,
            approvalId: 'approval',
          ),
      ],
    );

CanonicalPowerSelectionRegistry registry(
  Iterable<CanonicalPowerCircuitSelection> selections,
) =>
    CanonicalPowerSelectionRegistry(selections: selections);

void main() {
  group('P12A.8 typed canonical POWER changes', () {
    test('unchanged canonical data produces no changes', () {
      final before = registry([selection('c1')]);
      final after = registry([selection('c1')]);
      final diff = CanonicalPowerSelectionDiff.between(before, after);
      expect(diff.isEmpty, isTrue);
    });

    test('stable add update remove order and typed before after', () {
      final before = registry([selection('c2'), selection('c1')]);
      final after = registry([
        selection('c2', cable: 'cable-2'),
        selection('c3'),
      ]);
      final diff = CanonicalPowerSelectionDiff.between(before, after);
      expect(
        diff.changes.map((change) => change.circuitId.value),
        ['c1', 'c2', 'c3'],
      );
      expect(diff.changes.map((change) => change.kind), [
        CanonicalPowerSelectionChangeKind.remove,
        CanonicalPowerSelectionChangeKind.update,
        CanonicalPowerSelectionChangeKind.add,
      ]);
      expect(diff.changes[1].before!.cableCatalogId, 'cable-1');
      expect(diff.changes[1].after!.cableCatalogId, 'cable-2');
      expect(diff.changes[1].equipmentChanged, isTrue);
      expect(diff.changes[1].provenanceChanged, isFalse);
      expect(diff.isNotEmpty, isTrue);
    });

    test('fingerprint changes detect provenance-only edits', () {
      final before = registry([selection('c1')]);
      final after = registry([selection('c1', fingerprint: changedDigest)]);
      final diff = CanonicalPowerSelectionDiff.between(before, after);
      expect(diff.changes, hasLength(1));
      expect(diff.changes.single.equipmentChanged, isFalse);
      expect(diff.changes.single.provenanceChanged, isTrue);
    });

    test('permutations preserve typed diff fingerprint', () {
      final first = CanonicalPowerSelectionDiff.between(
        registry([]),
        registry([selection('c2'), selection('c1')]),
      );
      final second = CanonicalPowerSelectionDiff.between(
        registry([]),
        registry([selection('c1'), selection('c2')]),
      );
      expect(first.fingerprint, second.fingerprint);
    });

    test('cannot create an invalid typed operation', () {
      expect(
        () => CanonicalPowerSelectionChange(
          circuitId: CircuitId('c1'),
          kind: CanonicalPowerSelectionChangeKind.update,
          before: null,
          after: selection('c1'),
        ),
        throwsArgumentError,
      );
      expect(
        () => CanonicalPowerSelectionChange(
          circuitId: CircuitId('foreign'),
          kind: CanonicalPowerSelectionChangeKind.add,
          before: null,
          after: selection('c1'),
        ),
        throwsArgumentError,
      );
    });
  });
}
