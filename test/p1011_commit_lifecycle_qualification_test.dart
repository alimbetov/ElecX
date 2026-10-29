import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_orientation_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1011_wizard_fixture.dart';

void main() {
  for (final family in BuildingCompositionWizardFamily.values) {
    test(
        'P10-Q13 ${family.name}: cancel discards the exact frozen preview with zero canonical changes',
        () {
      final runtime = P1011WizardRuntime(family: family);
      final before = runtime.mutations.current,
          bytes = p1011Bytes(runtime.mutations.current);
      expect(runtime.wizard.generatePreview(), isTrue,
          reason: '${runtime.wizard.failure}');
      final frozen = runtime.wizard.preview!;
      expect(runtime.port.activePreviewCount, 1);
      expect(frozen.candidate.engineeringMetadata.siteLayout.serviceAnchors,
          hasLength(10));
      expect(runtime.wizard.cancel(), isTrue);
      expect(runtime.wizard.preview, isNull);
      expect(runtime.wizard.generatedCommand, isNull);
      expect(runtime.mutations.current, same(before));
      expect(p1011Bytes(runtime.mutations.current), bytes);
      expect(runtime.mutations.undoDepth, 0);
      expect(runtime.mutations.redoDepth, 0);
      expect(runtime.port.activePreviewCount, 0);
      expect(() => runtime.port.commitPreview(frozen),
          throwsA(isA<DiscardedWizardPreviewException>()));
    });
    test(
        'P10-Q14 ${family.name}: stale Apply drops reservation and preserves only concurrent edit',
        () {
      final runtime = P1011WizardRuntime(family: family);
      expect(runtime.wizard.generatePreview(), isTrue,
          reason: '${runtime.wizard.failure}');
      final frozen = runtime.wizard.preview!;
      runtime.mutations.commit(ProjectMutationRequest(
          expectedVersion: runtime.mutations.current.version,
          command: SetProjectNorthCommand(
              ProjectEngineeringNorth.fromDegrees(37.5))));
      final concurrent = runtime.mutations.current,
          bytes = p1011Bytes(runtime.mutations.current);
      expect(runtime.wizard.confirm(), isFalse);
      expect(runtime.wizard.blockReason,
          WizardPreviewBlockReason.staleBaseVersion);
      expect(runtime.wizard.preview, isNull);
      expect(runtime.wizard.generatedCommand, isNull);
      expect(runtime.port.activePreviewCount, 0);
      expect(runtime.mutations.current, same(concurrent));
      expect(p1011Bytes(runtime.mutations.current), bytes);
      expect(runtime.mutations.undoDepth, 1);
      expect(runtime.mutations.redoDepth, 0);
      expect(() => runtime.port.commitPreview(frozen),
          throwsA(isA<DiscardedWizardPreviewException>()));
      expect(runtime.wizard.rebaseToCurrent(), isTrue);
      expect(runtime.wizard.generatePreview(), isTrue);
      expect(identical(runtime.wizard.preview, frozen), isFalse);
      runtime.wizard.cancel();
      expect(runtime.port.activePreviewCount, 0);
    });
    test(
        'P10-Q15 ${family.name}: commit-time fault after successful Preview rejects fully validated state before publication',
        () {
      var reject = false, calls = 0;
      final runtime = P1011WizardRuntime(
          family: family,
          guard: (before, candidate, changeSet) {
            calls++;
            expect(candidate.version, before.version.next());
            expect(changeSet.entityDiff.addedEntityIds, isNotEmpty);
            expect(candidate.engineeringMetadata.siteLayout.serviceAnchors,
                hasLength(10));
            expect(candidate.stores.verticalCores, isNotEmpty);
            if (reject) {
              throw StateError(
                  'Injected canonical commit publication failure.');
            }
          });
      final before = runtime.mutations.current,
          bytes = p1011Bytes(runtime.mutations.current);
      expect(runtime.wizard.generatePreview(), isTrue,
          reason: '${runtime.wizard.failure}');
      expect(calls, 0);
      final frozen = runtime.wizard.preview!;
      expect(runtime.wizard.canConfirm, isTrue);
      reject = true;
      expect(runtime.wizard.confirm(), isFalse);
      expect(calls, 1);
      expect(runtime.wizard.status, WizardSessionStatus.failed);
      expect(runtime.wizard.failure, isA<StateError>());
      expect(runtime.mutations.current, same(before));
      expect(p1011Bytes(runtime.mutations.current), bytes);
      expect(runtime.mutations.undoDepth, 0);
      expect(runtime.mutations.redoDepth, 0);
      expect(runtime.port.activePreviewCount, 0);
      expect(runtime.wizard.preview, isNull);
      expect(runtime.wizard.generatedCommand, isNull);
      expect(runtime.wizard.commitResult, isNull);
      expect(() => runtime.port.commitPreview(frozen),
          throwsA(isA<DiscardedWizardPreviewException>()));
    });
    test(
        'P10-Q16 ${family.name}: one Apply Undo Redo restores exact entire composition, hosts and nested lineage',
        () {
      final runtime = P1011WizardRuntime(family: family);
      expect(runtime.wizard.generatePreview(), isTrue,
          reason: '${runtime.wizard.failure}');
      final frozen = runtime.wizard.preview!;
      final expected = p1011Bytes(frozen.candidate, includeVersion: false);
      expect(runtime.wizard.confirm(), isTrue);
      expect(runtime.mutations.undoDepth, 1);
      expect(runtime.mutations.redoDepth, 0);
      expect(runtime.port.activePreviewCount, 0);
      expect(p1011Bytes(runtime.mutations.current, includeVersion: false),
          expected);
      expect(runtime.wizard.confirm(), isFalse);
      expect(runtime.mutations.undoDepth, 1);
      runtime.mutations.undo(runtime.mutations.current.version);
      expect(runtime.mutations.undoDepth, 0);
      expect(runtime.mutations.redoDepth, 1);
      final undone = runtime.mutations.current;
      expect(undone.stores.buildings, isEmpty);
      expect(undone.stores.levels, isEmpty);
      expect(undone.stores.zones, isEmpty);
      expect(undone.stores.spaces, isEmpty);
      expect(undone.stores.boundaries, isEmpty);
      expect(undone.stores.openings, isEmpty);
      expect(undone.stores.adjacencies, isEmpty);
      expect(undone.stores.slabs, isEmpty);
      expect(undone.stores.verticalCores, isEmpty);
      expect(undone.engineeringMetadata.siteLayout.isEmpty, isTrue);
      expect(undone.engineeringMetadata.boundaryHostedObjectRegistry.references,
          isEmpty);
      expect(undone.engineeringMetadata.generationProvenanceRegistry.manifests,
          isEmpty);
      runtime.mutations.redo(runtime.mutations.current.version);
      expect(p1011Bytes(runtime.mutations.current, includeVersion: false),
          expected);
      expect(runtime.mutations.undoDepth, 1);
      expect(runtime.mutations.redoDepth, 0);
    });
  }
}
