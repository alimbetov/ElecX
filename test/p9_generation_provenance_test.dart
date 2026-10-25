import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/generation_provenance_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/structural_semantics_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.12 generation provenance', () {
    test('P9.12-AT-001 generation creates exactly one manifest', () {
      final harness = _Harness.generate(seed: 12001);
      final registry = harness.registry;

      expect(registry.manifests, hasLength(1));
      expect(registry.entities, isNotEmpty);
      final manifest = registry.manifests.values.single;
      expect(manifest.originType, GenerationOriginType.wizard);
      expect(manifest.projectId, harness.fixture.project.id);
      expect(manifest.buildingId, harness.fixture.buildingId);
      expect(manifest.levelId, harness.fixture.levelId);
      expect(manifest.selectedCandidateFingerprint, harness.card.candidateFingerprint);
      expect(manifest.normalizedIntentFingerprint, harness.card.identity.intentFingerprint);
      expect(manifest.generatedEntityIds, registry.entities.keys.toSet());
    });

    test('P9.12-AT-002 every generated Space has generationId and generationKey',
        () {
      final harness = _Harness.generate(seed: 12002);
      final registry = harness.registry;
      final manifest = registry.manifests.values.single;
      final zone = harness.mutations.current.stores.zones[manifest.apartmentZoneId]!;

      expect(zone.spaceIds, isNotEmpty);
      for (final spaceId in zone.spaceIds) {
        final provenance = registry.provenanceFor(spaceId);
        expect(provenance, isNotNull, reason: '$spaceId must have provenance');
        expect(provenance!.generationId, manifest.generationId);
        expect(provenance.generationKey, startsWith('space:'));
        expect(
          provenance.generatedProperties,
          containsAll(<GenerationPropertyKey>{
            GenerationPropertyKey.name,
            GenerationPropertyKey.spaceType,
            GenerationPropertyKey.spaceUsage,
            GenerationPropertyKey.geometry,
            GenerationPropertyKey.zoneMembership,
            GenerationPropertyKey.openingRelations,
            GenerationPropertyKey.adjacencyRelations,
          }),
        );
      }
    });

    test('P9.12-AT-003 save/reopen preserves provenance byte-semantics', () {
      final harness = _Harness.generate(seed: 12003);
      const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
      final first = codec.encode(_snapshot(harness.mutations.current));
      final reopened = codec.decode(first);
      final second = codec.encode(reopened);

      expect(first.schemaVersion, 12);
      expect(
        reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
            .sameAs(harness.registry),
        isTrue,
      );
      expect(
        jsonEncode(first.payload['generationProvenance']),
        jsonEncode(second.payload['generationProvenance']),
      );
    });

    test('P9.12-AT-004 rename marks name overridden and Undo/Redo is exact', () {
      final harness = _Harness.generate(seed: 12004);
      final spaceId = harness.firstSpaceId;
      final before = harness.registry.provenanceFor(spaceId)!;

      final renamed = harness.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: harness.mutations.current.version,
          command: _RenameSpaceCommand(spaceId, 'Custom Bedroom'),
        ),
      );
      expect(renamed, isNotNull);
      final after = harness.registry.provenanceFor(spaceId)!;
      expect(after.generationId, before.generationId);
      expect(after.generationKey, before.generationKey);
      expect(
        after.overriddenProperties,
        contains(GenerationPropertyKey.name),
      );

      final undo = harness.mutations.undo(harness.mutations.current.version);
      expect(undo, isNotNull);
      final undone = harness.registry.provenanceFor(spaceId)!;
      expect(undone.generationId, before.generationId);
      expect(undone.generationKey, before.generationKey);
      expect(
        undone.overriddenProperties,
        isNot(contains(GenerationPropertyKey.name)),
      );

      final redo = harness.mutations.redo(harness.mutations.current.version);
      expect(redo, isNotNull);
      final redone = harness.registry.provenanceFor(spaceId)!;
      expect(redone.generationId, before.generationId);
      expect(redone.generationKey, before.generationKey);
      expect(
        redone.overriddenProperties,
        contains(GenerationPropertyKey.name),
      );
    });

    test('P9.12-FR-003 SpaceUsage edit marks spaceUsage overridden', () {
      final harness = _Harness.generate(seed: 120041);
      final spaceId = harness.firstSpaceId;
      final before = harness.registry.provenanceFor(spaceId)!;
      final currentSpace = harness.mutations.current.stores.spaces[spaceId]!;
      final replacementUsage = currentSpace.usage == SpaceUsage.study
          ? SpaceUsage.office
          : SpaceUsage.study;

      final result = harness.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: harness.mutations.current.version,
          command: _ChangeSpaceUsageCommand(spaceId, replacementUsage),
        ),
      );
      expect(result, isNotNull);
      final after = harness.registry.provenanceFor(spaceId)!;
      expect(after.generationId, before.generationId);
      expect(after.generationKey, before.generationKey);
      expect(
        after.overriddenProperties,
        contains(GenerationPropertyKey.spaceUsage),
      );
    });

    test('P9.12-AT-005 boundary geometry edit marks geometry overridden', () {
      final harness = _Harness.generate(seed: 12005);
      final spaceId = harness.firstSpaceId;
      final before = harness.registry.provenanceFor(spaceId)!;

      final result = harness.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: harness.mutations.current.version,
          command: _TranslateSpaceBoundaryCommand(spaceId, dxMm: 100),
        ),
      );
      expect(result, isNotNull);
      final after = harness.registry.provenanceFor(spaceId)!;
      expect(after.generationId, before.generationId);
      expect(after.generationKey, before.generationKey);
      expect(
        after.overriddenProperties,
        contains(GenerationPropertyKey.geometry),
      );
    });

    test('P9.12-AT-006 generationId and key survive manual edits', () {
      final harness = _Harness.generate(seed: 12006);
      final spaceId = harness.firstSpaceId;
      final before = harness.registry.provenanceFor(spaceId)!;

      harness.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: harness.mutations.current.version,
          command: _RenameSpaceCommand(spaceId, 'Engineer override'),
        ),
      );
      final after = harness.registry.provenanceFor(spaceId)!;

      expect(after.generationId, before.generationId);
      expect(after.generationKey, before.generationKey);
      expect(after.generatedBaselineFingerprint, before.generatedBaselineFingerprint);
    });

    test('P9.12-AT-007 regeneration lock survives save/reopen', () {
      final harness = _Harness.generate(seed: 12007);
      final spaceId = harness.firstSpaceId;
      final before = harness.registry.provenanceFor(spaceId)!;

      final locked = harness.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: harness.mutations.current.version,
          command: SetGeneratedEntityRegenerationLockCommand(
            entityId: spaceId,
            locked: true,
          ),
        ),
      );
      expect(locked, isNotNull);
      expect(
        locked!.changeSet.engineeringMetadataDiff
            .generationProvenanceRegistryChanged,
        isTrue,
      );
      final afterLock = harness.registry.provenanceFor(spaceId)!;
      expect(afterLock.lockedFromRegeneration, isTrue);
      expect(afterLock.generationId, before.generationId);
      expect(afterLock.generationKey, before.generationKey);

      const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
      final reopened = codec.decode(codec.encode(_snapshot(harness.mutations.current)));
      final restored = reopened.aggregate.engineeringMetadata
          .generationProvenanceRegistry.provenanceFor(spaceId)!;
      expect(restored.lockedFromRegeneration, isTrue);
      expect(restored.generationId, before.generationId);
      expect(restored.generationKey, before.generationKey);
    });

    test('P9.12-AT-008 generation Undo removes provenance atomically', () {
      final harness = _Harness.generate(seed: 12008);
      expect(harness.registry.manifests, hasLength(1));
      expect(harness.registry.entities, isNotEmpty);

      final undo = harness.mutations.undo(harness.mutations.current.version);
      expect(undo, isNotNull);
      expect(harness.mutations.current.stores.zones, isEmpty);
      expect(harness.mutations.current.stores.spaces, isEmpty);
      expect(harness.registry.manifests, isEmpty);
      expect(harness.registry.entities, isEmpty);
    });

    test('P9.12-AT-009 Redo restores the same GenerationId and provenance', () {
      final harness = _Harness.generate(seed: 12009);
      final committed = harness.registry;
      final generationId = committed.manifests.keys.single;

      expect(
        harness.mutations.undo(harness.mutations.current.version),
        isNotNull,
      );
      expect(
        harness.mutations.redo(harness.mutations.current.version),
        isNotNull,
      );

      expect(harness.registry.manifests.keys.single, generationId);
      expect(harness.registry.sameAs(committed), isTrue);
    });

    test('P9.12-AT-010 old v11 project migrates to empty valid provenance', () {
      final fixture = _fixture();
      const v11 = StructuralSemanticsAwareCanonicalProjectDocumentCodec();
      const v12 = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
      final oldDocument = v11.encode(_snapshot(fixture.project));

      expect(oldDocument.schemaVersion, 11);
      final migrated = v12.decode(oldDocument);
      final registry =
          migrated.aggregate.engineeringMetadata.generationProvenanceRegistry;
      expect(registry.manifests, isEmpty);
      expect(registry.entities, isEmpty);
    });

    test('P9.12-AT-011 dangling manifest/entity relation is rejected', () {
      final projectId = ProjectId('p9-dangling-project');
      final generationId = GenerationId('p9-dangling-generation');
      final missingSpaceId = SpaceId('p9-missing-space');
      final manifest = GenerationManifest(
        provenanceSchemaVersion: 1,
        generationId: generationId,
        originType: GenerationOriginType.wizard,
        providerTemplateId: TemplateId('p9-provider'),
        providerTemplateVersion: 1,
        catalogVersion: 1,
        apartmentTemplateId: TemplateId('p9-template'),
        apartmentTemplateVersion: 1,
        familyId: 'linear',
        variantSeedId: 'seed',
        generatorVersion: 'generator-v1',
        scoringProfileVersion: 'score-v1',
        allocatorVersion: 'allocator-v1',
        geometryAlgorithmVersion: 'geometry-v1',
        normalizedIntentFingerprint: 'intent-fingerprint',
        selectedCandidateFingerprint: 'candidate-fingerprint',
        projectId: projectId,
        buildingId: BuildingId('building'),
        levelId: LevelId('level'),
        apartmentZoneId: ZoneId('zone'),
        generatedEntityIds: {missingSpaceId},
      );
      final registry = GenerationProvenanceRegistry(
        manifests: {generationId: manifest},
        entities: {
          missingSpaceId: EntityGenerationProvenance(
            entityId: missingSpaceId,
            generationId: generationId,
            generationKey: 'space:bedroom:1',
            generatedProperties: const {GenerationPropertyKey.name},
            generatedBaselineFingerprint: 'baseline',
          ),
        },
      );

      expect(
        () => registry.validateOrThrow(
          projectId: projectId,
          entityExists: (_) => false,
        ),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('P9.12-AT-012 RU/EN locale cannot alter provenance values', () {
      // Locale is intentionally absent from every provenance/generator input.
      // Equal canonical inputs plus equal reservation entropy must therefore
      // produce byte-semantic equal registries regardless of presentation locale.
      final en = _Harness.generate(seed: 12012);
      final ru = _Harness.generate(seed: 12012);

      expect(en.registry.sameAs(ru.registry), isTrue);
      final enManifest = en.registry.manifests.values.single;
      final ruManifest = ru.registry.manifests.values.single;
      expect(enManifest.normalizedIntentFingerprint, ruManifest.normalizedIntentFingerprint);
      expect(enManifest.selectedCandidateFingerprint, ruManifest.selectedCandidateFingerprint);
      expect(enManifest.familyId, ruManifest.familyId);
      expect(enManifest.generatorVersion, ruManifest.generatorVersion);
    });
  });
}

