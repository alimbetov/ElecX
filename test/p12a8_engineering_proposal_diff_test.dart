import 'package:elecx/src/application/project/engineering/engineering_proposal_diff.dart';
import 'package:elecx/src/engine/power_evidence_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringProposalDiffEntry _entry(
  String key,
  String circuit, {
  EngineeringProposalStatus status = EngineeringProposalStatus.selected,
}) =>
    EngineeringProposalDiffEntry(
      generationKey: key,
      calculationCircuitId: circuit,
      status: status,
      cableCatalogId:
          status == EngineeringProposalStatus.selected ? 'cable-a' : null,
      protectionCatalogId:
          status == EngineeringProposalStatus.selected ? 'mcb-a' : null,
    );

EngineeringProposalDiff _diff({
  List<EngineeringProposalDiffEntry>? entries,
  List<PowerEvidenceSelectionIssue> issues = const [],
  String fingerprint = 'source-v1',
}) =>
    EngineeringProposalDiff(
      sourceFingerprint: fingerprint,
      boardGenerationKey: 'board-01',
      catalogSnapshotId: 'catalog-r1',
      entries: entries ?? [_entry('key-1', 'circuit-1')],
      issues: issues,
    );

void main() {
  group('P12A.8 typed read-only engineering proposal diff', () {
    test('permuted circuits have identical ordered diff and fingerprint', () {
      final first = _diff(entries: [
        _entry('b', 'circuit-b'),
        _entry('a', 'circuit-a'),
      ]);
      final second = _diff(entries: [
        _entry('a', 'circuit-a'),
        _entry('b', 'circuit-b'),
      ]);
      expect(first.entries.map((entry) => entry.generationKey), ['a', 'b']);
      expect(first.fingerprint, second.fingerprint);
      expect(first.isFullySelected, isTrue);
      expect(first.readyToApply, isFalse);
    });

    test('source fingerprint changes invalidate proposal fingerprint', () {
      expect(
        _diff().fingerprint,
        isNot(_diff(fingerprint: 'source-v2').fingerprint),
      );
    });

    test('unresolved pair is visible but never fully selected', () {
      final diff = _diff(entries: [
        _entry('key-1', 'circuit-1',
            status: EngineeringProposalStatus.unresolved),
      ]);
      expect(diff.isFullySelected, isFalse);
      expect(diff.entries.single.cableCatalogId, isNull);
      expect(diff.readyToApply, isFalse);
    });

    test('unverified board rating remains an explicit blocker', () {
      final diff = _diff(
        issues: [
          PowerEvidenceSelectionIssue.boardElectricalRatingsUnverified,
        ],
      );
      expect(diff.isFullySelected, isFalse);
      expect(diff.readyToApply, isFalse);
    });

    test('duplicate generation or calculated circuit identity fails', () {
      expect(
        () => _diff(entries: [
          _entry('same', 'circuit-a'),
          _entry('same', 'circuit-b'),
        ]),
        throwsArgumentError,
      );
      expect(
        () => _diff(entries: [
          _entry('a', 'same'),
          _entry('b', 'same'),
        ]),
        throwsArgumentError,
      );
    });

    test('incomplete selected pair and false unresolved pair fail closed', () {
      expect(
        () => EngineeringProposalDiffEntry(
          generationKey: 'k',
          calculationCircuitId: 'c',
          status: EngineeringProposalStatus.selected,
          cableCatalogId: 'cable-only',
        ),
        throwsArgumentError,
      );
      expect(
        () => EngineeringProposalDiffEntry(
          generationKey: 'k',
          calculationCircuitId: 'c',
          status: EngineeringProposalStatus.unresolved,
          cableCatalogId: 'not-allowed',
        ),
        throwsArgumentError,
      );
    });

    test('empty and mutable inputs cannot silently qualify a candidate', () {
      expect(() => _diff(entries: []), throwsArgumentError);
      final source = [_entry('a', 'circuit-a')];
      final diff = _diff(entries: source);
      source.clear();
      expect(diff.entries, hasLength(1));
      expect(() => diff.entries.clear(), throwsUnsupportedError);
    });
  });
}
