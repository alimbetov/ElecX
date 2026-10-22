import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';

enum ProjectNavigationIssueCode {
  buildingNotFound,
  buildingSiteMismatch,
  levelNotFound,
  levelBuildingMismatch,
  zoneNotFound,
  zoneLevelMismatch,
  spaceNotFound,
  spaceLevelMismatch,
}

final class ProjectNavigationException implements Exception {
  const ProjectNavigationException({
    required this.code,
    required this.message,
    this.entityId,
    this.relatedEntityId,
  });

  final ProjectNavigationIssueCode code;
  final String message;
  final EntityId? entityId;
  final EntityId? relatedEntityId;

  @override
  String toString() => '${code.name}: $message';
}

/// One application/session source of truth for structural navigation.
///
/// This state is intentionally separate from canonical engineering data. It
/// references canonical stable identities only; display numbers, labels and
/// tree indices are never navigation identities.
final class ProjectNavigationState {
  const ProjectNavigationState._({
    required this.siteId,
    this.activeBuildingId,
    this.activeLevelId,
    this.selectedZoneId,
    this.selectedSpaceId,
  });

  /// Builds a deterministic valid location for a canonical project.
  ///
  /// The first Building/Level is chosen by explicit structural ordering and a
  /// stable ID tie-breaker, never by Set iteration order.
  factory ProjectNavigationState.initial(ProjectAggregateRoot project) {
    final building = _firstBuilding(project);
    final level = building == null ? null : _firstLevel(project, building.id);
    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: building?.id,
      activeLevelId: level?.id,
    );
  }

  /// Restores persisted/session navigation identities and validates them
  /// against the current canonical graph.
  ///
  /// Invalid identities are never rebound by label or level number. They are
  /// repaired through the same deterministic ID-backed policy as [reconcile].
  factory ProjectNavigationState.restore(
    ProjectAggregateRoot project, {
    BuildingId? activeBuildingId,
    LevelId? activeLevelId,
    ZoneId? selectedZoneId,
    SpaceId? selectedSpaceId,
  }) {
    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: activeBuildingId,
      activeLevelId: activeLevelId,
      selectedZoneId: selectedZoneId,
      selectedSpaceId: selectedSpaceId,
    ).reconcile(project);
  }

  final SiteId siteId;
  final BuildingId? activeBuildingId;
  final LevelId? activeLevelId;
  final ZoneId? selectedZoneId;
  final SpaceId? selectedSpaceId;

  /// Activates a Building and atomically resolves a valid Level in it.
  ///
  /// Existing entity selection is cleared because it belongs to the previous
  /// active context. A Building with no Levels is a valid Building-only state.
  ProjectNavigationState activateBuilding(
    ProjectAggregateRoot project,
    BuildingId buildingId,
  ) {
    final building = project.index.building(buildingId);
    if (building == null) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.buildingNotFound,
        entityId: buildingId,
        message: 'Building $buildingId does not exist.',
      );
    }
    if (building.siteId != project.siteId) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.buildingSiteMismatch,
        entityId: building.id,
        relatedEntityId: project.siteId,
        message: 'Building ${building.id} does not belong to the active site.',
      );
    }

    final level = _firstLevel(project, building.id);
    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: building.id,
      activeLevelId: level?.id,
    );
  }

  /// Activates a Level by stable identity and derives its Building atomically.
  ProjectNavigationState activateLevel(
    ProjectAggregateRoot project,
    LevelId levelId,
  ) {
    final level = project.index.level(levelId);
    if (level == null) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.levelNotFound,
        entityId: levelId,
        message: 'Level $levelId does not exist.',
      );
    }
    final building = project.index.building(level.buildingId);
    if (building == null || building.siteId != project.siteId) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.levelBuildingMismatch,
        entityId: level.id,
        relatedEntityId: level.buildingId,
        message: 'Level ${level.id} has no valid Building in the active site.',
      );
    }

    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: building.id,
      activeLevelId: level.id,
    );
  }

  /// Selects a structural Zone and activates its owning Building/Level.
  ProjectNavigationState selectZone(
    ProjectAggregateRoot project,
    ZoneId zoneId,
  ) {
    final zone = project.index.zone(zoneId);
    if (zone == null) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.zoneNotFound,
        entityId: zoneId,
        message: 'Structural zone $zoneId does not exist.',
      );
    }
    final level = project.index.level(zone.levelId);
    if (level == null) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.zoneLevelMismatch,
        entityId: zone.id,
        relatedEntityId: zone.levelId,
        message: 'Structural zone ${zone.id} has no valid owning Level.',
      );
    }

    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: level.buildingId,
      activeLevelId: level.id,
      selectedZoneId: zone.id,
    );
  }

  /// Selects a Space and activates its owning Building/Level.
  ///
  /// If the Space belongs to a structural Zone, that Zone is retained in the
  /// current path while the Space remains the selected leaf entity.
  ProjectNavigationState selectSpace(
    ProjectAggregateRoot project,
    SpaceId spaceId,
  ) {
    final space = project.index.space(spaceId);
    if (space == null) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.spaceNotFound,
        entityId: spaceId,
        message: 'Space $spaceId does not exist.',
      );
    }
    final level = project.index.level(space.levelId);
    if (level == null) {
      throw ProjectNavigationException(
        code: ProjectNavigationIssueCode.spaceLevelMismatch,
        entityId: space.id,
        relatedEntityId: space.levelId,
        message: 'Space ${space.id} has no valid owning Level.',
      );
    }

    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: level.buildingId,
      activeLevelId: level.id,
      selectedZoneId: project.index.structuralZoneBySpace[space.id],
      selectedSpaceId: space.id,
    );
  }

  ProjectNavigationState clearSelection() => ProjectNavigationState._(
        siteId: siteId,
        activeBuildingId: activeBuildingId,
        activeLevelId: activeLevelId,
      );

  /// Repairs this session state against the latest canonical project graph.
  ///
  /// This is used for restore/reopen validation and as a generic fallback when
  /// the previous graph is unavailable. Invalid identities are never rebound by
  /// display name or level number.
  ProjectNavigationState reconcile(ProjectAggregateRoot project) {
    var building = activeBuildingId == null
        ? null
        : project.index.building(activeBuildingId!);
    if (building == null || building.siteId != project.siteId) {
      building = _firstBuilding(project);
    }

    ProjectLevelEntity? level;
    if (building != null && activeLevelId != null) {
      final candidate = project.index.level(activeLevelId!);
      if (candidate != null && candidate.buildingId == building.id) {
        level = candidate;
      }
    }
    level ??= building == null ? null : _firstLevel(project, building.id);

    return _withValidatedSelection(project, building, level);
  }

  /// Reconciles after a structural mutation while preserving spatially local
  /// navigation where possible.
  ///
  /// If the active Level/Building was deleted, the next surviving sibling from
  /// the previous canonical ordering is preferred, then the previous sibling.
  /// This implements deterministic "neighbor" fallback without relying on Set
  /// iteration order, labels, or matching level numbers.
  ProjectNavigationState reconcileAfterMutation({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot after,
  }) {
    ProjectBuildingEntity? building;
    if (activeBuildingId != null) {
      building = after.index.building(activeBuildingId!);
    }

    if (building == null && activeBuildingId != null) {
      building = _neighborBuilding(
        before: before,
        after: after,
        removedBuildingId: activeBuildingId!,
      );
    }
    building ??= _firstBuilding(after);

    ProjectLevelEntity? level;
    if (building != null && activeLevelId != null) {
      final existing = after.index.level(activeLevelId!);
      if (existing != null && existing.buildingId == building.id) {
        level = existing;
      } else if (activeBuildingId == building.id) {
        level = _neighborLevel(
          before: before,
          after: after,
          buildingId: building.id,
          removedLevelId: activeLevelId!,
        );
      }
    }
    level ??= building == null ? null : _firstLevel(after, building.id);

    return _withValidatedSelection(after, building, level);
  }

  ProjectNavigationState _withValidatedSelection(
    ProjectAggregateRoot project,
    ProjectBuildingEntity? building,
    ProjectLevelEntity? level,
  ) {
    if (building == null || level == null) {
      return ProjectNavigationState._(
        siteId: project.siteId,
        activeBuildingId: building?.id,
      );
    }

    ZoneId? zoneId;
    if (selectedZoneId != null) {
      final zone = project.index.zone(selectedZoneId!);
      if (zone != null && zone.levelId == level.id) {
        zoneId = zone.id;
      }
    }

    SpaceId? spaceId;
    if (selectedSpaceId != null) {
      final space = project.index.space(selectedSpaceId!);
      if (space != null && space.levelId == level.id) {
        spaceId = space.id;
        zoneId = project.index.structuralZoneBySpace[space.id];
      }
    }

    return ProjectNavigationState._(
      siteId: project.siteId,
      activeBuildingId: building.id,
      activeLevelId: level.id,
      selectedZoneId: zoneId,
      selectedSpaceId: spaceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectNavigationState &&
      other.siteId == siteId &&
      other.activeBuildingId == activeBuildingId &&
      other.activeLevelId == activeLevelId &&
      other.selectedZoneId == selectedZoneId &&
      other.selectedSpaceId == selectedSpaceId;

  @override
  int get hashCode => Object.hash(
        siteId,
        activeBuildingId,
        activeLevelId,
        selectedZoneId,
        selectedSpaceId,
      );
}

ProjectBuildingEntity? _firstBuilding(ProjectAggregateRoot project) {
  final buildings = _orderedBuildings(project);
  return buildings.isEmpty ? null : buildings.first;
}

ProjectLevelEntity? _firstLevel(
  ProjectAggregateRoot project,
  BuildingId buildingId,
) {
  final levels = _orderedLevels(project, buildingId);
  return levels.isEmpty ? null : levels.first;
}

ProjectBuildingEntity? _neighborBuilding({
  required ProjectAggregateRoot before,
  required ProjectAggregateRoot after,
  required BuildingId removedBuildingId,
}) {
  final previousOrder = _orderedBuildings(before);
  final removedIndex = previousOrder.indexWhere(
    (building) => building.id == removedBuildingId,
  );
  if (removedIndex < 0) return null;

  for (var index = removedIndex + 1; index < previousOrder.length; index++) {
    final candidate = after.index.building(previousOrder[index].id);
    if (candidate != null) return candidate;
  }
  for (var index = removedIndex - 1; index >= 0; index--) {
    final candidate = after.index.building(previousOrder[index].id);
    if (candidate != null) return candidate;
  }
  return null;
}

ProjectLevelEntity? _neighborLevel({
  required ProjectAggregateRoot before,
  required ProjectAggregateRoot after,
  required BuildingId buildingId,
  required LevelId removedLevelId,
}) {
  final previousOrder = _orderedLevels(before, buildingId);
  final removedIndex = previousOrder.indexWhere(
    (level) => level.id == removedLevelId,
  );
  if (removedIndex < 0) return null;

  for (var index = removedIndex + 1; index < previousOrder.length; index++) {
    final candidate = after.index.level(previousOrder[index].id);
    if (candidate != null && candidate.buildingId == buildingId) {
      return candidate;
    }
  }
  for (var index = removedIndex - 1; index >= 0; index--) {
    final candidate = after.index.level(previousOrder[index].id);
    if (candidate != null && candidate.buildingId == buildingId) {
      return candidate;
    }
  }
  return null;
}

List<ProjectBuildingEntity> _orderedBuildings(ProjectAggregateRoot project) {
  return project.index.buildings.values.toList()
    ..sort((left, right) {
      final byOrder = left.displayOrder.compareTo(right.displayOrder);
      if (byOrder != 0) return byOrder;
      return left.id.value.compareTo(right.id.value);
    });
}

List<ProjectLevelEntity> _orderedLevels(
  ProjectAggregateRoot project,
  BuildingId buildingId,
) {
  return project.index.levels.values
      .where((level) => level.buildingId == buildingId)
      .toList()
    ..sort((left, right) {
      final byOrder = left.displayOrder.compareTo(right.displayOrder);
      if (byOrder != 0) return byOrder;
      final byNumber = left.levelNumber.compareTo(right.levelNumber);
      if (byNumber != 0) return byNumber;
      return left.id.value.compareTo(right.id.value);
    });
}
