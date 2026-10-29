import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'dart:math';
import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/domain/boundary_opening_profile_validation.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_level_stack_generator.dart';
import 'package:elecx/src/application/project/wizard/building/cottage_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P10.7 production cottage composition', () {
    test(
        'pure plan is deterministic and retains deferred service-anchor intent',
        () {
      final fixture = _P107Fixture();
      final generator = const CottageCompositionGenerator();
      final first = generator.generate(
        compositionKey: 'cottage.main',
        parameters: fixture.parameters,
        layout: fixture.layout,
      );
      final second = generator.generate(
        compositionKey: 'cottage.main',
        parameters: fixture.parameters,
        layout: fixture.layout,
      );

      expect(first.semanticFingerprint, second.semanticFingerprint);
      expect(first.levelStack.levels, hasLength(4));
      expect(first.slabs, hasLength(3));
      expect(first.servedLevelCount, 3);
      expect(first.coreCount, 3);
      expect(
        first.pendingServiceAnchorKinds,
        {
          BuildingServiceAnchorKind.electricalEntry,
          BuildingServiceAnchorKind.telecomEntry,
        },
      );
      expect(first.hasDeferredServiceAnchors, isTrue);
      expect(first.zoneCount, greaterThan(0));
      expect(first.spaceCount, greaterThan(0));
    });

    test('one reserved command materializes cottage and exact Undo Redo IDs',
        () {
      final fixture = _P107Fixture();
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10701)),
      );
      final command = fixture.command(session.current);
      final preview = port.preview(command);

      expect(session.current.stores.buildings, isEmpty);
      expect(session.current.stores.levels, isEmpty);
      expect(session.current.stores.slabs, isEmpty);
      expect(session.current.stores.verticalCores, isEmpty);
      expect(preview.preview.candidate.stores.buildings, hasLength(1));
      expect(preview.preview.candidate.stores.levels, hasLength(4));
      expect(preview.preview.candidate.stores.slabs, hasLength(3));

      final committed = port.commitPreview(preview);
      expect(committed, isNotNull);
      expect(session.undoDepth, 1);
      expect(session.current.stores.buildings, hasLength(1));
      expect(session.current.stores.levels, hasLength(4));
      expect(session.current.stores.slabs, hasLength(3));
      expect(session.current.stores.verticalCores, hasLength(3));

      final building = session.current.stores.buildings.values.single;
      expect(building.siteId, fixture.siteId);
      expect(building.levelIds, hasLength(4));
      expect(
        session.current.stores.sites[fixture.siteId]!.buildingIds,
        {building.id},
      );

      final usages = session.current.stores.verticalCores.values
          .map((core) => core.usage)
          .toSet();
      expect(
        usages,
        {
          VerticalCoreUsage.stairwell,
          VerticalCoreUsage.electricalRiser,
          VerticalCoreUsage.telecomRiser,
        },
      );
      for (final core in session.current.stores.verticalCores.values) {
        expect(core.buildingId, building.id);
        expect(core.levelIds, hasLength(3));
        expect(core.hostSpaceIdsByLevel, hasLength(3));
      }

      final roof = session.current.stores.levels.values.singleWhere(
        (level) => level.kind == ProjectLevelKind.roof,
      );
      expect(roof.spaceIds, isEmpty);
      expect(roof.zoneIds, isEmpty);

      final buildingIds = session.current.stores.buildings.keys.toSet();
      final levelIds = session.current.stores.levels.keys.toSet();
      final slabIds = session.current.stores.slabs.keys.toSet();
      final zoneIds = session.current.stores.zones.keys.toSet();
      final spaceIds = session.current.stores.spaces.keys.toSet();
      final openingIds = session.current.stores.openings.keys.toSet();
      final adjacencyIds = session.current.stores.adjacencies.keys.toSet();
      final coreIds = session.current.stores.verticalCores.keys.toSet();

      final undo = session.undo(session.current.version);
      expect(undo, isNotNull);
      expect(session.current.stores.buildings, isEmpty);
      expect(session.current.stores.levels, isEmpty);
      expect(session.current.stores.slabs, isEmpty);
      expect(session.current.stores.zones, isEmpty);
      expect(session.current.stores.spaces, isEmpty);
      expect(session.current.stores.openings, isEmpty);
      expect(session.current.stores.adjacencies, isEmpty);
      expect(session.current.stores.verticalCores, isEmpty);

      final redo = session.redo(session.current.version);
      expect(redo, isNotNull);
      expect(session.current.stores.buildings.keys.toSet(), buildingIds);
      expect(session.current.stores.levels.keys.toSet(), levelIds);
      expect(session.current.stores.slabs.keys.toSet(), slabIds);
      expect(session.current.stores.zones.keys.toSet(), zoneIds);
      expect(session.current.stores.spaces.keys.toSet(), spaceIds);
      expect(session.current.stores.openings.keys.toSet(), openingIds);
      expect(session.current.stores.adjacencies.keys.toSet(), adjacencyIds);
      expect(session.current.stores.verticalCores.keys.toSet(), coreIds);
    });

    test('schema v19 save reopen preserves the exact cottage canonical graph',
        () {
      final fixture = _P107Fixture();
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10702)),
      );
      port.commitPreview(port.preview(fixture.command(session.current)));

      final before = session.current;
      const codec = CompositionProvenanceAwareCanonicalProjectDocumentCodec();
      final timestamp = DateTime.utc(2026, 10, 29, 12);
      final document = codec.encode(
        ProjectSnapshot(
          aggregate: before,
          name: 'P10.7 Cottage',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      expect(
        document.schemaVersion,
        CompositionProvenanceAwareCanonicalProjectDocumentCodec.schemaVersion,
      );
      final reopened = codec.decode(document).aggregate;

      expect(
        reopened.stores.buildings.keys.toSet(),
        before.stores.buildings.keys.toSet(),
      );
      expect(
        reopened.stores.levels.keys.toSet(),
        before.stores.levels.keys.toSet(),
      );
      expect(
        reopened.stores.slabs.keys.toSet(),
        before.stores.slabs.keys.toSet(),
      );
      expect(
        reopened.stores.zones.keys.toSet(),
        before.stores.zones.keys.toSet(),
      );
      expect(
        reopened.stores.spaces.keys.toSet(),
        before.stores.spaces.keys.toSet(),
      );
      expect(
        reopened.stores.openings.keys.toSet(),
        before.stores.openings.keys.toSet(),
      );
      expect(
        reopened.stores.adjacencies.keys.toSet(),
        before.stores.adjacencies.keys.toSet(),
      );
      expect(
        reopened.stores.verticalCores.keys.toSet(),
        before.stores.verticalCores.keys.toSet(),
      );
      for (final entry in before.stores.verticalCores.entries) {
        final restored = reopened.stores.verticalCores[entry.key]!;
        expect(restored.levelIds, entry.value.levelIds);
        expect(restored.usage, entry.value.usage);
        expect(
          restored.hostSpaceIdsByLevel,
          entry.value.hostSpaceIdsByLevel,
        );
      }
    });

    test(
        'P10-Q09 production Save Reopen Edit Undo Redo Save Reopen keeps hosts and IDs',
        () async {
      final fixture = _P107Fixture();
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
          mutations: session,
          idFactory: SecureRandomEntityIdFactory(random: Random(10709)));
      port.commitPreview(port.preview(fixture.command(session.current)));
      for (final opening in session.current.stores.openings.values) {
        for (final spaceId in opening.connectedSpaceIds) {
          expect(
              session.current.engineeringMetadata.boundaryHostedObjectRegistry
                  .openingHost(opening.id, spaceId),
              isNotNull);
        }
      }
      final directory = await Directory.systemTemp.createTemp('p107-golden-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonProjectRepository(
          rootDirectory: directory,
          codec:
              const CompositionProvenanceAwareCanonicalProjectDocumentCodec());
      final timestamp = DateTime.utc(2026, 10, 29, 12);
      final owner = CanonicalProjectPersistenceOwner(
          repository: repository,
          snapshot: ProjectSnapshot(
              aggregate: session.current,
              name: 'Cottage',
              createdAt: timestamp,
              updatedAt: timestamp));
      await owner.save();
      final loaded = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: fixture.projectId))!;
      final edits = ProjectMutationSession(loaded.project);
      final core = edits.current.stores.verticalCores.values.first;
      final spaceId = core.hostSpaceIdsByLevel.values.first;
      final originalName = edits.current.stores.spaces[spaceId]!.name;
      final edit = edits.commit(ProjectMutationRequest(
          expectedVersion: edits.current.version,
          command: RenameSpaceCommand(
              spaceId: spaceId, name: 'Custom stair host')))!;
      loaded.acceptMutation(
          sessionProject: edits.current, result: edit, now: timestamp);
      final undo = edits.undo(edits.current.version)!;
      loaded.acceptMutation(
          sessionProject: edits.current, result: undo, now: timestamp);
      expect(edits.current.stores.spaces[spaceId]!.name, originalName);
      final redo = edits.redo(edits.current.version)!;
      loaded.acceptMutation(
          sessionProject: edits.current,
          result: redo,
          now: timestamp.add(const Duration(minutes: 1)));
      await loaded.save();
      final reopened = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: fixture.projectId))!;
      expect(
          reopened.project.stores.spaces[spaceId]!.name, 'Custom stair host');
      expect(reopened.project.stores.spaces.keys.toSet(),
          session.current.stores.spaces.keys.toSet());
      expect(
          reopened.project.stores.verticalCores[core.id]!.hostSpaceIdsByLevel,
          core.hostSpaceIdsByLevel);
      for (final id in reopened.project.stores.spaces.keys) {
        BoundaryOpeningProfileValidator.validateSpace(
            spaceId: id,
            openings: reopened.project.stores.openings.values,
            hostedObjects: reopened
                .project.engineeringMetadata.boundaryHostedObjectRegistry,
            wallProfiles: reopened
                .project.engineeringMetadata.boundaryWallProfileRegistry);
      }
    });

    test('invalid cottage topology and deferred site rotation fail closed', () {
      final fixture = _P107Fixture();
      final generator = const CottageCompositionGenerator();

      expect(
        () => generator.generate(
          compositionKey: 'cottage.main',
          parameters: fixture.parametersWith(
            kind: BuildingCompositionKind.residentialTower,
          ),
          layout: fixture.layout,
        ),
        throwsA(
          isA<CottageCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.cottage.kind-not-detached',
          ),
        ),
      );
      expect(
        () => generator.generate(
          compositionKey: 'cottage.main',
          parameters: fixture.parametersWith(
            commonCore: fixture.commonCore(stairCount: 0),
          ),
          layout: fixture.layout,
        ),
        throwsA(
          isA<CottageCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.cottage.internal-stair-required',
          ),
        ),
      );
      expect(
        () => generator.generate(
          compositionKey: 'cottage.main',
          parameters: fixture.parametersWith(
            placement: BuildingSitePlacement(
              xMm: 0,
              yMm: 0,
              orientation: ProjectEngineeringNorth.fromDegrees(90),
            ),
          ),
          layout: fixture.layout,
        ),
        throwsA(
          isA<CottageCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.cottage.rotated-site-placement-deferred',
          ),
        ),
      );
      expect(
        () => generator.generate(
          compositionKey: 'cottage.main',
          parameters: fixture.parametersWith(
            levelStack: const BuildingLevelStackGenerator()
                .residentialParameters(upperResidentialLevels: 4),
          ),
          layout: fixture.layout,
        ),
        throwsA(
          isA<CottageCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.cottage.occupiable-level-count-out-of-range',
          ),
        ),
      );

      final occupied = fixture.projectWithExistingBuilding;
      expect(
        () => CottageCompositionCommand.create(
          project: occupied,
          compositionKey: 'cottage.main',
          parameters: fixture.parameters,
          layout: fixture.layout,
        ),
        throwsA(
          isA<CottageCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.cottage.site-not-empty',
          ),
        ),
      );
    });
  });
}

