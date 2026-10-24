import 'dart:convert';

import '../../../domain/project_aggregate.dart';
import '../../../domain/project_entity_stores_copy.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation.dart';
import '../project_mutation_reservation.dart';
import 'wizard_contracts.dart';

/// Structural-only P8 startup/insertion parameters.
///
/// [aboveGroundLevelCount] counts positive numbered levels (1..N). When
/// [createGroundLevel] is true an explicit level 0 is added in addition to
/// those positive levels. Basements use -N..-1.
final class BasicBuildingWizardParameters extends WizardParameters {
  const BasicBuildingWizardParameters({
    required this.buildingName,
    required this.aboveGroundLevelCount,
    required this.basementLevelCount,
    required this.floorToFloorHeightMm,
    this.createGroundLevel = true,
  });

  final String buildingName;
  final int aboveGroundLevelCount;
  final int basementLevelCount;
  final int floorToFloorHeightMm;
  final bool createGroundLevel;

  BasicBuildingWizardParameters normalized() => BasicBuildingWizardParameters(
        buildingName: buildingName.trim(),
        aboveGroundLevelCount: aboveGroundLevelCount,
        basementLevelCount: basementLevelCount,
        floorToFloorHeightMm: floorToFloorHeightMm,
        createGroundLevel: createGroundLevel,
      );
}

/// Production P8 base provider for deterministic structural Building + Levels.
///
/// Site insertion allocates a new Building and all Levels. New-project startup
/// normalizes the one compatibility seed in-place: the bound Building identity
/// and one reference Level identity are reused, while only additional Levels
/// receive reserved durable identities. This keeps the legacy/canonical bridge
/// stable across the startup Wizard transaction.
final class BasicBuildingWizardProvider
    extends TypedWizardProvider<BasicBuildingWizardParameters> {
  BasicBuildingWizardProvider();

  static final WizardFamilyId familyId = WizardFamilyId('basic-building');

  @override
  final WizardProviderDescriptor descriptor = WizardProviderDescriptor(
    templateId: TemplateId('p8-basic-building'),
    templateVersion: 1,
    generatorVersion: '2',
    familyId: familyId,
    displayName: 'Building',
    supportedScopes: const {
      WizardTargetScope.newProject,
      WizardTargetScope.site,
    },
  );

  @override
  BasicBuildingWizardParameters typedDefaultsFor(WizardTargetContext target) =>
      const BasicBuildingWizardParameters(
        buildingName: 'Building',
        aboveGroundLevelCount: 1,
        basementLevelCount: 0,
        floorToFloorHeightMm: 3000,
        createGroundLevel: true,
      );

  @override
  WizardParameterValidation validateTypedParameters(
    BasicBuildingWizardParameters parameters,
    WizardTargetContext target,
  ) {
    final normalized = parameters.normalized();
    final issues = <WizardValidationIssue>[];
    if (target is! SiteWizardTarget && target is! NewProjectWizardTarget) {
      issues.add(
        const WizardValidationIssue(
          code: 'basic-building.target.unsupported',
          message: 'Basic Building requires a new-project or Site target.',
          severity: WizardIssueSeverity.blocker,
        ),
      );
    }
    if (normalized.buildingName.isEmpty) {
      issues.add(
        const WizardValidationIssue(
          code: 'basic-building.name.empty',
          message: 'Building name is required.',
          severity: WizardIssueSeverity.blocker,
        ),
      );
    }
    if (normalized.aboveGroundLevelCount < 1 ||
        normalized.aboveGroundLevelCount > 200) {
      issues.add(
        const WizardValidationIssue(
          code: 'basic-building.above-ground.out-of-range',
          message: 'Above-ground level count must be between 1 and 200.',
          severity: WizardIssueSeverity.blocker,
        ),
      );
    }
    if (normalized.basementLevelCount < 0 ||
        normalized.basementLevelCount > 30) {
      issues.add(
        const WizardValidationIssue(
          code: 'basic-building.basement.out-of-range',
          message: 'Basement level count must be between 0 and 30.',
          severity: WizardIssueSeverity.blocker,
        ),
      );
    }
    if (normalized.floorToFloorHeightMm <= 0) {
      issues.add(
        const WizardValidationIssue(
          code: 'basic-building.height.non-positive',
          message: 'Floor-to-floor height must be a positive millimetre value.',
          severity: WizardIssueSeverity.blocker,
        ),
      );
    }
    return WizardParameterValidation(issues);
  }

  @override
  ReservedProjectCommand generateTyped(
    BasicBuildingWizardParameters parameters,
    WizardGenerationContext context,
  ) {
    final validation = validateTypedParameters(parameters, context.target);
    if (validation.hasBlockers) {
      throw StateError(
        'Cannot generate Basic Building from invalid parameters.',
      );
    }
    final normalized = parameters.normalized();
    final target = context.target;
    if (target is SiteWizardTarget) {
      return _ApplyBasicBuildingCommand.site(
        target: target,
        parameters: normalized,
        descriptor: descriptor,
      );
    }
    if (target is NewProjectWizardTarget) {
      final seed = _resolveNewProjectSeed(context.project, target);
      return _ApplyBasicBuildingCommand.newProject(
        target: target,
        parameters: normalized,
        descriptor: descriptor,
        seedBuildingId: seed.buildingId,
        seedLevelId: seed.levelId,
      );
    }
    throw StateError('Basic Building target is not supported.');
  }
}

