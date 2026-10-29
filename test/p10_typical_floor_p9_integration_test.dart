import 'dart:math';

import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/typical_floor_commands.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/typical_floor.dart';
import 'package:elecx/src/serialization/project/typical_floor_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_typical_floor_fixture.dart';

void main() {
  test(
      'P10-Q04 real P9 apartment generations retain child provenance and independent floor overrides',
      () {
    final fixture = P10TypicalFloorFixture.create();
    final session = fixture.registeredSession();
    final ids = SecureRandomEntityIdFactory(random: Random(10409));
    final buildingId = fixture.definition.buildingId;
    final levelIds = [ids.newLevelId(), ids.newLevelId()];
    for (var index = 0; index < levelIds.length; index++) {
      session.commit(ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateLevelCommand(
              levelId: levelIds[index],
              buildingId: buildingId,
              name: 'Floor ${index + 3}',
              levelNumber: index + 3,
              elevationMm: (index + 2) * 3000,
              kind: ProjectLevelKind.residential)));
    }
    LevelWizardTarget target(LevelId levelId) => LevelWizardTarget(
        projectId: session.current.id,
        siteId: session.current.siteId,
        baseVersion: session.current.version,
        buildingId: buildingId,
        levelId: levelId);
    final generated = const ApartmentCandidateSetService().generate(
        input: ApartmentRequestInput.productionDefaults,
        target: target(levelIds.first),
        project: session.current);
    expect(generated.accepted, isTrue);
    final set = generated.candidateSet!;
    final selected = set.recommendedCandidate;
    final descriptor = const ApartmentWizardProvider.geometryOnly().descriptor;
    for (final levelId in levelIds) {
      final command = ApartmentReservedProjectCommand(
          target: target(levelId),
          descriptor: descriptor,
          candidateSetFingerprint: set.candidateSetFingerprint,
          candidateIdentity: selected.identity,
          selectedCandidate: selected.rankedCandidate.candidate,
          template: selected.template);
      final coordinator =
          ReservedProjectMutationCoordinator(session, entityIdFactory: ids);
      coordinator.commitPreview(coordinator.preview(command));
    }
    final registry = p10Registry(session);
    expect(registry.manifests, hasLength(2));
    expect(registry.typicalFloorDefinitions, hasLength(1));
    expect(registry.floorInstances, hasLength(2));
    final mappings = [
      for (final levelId in levelIds)
        <String, EntityId>{
          'level': levelId,
          for (final manifest in registry.manifests.values
              .where((manifest) => manifest.levelId == levelId))
            for (final entityId in manifest.generatedEntityIds)
              registry.provenanceFor(entityId)!.generationKey: entityId,
        },
    ];
    final definition = TypicalFloorDefinition(
        id: ids.newTypicalFloorDefinitionId(),
        buildingId: buildingId,
        templateId: TemplateId('p10.p9-floor'),
        templateVersion: 1,
        definitionKey: 'residential.p9',
        patternFingerprint: TypicalFloorPattern.fingerprint(
            stores: session.current.stores, entities: mappings.first),
        entityKinds: {
          for (final entry in mappings.first.entries)
            entry.key: typicalFloorEntityKind(entry.value)
        });
    final instances = [
      for (var index = 0; index < levelIds.length; index++)
        TypicalFloorInstance(
            levelId: levelIds[index],
            definitionId: definition.id,
            generationKey: 'p9.floor.${index + 1}',
            patternFingerprint: definition.patternFingerprint,
            entities: mappings[index])
    ];
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RegisterTypicalFloorCommand(
            definition: definition, instances: instances)));
    final firstSpaceEntry =
        mappings.first.entries.firstWhere((entry) => entry.value is SpaceId);
    final firstSpace = firstSpaceEntry.value as SpaceId;
    final siblingSpace = mappings.last[firstSpaceEntry.key]! as SpaceId;
    final siblingName = session.current.stores.spaces[siblingSpace]!.name;
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command:
            RenameSpaceCommand(spaceId: firstSpace, name: 'Edited P9 room')));
    final after = p10Registry(session);
    expect(after.provenanceFor(firstSpace)!.overriddenProperties,
        contains(GenerationPropertyKey.name));
    expect(
        after.floorInstances[levelIds.first]!
            .overriddenProperties[firstSpaceEntry.key],
        {GenerationPropertyKey.name});
    expect(after.provenanceFor(siblingSpace)!.overriddenProperties, isEmpty);
    expect(after.floorInstances[levelIds.last]!.overriddenProperties, isEmpty);
    expect(session.current.stores.spaces[siblingSpace]!.name, siblingName);
    const codec = TypicalFloorAwareCanonicalProjectDocumentCodec();
    final reopened = codec.decode(codec.encode(p10Snapshot(session.current)));
    expect(
        reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
            .sameAs(after),
        isTrue);
    expect(after.manifests, hasLength(2));
    expect(after.floorInstances, hasLength(4));
  });
}
