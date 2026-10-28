import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/applied_engineering_proposal.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE10-CQ20 applied engineering proposal freshness', () {
    test('canonical edit marks proposal stale and Undo/Redo restores lifecycle',
        () {
      final fixture = _fixture();
      final mutations = ProjectMutationSession(fixture.project);

      expect(_lifecycle(mutations.current).isCurrent, isTrue);
      expect(_currentProposal(mutations.current), isNotNull);

      final changed = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: mutations.current.version,
          command: _RenameGeneratedSpaceCommand(fixture.spaceId),
        ),
      );
      expect(changed, isNotNull);

      final stale = _lifecycle(mutations.current);
      expect(stale.state, AppliedEngineeringProposalLifecycleState.stale);
      expect(
        stale.reason,
        AppliedEngineeringProposalLifecycleReason.generatedPropertyOverridden,
      );
      expect(stale.affectedEntityIds, contains(fixture.spaceId));
      expect(stale.canUseEngineeringOutput, isFalse);
      expect(_currentProposal(mutations.current), isNull);

      final undo = mutations.undo(mutations.current.version);
      expect(undo, isNotNull);
      expect(_lifecycle(mutations.current).isCurrent, isTrue);
      expect(_currentProposal(mutations.current), isNotNull);

      final redo = mutations.redo(mutations.current.version);
      expect(redo, isNotNull);
      expect(_lifecycle(mutations.current).isStale, isTrue);
      expect(_currentProposal(mutations.current), isNull);
    });

    test('generated entity deletion invalidates the frozen proposal', () {
      final fixture = _fixture();
      final mutations = ProjectMutationSession(fixture.project);

      final changed = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: mutations.current.version,
          command: _RemoveGeneratedSpaceCommand(
            levelId: fixture.levelId,
            zoneId: fixture.zoneId,
            spaceId: fixture.spaceId,
          ),
        ),
      );
      expect(changed, isNotNull);

      final invalidated = _lifecycle(mutations.current);
      expect(
        invalidated.state,
        AppliedEngineeringProposalLifecycleState.invalidated,
      );
      expect(
        invalidated.reason,
        AppliedEngineeringProposalLifecycleReason.generatedEntityRemoved,
      );
      expect(invalidated.removedGenerationKeys, contains('space:living'));
      expect(invalidated.canUseEngineeringOutput, isFalse);
      expect(_currentProposal(mutations.current), isNull);
    });

    test('stale lifecycle survives Save/Reopen without a duplicate stale flag',
        () {
      final fixture = _fixture();
      final mutations = ProjectMutationSession(fixture.project);
      expect(
        mutations.commit(
          ProjectMutationRequest(
            expectedVersion: mutations.current.version,
            command: _RenameGeneratedSpaceCommand(fixture.spaceId),
          ),
        ),
        isNotNull,
      );
      expect(_lifecycle(mutations.current).isStale, isTrue);

      final now = DateTime.utc(2026, 10, 28);
      const codec =
          AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();
      final document = codec.encode(
        ProjectSnapshot(
          aggregate: mutations.current,
          name: 'PRE10 DEF020',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final reopened = codec.decode(document).aggregate;

      final lifecycle = _lifecycle(reopened);
      expect(lifecycle.isStale, isTrue);
      expect(
        lifecycle.reason,
        AppliedEngineeringProposalLifecycleReason.generatedPropertyOverridden,
      );
      expect(lifecycle.affectedEntityIds, contains(fixture.spaceId));
      expect(_currentProposal(reopened), isNull);
    });
  });
}

final class _Fixture {
  const _Fixture({
    required this.project,
    required this.levelId,
    required this.zoneId,
    required this.spaceId,
  });

  final ProjectAggregateRoot project;
  final LevelId levelId;
  final ZoneId zoneId;
  final SpaceId spaceId;
}

