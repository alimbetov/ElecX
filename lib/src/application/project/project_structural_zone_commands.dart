import '../../domain/project_aggregate.dart';
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

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: current.stores.buildings,
        levels: levels,
        zones: zones,
        spaces: current.stores.spaces,
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

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: current.stores.buildings,
        levels: current.stores.levels,
        zones: zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[zone.id],
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
