import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'package:elecx/src/application/project/wizard/wizard_preview_scene.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic diff is hierarchy ordered, filterable and field-level', () {
    final project = _project();
    final session = _previewSession(
      project,
      buildingName: 'Tower A',
      randomSeed: 301,
    );
    final diff = const WizardDiffProjector().project(
      before: project,
      preview: session.preview!,
    );

    expect(diff.entries, hasLength(6));
    expect(diff.count(WizardDiffKind.add), 5);
    expect(diff.count(WizardDiffKind.update), 1);
    expect(diff.entries.first.category, WizardDiffEntityCategory.site);
    expect(diff.entries[1].category, WizardDiffEntityCategory.building);
    expect(
      diff.entries.skip(2).every(
            (entry) => entry.category == WizardDiffEntityCategory.level,
          ),
      isTrue,
    );

    final building = diff.entries[1];
    expect(building.title, contains('Tower A'));
    expect(
      building.fields.any(
        (field) => field.field == 'Name' && field.afterValue == 'Tower A',
      ),
      isTrue,
    );
    expect(
      diff.filtered(categories: {WizardDiffEntityCategory.level}),
      hasLength(4),
    );
    expect(diff.filtered(query: '3200 mm'), isNotEmpty);
  });

  test('semantic diff renders remove operations from canonical before-values',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final port = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(303)),
    );
    final provider = BasicBuildingWizardProvider();
    final target = SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );
    final create = provider.generateTyped(
      const BasicBuildingWizardParameters(
        buildingName: 'Tower Remove',
        aboveGroundLevelCount: 2,
        basementLevelCount: 0,
        floorToFloorHeightMm: 3000,
        createGroundLevel: false,
      ),
      WizardGenerationContext(target: target, project: project),
    );
    expect(port.commitPreview(port.preview(create)), isNotNull);

    final beforeRemoval = mutations.current;
    final building = beforeRemoval.stores.buildings.values.single;
    final levelIds = building.levelIds.toSet();
    final removalPreview = port.preview(
      _RemoveBuildingCommand(
        siteId: beforeRemoval.siteId,
        buildingId: building.id,
        levelIds: levelIds,
      ),
    );
    final diff = const WizardDiffProjector().project(
      before: beforeRemoval,
      preview: removalPreview,
    );

    expect(diff.count(WizardDiffKind.remove), 3);
    expect(diff.count(WizardDiffKind.update), 1);
    expect(diff.count(WizardDiffKind.add), 0);
    expect(diff.filtered(kinds: {WizardDiffKind.remove}), hasLength(3));

    final removedBuilding = diff.entries.singleWhere(
      (entry) => entry.entityId == building.id,
    );
    expect(removedBuilding.kind, WizardDiffKind.remove);
    expect(removedBuilding.title, contains('Tower Remove'));
    expect(removedBuilding.context, contains('Site'));
    expect(
      removedBuilding.fields.any(
        (field) =>
            field.field == 'Name' &&
            field.beforeValue == 'Tower Remove' &&
            field.afterValue == null,
      ),
      isTrue,
    );

    for (final levelId in levelIds) {
      final removedLevel = diff.entries.singleWhere(
        (entry) => entry.entityId == levelId,
      );
      expect(removedLevel.kind, WizardDiffKind.remove);
      expect(removedLevel.context, contains('Tower Remove'));
      expect(
        removedLevel.fields.every((field) => field.afterValue == null),
        isTrue,
      );
    }
  });

  test('Basic Building preview scene and SVG are deterministic and inert', () {
    final project = _project();
    final session = _previewSession(
      project,
      buildingName: 'Tower <A> & "North"',
      randomSeed: 307,
    );
    final scene = const BasicBuildingWizardPreviewProjector().project(
      session.preview!,
    );
    final svgProjector = const WizardSvgProjector();
    final first = svgProjector.toSvg(scene);
    final second = svgProjector.toSvg(scene);

    expect(first, second);
    expect(scene.semanticLabel, contains('Tower <A> & "North"'));
    expect(
      scene.elements.whereType<WizardPreviewText>().map((item) => item.text),
      contains('Ground'),
    );
    expect(first, contains('Tower &lt;A&gt; &amp; &quot;North&quot;'));
    expect(first, isNot(contains('<script')));
    expect(first, isNot(contains('foreignObject')));
    expect(first, isNot(contains('href=')));
    expect(RegExp(r'\son[a-z]+=').hasMatch(first), isFalse);
  });
}

final class _RemoveBuildingCommand implements ReservedProjectCommand {
  const _RemoveBuildingCommand({
    required this.siteId,
    required this.buildingId,
    required this.levelIds,
  });

  final SiteId siteId;
  final BuildingId buildingId;
  final Set<LevelId> levelIds;

  @override
  String get commandType => 'test.remove-building';

  @override
  String get normalizedIntentKey =>
      'test.remove-building|${siteId.value}|${buildingId.value}';

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory);

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final building = current.stores.buildings[buildingId];
    if (building == null || building.siteId != siteId) {
      throw StateError('Building is missing or has another owner.');
    }
    if (!building.levelIds.containsAll(levelIds) ||
        building.levelIds.length != levelIds.length) {
      throw StateError('Removal level set does not match Building membership.');
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final site = current.stores.sites[siteId]!;
    final sites = Map<SiteId, ProjectSiteEntity>.of(current.stores.sites)
      ..[siteId] = ProjectSiteEntity(
        id: site.id,
        name: site.name,
        buildingIds: site.buildingIds.where((id) => id != buildingId),
      );
    final buildings =
        Map<BuildingId, ProjectBuildingEntity>.of(current.stores.buildings)
          ..remove(buildingId);
    final levels = Map<LevelId, ProjectLevelEntity>.of(current.stores.levels)
      ..removeWhere((id, _) => levelIds.contains(id));
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          sites: sites,
          buildings: buildings,
          levels: levels,
        ),
      ),
      affectedEntityIds: <EntityId>{siteId, buildingId, ...levelIds},
    );
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    yield UpdateEntityOperation(entityId: siteId);
    for (final levelId in levelIds) {
      yield RemoveEntityOperation(entityId: levelId, ownerId: buildingId);
    }
    yield RemoveEntityOperation(entityId: buildingId, ownerId: siteId);
  }
}

WizardSession _previewSession(
  ProjectAggregateRoot project, {
  required String buildingName,
  required int randomSeed,
}) {
  final session = WizardSession(
    target: SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    ),
    registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
    mutations: SharedProjectWizardMutationPort(
      mutations: ProjectMutationSession(project),
      idFactory: SecureRandomEntityIdFactory(random: Random(randomSeed)),
    ),
  );
  expect(session.begin(), isTrue);
  expect(session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
  expect(
    session.updateParameters(
      BasicBuildingWizardParameters(
        buildingName: buildingName,
        aboveGroundLevelCount: 2,
        basementLevelCount: 1,
        floorToFloorHeightMm: 3200,
        createGroundLevel: true,
      ),
    ),
    isTrue,
  );
  expect(session.generatePreview(), isTrue);
  return session;
}

ProjectAggregateRoot _project() {
  final projectId = ProjectId('project-diff-preview');
  final siteId = SiteId('site-diff-preview');
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
