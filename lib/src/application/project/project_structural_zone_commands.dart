import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

/// Creates one empty structural zone under an existing canonical level.
///
/// Structural zones are exclusive hierarchy groupings. Cross-discipline
/// overlays are intentionally handled later and must not reuse this identity.
final class CreateStructuralZoneCommand implements ProjectCommand {
  CreateStructuralZoneCommand({
    required this.zoneId,
    required this.levelId,
    required this.name,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Structural zone name must be non-empty.',
      );
    }
  }

  final ZoneId zoneId;
  final LevelId levelId;
  final String name;

  @override
  String get commandType => 'project.structural-zone.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = _requireLevel(current, levelId);
    final existingZone = current.index.zone(zoneId);
    if (existingZone != null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.structuralZoneAlreadyExists,
        entityId: zoneId,
        relatedEntityId: existingZone.levelId,
        message: 'Structural zone $zoneId already exists on level '
            '${existingZone.levelId}; requested parent level is $levelId.',
      );
    }

    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels);
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    );

    levels[level.id] = ProjectLevelEntity(
      id: level.id,
      buildingId: level.buildingId,
      name: level.name,
      levelNumber: level.levelNumber,
      displayOrder: level.displayOrder,
      elevationMm: level.elevationMm,
      zoneIds: <ZoneId>{...level.zoneIds, zoneId},
      spaceIds: level.spaceIds,
    );
    zones[zoneId] = ProjectStructuralZoneEntity(
      id: zoneId,
      levelId: level.id,
      name: name,
      spaceIds: const <SpaceId>[],
    );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          levels: levels,
          zones: zones,
        ),
      ),
      affectedEntityIds: <EntityId>[level.id, zoneId],
    );
  }
}

/// Renames one structural zone without changing identity, level ownership or
/// current space membership.
final class RenameStructuralZoneCommand implements ProjectCommand {
  RenameStructuralZoneCommand({required this.zoneId, required this.name}) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Structural zone name must be non-empty.',
      );
    }
  }

  final ZoneId zoneId;
  final String name;

  @override
  String get commandType => 'project.structural-zone.rename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final zone = _requireStructuralZone(current, zoneId);
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    );
    zones[zone.id] = ProjectStructuralZoneEntity(
      id: zone.id,
      levelId: zone.levelId,
      name: name,
      spaceIds: zone.spaceIds,
    );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(zones: zones),
      ),
      affectedEntityIds: <EntityId>[zone.id],
    );
  }
}

/// Moves one existing Space into [zoneId] atomically.
///
/// Structural-zone membership is exclusive. If the Space already belongs to a
/// different structural zone on the same Level, it is removed from the old
/// zone and added to the requested zone in the same canonical mutation and Undo
/// boundary. Cross-level assignment is rejected fail-closed.
final class AssignSpaceToStructuralZoneCommand implements ProjectCommand {
  const AssignSpaceToStructuralZoneCommand({
    required this.spaceId,
    required this.zoneId,
  });

  final SpaceId spaceId;
  final ZoneId zoneId;

  @override
  String get commandType => 'project.structural-zone.space.assign';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = _requireSpace(current, spaceId);
    final target = _requireStructuralZone(current, zoneId);
    if (target.levelId != space.levelId) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.structuralZoneLevelMismatch,
        entityId: target.id,
        relatedEntityId: target.levelId,
        message: 'Structural zone ${target.id} belongs to level '
            '${target.levelId}, not Space ${space.id} level ${space.levelId}.',
      );
    }

    final currentZoneId = current.index.structuralZoneBySpace[space.id];
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    );
    if (currentZoneId != null && currentZoneId != target.id) {
      final previous = current.index.zone(currentZoneId)!;
      zones[previous.id] = ProjectStructuralZoneEntity(
        id: previous.id,
        levelId: previous.levelId,
        name: previous.name,
        spaceIds: <SpaceId>{...previous.spaceIds}..remove(space.id),
      );
    }
    zones[target.id] = ProjectStructuralZoneEntity(
      id: target.id,
      levelId: target.levelId,
      name: target.name,
      spaceIds: <SpaceId>{...target.spaceIds, space.id},
    );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(zones: zones),
      ),
      affectedEntityIds: <EntityId>[
        space.id,
        if (currentZoneId != null) currentZoneId,
        target.id,
      ],
    );
  }
}

/// Removes the Space from its current structural zone without changing Level
/// ownership or any overlay classification.
final class UnassignSpaceFromStructuralZoneCommand implements ProjectCommand {
  const UnassignSpaceFromStructuralZoneCommand({required this.spaceId});

  final SpaceId spaceId;

  @override
  String get commandType => 'project.structural-zone.space.unassign';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = _requireSpace(current, spaceId);
    final currentZoneId = current.index.structuralZoneBySpace[space.id];
    if (currentZoneId == null) {
      return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(current),
        affectedEntityIds: <EntityId>[space.id],
      );
    }

    final zone = current.index.zone(currentZoneId)!;
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    );
    zones[zone.id] = ProjectStructuralZoneEntity(
      id: zone.id,
      levelId: zone.levelId,
      name: zone.name,
      spaceIds: <SpaceId>{...zone.spaceIds}..remove(space.id),
    );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(zones: zones),
      ),
      affectedEntityIds: <EntityId>[space.id, zone.id],
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

ProjectSpaceEntity _requireSpace(ProjectAggregateRoot current, SpaceId spaceId) {
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
