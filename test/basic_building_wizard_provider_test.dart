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
  test('provider validates structural ranges and normalized name', () {
    final project = _project();
    final provider = BasicBuildingWizardProvider();
    final target = _siteTarget(project);

    expect(
      provider
          .validateTypedParameters(
            const BasicBuildingWizardParameters(
              buildingName: '   ',
              aboveGroundLevelCount: 0,
              basementLevelCount: 31,
              floorToFloorHeightMm: 0,
            ),
            target,
          )
          .issues
          .where((issue) => issue.severity == WizardIssueSeverity.blocker)
          .map((issue) => issue.code)
          .toSet(),
      {
        'basic-building.name.empty',
        'basic-building.above-ground.out-of-range',
        'basic-building.basement.out-of-range',
        'basic-building.height.non-positive',
      },
    );
  });

  test('normalized semantic intent is deterministic and excludes reserved ids',
      () {
    final project = _project();
    final provider = BasicBuildingWizardProvider();
    final target = _siteTarget(project);
    final context = WizardGenerationContext(target: target, project: project);

    final first = provider.generateTyped(
      const BasicBuildingWizardParameters(
        buildingName: '  Tower A  ',
        aboveGroundLevelCount: 3,
        basementLevelCount: 1,
        floorToFloorHeightMm: 3300,
      ),
      context,
    );
    final second = provider.generateTyped(
      const BasicBuildingWizardParameters(
        buildingName: 'Tower A',
        aboveGroundLevelCount: 3,
        basementLevelCount: 1,
        floorToFloorHeightMm: 3300,
      ),
      context,
    );

    expect(first.normalizedIntentKey, second.normalizedIntentKey);
    expect(first.normalizedIntentKey, contains('Tower A'));
    expect(first.normalizedIntentKey, contains(project.id.value));
    expect(first.normalizedIntentKey, contains(project.siteId.value));
  });

  test('wizard preview is side-effect free and commit creates hierarchy once',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final provider = BasicBuildingWizardProvider();
    final session = WizardSession(
      target: _siteTarget(project),
      registry: WizardProviderRegistry([provider]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(41)),
      ),
    );

    session.begin();
    expect(session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
    expect(
      session.updateParameters(
        const BasicBuildingWizardParameters(
          buildingName: 'Tower A',
          aboveGroundLevelCount: 2,
          basementLevelCount: 2,
          floorToFloorHeightMm: 3000,
          createGroundLevel: true,
        ),
      ),
      isTrue,
    );

    final versionBefore = mutations.current.version;
    final undoBefore = mutations.undoDepth;
    expect(session.generatePreview(), isTrue);
    expect(mutations.current.version, versionBefore);
    expect(mutations.current.stores.buildings, isEmpty);
    expect(mutations.current.stores.levels, isEmpty);

    expect(session.confirm(), isTrue);
    expect(mutations.current.version.value, versionBefore.value + 1);
    expect(mutations.undoDepth, undoBefore + 1);
    expect(mutations.current.stores.buildings, hasLength(1));
    expect(mutations.current.stores.levels, hasLength(5));

    final building = mutations.current.stores.buildings.values.single;
    expect(building.name, 'Tower A');
    expect(building.siteId, project.siteId);
    expect(building.levelIds, hasLength(5));

    final levels = mutations.current.stores.levels.values.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    expect(
      levels.map((level) => level.levelNumber).toList(),
      [-2, -1, 0, 1, 2],
    );
    expect(
      levels.map((level) => level.elevationMm).toList(),
      [-6000, -3000, 0, 3000, 6000],
    );
    expect(
      levels.map((level) => level.kind).toList(),
      [
        ProjectLevelKind.basement,
        ProjectLevelKind.basement,
        ProjectLevelKind.ground,
        ProjectLevelKind.residential,
        ProjectLevelKind.residential,
      ],
    );
    expect(levels.every((level) => level.buildingId == building.id), isTrue);
    expect(
      levels.every((level) => level.floorToFloorHeightMm == 3000),
      isTrue,
    );

    mutations.undo(mutations.current.version);
    expect(mutations.current.stores.buildings, isEmpty);
    expect(mutations.current.stores.levels, isEmpty);
  });

  test(
      'without explicit ground the first positive level is reference elevation',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final provider = BasicBuildingWizardProvider();
    final session = WizardSession(
      target: _siteTarget(project),
      registry: WizardProviderRegistry([provider]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(43)),
      ),
    );

    session.begin();
    session.selectFamily(BasicBuildingWizardProvider.familyId);
    session.updateParameters(
      const BasicBuildingWizardParameters(
        buildingName: 'Tower B',
        aboveGroundLevelCount: 2,
        basementLevelCount: 1,
        floorToFloorHeightMm: 3200,
        createGroundLevel: false,
      ),
    );
    expect(session.generatePreview(), isTrue);
    expect(session.confirm(), isTrue);

    final levels = mutations.current.stores.levels.values.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    expect(levels.map((level) => level.levelNumber).toList(), [-1, 1, 2]);
    expect(levels.map((level) => level.elevationMm).toList(), [-3200, 0, 3200]);
  });

  test('base provider is exposed for new-project seed normalization', () {
    final project = _project();
    final registry = WizardProviderRegistry([BasicBuildingWizardProvider()]);
    final target = NewProjectWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );

    expect(registry.availableFor(target), hasLength(1));
  });
}

SiteWizardTarget _siteTarget(ProjectAggregateRoot project) => SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );

ProjectAggregateRoot _project() {
  final projectId = ProjectId('project-basic-building');
  final siteId = SiteId('site-basic-building');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