final class _NewProjectSeed {
  const _NewProjectSeed({required this.buildingId, required this.levelId});

  final BuildingId buildingId;
  final LevelId levelId;
}

_NewProjectSeed _resolveNewProjectSeed(
  ProjectAggregateRoot project,
  NewProjectWizardTarget target,
) {
  if (project.id != target.projectId || project.siteId != target.siteId) {
    throw StateError('New-project Wizard target does not match the project.');
  }
  final site = project.stores.sites[target.siteId];
  if (site == null || site.buildingIds.length != 1) {
    throw StateError(
      'New-project Basic Building requires exactly one compatibility Building.',
    );
  }
  final buildingId = site.buildingIds.single;
  final building = project.stores.buildings[buildingId];
  if (building == null ||
      building.siteId != target.siteId ||
      building.levelIds.length != 1) {
    throw StateError(
      'New-project compatibility Building must contain exactly one seed Level.',
    );
  }
  final levelId = building.levelIds.single;
  final level = project.stores.levels[levelId];
  if (level == null || level.buildingId != buildingId) {
    throw StateError('New-project compatibility Level is incoherent.');
  }
  if (level.zoneIds.isNotEmpty || level.spaceIds.isNotEmpty) {
    throw StateError(
      'New-project compatibility Level is already authored and cannot be '
      'normalized by the startup Wizard.',
    );
  }
  return _NewProjectSeed(buildingId: buildingId, levelId: levelId);
}

final class _ApplyBasicBuildingCommand implements ReservedProjectCommand {
  const _ApplyBasicBuildingCommand.site({
    required this.target,
    required this.parameters,
    required this.descriptor,
  })  : seedBuildingId = null,
        seedLevelId = null;

  const _ApplyBasicBuildingCommand.newProject({
    required this.target,
    required this.parameters,
    required this.descriptor,
    required this.seedBuildingId,
    required this.seedLevelId,
  });

  final WizardTargetContext target;
  final BasicBuildingWizardParameters parameters;
  final WizardProviderDescriptor descriptor;
  final BuildingId? seedBuildingId;
  final LevelId? seedLevelId;

  static const String _buildingSlot = 'building';

  bool get _isNewProject => target is NewProjectWizardTarget;

  int get _referenceLevelNumber => parameters.createGroundLevel ? 0 : 1;

  List<int> get _levelNumbers => [
        for (var number = -parameters.basementLevelCount; number < 0; number++)
          number,
        if (parameters.createGroundLevel) 0,
        for (var number = 1;
            number <= parameters.aboveGroundLevelCount;
            number++)
          number,
      ];

  String _levelSlot(int number) => 'level:$number';

  @override
  String get commandType => 'p8.basic-building.apply';

