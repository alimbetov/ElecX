import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

/// Creates one canonical space under an existing level.
///
/// [spaceId] is the persistent identity. Optional [structuralZoneId] assigns
/// the new space to one exclusive structural zone on the same level. Semantic
/// usage/classification is intentionally not introduced here; that belongs to
/// the later SpaceUsage/overlay stage.
final class CreateSpaceCommand implements ProjectCommand {
  CreateSpaceCommand({
    required this.spaceId,
    required this.levelId,
    required this.name,
    this.structuralZoneId,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Space name must be non-empty.',
      );
    }
  }

  final SpaceId spaceId;
  final LevelId levelId;
  final String name;
  final ZoneId? structuralZoneId;

  @override
  String get commandType => 'project.space.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = _requireLevel(current, levelId);
    if (current.stores.spaces.containsKey(spaceId)) {
      final existing = current.index.space(spaceId)!;
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.spaceAlreadyExists,
        entityId: spaceId,
        relatedEntityId: existing.levelId,
        message: 'Space $spaceId already exists on level ${existing.levelId}; '
            'requested parent level is $levelId.',
      );
    }

    ProjectStructuralZoneEntity? zone;
    if (structuralZoneId != null) {
      zone = _requireStructuralZone(current, structuralZoneId!);
      if (zone.levelId != level.id) {
        throw ProjectAuthoringException(
          code: ProjectAuthoringIssueCode.structuralZoneLevelMismatch,
          entityId: zone.id,
          relatedEntityId: zone.levelId,
          message:
              'Structural zone ${zone.id} belongs to level ${zone.levelId}, '
              'not requested level ${level.id}.',
        );
      }
    }

    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels);
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    );
    final spaces = Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces);

    levels[level.id] = ProjectLevelEntity(
      id: level.id,
      buildingId: level.buildingId,
      name: level.name,
      levelNumber: level.levelNumber,
      displayOrder: level.displayOrder,
      elevationMm: level.elevationMm,
      zoneIds: level.zoneIds,
      spaceIds: <SpaceId>{...level.spaceIds, spaceId},
    );

    if (zone != null) {
      zones[zone.id] = ProjectStructuralZoneEntity(
        id: zone.id,
        levelId: zone.levelId,
        name: zone.name,
        spaceIds: <SpaceId>{...zone.spaceIds, spaceId},
      );
    }

    spaces[spaceId] = ProjectSpaceEntity(
      id: spaceId,
      levelId: level.id,
      name: name,
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: current.stores.buildings,
        levels: levels,
        zones: zones,
        spaces: spaces,
      ),
      affectedEntityIds: <EntityId>[
        level.id,
        if (zone != null) zone.id,
        spaceId,
      ],
    );
  }
}

/// Renames a space while preserving stable identity and level ownership.
final class RenameSpaceCommand implements ProjectCommand {
  RenameSpaceCommand({
    required this.spaceId,
    required this.name,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Space name must be non-empty.',
      );
    }
  }

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'project.space.rename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = _requireSpace(current, spaceId);
    final spaces = Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces);
    spaces[space.id] = ProjectSpaceEntity(
      id: space.id,
      levelId: space.levelId,
      name: name,
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: current.stores.buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: spaces,
      ),
      affectedEntityIds: <EntityId>[space.id],
    );
  }
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

ProjectStructuralZoneEntity _requireStructuralZone(
  ProjectAggregateRoot current,
  ZoneId zoneId,
) {
  final zone = current.index.zone(zoneId);
  if (zone == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.structuralZoneNotFound,
      entityId: zoneId,
      message: 'Structural zone $zoneId does not exist.',
    );
  }
  return zone;
}

ProjectSpaceEntity _requireSpace(
  ProjectAggregateRoot current,
  SpaceId spaceId,
) {
  final space = current.index.space(spaceId);
  if (space == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.spaceNotFound,
      entityId: spaceId,
      message: 'Space $spaceId does not exist.',
    );
  }
  return space;
}
