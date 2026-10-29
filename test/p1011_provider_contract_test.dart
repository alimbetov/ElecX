import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_command.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_preview.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/service_anchor_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1011_wizard_fixture.dart';
import 'support/p109_site_fixture.dart';

void main() {
  test(
      'candidate evidence is ID-free, immutable and normalized; actual templates and P9 selections are retained',
      () {
    final runtime = P1011WizardRuntime(
        family: BuildingCompositionWizardFamily.residentialComplex);
    final before = runtime.mutations.current,
        bytes = p1011Bytes(runtime.mutations.current);
    final input =
        runtime.wizard.parameters! as BuildingCompositionWizardParameters;
    final reversed = BuildingCompositionWizardParameters.residentialComplex(
        compositionKey: input.compositionKey,
        buildings: input.siteBuildings.reversed,
        sharedSiteAnchors: input.sharedSiteAnchors.reversed,
        serviceAnchors: input.serviceAnchors.reversed);
    BuildingCompositionWizardCommand generate(
            BuildingCompositionWizardParameters p) =>
        const BuildingCompositionWizardProvider().generateTyped(
            p,
            WizardGenerationContext(
                target: runtime.wizard.target,
                project: before)) as BuildingCompositionWizardCommand;
    final a = generate(input).composition, b = generate(reversed).composition;
    expect(a.requestFingerprint, b.requestFingerprint);
    expect(a.candidateFingerprint, b.candidateFingerprint);
    expect(a.requestFingerprint, isNot(a.candidateFingerprint));
    expect(a.templates, hasLength(3));
    expect(a.apartmentCandidateFingerprints, hasLength(2));
    expect(a.deterministicRank, 0);
    expect(a.validationEvidence, isNotEmpty);
    expect(() => a.serviceAnchors.clear(), throwsUnsupportedError);
    expect(() => a.templates.clear(), throwsUnsupportedError);
    for (final binding in a.templates.values) {
      expect(binding.reference.templateVersion, 1);
      expect(binding.reference.catalogVersion, 1);
    }
    expect(runtime.mutations.current, same(before));
    expect(p1011Bytes(runtime.mutations.current), bytes);
    expect(runtime.port.activePreviewCount, 0);
  });
  test(
      'frozen composition diff exposes typed cores, service wall hosts, apartments and shared Site anchors',
      () {
    final runtime = P1011WizardRuntime(
        family: BuildingCompositionWizardFamily.residentialComplex);
    expect(runtime.wizard.generatePreview(), isTrue,
        reason: '${runtime.wizard.failure}');
    final frozen = runtime.wizard.preview!;
    final projection = const BuildingCompositionWizardPreviewProjector()
        .project(before: runtime.mutations.current, preview: frozen);
    expect(projection.addedBuildings, 3);
    expect(projection.addedApartments, 4);
    expect(projection.addedServiceAnchors, 10);
    expect(projection.addedSharedAnchors, 2);
    expect(projection.serviceCounts.keys.toSet(),
        ProjectServiceAnchorKind.values.toSet());
    expect(
        projection.diff.entries
            .where((e) => e.category == WizardDiffEntityCategory.verticalCore),
        isNotEmpty);
    final services = projection.diff.entries
        .where((e) => e.category == WizardDiffEntityCategory.serviceAnchor)
        .toList();
    expect(services, hasLength(12));
    expect(services.expand((e) => e.fields).map((f) => f.field),
        containsAll(['Boundary edge', 'Offset']));
    final scene =
        const BuildingCompositionWizardSceneProjector().project(frozen);
    expect(scene.elements.where((e) => e.key.startsWith('outline:')),
        hasLength(3));
    expect(scene.elements.where((e) => e.key.startsWith('anchor:')),
        hasLength(12));
    runtime.wizard.cancel();
  });
  test(
      'selected service intent without explicit locations fails without a live reservation',
      () {
    final runtime = P1011WizardRuntime();
    final input =
        runtime.wizard.parameters! as BuildingCompositionWizardParameters;
    runtime.wizard.updateParameters(BuildingCompositionWizardParameters.cottage(
        compositionKey: input.compositionKey,
        parameters: input.buildingParameters!,
        layout: input.layout!));
    final bytes = p1011Bytes(runtime.mutations.current);
    expect(runtime.wizard.generatePreview(), isFalse);
    expect(runtime.wizard.failure, isA<ServiceAnchorException>());
    expect(runtime.port.activePreviewCount, 0);
    expect(runtime.mutations.undoDepth, 0);
    expect(p1011Bytes(runtime.mutations.current), bytes);
  });
  test(
      'editing a draft after Preview invalidates retained reservation and Apply requires a fresh preview',
      () {
    final runtime = P1011WizardRuntime();
    expect(runtime.wizard.generatePreview(), isTrue);
    final frozen = runtime.wizard.preview!;
    expect(runtime.wizard.updateParameters(runtime.wizard.parameters!), isTrue);
    expect(runtime.wizard.canConfirm, isFalse);
    expect(runtime.wizard.preview, isNull);
    expect(runtime.port.activePreviewCount, 0);
    expect(() => runtime.port.commitPreview(frozen),
        throwsA(isA<DiscardedWizardPreviewException>()));
    expect(runtime.mutations.undoDepth, 0);
  });
  for (final family in BuildingCompositionWizardFamily.values) {
    test(
        'OWNER-01 ${family.name}: same persistence owner Save Reopen Edit Undo Redo Save Reopen',
        () async {
      final directory = await Directory.systemTemp.createTemp('p1011-owner-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonProjectRepository(
          rootDirectory: directory,
          codec: const ServiceAnchorAwareCanonicalProjectDocumentCodec());
      final runtime = P1011WizardRuntime(family: family);
      final owner = CanonicalProjectPersistenceOwner(
          repository: repository,
          snapshot: p109Snapshot(runtime.mutations.current));
      expect(runtime.wizard.generatePreview(), isTrue);
      expect(runtime.wizard.confirm(), isTrue);
      owner.acceptMutation(
          sessionProject: runtime.mutations.current,
          result: runtime.wizard.commitResult!.mutation);
      await owner.save();
      final loaded = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: owner.projectId))!;
      expect(p1011Bytes(loaded.project), p1011Bytes(runtime.mutations.current));
      final edits = ProjectMutationSession(loaded.project);
      final provenance =
          loaded.project.engineeringMetadata.generationProvenanceRegistry;
      final space = provenance.manifests.isEmpty
          ? loaded.project.stores.spaces.keys.first
          : loaded
              .project
              .stores
              .zones[provenance.manifests.values.first.apartmentZoneId]!
              .spaceIds
              .first;
      void accept(ProjectMutationResult result) =>
          loaded.acceptMutation(sessionProject: edits.current, result: result);
      accept(edits.commit(ProjectMutationRequest(
          expectedVersion: edits.current.version,
          command: RenameSpaceCommand(
              spaceId: space, name: 'Custom generated room')))!);
      accept(edits.undo(edits.current.version)!);
      accept(edits.redo(edits.current.version)!);
      await loaded.save();
      final reopened = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: owner.projectId))!;
      expect(p1011Bytes(reopened.project), p1011Bytes(edits.current));
      expect(
          reopened.project.engineeringMetadata.siteLayout.serviceAnchors.keys
              .toSet(),
          runtime.mutations.current.engineeringMetadata.siteLayout
              .serviceAnchors.keys
              .toSet());
      expect(
          reopened.project.engineeringMetadata.boundaryHostedObjectRegistry
              .sameAs(runtime.mutations.current.engineeringMetadata
                  .boundaryHostedObjectRegistry),
          isTrue);
    });
  }
}