  @override
  String get normalizedIntentKey => jsonEncode({
        'command': commandType,
        'templateId': descriptor.templateId.value,
        'templateVersion': descriptor.templateVersion,
        'generatorVersion': descriptor.generatorVersion,
        'scope': target.scope.name,
        'projectId': target.projectId.value,
        'siteId': target.siteId.value,
        if (seedBuildingId != null) 'seedBuildingId': seedBuildingId!.value,
        if (seedLevelId != null) 'seedLevelId': seedLevelId!.value,
        'buildingName': parameters.buildingName,
        'aboveGroundLevelCount': parameters.aboveGroundLevelCount,
        'basementLevelCount': parameters.basementLevelCount,
        'floorToFloorHeightMm': parameters.floorToFloorHeightMm,
        'createGroundLevel': parameters.createGroundLevel,
      });

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) {
    final slots = <String, ReservedEntityIdKind>{
      if (!_isNewProject) _buildingSlot: ReservedEntityIdKind.building,
      for (final number in _levelNumbers)
        if (!_isNewProject || number != _referenceLevelNumber)
          _levelSlot(number): ReservedEntityIdKind.level,
    };
    return MutationIdentityReservation.allocate(
      factory: factory,
      entitySlots: slots,
    );
  }

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    if (current.id != target.projectId || current.siteId != target.siteId) {
      throw StateError('Basic Building target no longer matches the project.');
    }
    if (!current.stores.sites.containsKey(target.siteId)) {
      throw StateError('Target Site no longer exists.');
    }

    if (_isNewProject) {
      final buildingId = seedBuildingId;
      final levelId = seedLevelId;
      if (buildingId == null || levelId == null) {
        throw StateError('New-project seed identities are missing.');
      }
      final site = current.stores.sites[target.siteId]!;
      final building = current.stores.buildings[buildingId];
      final level = current.stores.levels[levelId];
      if (site.buildingIds.length != 1 ||
          !site.buildingIds.contains(buildingId) ||
          building == null ||
          building.siteId != target.siteId ||
          building.levelIds.length != 1 ||
          !building.levelIds.contains(levelId) ||
          level == null ||
          level.buildingId != buildingId ||
          level.zoneIds.isNotEmpty ||
          level.spaceIds.isNotEmpty) {
        throw StateError(
          'New-project compatibility seed changed after Wizard generation.',
        );
      }
    } else {
      final buildingId = reservation.entityId<BuildingId>(_buildingSlot);
      if (current.stores.buildings.containsKey(buildingId)) {
        throw StateError('Reserved Building identity already exists.');
      }
    }

    for (final number in _levelNumbers) {
      if (_isNewProject && number == _referenceLevelNumber) continue;
      final levelId = reservation.entityId<LevelId>(_levelSlot(number));
      if (current.stores.levels.containsKey(levelId)) {
        throw StateError('Reserved Level identity already exists.');
      }
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final site = current.stores.sites[target.siteId];
    if (site == null) throw StateError('Target Site no longer exists.');

    final buildingId = _isNewProject
        ? seedBuildingId!
        : reservation.entityId<BuildingId>(_buildingSlot);
    final levelNumbers = _levelNumbers;
    final levelIds = <LevelId>{};
    final levels = <LevelId, ProjectLevelEntity>{...current.stores.levels};
    final reusableLevelId = _isNewProject ? seedLevelId : null;

    for (var displayOrder = 0;
        displayOrder < levelNumbers.length;
        displayOrder++) {
      final number = levelNumbers[displayOrder];
      final levelId = _isNewProject && number == _referenceLevelNumber
          ? reusableLevelId!
          : reservation.entityId<LevelId>(_levelSlot(number));
      final previous = current.stores.levels[levelId];
      levelIds.add(levelId);
      levels[levelId] = ProjectLevelEntity(
        id: levelId,
        buildingId: buildingId,
        name: _levelName(number),
        levelNumber: number,
        kind: _levelKind(number),
        elevationMm: _elevationMm(number),
        floorToFloorHeightMm: parameters.floorToFloorHeightMm,
        displayOrder: displayOrder,
        zoneIds: previous?.zoneIds ?? const <ZoneId>{},
        spaceIds: previous?.spaceIds ?? const <SpaceId>{},
      );
    }

    final previousBuilding = current.stores.buildings[buildingId];
    final building = ProjectBuildingEntity(
      id: buildingId,
      siteId: target.siteId,
      name: parameters.buildingName,
      displayOrder:
          previousBuilding?.displayOrder ?? current.stores.buildings.length,
      levelIds: levelIds,
    );
    final updatedSite = _isNewProject
        ? site
        : ProjectSiteEntity(
            id: site.id,
            name: site.name,
            buildingIds: {...site.buildingIds, buildingId},
          );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          sites: {...current.stores.sites, target.siteId: updatedSite},
          buildings: {...current.stores.buildings, buildingId: building},
          levels: levels,
        ),
      ),
      affectedEntityIds: [
        if (!_isNewProject) target.siteId,
        buildingId,
        ...levelIds,
      ],
    );
  }

  int _elevationMm(int levelNumber) {
    final h = parameters.floorToFloorHeightMm;
    if (levelNumber < 0) return levelNumber * h;
    if (parameters.createGroundLevel) return levelNumber * h;
    return (levelNumber - 1) * h;
  }

  String _levelName(int number) {
    if (number < 0) return 'Basement ${number.abs()}';
    if (number == 0) return 'Ground';
    return 'Level $number';
  }

  ProjectLevelKind _levelKind(int number) {
    if (number < 0) return ProjectLevelKind.basement;
    if (number == 0) return ProjectLevelKind.ground;
    return ProjectLevelKind.residential;
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    final buildingId = _isNewProject
        ? seedBuildingId!
        : reservation.entityId<BuildingId>(_buildingSlot);

    if (_isNewProject) {
      final beforeBuilding = before.stores.buildings[buildingId];
      final afterBuilding = candidate.stores.buildings[buildingId];
      if (!_sameBuilding(beforeBuilding, afterBuilding)) {
        yield UpdateEntityOperation(entityId: buildingId);
      }
      final reusedLevelId = seedLevelId!;
      if (!_sameLevel(
        before.stores.levels[reusedLevelId],
        candidate.stores.levels[reusedLevelId],
      )) {
        yield UpdateEntityOperation(entityId: reusedLevelId);
      }
      for (final number in _levelNumbers) {
        if (number == _referenceLevelNumber) continue;
        yield CreateEntityOperation(
          entityId: reservation.entityId<LevelId>(_levelSlot(number)),
          ownerId: buildingId,
        );
      }
      return;
    }

    yield UpdateEntityOperation(entityId: target.siteId);
    yield CreateEntityOperation(
      entityId: buildingId,
      ownerId: target.siteId,
    );
    for (final number in _levelNumbers) {
      yield CreateEntityOperation(
        entityId: reservation.entityId<LevelId>(_levelSlot(number)),
        ownerId: buildingId,
      );
    }
  }
}

bool _sameBuilding(
  ProjectBuildingEntity? before,
  ProjectBuildingEntity? after,
) {
  if (before == null || after == null) return identical(before, after);
  return before.id == after.id &&
      before.siteId == after.siteId &&
      before.name == after.name &&
      before.displayOrder == after.displayOrder &&
      _sameEntityIds(before.levelIds, after.levelIds);
}

bool _sameLevel(ProjectLevelEntity? before, ProjectLevelEntity? after) {
  if (before == null || after == null) return identical(before, after);
  return before.id == after.id &&
      before.buildingId == after.buildingId &&
      before.name == after.name &&
      before.levelNumber == after.levelNumber &&
      before.kind == after.kind &&
      before.elevationMm == after.elevationMm &&
      before.floorToFloorHeightMm == after.floorToFloorHeightMm &&
      before.displayOrder == after.displayOrder &&
      _sameEntityIds(before.zoneIds, after.zoneIds) &&
      _sameEntityIds(before.spaceIds, after.spaceIds);
}

bool _sameEntityIds<T extends EntityId>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
