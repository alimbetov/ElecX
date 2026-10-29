import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'dart:io';
import 'dart:math';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p108_tower_fixture.dart';

void main() {
  final fixture = P108TowerFixture();
  test(
      'P10-Q10 production Generate Preview Apply Save Reopen Edit Undo Redo Save Reopen',
      () async {
    final basis = fixture.project;
    final mutations = ProjectMutationSession(basis);
    final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(10810)));
    final command = fixture.command(project: basis);
    final preview = port.preview(command);
    expect(mutations.current.stores.buildings, isEmpty);
    port.commitPreview(preview);
    final registry =
        mutations.current.engineeringMetadata.generationProvenanceRegistry;
    final floor = registry.floorInstances.keys.first;
    final sibling = registry.floorInstances.keys.last;
    final parent = registry.levelCompositions.values
        .singleWhere((p) => p.levelId == floor);
    final room = mutations.current.stores
        .zones[parent.apartments['a']!.apartmentZoneId]!.spaceIds.first;
    final core = mutations.current.stores.verticalCores.values.first;
    final bindings = core.hostSpaceIdsByLevel;
    final directory = await Directory.systemTemp.createTemp('p108-golden-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = JsonProjectRepository(
        rootDirectory: directory,
        codec: const CompositionProvenanceAwareCanonicalProjectDocumentCodec());
    final owner = CanonicalProjectPersistenceOwner(
        repository: repository, snapshot: p108Snapshot(mutations.current));
    await owner.save();
    final loaded = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: fixture.projectId))!;
    final edits = ProjectMutationSession(loaded.project);
    void accept(ProjectMutationResult result) => loaded.acceptMutation(
        sessionProject: edits.current,
        result: result,
        now: DateTime.utc(2026, 10, 29, 1));
    accept(edits.commit(ProjectMutationRequest(
        expectedVersion: edits.current.version,
        command:
            RenameSpaceCommand(spaceId: room, name: 'Custom tower room')))!);
    accept(edits.undo(edits.current.version)!);
    expect(edits.current.stores.spaces[room]!.name, isNot('Custom tower room'));
    accept(edits.redo(edits.current.version)!);
    accept(edits.commit(ProjectMutationRequest(
        expectedVersion: edits.current.version,
        command: RenumberLevelCommand(levelId: floor, levelNumber: 99)))!);
    await loaded.save();
    final reopened = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: fixture.projectId))!;
    final finalRegistry =
        reopened.project.engineeringMetadata.generationProvenanceRegistry;
    expect(reopened.project.stores.spaces[room]!.name, 'Custom tower room');
    expect(reopened.project.stores.levels[floor]!.levelNumber, 99);
    expect(reopened.project.stores.verticalCores[core.id]!.hostSpaceIdsByLevel,
        bindings);
    expect(reopened.project.stores.spaces.keys.toSet(),
        mutations.current.stores.spaces.keys.toSet());
    expect(finalRegistry.provenanceFor(room)!.overriddenProperties,
        contains(GenerationPropertyKey.name));
    expect(
        finalRegistry.floorInstances[floor]!.overriddenProperties, isNotEmpty);
    expect(
        finalRegistry.floorInstances[sibling]!
            .sameAs(registry.floorInstances[sibling]!),
        isTrue);
  });

  test(
      'cancel and stale confirmation never leave a partial tower or child provenance',
      () {
    final mutations = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(10811)));
    final command = fixture.command();
    final cancelled = port.preview(command);
    port.discardPreview(cancelled);
    expect(() => port.commitPreview(cancelled),
        throwsA(isA<DiscardedWizardPreviewException>()));
    final stale = port.preview(command);
    port.commitPreview(port.preview(command));
    final state = mutations.current;
    expect(() => port.commitPreview(stale),
        throwsA(isA<StaleProjectMutationException>()));
    expect(identical(mutations.current, state), isTrue);
    expect(
        mutations
            .current.engineeringMetadata.generationProvenanceRegistry.manifests,
        hasLength(4));
    mutations.undo(mutations.current.version);
    expect(mutations.current.stores.buildings, isEmpty);
    expect(
        mutations
            .current.engineeringMetadata.generationProvenanceRegistry.manifests,
        isEmpty);
  });
}
