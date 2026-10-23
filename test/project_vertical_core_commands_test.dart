import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_vertical_core_commands.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical VerticalCore CRUD commands', () {
    test('create indexes core by identity, building and levels', () {
      final fixture = _Fixture();
      final session = ProjectMutationSession(fixture.project());
      final core = fixture.core();

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateVerticalCoreCommand(verticalCore: core),
        ),
      );

      expect(result, isNotNull);
      expect(result!.changeSet.commandType, 'project.verticalCore.create');
      expect(result.changeSet.addedEntityIds, {fixture.coreId});
      expect(result.project.index.verticalCore(fixture.coreId), same(core));
      expect(
        result.project.index.verticalCoresForBuilding(fixture.buildingId),
        {fixture.coreId},
      );
      expect(
        result.project.index.verticalCoresForLevel(fixture.level1Id),
        {fixture.coreId},
      );
      expect(
        result.project.index.verticalCoresForLevel(fixture.level2Id),
        {fixture.coreId},
      );
    });

    test('update preserves VerticalCoreId and reports one entity update', () {
      final fixture = _Fixture();
      final before = fixture.core();
      final session = ProjectMutationSession(
        fixture.project(verticalCores: {before.id: before}),
      );
      final after = fixture.core(
        kind: VerticalCoreKind.serviceShaft,
        name: 'Main service shaft',
        footprint: const [
          BoundaryPointMm(xMm: 1000, yMm: 1000),
          BoundaryPointMm(xMm: 1500, yMm: 1000),
          BoundaryPointMm(xMm: 1500, yMm: 1600),
          BoundaryPointMm(xMm: 1000, yMm: 1600),
        ],
      );

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UpdateVerticalCoreCommand(verticalCore: after),
        ),
      );

      expect(result, isNotNull);
      expect(result!.changeSet.updatedEntityIds, {fixture.coreId});
      final committed = result.project.index.verticalCore(fixture.coreId)!;
      expect(committed.id, fixture.coreId);
      expect(committed.kind, VerticalCoreKind.serviceShaft);
      expect(committed.name, 'Main service shaft');
      expect(committed.footprint, hasLength(4));
    });

    test('remove participates atomically in undo and redo', () {
      final fixture = _Fixture();
      final core = fixture.core();
      final session = ProjectMutationSession(
        fixture.project(verticalCores: {core.id: core}),
      );

      final removed = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveVerticalCoreCommand(verticalCoreId: fixture.coreId),
        ),
      );

      expect(removed, isNotNull);
      expect(removed!.changeSet.removedEntityIds, {fixture.coreId});
      expect(removed.project.index.verticalCore(fixture.coreId), isNull);
      expect(
        removed.project.index.verticalCoresForLevel(fixture.level1Id),
        isEmpty,
      );

      final undo = session.undo(session.current.version);
      expect(undo, isNotNull);
      expect(undo!.changeSet.addedEntityIds, {fixture.coreId});
      expect(undo.project.index.verticalCore(fixture.coreId), same(core));

      final redo = session.redo(session.current.version);
      expect(redo, isNotNull);
      expect(redo!.changeSet.removedEntityIds, {fixture.coreId});
      expect(redo.project.index.verticalCore(fixture.coreId), isNull);
    });

    test('duplicate create and unknown update/remove fail before commit', () {
      final fixture = _Fixture();
      final core = fixture.core();
      final project = fixture.project(verticalCores: {core.id: core});

      expect(
        () => CreateVerticalCoreCommand(verticalCore: core)
            .buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.verticalCoreAlreadyExists,
          ),
        ),
      );

      final empty = fixture.project();
      expect(
        () =>
            UpdateVerticalCoreCommand(verticalCore: core).buildCandidate(empty),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.verticalCoreNotFound,
          ),
        ),
      );
      expect(
        () => RemoveVerticalCoreCommand(verticalCoreId: fixture.coreId)
            .buildCandidate(empty),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.verticalCoreNotFound,
          ),
        ),
      );
    });

    test('create rejects a core that skips an intermediate physical level', () {
      final fixture = _Fixture();
      final project = fixture.project();
      final discontinuous = fixture.core(
        levelIds: [fixture.level1Id, fixture.level3Id],
      );

      expect(
        () => CreateVerticalCoreCommand(verticalCore: discontinuous)
            .buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.verticalCoreNonContiguousLevelRange,
          ),
        ),
      );
    });

    test('physical continuity ignores level set order and presentation number',
        () {
      final fixture = _Fixture();
      final project = fixture.project(scrambledLevelNumbers: true);
      final reversedContiguous = fixture.core(
        levelIds: [fixture.level3Id, fixture.level2Id],
      );

      expect(
        () => CreateVerticalCoreCommand(verticalCore: reversedContiguous)
            .buildCandidate(project),
        returnsNormally,
      );
    });

    test('create fails closed when physical level order is ambiguous', () {
      final fixture = _Fixture();
      final project = fixture.project(duplicateElevation: true);

      expect(
        () => CreateVerticalCoreCommand(verticalCore: fixture.core())
            .buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.verticalCoreAmbiguousPhysicalLevelOrder,
          ),
        ),
      );
    });

    test('stale expected version rejects VerticalCore mutation', () {
      final fixture = _Fixture();
      final session = ProjectMutationSession(fixture.project());
      session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateVerticalCoreCommand(verticalCore: fixture.core()),
        ),
      );

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: LocalProjectVersion(0),
            command: RemoveVerticalCoreCommand(verticalCoreId: fixture.coreId),
          ),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );
    });
  });
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId level1Id = LevelId('level-01');
  final LevelId level2Id = LevelId('level-02');
  final LevelId level3Id = LevelId('level-03');
  final VerticalCoreId coreId = VerticalCoreId('core-01');

  ProjectVerticalCore core({
    VerticalCoreKind kind = VerticalCoreKind.riser,
    String? name = 'Riser 1',
    Iterable<LevelId>? levelIds,
    List<BoundaryPointMm> footprint = const [
      BoundaryPointMm(xMm: 1000, yMm: 1000),
      BoundaryPointMm(xMm: 1400, yMm: 1000),
      BoundaryPointMm(xMm: 1400, yMm: 1400),
      BoundaryPointMm(xMm: 1000, yMm: 1400),
    ],
  }) =>
      ProjectVerticalCore(
        id: coreId,
        buildingId: buildingId,
        kind: kind,
        levelIds: levelIds ?? [level1Id, level2Id],
        footprint: footprint,
        name: name,
      );

  ProjectAggregateRoot project({
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores = const {},
    bool duplicateElevation = false,
    bool scrambledLevelNumbers = false,
  }) =>
      ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Site',
              buildingIds: [buildingId],
            ),
          },
          buildings: {
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Building',
              levelIds: [level1Id, level2Id, level3Id],
            ),
          },
          levels: {
            level1Id: ProjectLevelEntity(
              id: level1Id,
              buildingId: buildingId,
              name: 'Level 1',
              levelNumber: scrambledLevelNumbers ? 30 : 1,
              elevationMm: 0,
            ),
            level2Id: ProjectLevelEntity(
              id: level2Id,
              buildingId: buildingId,
              name: 'Level 2',
              levelNumber: scrambledLevelNumbers ? -2 : 2,
              elevationMm: duplicateElevation ? 0 : 3200,
            ),
            level3Id: ProjectLevelEntity(
              id: level3Id,
              buildingId: buildingId,
              name: 'Level 3',
              levelNumber: scrambledLevelNumbers ? 7 : 3,
              elevationMm: 6400,
            ),
          },
          verticalCores: verticalCores,
        ),
      );
}
