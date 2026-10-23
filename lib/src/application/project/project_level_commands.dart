import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

const int _minimumLevelNumber = -30;
const int _maximumLevelNumber = 200;

/// Creates one canonical level under an existing building.
///
/// [levelId] is the persistent identity. [levelNumber], [displayOrder],
/// [elevationMm], [kind] and [floorToFloorHeightMm] are structural attributes
/// and must never be used as foreign keys.
final class CreateLevelCommand implements ProjectCommand {
  CreateLevelCommand({
    required this.levelId,
    required this.buildingId,
    required this.name,
    required this.levelNumber,
    required this.elevationMm,
    this.displayOrder = 0,
    this.kind,
    this.floorToFloorHeightMm = 3000,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Level name must be non-empty.');
    }
    if (floorToFloorHeightMm <= 0) {
      throw ArgumentError.value(
        floorToFloorHeightMm,
        'floorToFloorHeightMm',
        'Must be positive.',
      );
    }
  }

  final LevelId levelId;
  final BuildingId buildingId;
  final String name;
  final int levelNumber;
  final int displayOrder;
  final int elevationMm;

  /// Nullable only at the compatibility/application request boundary.
  /// Canonical state normalizes an omitted classification to [ProjectLevelKind.unknown].
  final ProjectLevelKind? kind;
  final int floorToFloorHeightMm;

  @override
  String get commandType => 'project.level.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    _validateLevelNumber(levelNumber);
    final building = _requireBuilding(current, buildingId);
    if (current.stores.levels.containsKey(levelId)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.levelAlreadyExists,
        entityId: levelId,
        relatedEntityId: buildingId,
        message: 'Level $levelId already exists.',
      );
    }
    _ensureLevelNumberAvailable(
      current,
      building: building,
      levelNumber: levelNumber,
      subjectLevelId: levelId,
    );

    final buildings = Map<BuildingId, ProjectBuildingEntity>.from(
      current.stores.buildings,
    );
    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels);

    buildings[building.id] = ProjectBuildingEntity(
      id: building.id,
      siteId: building.siteId,
      name: building.name,
      displayOrder: building.displayOrder,
      levelIds: <LevelId>{...building.levelIds, levelId},
    );
    levels[levelId] = ProjectLevelEntity(
      id: levelId,
      buildingId: building.id,
      name: name,
      levelNumber: levelNumber,
      displayOrder: displayOrder,
      elevationMm: elevationMm,
      kind: kind ?? ProjectLevelKind.unknown,
      floorToFloorHeightMm: floorToFloorHeightMm,
    );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          buildings: buildings,
          levels: levels,
        ),
      ),
      affectedEntityIds: <EntityId>[building.id, levelId],
    );
  }
}

/// Renames a level while preserving identity and all structural semantics.
final class RenameLevelCommand implements ProjectCommand {
  RenameLevelCommand({required this.levelId, required this.name}) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Level name must be non-empty.');
    }
  }

  final LevelId levelId;
  final String name;

  @override
  String get commandType => 'project.level.rename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = _requireLevel(current, levelId);
    return _replaceLevel(current, level, name: name);
  }
}

/// Changes user-visible level numbering without changing [LevelId].
final class RenumberLevelCommand implements ProjectCommand {
  const RenumberLevelCommand({
    required this.levelId,
    required this.levelNumber,
  });

  final LevelId levelId;
  final int levelNumber;

  @override
  String get commandType => 'project.level.renumber';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    _validateLevelNumber(levelNumber);
    final level = _requireLevel(current, levelId);
    final building = _requireBuilding(current, level.buildingId);
    _ensureLevelNumberAvailable(
      current,
      building: building,
      levelNumber: levelNumber,
      subjectLevelId: level.id,
      excludingLevelId: level.id,
    );
    return _replaceLevel(current, level, levelNumber: levelNumber);
  }
}

/// Changes structural navigator ordering without changing numbering or identity.
final class ReorderLevelCommand implements ProjectCommand {
  const ReorderLevelCommand({
    required this.levelId,
    required this.displayOrder,
  });

  final LevelId levelId;
  final int displayOrder;

  @override
  String get commandType => 'project.level.reorder';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = _requireLevel(current, levelId);
    return _replaceLevel(current, level, displayOrder: displayOrder);
  }
}

ProjectBuildingEntity _requireBuilding(
  ProjectAggregateRoot current,
  BuildingId buildingId,
) {
  final building = current.index.building(buildingId);
  if (building == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.buildingNotFound,
      entityId: buildingId,
      message: 'Building $buildingId does not exist.',
    );
  }
  return building;
}

ProjectLevelEntity _requireLevel(
  ProjectAggregateRoot current,
  LevelId levelId,
) {
  final level = current.index.level(levelId);
  if (level == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.levelNotFound,
      entityId: levelId,
      message: 'Level $levelId does not exist.',
    );
  }
  return level;
}

void _validateLevelNumber(int levelNumber) {
  if (levelNumber < _minimumLevelNumber ||
      levelNumber > _maximumLevelNumber) {
    throw RangeError.range(
      levelNumber,
      _minimumLevelNumber,
      _maximumLevelNumber,
      'levelNumber',
    );
  }
}

void _ensureLevelNumberAvailable(
  ProjectAggregateRoot current, {
  required ProjectBuildingEntity building,
  required int levelNumber,
  required LevelId subjectLevelId,
  LevelId? excludingLevelId,
}) {
  for (final candidateId in building.levelIds) {
    if (candidateId == excludingLevelId) continue;
    final candidate = current.index.level(candidateId);
    if (candidate?.levelNumber == levelNumber) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.duplicateLevelNumber,
        entityId: subjectLevelId,
        relatedEntityId: candidateId,
        message: 'Building ${building.id} already contains level number '
            '$levelNumber at $candidateId.',
      );
    }
  }
}

ProjectCommandCandidate _replaceLevel(
  ProjectAggregateRoot current,
  ProjectLevelEntity level, {
  String? name,
  int? levelNumber,
  int? displayOrder,
}) {
  final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels);
  levels[level.id] = ProjectLevelEntity(
    id: level.id,
    buildingId: level.buildingId,
    name: name ?? level.name,
    levelNumber: levelNumber ?? level.levelNumber,
    displayOrder: displayOrder ?? level.displayOrder,
    elevationMm: level.elevationMm,
    kind: level.kind,
    floorToFloorHeightMm: level.floorToFloorHeightMm,
    zoneIds: level.zoneIds,
    spaceIds: level.spaceIds,
  );

  return ProjectCommandCandidate.fromState(
    state: ProjectMutableState(
      engineeringMetadata: current.engineeringMetadata,
      stores: current.stores.copyWith(levels: levels),
    ),
    affectedEntityIds: <EntityId>[level.id],
  );
}