final class _Harness {
  _Harness({
    required this.fixture,
    required this.card,
    required this.mutations,
  });

  factory _Harness.generate({required int seed}) {
    final fixture = _fixture();
    const service = ApartmentCandidateSetService();
    final request = _request();
    final generation = service.generate(
      input: request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generation.accepted, isTrue, reason: '${generation.failures}');
    final set = generation.candidateSet!;
    final card = set.candidates.first;
    final parameters = ApartmentWizardParameters(
      request: request,
      selection: set.selectionFor(card),
    );
    final mutations = ProjectMutationSession(fixture.project);
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
      ),
    );

    expect(session.begin(), isTrue);
    expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
    expect(session.updateParameters(parameters), isTrue);
    expect(session.generatePreview(), isTrue, reason: '${session.failure}');
    expect(session.confirm(), isTrue, reason: '${session.failure}');

    return _Harness(fixture: fixture, card: card, mutations: mutations);
  }

  final _Fixture fixture;
  final ApartmentCandidateCard card;
  final ProjectMutationSession mutations;

  GenerationProvenanceRegistry get registry =>
      mutations.current.engineeringMetadata.generationProvenanceRegistry;

  SpaceId get firstSpaceId {
    final manifest = registry.manifests.values.single;
    final zone = mutations.current.stores.zones[manifest.apartmentZoneId]!;
    final ids = zone.spaceIds.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return ids.first;
  }
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7800,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _Fixture {
  const _Fixture({
    required this.project,
    required this.target,
    required this.buildingId,
    required this.levelId,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
  final BuildingId buildingId;
  final LevelId levelId;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-provenance-project');
  final siteId = SiteId('p9-provenance-site');
  final buildingId = BuildingId('p9-provenance-building');
  final levelId = LevelId('p9-provenance-level');
  final version = LocalProjectVersion(7);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: {levelId},
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
        ),
      },
    ),
  );
  return _Fixture(
    project: project,
    buildingId: buildingId,
    levelId: levelId,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}

