import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new-project provider reuses compatibility Building and reference Level',
      () {
    final project = _seedProject();
    final originalBuildingId = project.stores.buildings.keys.single;
    final originalLevelId = project.stores.levels.keys.single;
    final mutations = ProjectMutationSession(project);
    final provider = BasicBuildingWizardProvider();
    final target = NewProjectWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );
    final session = WizardSession(
      target: target,
      registry: WizardProviderRegistry([provider]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(101)),
      ),
    );

    expect(session.availableProviders, hasLength(1));
    expect(session.begin(), isTrue);
    expect(session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
    expect(
      session.updateParameters(
        const BasicBuildingWizardParameters(
          buildingName: 'Tower A',
          aboveGroundLevelCount: 2,
          basementLevelCount: 1,
          floorToFloorHeightMm: 3200,
          createGroundLevel: true,
        ),
      ),
      isTrue,
    );
    expect(session.generatePreview(), isTrue);

    final preview = session.preview!;
    expect(preview.reservation.slots, isNot(contains('building')));
    expect(preview.reservation.slots, isNot(contains('level:0')));
    expect(preview.candidate.stores.buildings.keys, {originalBuildingId});
    final candidateBuilding =
        preview.candidate.stores.buildings[originalBuildingId]!;
    expect(candidateBuilding.name, 'Tower A');
    expect(candidateBuilding.levelIds, contains(originalLevelId));
    expect(candidateBuilding.levelIds, hasLength(4));

    final reusedLevel = preview.candidate.stores.levels[originalLevelId]!;
    expect(reusedLevel.levelNumber, 0);
    expect(reusedLevel.name, 'Ground');
    expect(reusedLevel.elevationMm, 0);
    expect(reusedLevel.kind, ProjectLevelKind.ground);

    expect(session.confirm(), isTrue);
    expect(mutations.current.version.value, 1);
    expect(mutations.undoDepth, 1);
    expect(mutations.current.stores.buildings.keys, {originalBuildingId});
    expect(
      mutations.current.stores.buildings[originalBuildingId]!.levelIds,
      contains(originalLevelId),
    );

    final undo = mutations.undo(mutations.current.version);
    expect(undo, isNotNull);
    expect(mutations.current.stores.buildings.keys, {originalBuildingId});
    expect(
      mutations.current.stores.buildings[originalBuildingId]!.levelIds,
      {originalLevelId},
    );
    expect(mutations.current.stores.levels[originalLevelId]!.levelNumber, 1);
  });

  test('new-project provider reuses seed Level 1 without explicit ground', () {
    final project = _seedProject();
    final originalLevelId = project.stores.levels.keys.single;
    final session = _session(project, randomSeed: 103);

    session.begin();
    session.selectFamily(BasicBuildingWizardProvider.familyId);
    session.updateParameters(
      const BasicBuildingWizardParameters(
        buildingName: 'Tower B',
        aboveGroundLevelCount: 3,
        basementLevelCount: 0,
        floorToFloorHeightMm: 3000,
        createGroundLevel: false,
      ),
    );

    expect(session.generatePreview(), isTrue);
    expect(session.preview!.reservation.slots, isNot(contains('level:1')));
    expect(
      session.preview!.candidate.stores.levels[originalLevelId]!.levelNumber,
      1,
    );
    expect(
      session.preview!.candidate.stores.levels[originalLevelId]!.elevationMm,
      0,
    );
  });

  test(
      'new-project generation fails closed when compatibility seed is not blank',
      () {
    final project = _seedProject(extraLevel: true);
    final session = _session(project, randomSeed: 107);

    session.begin();
    session.selectFamily(BasicBuildingWizardProvider.familyId);
    session.updateParameters(
      const BasicBuildingWizardParameters(
        buildingName: 'Tower C',
        aboveGroundLevelCount: 2,
        basementLevelCount: 0,
        floorToFloorHeightMm: 3000,
      ),
    );

    expect(session.generatePreview(), isFalse);
    expect(session.status, WizardSessionStatus.failed);
    expect(session.preview, isNull);
  });
}

WizardSession _session(ProjectAggregateRoot project,
    {required int randomSeed}) {
  final mutations = ProjectMutationSession(project);
  return WizardSession(
    target: NewProjectWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    ),
    registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
    mutations: SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(randomSeed)),
    ),
  );
}

ProjectAggregateRoot _seedProject({bool extraLevel = false}) {
  final projectId = ProjectId('project-new');
  final siteId = SiteId('site-new');
  final buildingId = BuildingId('building-seed');
  final levelId = LevelId('level-seed');
  final extraLevelId = LevelId('level-extra');
  final levelIds = <LevelId>{levelId, if (extraLevel) extraLevelId};
  final levels = <LevelId, ProjectLevelEntity>{
    levelId: ProjectLevelEntity(
      id: levelId,
      buildingId: buildingId,
      name: 'Level 1',
      levelNumber: 1,
      elevationMm: 0,
      kind: ProjectLevelKind.residential,
    ),
    if (extraLevel)
      extraLevelId: ProjectLevelEntity(
        id: extraLevelId,
        buildingId: buildingId,
        name: 'Level 2',
        levelNumber: 2,
        elevationMm: 3000,
        kind: ProjectLevelKind.residential,
        displayOrder: 1,
      ),
  };
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
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
          name: 'Compatibility Building',
          levelIds: levelIds,
        ),
      },
      levels: levels,
    ),
  );
}