_Fixture _fixture() {
  final projectId = ProjectId('pre10-def020-project');
  final siteId = SiteId('pre10-def020-site');
  final buildingId = BuildingId('pre10-def020-building');
  final levelId = LevelId('pre10-def020-level');
  final zoneId = ZoneId('pre10-def020-zone');
  final spaceId = SpaceId('pre10-def020-living');
  final generationId = GenerationId('pre10-def020-generation');
  final candidateFingerprint = _sha('1');
  final intentFingerprint = _sha('2');

  final manifest = GenerationManifest(
    provenanceSchemaVersion: 1,
    generationId: generationId,
    originType: GenerationOriginType.wizard,
    providerTemplateId: TemplateId('pre10-def020-provider'),
    providerTemplateVersion: 1,
    catalogVersion: 1,
    apartmentTemplateId: TemplateId('pre10-def020-template'),
    apartmentTemplateVersion: 1,
    familyId: 'linear',
    variantSeedId: 'seed-1',
    generatorVersion: 'generator-v1',
    scoringProfileVersion: 'score-v1',
    allocatorVersion: 'allocator-v1',
    geometryAlgorithmVersion: 'geometry-v1',
    normalizedIntentFingerprint: intentFingerprint,
    selectedCandidateFingerprint: candidateFingerprint,
    projectId: projectId,
    buildingId: buildingId,
    levelId: levelId,
    apartmentZoneId: zoneId,
    generatedEntityIds: <EntityId>{spaceId},
  );
  final provenance = const GenerationProvenanceRegistry.empty().addGeneration(
    manifest: manifest,
    provenances: <EntityGenerationProvenance>[
      EntityGenerationProvenance(
        entityId: spaceId,
        generationId: generationId,
        generationKey: 'space:living',
        generatedProperties: const <GenerationPropertyKey>{
          GenerationPropertyKey.name,
          GenerationPropertyKey.spaceType,
          GenerationPropertyKey.spaceUsage,
          GenerationPropertyKey.geometry,
          GenerationPropertyKey.zoneMembership,
          GenerationPropertyKey.openingRelations,
          GenerationPropertyKey.adjacencyRelations,
        },
        generatedBaselineFingerprint: _sha('3'),
      ),
    ],
  );
  final proposal = AppliedEngineeringProposalSnapshot(
    levelId: levelId,
    proposalVersion: supportedApartmentEngineeringProposalVersion,
    outputProjectionVersion:
        supportedApartmentEngineeringOutputProjectionVersion,
    candidateSetFingerprint: _sha('4'),
    candidateFingerprint: candidateFingerprint,
    intentFingerprint: intentFingerprint,
    d1RequirementsFingerprint: _sha('5'),
    requirementsFingerprint: _sha('6'),
    outputFingerprint: _sha('7'),
    proposalFingerprint: _sha('8'),
    loadScheduleRows: const <String>['load-row'],
    circuitScheduleRows: const <String>['circuit-row'],
    panelSummary: 'panel-summary',
    sldNodes: const <String>['node-row'],
    sldEdges: const <String>['edge-row'],
    explanations: const <String>['explanation-row'],
  );
  final stores = ProjectEntityStores(
    sites: <SiteId, ProjectSiteEntity>{
      siteId: ProjectSiteEntity(
        id: siteId,
        name: 'Site',
        buildingIds: <BuildingId>{buildingId},
      ),
    },
    buildings: <BuildingId, ProjectBuildingEntity>{
      buildingId: ProjectBuildingEntity(
        id: buildingId,
        siteId: siteId,
        name: 'Building',
        levelIds: <LevelId>{levelId},
      ),
    },
    levels: <LevelId, ProjectLevelEntity>{
      levelId: ProjectLevelEntity(
        id: levelId,
        buildingId: buildingId,
        name: 'Level 1',
        levelNumber: 1,
        elevationMm: 3000,
        kind: ProjectLevelKind.residential,
        zoneIds: <ZoneId>{zoneId},
        spaceIds: <SpaceId>{spaceId},
      ),
    },
    zones: <ZoneId, ProjectStructuralZoneEntity>{
      zoneId: ProjectStructuralZoneEntity(
        id: zoneId,
        levelId: levelId,
        name: 'Apartment 1',
        kind: ProjectStructuralZoneKind.apartment,
        spaceIds: <SpaceId>{spaceId},
      ),
    },
    spaces: <SpaceId, ProjectSpaceEntity>{
      spaceId: ProjectSpaceEntity(
        id: spaceId,
        levelId: levelId,
        name: 'Living room',
        type: ProjectSpaceType.room,
        usage: SpaceUsage.livingRoom,
      ),
    },
  );
  final metadata = ProjectEngineeringMetadata(
    generationProvenanceRegistry: provenance,
    appliedEngineeringProposalRegistry: AppliedEngineeringProposalRegistry(
      byLevel: <LevelId, AppliedEngineeringProposalSnapshot>{
        levelId: proposal,
      },
    ),
  );

  return _Fixture(
    project: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: metadata,
      stores: stores,
    ),
    levelId: levelId,
    zoneId: zoneId,
    spaceId: spaceId,
  );
}

