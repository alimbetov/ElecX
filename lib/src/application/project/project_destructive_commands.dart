import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

/// Removes one space and all structural back-references.
///
/// P6 semantic dependencies are never cascaded implicitly. Openings,
/// adjacencies and overlay classifications must be edited explicitly first so
/// one destructive action cannot silently erase engineering meaning.
///
/// P7A boundary topology is different: it is owned state of the space itself,
/// not an independent semantic dependency. Removing a space therefore removes
/// its boundary topology and stable edge identities atomically in the same
/// mutation. Future wall-hosted engineering objects must block removal before
/// this owned cascade is allowed.
final class RemoveSpaceCommand implements ProjectCommand {
  const RemoveSpaceCommand({required this.spaceId});

  final SpaceId spaceId;

  @override
  String get commandType => 'project.space.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = current.index.space(spaceId);
    if (space == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.spaceNotFound,
        entityId: spaceId,
        message: 'Space $spaceId does not exist.',
      );
    }

    final semanticBlockers = <EntityId>{
      ...?current.index.openingsBySpaceId[space.id],
      ...?current.index.adjacenciesBySpaceId[space.id],
      ...?current.index.overlaysBySpaceId[space.id],
    };
    if (semanticBlockers.isNotEmpty) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.spaceHasSemanticDependencies,
        entityId: space.id,
        relatedEntityId: semanticBlockers.first,
        blockingEntityIds: Set<EntityId>.unmodifiable(semanticBlockers),
        message: 'Space ${space.id} cannot be removed while '
            '${semanticBlockers.length} P6 semantic dependency/dependencies '
            'still reference it.',
      );
    }

    final level = current.index.level(space.levelId)!;
    final structuralZoneId = current.index.structuralZoneBySpace[space.id];
    final boundary = current.index.boundary(space.id);
    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels);
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    );
    final spaces = Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces)
      ..remove(space.id);
    final boundaries = Map<SpaceId, SpaceBoundaryTopology>.from(
      current.stores.boundaries,
    )..remove(space.id);

    levels[level.id] = ProjectLevelEntity(
      id: level.id,
      buildingId: level.buildingId,
      name: level.name,
      levelNumber: level.levelNumber,
      displayOrder: level.displayOrder,
      elevationMm: level.elevationMm,
      zoneIds: level.zoneIds,
      spaceIds: <SpaceId>{...level.spaceIds}..remove(space.id),
    );

    if (structuralZoneId != null) {
      final zone = current.index.zone(structuralZoneId)!;
      zones[zone.id] = ProjectStructuralZoneEntity(
        id: zone.id,
        levelId: zone.levelId,
        name: zone.name,
        spaceIds: <SpaceId>{...zone.spaceIds}..remove(space.id),
      );
    }

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: current.stores.sites,
          buildings: current.stores.buildings,
          levels: levels,
          zones: zones,
          spaces: spaces,
          openings: current.stores.openings,
          adjacencies: current.stores.adjacencies,
          overlays: current.stores.overlays,
          boundaries: boundaries,
        ),
      ),
      affectedEntityIds: <EntityId>[
        space.id,
        level.id,
        if (structuralZoneId != null) structuralZoneId,
        ...?boundary?.orderedEdgeIds,
      ],
    );
  }
}

final class RemoveStructuralZoneCommand implements ProjectCommand {
  const RemoveStructuralZoneCommand({required this.zoneId});

  final ZoneId zoneId;

  @override
  String get commandType => 'project.structural-zone.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final zone = current.index.zone(zoneId);
    if (zone == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.structuralZoneNotFound,
        entityId: zoneId,
        message: 'Structural zone $zoneId does not exist.',
      );
    }
    if (zone.spaceIds.isNotEmpty) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.structuralZoneHasSpaces,
        entityId: zone.id,
        relatedEntityId: zone.spaceIds.first,
        blockingEntityIds: Set<EntityId>.unmodifiable(zone.spaceIds),
        message: 'Structural zone ${zone.id} cannot be removed while it '
            'contains ${zone.spaceIds.length} space(s).',
      );
    }

    final level = current.index.level(zone.levelId)!;
    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels);
    final zones = Map<ZoneId, ProjectStructuralZoneEntity>.from(
      current.stores.zones,
    )..remove(zone.id);

    levels[level.id] = ProjectLevelEntity(
      id: level.id,
      buildingId: level.buildingId,
      name: level.name,
      levelNumber: level.levelNumber,
      displayOrder: level.displayOrder,
      elevationMm: level.elevationMm,
      zoneIds: <ZoneId>{...level.zoneIds}..remove(zone.id),
      spaceIds: level.spaceIds,
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: current.stores.buildings,
        levels: levels,
        zones: zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[zone.id, level.id],
    );
  }
}

final class RemoveLevelCommand implements ProjectCommand {
  const RemoveLevelCommand({required this.levelId});

  final LevelId levelId;

  @override
  String get commandType => 'project.level.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = current.index.level(levelId);
    if (level == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.levelNotFound,
        entityId: levelId,
        message: 'Level $levelId does not exist.',
      );
    }
    if (level.zoneIds.isNotEmpty || level.spaceIds.isNotEmpty) {
      final blockingEntityIds = <EntityId>{...level.zoneIds, ...level.spaceIds};
      final dependentId =
          level.zoneIds.isNotEmpty ? level.zoneIds.first : level.spaceIds.first;
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.levelHasChildren,
        entityId: level.id,
        relatedEntityId: dependentId,
        blockingEntityIds: Set<EntityId>.unmodifiable(blockingEntityIds),
        message: 'Level ${level.id} cannot be removed while it contains '
            '${level.zoneIds.length} structural zone(s) and '
            '${level.spaceIds.length} space(s).',
      );
    }

    final building = current.index.building(level.buildingId)!;
    final buildings = Map<BuildingId, ProjectBuildingEntity>.from(
      current.stores.buildings,
    );
    final levels = Map<LevelId, ProjectLevelEntity>.from(current.stores.levels)
      ..remove(level.id);

    buildings[building.id] = ProjectBuildingEntity(
      id: building.id,
      siteId: building.siteId,
      name: building.name,
      displayOrder: building.displayOrder,
      levelIds: <LevelId>{...building.levelIds}..remove(level.id),
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: buildings,
        levels: levels,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[level.id, building.id],
    );
  }
}

final class RemoveBuildingCommand implements ProjectCommand {
  const RemoveBuildingCommand({required this.buildingId});

  final BuildingId buildingId;

  @override
  String get commandType => 'project.building.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final building = current.index.building(buildingId);
    if (building == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.buildingNotFound,
        entityId: buildingId,
        message: 'Building $buildingId does not exist.',
      );
    }
    if (building.levelIds.isNotEmpty) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.buildingHasLevels,
        entityId: building.id,
        relatedEntityId: building.levelIds.first,
        blockingEntityIds: Set<EntityId>.unmodifiable(building.levelIds),
        message: 'Building ${building.id} cannot be removed while it '
            'contains ${building.levelIds.length} level(s).',
      );
    }

    final site = current.index.site(building.siteId)!;
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites);
    final buildings = Map<BuildingId, ProjectBuildingEntity>.from(
      current.stores.buildings,
    )..remove(building.id);

    sites[site.id] = ProjectSiteEntity(
      id: site.id,
      name: site.name,
      buildingIds: <BuildingId>{...site.buildingIds}..remove(building.id),
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: sites,
        buildings: buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[building.id, site.id],
    );
  }
}