final class _P107Fixture {
  final ProjectId projectId = ProjectId('project-p107');
  final SiteId siteId = SiteId('site-p107');

  LevelStackParameters get levelStack =>
      const BuildingLevelStackGenerator().residentialParameters(
        basementLevels: 1,
        upperResidentialLevels: 1,
        includeRoof: true,
        basementHeightMm: 3000,
        groundHeightMm: 3200,
        residentialHeightMm: 3200,
        roofHeightMm: 2800,
      );

  CommonCoreParameters commonCore({int stairCount = 1}) =>
      CommonCoreParameters.v2(
        stairCount: stairCount,
        liftCount: 0,
        serviceShaftCount: 0,
        electricalRiserCount: 1,
        telecomRiserCount: 1,
        corridorWidthMm: 1800,
        includeTechnicalRoom: true,
        serviceSpacePolicy: const CommonServiceSpacePolicy(
          includeCommonHall: true,
          includeElevatorHall: false,
          includeElectricalRoomCandidate: true,
          includeTelecomRoomCandidate: true,
          includeFireControlRoomCandidate: false,
          includeUtilityRoomCandidate: true,
        ),
      );

  BuildingGenerationParameters get parameters => parametersWith();

  BuildingGenerationParameters parametersWith({
    BuildingCompositionKind kind = BuildingCompositionKind.detachedHouse,
    BuildingSitePlacement? placement,
    LevelStackParameters? levelStack,
    CommonCoreParameters? commonCore,
  }) =>
      BuildingGenerationParameters(
        kind: kind,
        siteId: siteId,
        displayName: 'P10.7 Cottage',
        placement: placement ??
            BuildingSitePlacement(
              xMm: 0,
              yMm: 0,
              orientation: ProjectEngineeringNorth.fromDegrees(0),
            ),
        levelStack: levelStack ?? this.levelStack,
        commonCore: commonCore ?? this.commonCore(),
        serviceAnchors: ServiceAnchorParameters(
          kinds: const {
            BuildingServiceAnchorKind.electricalEntry,
            BuildingServiceAnchorKind.telecomEntry,
          },
        ),
      );

  CottageCompositionLayout get layout => CottageCompositionLayout(
        footprintWidthMm: 18000,
        footprintDepthMm: 12000,
        commonCore: CommonCoreLayoutParameters(
          originXmm: 1000,
          originYmm: 3500,
          corridorLengthMm: 16000,
        ),
      );

  CottageCompositionCommand command(ProjectAggregateRoot project) =>
      CottageCompositionCommand.create(
        project: project,
        compositionKey: 'cottage.main',
        parameters: parameters,
        layout: layout,
      );

  ProjectAggregateRoot get project => ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'P10.7 Site',
              buildingIds: const [],
            ),
          },
        ),
      );

  ProjectAggregateRoot get projectWithExistingBuilding {
    final buildingId = BuildingId('existing-p107-building');
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'P10.7 Site',
            buildingIds: [buildingId],
          ),
        },
        buildings: {
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'Existing Building',
            levelIds: const [],
          ),
        },
      ),
    );
  }
}