AppliedEngineeringProposalLifecycle _lifecycle(ProjectAggregateRoot project) {
  final proposal = project.engineeringMetadata.appliedEngineeringProposalRegistry
      .byLevel.values.single;
  return project.engineeringMetadata.appliedEngineeringProposalRegistry
      .lifecycleForLevel(
    levelId: proposal.levelId,
    provenance: project.engineeringMetadata.generationProvenanceRegistry,
  )!;
}

AppliedEngineeringProposalSnapshot? _currentProposal(
  ProjectAggregateRoot project,
) {
  final proposal = project.engineeringMetadata.appliedEngineeringProposalRegistry
      .byLevel.values.single;
  return project.engineeringMetadata.appliedEngineeringProposalRegistry
      .currentForLevel(
    levelId: proposal.levelId,
    provenance: project.engineeringMetadata.generationProvenanceRegistry,
  );
}

final class _RenameGeneratedSpaceCommand implements ProjectCommand {
  const _RenameGeneratedSpaceCommand(this.spaceId);

  final SpaceId spaceId;

  @override
  String get commandType => 'pre10.def020.rename-generated-space';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final before = current.stores.spaces[spaceId]!;
    final spaces = Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces)
      ..[spaceId] = ProjectSpaceEntity(
        id: before.id,
        levelId: before.levelId,
        name: '${before.name} edited',
        type: before.type,
        usage: before.usage,
      );
    return ProjectCommandCandidate(
      stores: current.stores.copyWith(spaces: spaces),
      affectedEntityIds: <EntityId>{spaceId},
    );
  }
}

final class _RemoveGeneratedSpaceCommand implements ProjectCommand {
  const _RemoveGeneratedSpaceCommand({
    required this.levelId,
    required this.zoneId,
    required this.spaceId,
  });

  final LevelId levelId;
  final ZoneId zoneId;
  final SpaceId spaceId;

  @override
  String get commandType => 'pre10.def020.remove-generated-space';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = current.stores.levels[levelId]!;
    final zone = current.stores.zones[zoneId]!;
    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels)
      ..[levelId] = ProjectLevelEntity(
        id: level.id,
        buildingId: level.buildingId,
        name: level.name,
        levelNumber: level.levelNumber,
        elevationMm: level.elevationMm,
        kind: level.kind,
        floorToFloorHeightMm: level.floorToFloorHeightMm,
        displayOrder: level.displayOrder,
        zoneIds: level.zoneIds,
        spaceIds: <SpaceId>{...level.spaceIds}..remove(spaceId),
      );
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    )
      ..[zoneId] = ProjectStructuralZoneEntity(
        id: zone.id,
        levelId: zone.levelId,
        name: zone.name,
        kind: zone.kind,
        spaceIds: <SpaceId>{...zone.spaceIds}..remove(spaceId),
      );
    final spaces = Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces)
      ..remove(spaceId);
    final boundaries = Map.of(current.stores.boundaries)..remove(spaceId);

    return ProjectCommandCandidate(
      stores: current.stores.copyWith(
        levels: levels,
        zones: zones,
        spaces: spaces,
        boundaries: boundaries,
      ),
      affectedEntityIds: <EntityId>{levelId, zoneId, spaceId},
    );
  }
}

String _sha(String character) => List<String>.filled(64, character).join();
