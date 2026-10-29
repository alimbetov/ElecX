import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/project_vertical_core_commands.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_project_validation.dart';
import 'package:elecx/src/serialization/project/common_core_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/level_composition_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P10.6 vertical-core host semantics', () {
    test('architectural core requires one canonical host per served LevelId',
        () {
      final fixture = _Fixture();

      expect(
        () => fixture.core(
          usage: VerticalCoreUsage.electricalRiser,
          hosts: {fixture.level1Id: fixture.host1Id},
        ),
        throwsArgumentError,
      );
    });

    test('host validation rejects a SpaceId owned by another level', () {
      final fixture = _Fixture();
      final core = fixture.core(
        usage: VerticalCoreUsage.telecomRiser,
        hosts: {
          fixture.level1Id: fixture.host1Id,
          fixture.level2Id: fixture.host2Id,
        },
      );

      final issues = VerticalCoreProjectValidator.validate(
        verticalCores: {core.id: core},
        buildingExists: (_) => true,
        levelBuildingResolver: (_) => fixture.buildingId,
        spaceLevelResolver: (spaceId) =>
            spaceId == fixture.host1Id ? fixture.level2Id : fixture.level2Id,
      );

      expect(
        issues.map((issue) => issue.code),
        contains(VerticalCoreProjectIssueCode.hostSpaceLevelMismatch),
      );
    });

    test('aggregate maps wrong-level and dangling hosts to canonical issues', () {
      final fixture = _Fixture();
      final wrongLevelCore = fixture.core(
        usage: VerticalCoreUsage.serviceShaft,
        hosts: {
          fixture.level1Id: fixture.host2Id,
          fixture.level2Id: fixture.host1Id,
        },
      );
      final wrongLevelIssues = ProjectAggregateValidator.validate(
        rootSiteId: fixture.siteId,
        stores: fixture.stores(coreValue: wrongLevelCore),
      );
      expect(
        wrongLevelIssues.map((issue) => issue.code),
        contains(ProjectAggregateIssueCode.verticalCoreHostSpaceLevelMismatch),
      );

      final missingHostId = SpaceId('space-missing-host');
      final danglingCore = fixture.core(
        usage: VerticalCoreUsage.serviceShaft,
        hosts: {
          fixture.level1Id: missingHostId,
          fixture.level2Id: fixture.host2Id,
        },
      );
      final danglingIssues = ProjectAggregateValidator.validate(
        rootSiteId: fixture.siteId,
        stores: fixture.stores(coreValue: danglingCore),
      );
      expect(
        danglingIssues.map((issue) => issue.code),
        contains(ProjectAggregateIssueCode.danglingVerticalCoreHostSpace),
      );
    });

    test('host-only update participates in diff, Undo and Redo', () {
      final fixture = _Fixture();
      final before = fixture.core(
        usage: VerticalCoreUsage.electricalRiser,
        hosts: fixture.primaryHosts,
      );
      final after = fixture.core(
        usage: VerticalCoreUsage.electricalRiser,
        hosts: fixture.alternateHosts,
      );
      final session = ProjectMutationSession(
        fixture.project(coreValue: before),
      );

      final committed = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UpdateVerticalCoreCommand(verticalCore: after),
        ),
      );

      expect(committed, isNotNull);
      expect(committed!.changeSet.updatedEntityIds, {fixture.coreId});
      expect(
        committed.project.stores.verticalCores[fixture.coreId]!
            .hostSpaceIdsByLevel,
        fixture.alternateHosts,
      );

      final undo = session.undo(session.current.version);
      expect(
        undo!.project.stores.verticalCores[fixture.coreId]!.hostSpaceIdsByLevel,
        fixture.primaryHosts,
      );

      final redo = session.redo(session.current.version);
      expect(
        redo!.project.stores.verticalCores[fixture.coreId]!.hostSpaceIdsByLevel,
        fixture.alternateHosts,
      );
    });

    test('usage-only update is a canonical VerticalCore update', () {
      final fixture = _Fixture();
      final before = fixture.core(
        usage: VerticalCoreUsage.electricalRiser,
        hosts: fixture.primaryHosts,
      );
      final after = fixture.core(
        usage: VerticalCoreUsage.telecomRiser,
        hosts: fixture.primaryHosts,
      );
      final session = ProjectMutationSession(
        fixture.project(coreValue: before),
      );

      final committed = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UpdateVerticalCoreCommand(verticalCore: after),
        ),
      );

      expect(committed, isNotNull);
      expect(committed!.changeSet.updatedEntityIds, {fixture.coreId});
      expect(
        committed.project.stores.verticalCores[fixture.coreId]!.usage,
        VerticalCoreUsage.telecomRiser,
      );
    });

    test('host Space removal fails closed with the core as a blocker', () {
      final fixture = _Fixture();
      final core = fixture.core(
        usage: VerticalCoreUsage.stairwell,
        hosts: fixture.primaryHosts,
      );
      final project = fixture.project(coreValue: core);

      expect(
        () => RemoveSpaceCommand(spaceId: fixture.host1Id)
            .buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.spaceHasSemanticDependencies,
              )
              .having(
                (error) => error.blockingEntityIds,
                'blockingEntityIds',
                contains(fixture.coreId),
              ),
        ),
      );
    });

    test('P10-Q08 core identity survives display level renumbering', () {
      final fixture = _Fixture();
      final core = fixture.core(
        usage: VerticalCoreUsage.elevatorShaft,
        hosts: fixture.primaryHosts,
      );
      final session = ProjectMutationSession(
        fixture.project(coreValue: core),
      );

      final committed = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenumberLevelCommand(
            levelId: fixture.level1Id,
            levelNumber: 101,
          ),
        ),
      );

      expect(committed, isNotNull);
      final retained = committed!.project.stores.verticalCores[fixture.coreId]!;
      expect(retained.id, fixture.coreId);
      expect(retained.levelIds, {fixture.level1Id, fixture.level2Id});
      expect(retained.hostSpaceIdsByLevel, fixture.primaryHosts);
      expect(committed.project.stores.levels[fixture.level1Id]!.levelNumber, 101);
    });

    test('schema v16 preserves typed usage and LevelId to SpaceId hosts', () {
      final fixture = _Fixture();
      final snapshot = fixture.snapshot();
      const codec = CommonCoreAwareCanonicalProjectDocumentCodec();

      final document = codec.encode(snapshot);
      final reopened = codec.decode(document);
      final core = reopened.aggregate.stores.verticalCores[fixture.coreId]!;

      expect(document.schemaVersion, 16);
      expect(core.usage, VerticalCoreUsage.electricalRiser);
      expect(core.hostSpaceIdsByLevel, fixture.primaryHosts);
    });

    test('pre-v16 codec rejects lossy building-core semantics', () {
      final fixture = _Fixture();
      const oldCodec = LevelCompositionAwareCanonicalProjectDocumentCodec();

      expect(
        () => oldCodec.encode(fixture.snapshot()),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project-p106');
  final SiteId siteId = SiteId('site-p106');
  final BuildingId buildingId = BuildingId('building-p106');
  final LevelId level1Id = LevelId('level-p106-01');
  final LevelId level2Id = LevelId('level-p106-02');
  final SpaceId host1Id = SpaceId('space-riser-01');
  final SpaceId host2Id = SpaceId('space-riser-02');
  final SpaceId alternateHost1Id = SpaceId('space-riser-01-alt');
  final SpaceId alternateHost2Id = SpaceId('space-riser-02-alt');
  final VerticalCoreId coreId = VerticalCoreId('core-p106');

  Map<LevelId, SpaceId> get primaryHosts => {
        level1Id: host1Id,
        level2Id: host2Id,
      };

  Map<LevelId, SpaceId> get alternateHosts => {
        level1Id: alternateHost1Id,
        level2Id: alternateHost2Id,
      };

  ProjectVerticalCore core({
    VerticalCoreUsage usage = VerticalCoreUsage.unspecified,
    Map<LevelId, SpaceId> hosts = const {},
  }) =>
      ProjectVerticalCore(
        id: coreId,
        buildingId: buildingId,
        kind: VerticalCoreKind.riser,
        usage: usage,
        hostSpaceIdsByLevel: hosts,
        levelIds: [level1Id, level2Id],
        footprint: const [
          BoundaryPointMm(xMm: 1000, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1400),
          BoundaryPointMm(xMm: 1000, yMm: 1400),
        ],
        name: 'Vertical core',
      );

  ProjectEntityStores stores({ProjectVerticalCore? coreValue}) =>
      ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'P10.6 Site',
            buildingIds: [buildingId],
          ),
        },
        buildings: {
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'P10.6 Building',
            levelIds: [level1Id, level2Id],
          ),
        },
        levels: {
          level1Id: ProjectLevelEntity(
            id: level1Id,
            buildingId: buildingId,
            name: 'Level 1',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [host1Id, alternateHost1Id],
          ),
          level2Id: ProjectLevelEntity(
            id: level2Id,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
            spaceIds: [host2Id, alternateHost2Id],
          ),
        },
        spaces: {
          host1Id: ProjectSpaceEntity(
            id: host1Id,
            levelId: level1Id,
            name: 'Core host L1',
            type: ProjectSpaceType.shaft,
            usage: SpaceUsage.commonArea,
          ),
          alternateHost1Id: ProjectSpaceEntity(
            id: alternateHost1Id,
            levelId: level1Id,
            name: 'Alternate core host L1',
            type: ProjectSpaceType.shaft,
            usage: SpaceUsage.commonArea,
          ),
          host2Id: ProjectSpaceEntity(
            id: host2Id,
            levelId: level2Id,
            name: 'Core host L2',
            type: ProjectSpaceType.shaft,
            usage: SpaceUsage.commonArea,
          ),
          alternateHost2Id: ProjectSpaceEntity(
            id: alternateHost2Id,
            levelId: level2Id,
            name: 'Alternate core host L2',
            type: ProjectSpaceType.shaft,
            usage: SpaceUsage.commonArea,
          ),
        },
        verticalCores: {
          if (coreValue != null) coreValue.id: coreValue,
        },
      );

  ProjectAggregateRoot project({ProjectVerticalCore? coreValue}) =>
      ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: stores(coreValue: coreValue),
      );

  ProjectSnapshot snapshot() {
    final coreValue = core(
      usage: VerticalCoreUsage.electricalRiser,
      hosts: primaryHosts,
    );
    final instant = DateTime.utc(2026, 10, 29, 8);
    return ProjectSnapshot(
      aggregate: project(coreValue: coreValue),
      name: 'P10.6 qualification',
      createdAt: instant,
      updatedAt: instant,
    );
  }
}
