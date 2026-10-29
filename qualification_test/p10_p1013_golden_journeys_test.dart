import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/p1011_wizard_fixture.dart';
import '../test/support/p109_site_fixture.dart';
import 'support/p10_qualification_fixture.dart';

void main() {
  for (final (family, gate) in [
    (BuildingCompositionWizardFamily.cottage, 'GJ-COTTAGE-01'),
    (BuildingCompositionWizardFamily.residentialTower, 'GJ-TOWER-01'),
    (BuildingCompositionWizardFamily.residentialComplex, 'GJ-COMPLEX-01')
  ]) {
    test(
        '$gate: real owner Generate Preview Apply Undo Redo Save Reopen Edit Undo Redo Save Reopen',
        () async {
      final r = P1011WizardRuntime(family: family);
      r.wizard.updateParameters(p10QualificationParameters(family));
      final ownerDirectory = await Directory.systemTemp.createTemp('p1013-gj-');
      addTearDown(() => ownerDirectory.delete(recursive: true));
      final repository = JsonProjectRepository(
          rootDirectory: ownerDirectory,
          codec:
              const CompositionProvenanceAwareCanonicalProjectDocumentCodec());
      final owner = CanonicalProjectPersistenceOwner(
          repository: repository, snapshot: p109Snapshot(r.mutations.current));
      expect(r.wizard.generatePreview(), isTrue, reason: '${r.wizard.failure}');
      final frozen = r.wizard.preview!;
      expect(owner.project.stores.buildings, isEmpty);
      final expected = p1011Bytes(frozen.candidate, includeVersion: false);
      expect(r.wizard.confirm(), isTrue, reason: '${r.wizard.failure}');
      final result = r.wizard.commitResult!.mutation;
      owner.acceptMutation(sessionProject: r.mutations.current, result: result);
      expect(r.mutations.undoDepth, 1);
      if (family != BuildingCompositionWizardFamily.cottage) {
        final tower = r.mutations.current.stores.buildings.values.firstWhere(
            (b) =>
                b.levelIds
                    .where((id) =>
                        r.mutations.current.stores.levels[id]!.kind ==
                        ProjectLevelKind.residential)
                    .length ==
                16);
        final levels =
            tower.levelIds.map((id) => r.mutations.current.stores.levels[id]!);
        expect(levels.where((l) => l.kind == ProjectLevelKind.basement),
            hasLength(2));
        expect(levels.where((l) => l.kind == ProjectLevelKind.technical),
            hasLength(1));
        expect(
            levels.where((l) => l.kind == ProjectLevelKind.roof), hasLength(1));
        expect(r.mutations.current.stores.spaces.length, greaterThan(200));
        expect(
            r.mutations.current.engineeringMetadata.generationProvenanceRegistry
                .levelCompositions,
            hasLength(16));
      }
      expect(r.mutations.current.engineeringMetadata.siteLayout.serviceAnchors,
          hasLength(10));
      if (family == BuildingCompositionWizardFamily.residentialComplex) {
        expect(r.mutations.current.stores.buildings, hasLength(3));
        expect(r.mutations.current.engineeringMetadata.siteLayout.sharedAnchors,
            hasLength(2));
      }
      final undo = r.mutations.undo(r.mutations.current.version)!;
      owner.acceptMutation(sessionProject: r.mutations.current, result: undo);
      expect(owner.project.stores.buildings, isEmpty);
      final redo = r.mutations.redo(r.mutations.current.version)!;
      owner.acceptMutation(sessionProject: r.mutations.current, result: redo);
      expect(p1011Bytes(owner.project, includeVersion: false), expected);
      await owner.save();
      final reopened = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: owner.projectId))!;
      expect(p1011Bytes(reopened.project, includeVersion: false), expected);
      final session = ProjectMutationSession(reopened.project);
      final space = reopened.project.stores.spaces.keys.last;
      final edit = session.commit(ProjectMutationRequest(
          expectedVersion: session.current.version,
          command:
              RenameSpaceCommand(spaceId: space, name: 'GJ manual override')))!;
      reopened.acceptMutation(sessionProject: session.current, result: edit);
      final edited = p1011Bytes(session.current, includeVersion: false);
      final editUndo = session.undo(session.current.version)!;
      reopened.acceptMutation(
          sessionProject: session.current, result: editUndo);
      expect(p1011Bytes(reopened.project, includeVersion: false), expected);
      final editRedo = session.redo(session.current.version)!;
      reopened.acceptMutation(
          sessionProject: session.current, result: editRedo);
      await reopened.save();
      final finalOwner = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: owner.projectId))!;
      expect(p1011Bytes(finalOwner.project, includeVersion: false), edited);
      stdout.writeln(
          '$gate: ${finalOwner.project.stores.buildings.length} buildings / ${finalOwner.project.stores.levels.length} levels / ${finalOwner.project.stores.spaces.length} spaces');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