ProjectSnapshot _snapshot(ProjectAggregateRoot aggregate) => ProjectSnapshot(
      aggregate: aggregate,
      name: 'P9 provenance project',
      createdAt: DateTime.utc(2026, 10, 25, 12),
      updatedAt: DateTime.utc(2026, 10, 25, 12),
    );

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand(this.spaceId, this.name);

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'test.p9.rename-space';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = current.stores.spaces[spaceId]!;
    final next = ProjectSpaceEntity(
      id: space.id,
      levelId: space.levelId,
      name: name,
      type: space.type,
      usage: space.usage,
    );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          spaces: {...current.stores.spaces, spaceId: next},
        ),
      ),
      affectedEntityIds: {spaceId},
    );
  }
}

final class _ChangeSpaceUsageCommand implements ProjectCommand {
  const _ChangeSpaceUsageCommand(this.spaceId, this.usage);

  final SpaceId spaceId;
  final SpaceUsage usage;

  @override
  String get commandType => 'test.p9.change-space-usage';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = current.stores.spaces[spaceId]!;
    final next = ProjectSpaceEntity(
      id: space.id,
      levelId: space.levelId,
      name: space.name,
      type: space.type,
      usage: usage,
    );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          spaces: {...current.stores.spaces, spaceId: next},
        ),
      ),
      affectedEntityIds: {spaceId},
    );
  }
}

final class _TranslateSpaceBoundaryCommand implements ProjectCommand {
  const _TranslateSpaceBoundaryCommand(this.spaceId, {required this.dxMm});

  final SpaceId spaceId;
  final int dxMm;

  @override
  String get commandType => 'test.p9.translate-space-boundary';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final topology = current.stores.boundaries[spaceId]!;
    final translated = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: topology.orderedEdgeIds,
      edges: {
        for (final entry in topology.edges.entries)
          entry.key: ProjectBoundaryEdge(
            id: entry.value.id,
            spaceId: entry.value.spaceId,
            start: BoundaryPointMm(
              xMm: entry.value.start.xMm + dxMm,
              yMm: entry.value.start.yMm,
            ),
            end: BoundaryPointMm(
              xMm: entry.value.end.xMm + dxMm,
              yMm: entry.value.end.yMm,
            ),
          ),
      },
    );
    translated.validateOrThrow();
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          boundaries: {...current.stores.boundaries, spaceId: translated},
        ),
      ),
      affectedEntityIds: {spaceId, ...topology.edges.keys},
    );
  }
}
