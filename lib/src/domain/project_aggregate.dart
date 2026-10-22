import 'project_identity.dart';
import 'project_orientation.dart';
import 'project_space_semantics.dart';

/// Local monotonic version of the canonical in-memory project state.
final class LocalProjectVersion {
  LocalProjectVersion(this.value) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Version must be non-negative.',
      );
    }
  }

  final int value;

  LocalProjectVersion next() => LocalProjectVersion(value + 1);

  @override
  bool operator ==(Object other) =>
      other is LocalProjectVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

final class ProjectSiteEntity {
  ProjectSiteEntity({
    required this.id,
    required this.name,
    required Iterable<BuildingId> buildingIds,
  }) : buildingIds = Set.unmodifiable(buildingIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Site name must be non-empty.');
    }
  }

  final SiteId id;
  final String name;
  final Set<BuildingId> buildingIds;
}

final class ProjectBuildingEntity {
  ProjectBuildingEntity({
    required this.id,
    required this.siteId,
    required this.name,
    required Iterable<LevelId> levelIds,
    this.displayOrder = 0,
  }) : levelIds = Set.unmodifiable(levelIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Building name must be non-empty.',
      );
    }
  }

  final BuildingId id;
  final SiteId siteId;
  final String name;
  final int displayOrder;
  final Set<LevelId> levelIds;
}

final class ProjectLevelEntity {
  ProjectLevelEntity({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.levelNumber,
    required this.elevationMm,
    this.displayOrder = 0,
    Iterable<ZoneId> zoneIds = const [],
    Iterable<SpaceId> spaceIds = const [],
  })  : zoneIds = Set.unmodifiable(zoneIds),
        spaceIds = Set.unmodifiable(spaceIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Level name must be non-empty.');
    }
  }

  final LevelId id;
  final BuildingId buildingId;
  final String name;
  final int levelNumber;
  final int displayOrder;
  final int elevationMm;
  final Set<ZoneId> zoneIds;
  final Set<SpaceId> spaceIds;
}

/// Exclusive structural grouping such as an apartment or common area.
/// Cross-discipline overlays are intentionally represented separately.
final class ProjectStructuralZoneEntity {
  ProjectStructuralZoneEntity({
    required this.id,
    required this.levelId,
    required this.name,
    required Iterable<SpaceId> spaceIds,
  }) : spaceIds = Set.unmodifiable(spaceIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Zone name must be non-empty.');
    }
  }

  final ZoneId id;
  final LevelId levelId;
  final String name;
  final Set<SpaceId> spaceIds;
}

/// Canonical space identity/hierarchy and persisted semantic usage.
final class ProjectSpaceEntity {
  ProjectSpaceEntity({
    required this.id,
    required this.levelId,
    required this.name,
    this.usage = SpaceUsage.unknown,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Space name must be non-empty.');
    }
  }

  final SpaceId id;
  final LevelId levelId;
  final String name;
  final SpaceUsage usage;
}

/// Normalized authoritative entity stores for one canonical consistency boundary.
final class ProjectEntityStores {
  ProjectEntityStores({
    Map<SiteId, ProjectSiteEntity> sites = const {},
    Map<BuildingId, ProjectBuildingEntity> buildings = const {},
    Map<LevelId, ProjectLevelEntity> levels = const {},
    Map<ZoneId, ProjectStructuralZoneEntity> zones = const {},
    Map<SpaceId, ProjectSpaceEntity> spaces = const {},
    Map<OpeningId, ProjectOpeningEntity> openings = const {},
    Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies = const {},
    Map<OverlayClassificationId, ProjectOverlayClassificationEntity> overlays =
        const {},
  })  : sites = Map.unmodifiable(sites),
        buildings = Map.unmodifiable(buildings),
        levels = Map.unmodifiable(levels),
        zones = Map.unmodifiable(zones),
        spaces = Map.unmodifiable(spaces),
        openings = Map.unmodifiable(openings),
        adjacencies = Map.unmodifiable(adjacencies),
        overlays = Map.unmodifiable(overlays);

  final Map<SiteId, ProjectSiteEntity> sites;
  final Map<BuildingId, ProjectBuildingEntity> buildings;
  final Map<LevelId, ProjectLevelEntity> levels;
  final Map<ZoneId, ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, ProjectSpaceEntity> spaces;
  final Map<OpeningId, ProjectOpeningEntity> openings;
  final Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies;
  final Map<OverlayClassificationId, ProjectOverlayClassificationEntity>
      overlays;
}

enum ProjectAggregateIssueCode {
  missingRootSite,
  unexpectedSite,
  danglingBuilding,
  buildingSiteMismatch,
  siteBuildingBackReferenceMissing,
  danglingLevel,
  levelBuildingMismatch,
  buildingLevelBackReferenceMissing,
  duplicateLevelNumber,
  danglingZone,
  zoneLevelMismatch,
  levelZoneBackReferenceMissing,
  danglingSpace,
  spaceLevelMismatch,
  levelSpaceBackReferenceMissing,
  duplicateStructuralZoneMembership,
  danglingOpeningLevel,
  danglingOpeningSpace,
  openingSpaceLevelMismatch,
  danglingAdjacencySpace,
  adjacencyLevelMismatch,
  duplicateAdjacencyPair,
  danglingAdjacencyOpening,
  adjacencyOpeningSpaceMismatch,
  danglingOverlaySpace,
}

final class ProjectAggregateValidationIssue {
  const ProjectAggregateValidationIssue({
    required this.code,
    required this.message,
    this.entityId,
    this.relatedEntityId,
  });

  final ProjectAggregateIssueCode code;
  final EntityId? entityId;
  final EntityId? relatedEntityId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

final class ProjectAggregateValidationException implements Exception {
  ProjectAggregateValidationException(
    Iterable<ProjectAggregateValidationIssue> issues,
  ) : issues = List.unmodifiable(issues);

  final List<ProjectAggregateValidationIssue> issues;

  @override
  String toString() =>
      'Invalid canonical project aggregate:\n${issues.join('\n')}';
}

/// Validates hierarchy plus P6 semantic/referential invariants.
abstract final class ProjectAggregateValidator {
  static List<ProjectAggregateValidationIssue> validate({
    required SiteId rootSiteId,
    required ProjectEntityStores stores,
  }) {
    final issues = <ProjectAggregateValidationIssue>[];
    final rootSite = stores.sites[rootSiteId];
    if (rootSite == null) {
      issues.add(
        ProjectAggregateValidationIssue(
          code: ProjectAggregateIssueCode.missingRootSite,
          entityId: rootSiteId,
          message: 'Root site $rootSiteId does not exist.',
        ),
      );
    }

    for (final site in stores.sites.values) {
      if (site.id != rootSiteId) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.unexpectedSite,
            entityId: site.id,
            relatedEntityId: rootSiteId,
            message: 'Project contains unexpected site ${site.id}; '
                'exactly one canonical site is currently permitted.',
          ),
        );
      }
      for (final buildingId in site.buildingIds) {
        final building = stores.buildings[buildingId];
        if (building == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingBuilding,
              entityId: site.id,
              relatedEntityId: buildingId,
              message: 'Site ${site.id} references missing building $buildingId.',
            ),
          );
        } else if (building.siteId != site.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.buildingSiteMismatch,
              entityId: building.id,
              relatedEntityId: site.id,
              message: 'Building ${building.id} belongs to ${building.siteId}, '
                  'not site ${site.id}.',
            ),
          );
        }
      }
    }

    for (final building in stores.buildings.values) {
      final site = stores.sites[building.siteId];
      if (site == null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingBuilding,
            entityId: building.id,
            relatedEntityId: building.siteId,
            message: 'Building ${building.id} references missing site '
                '${building.siteId}.',
          ),
        );
      } else if (!site.buildingIds.contains(building.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.siteBuildingBackReferenceMissing,
            entityId: building.id,
            relatedEntityId: site.id,
            message: 'Site ${site.id} does not reference building ${building.id}.',
          ),
        );
      }

      final levelNumbers = <int>{};
      for (final levelId in building.levelIds) {
        final level = stores.levels[levelId];
        if (level == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingLevel,
              entityId: building.id,
              relatedEntityId: levelId,
              message: 'Building ${building.id} references missing level $levelId.',
            ),
          );
          continue;
        }
        if (level.buildingId != building.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.levelBuildingMismatch,
              entityId: level.id,
              relatedEntityId: building.id,
              message: 'Level ${level.id} belongs to ${level.buildingId}, '
                  'not building ${building.id}.',
            ),
          );
        }
        if (!levelNumbers.add(level.levelNumber)) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.duplicateLevelNumber,
              entityId: level.id,
              relatedEntityId: building.id,
              message: 'Building ${building.id} contains duplicate level number '
                  '${level.levelNumber}.',
            ),
          );
        }
      }
    }

    for (final level in stores.levels.values) {
      final building = stores.buildings[level.buildingId];
      if (building == null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingLevel,
            entityId: level.id,
            relatedEntityId: level.buildingId,
            message: 'Level ${level.id} references missing building '
                '${level.buildingId}.',
          ),
        );
      } else if (!building.levelIds.contains(level.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.buildingLevelBackReferenceMissing,
            entityId: level.id,
            relatedEntityId: building.id,
            message: 'Building ${building.id} does not reference level ${level.id}.',
          ),
        );
      }

      for (final zoneId in level.zoneIds) {
        final zone = stores.zones[zoneId];
        if (zone == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingZone,
              entityId: level.id,
              relatedEntityId: zoneId,
              message: 'Level ${level.id} references missing zone $zoneId.',
            ),
          );
        } else if (zone.levelId != level.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.zoneLevelMismatch,
              entityId: zone.id,
              relatedEntityId: level.id,
              message: 'Zone ${zone.id} belongs to ${zone.levelId}, '
                  'not level ${level.id}.',
            ),
          );
        }
      }

      for (final spaceId in level.spaceIds) {
        final space = stores.spaces[spaceId];
        if (space == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingSpace,
              entityId: level.id,
              relatedEntityId: spaceId,
              message: 'Level ${level.id} references missing space $spaceId.',
            ),
          );
        } else if (space.levelId != level.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.spaceLevelMismatch,
              entityId: space.id,
              relatedEntityId: level.id,
              message: 'Space ${space.id} belongs to ${space.levelId}, '
                  'not level ${level.id}.',
            ),
          );
        }
      }
    }

    for (final zone in stores.zones.values) {
      final level = stores.levels[zone.levelId];
      if (level == null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingZone,
            entityId: zone.id,
            relatedEntityId: zone.levelId,
            message: 'Zone ${zone.id} references missing level ${zone.levelId}.',
          ),
        );
        continue;
      }
      if (!level.zoneIds.contains(zone.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.levelZoneBackReferenceMissing,
            entityId: zone.id,
            relatedEntityId: level.id,
            message: 'Level ${level.id} does not reference zone ${zone.id}.',
          ),
        );
      }
      for (final spaceId in zone.spaceIds) {
        final space = stores.spaces[spaceId];
        if (space == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingSpace,
              entityId: zone.id,
              relatedEntityId: spaceId,
              message: 'Zone ${zone.id} references missing space $spaceId.',
            ),
          );
        } else if (space.levelId != zone.levelId) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.spaceLevelMismatch,
              entityId: space.id,
              relatedEntityId: zone.id,
              message: 'Zone ${zone.id} references space ${space.id} from '
                  'level ${space.levelId}.',
            ),
          );
        }
      }
    }

    for (final space in stores.spaces.values) {
      final level = stores.levels[space.levelId];
      if (level == null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingSpace,
            entityId: space.id,
            relatedEntityId: space.levelId,
            message: 'Space ${space.id} references missing level ${space.levelId}.',
          ),
        );
      } else if (!level.spaceIds.contains(space.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.levelSpaceBackReferenceMissing,
            entityId: space.id,
            relatedEntityId: level.id,
            message: 'Level ${level.id} does not reference space ${space.id}.',
          ),
        );
      }
    }

    for (final level in stores.levels.values) {
      final claimedSpaces = <SpaceId>{};
      for (final zoneId in level.zoneIds) {
        final zone = stores.zones[zoneId];
        if (zone == null || zone.levelId != level.id) {
          continue;
        }
        for (final spaceId in zone.spaceIds) {
          if (!claimedSpaces.add(spaceId)) {
            issues.add(
              ProjectAggregateValidationIssue(
                code: ProjectAggregateIssueCode.duplicateStructuralZoneMembership,
                entityId: spaceId,
                relatedEntityId: level.id,
                message: 'Space $spaceId belongs to more than one structural '
                    'zone on level ${level.id}.',
              ),
            );
          }
        }
      }
    }

    _validateOpenings(stores, issues);
    _validateAdjacencies(stores, issues);
    _validateOverlays(stores, issues);
    return List.unmodifiable(issues);
  }

  static void _validateOpenings(
    ProjectEntityStores stores,
    List<ProjectAggregateValidationIssue> issues,
  ) {
    for (final opening in stores.openings.values) {
      if (!stores.levels.containsKey(opening.levelId)) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingOpeningLevel,
            entityId: opening.id,
            relatedEntityId: opening.levelId,
            message: 'Opening ${opening.id} references missing level '
                '${opening.levelId}.',
          ),
        );
      }
      for (final spaceId in opening.connectedSpaceIds) {
        final space = stores.spaces[spaceId];
        if (space == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingOpeningSpace,
              entityId: opening.id,
              relatedEntityId: spaceId,
              message: 'Opening ${opening.id} references missing space $spaceId.',
            ),
          );
        } else if (space.levelId != opening.levelId) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.openingSpaceLevelMismatch,
              entityId: opening.id,
              relatedEntityId: space.id,
              message: 'Opening ${opening.id} is on ${opening.levelId} but '
                  'space ${space.id} is on ${space.levelId}.',
            ),
          );
        }
      }
    }
  }

  static void _validateAdjacencies(
    ProjectEntityStores stores,
    List<ProjectAggregateValidationIssue> issues,
  ) {
    final pairs = <String, SpaceAdjacencyId>{};
    for (final adjacency in stores.adjacencies.values) {
      final a = stores.spaces[adjacency.spaceAId];
      final b = stores.spaces[adjacency.spaceBId];
      if (a == null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingAdjacencySpace,
            entityId: adjacency.id,
            relatedEntityId: adjacency.spaceAId,
            message: 'Adjacency ${adjacency.id} references missing space '
                '${adjacency.spaceAId}.',
          ),
        );
      }
      if (b == null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.danglingAdjacencySpace,
            entityId: adjacency.id,
            relatedEntityId: adjacency.spaceBId,
            message: 'Adjacency ${adjacency.id} references missing space '
                '${adjacency.spaceBId}.',
          ),
        );
      }
      if (a != null && b != null && a.levelId != b.levelId) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.adjacencyLevelMismatch,
            entityId: adjacency.id,
            relatedEntityId: b.id,
            message: 'Adjacency ${adjacency.id} spans levels ${a.levelId} and '
                '${b.levelId}; P6 adjacency is level-local.',
          ),
        );
      }

      final ids = <String>[adjacency.spaceAId.value, adjacency.spaceBId.value]
        ..sort();
      final key = '${ids[0]}\u0000${ids[1]}';
      final previous = pairs[key];
      if (previous != null) {
        issues.add(
          ProjectAggregateValidationIssue(
            code: ProjectAggregateIssueCode.duplicateAdjacencyPair,
            entityId: adjacency.id,
            relatedEntityId: previous,
            message: 'Adjacency pair ${adjacency.spaceAId}/'
                '${adjacency.spaceBId} already exists as $previous.',
          ),
        );
      } else {
        pairs[key] = adjacency.id;
      }

      if (adjacency.openingId != null) {
        final opening = stores.openings[adjacency.openingId!];
        if (opening == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingAdjacencyOpening,
              entityId: adjacency.id,
              relatedEntityId: adjacency.openingId,
              message: 'Adjacency ${adjacency.id} references missing opening '
                  '${adjacency.openingId}.',
            ),
          );
        } else if (opening.connectedSpaceIds.length != 2 ||
            !opening.connectedSpaceIds.contains(adjacency.spaceAId) ||
            !opening.connectedSpaceIds.contains(adjacency.spaceBId)) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.adjacencyOpeningSpaceMismatch,
              entityId: adjacency.id,
              relatedEntityId: opening.id,
              message: 'Opening ${opening.id} does not connect exactly the '
                  'spaces of adjacency ${adjacency.id}.',
            ),
          );
        }
      }
    }
  }

  static void _validateOverlays(
    ProjectEntityStores stores,
    List<ProjectAggregateValidationIssue> issues,
  ) {
    for (final overlay in stores.overlays.values) {
      for (final spaceId in overlay.spaceIds) {
        if (!stores.spaces.containsKey(spaceId)) {
          issues.add(
            ProjectAggregateValidationIssue(
              code: ProjectAggregateIssueCode.danglingOverlaySpace,
              entityId: overlay.id,
              relatedEntityId: spaceId,
              message: 'Overlay ${overlay.id} references missing space $spaceId.',
            ),
          );
        }
      }
    }
  }
}

/// Read-optimized identity/relationship index built from one validated graph.
final class ProjectIndex {
  ProjectIndex._({
    required this.sites,
    required this.buildings,
    required this.levels,
    required this.zones,
    required this.spaces,
    required this.openings,
    required this.adjacencies,
    required this.overlays,
    required this.siteByBuilding,
    required this.buildingByLevel,
    required this.levelByZone,
    required this.levelBySpace,
    required this.structuralZoneBySpace,
    required this.openingsBySpaceId,
    required this.adjacenciesBySpaceId,
    required this.overlaysBySpaceId,
  });

  factory ProjectIndex.build(ProjectEntityStores stores) {
    final structuralZoneBySpace = <SpaceId, ZoneId>{};
    final openingsBySpaceId = <SpaceId, Set<OpeningId>>{};
    final adjacenciesBySpaceId = <SpaceId, Set<SpaceAdjacencyId>>{};
    final overlaysBySpaceId = <SpaceId, Set<OverlayClassificationId>>{};

    for (final zone in stores.zones.values) {
      for (final spaceId in zone.spaceIds) {
        structuralZoneBySpace[spaceId] = zone.id;
      }
    }
    for (final opening in stores.openings.values) {
      for (final spaceId in opening.connectedSpaceIds) {
        (openingsBySpaceId[spaceId] ??= <OpeningId>{}).add(opening.id);
      }
    }
    for (final adjacency in stores.adjacencies.values) {
      for (final spaceId in adjacency.spaceIds) {
        (adjacenciesBySpaceId[spaceId] ??= <SpaceAdjacencyId>{})
            .add(adjacency.id);
      }
    }
    for (final overlay in stores.overlays.values) {
      for (final spaceId in overlay.spaceIds) {
        (overlaysBySpaceId[spaceId] ??= <OverlayClassificationId>{})
            .add(overlay.id);
      }
    }

    return ProjectIndex._(
      sites: stores.sites,
      buildings: stores.buildings,
      levels: stores.levels,
      zones: stores.zones,
      spaces: stores.spaces,
      openings: stores.openings,
      adjacencies: stores.adjacencies,
      overlays: stores.overlays,
      siteByBuilding: Map.unmodifiable({
        for (final building in stores.buildings.values)
          building.id: building.siteId,
      }),
      buildingByLevel: Map.unmodifiable({
        for (final level in stores.levels.values) level.id: level.buildingId,
      }),
      levelByZone: Map.unmodifiable({
        for (final zone in stores.zones.values) zone.id: zone.levelId,
      }),
      levelBySpace: Map.unmodifiable({
        for (final space in stores.spaces.values) space.id: space.levelId,
      }),
      structuralZoneBySpace: Map.unmodifiable(structuralZoneBySpace),
      openingsBySpaceId: _freezeSetMap(openingsBySpaceId),
      adjacenciesBySpaceId: _freezeSetMap(adjacenciesBySpaceId),
      overlaysBySpaceId: _freezeSetMap(overlaysBySpaceId),
    );
  }

  final Map<SiteId, ProjectSiteEntity> sites;
  final Map<BuildingId, ProjectBuildingEntity> buildings;
  final Map<LevelId, ProjectLevelEntity> levels;
  final Map<ZoneId, ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, ProjectSpaceEntity> spaces;
  final Map<OpeningId, ProjectOpeningEntity> openings;
  final Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies;
  final Map<OverlayClassificationId, ProjectOverlayClassificationEntity> overlays;
  final Map<BuildingId, SiteId> siteByBuilding;
  final Map<LevelId, BuildingId> buildingByLevel;
  final Map<ZoneId, LevelId> levelByZone;
  final Map<SpaceId, LevelId> levelBySpace;
  final Map<SpaceId, ZoneId> structuralZoneBySpace;
  final Map<SpaceId, Set<OpeningId>> openingsBySpaceId;
  final Map<SpaceId, Set<SpaceAdjacencyId>> adjacenciesBySpaceId;
  final Map<SpaceId, Set<OverlayClassificationId>> overlaysBySpaceId;

  ProjectSiteEntity? site(SiteId id) => sites[id];
  ProjectBuildingEntity? building(BuildingId id) => buildings[id];
  ProjectLevelEntity? level(LevelId id) => levels[id];
  ProjectStructuralZoneEntity? zone(ZoneId id) => zones[id];
  ProjectSpaceEntity? space(SpaceId id) => spaces[id];
  ProjectOpeningEntity? opening(OpeningId id) => openings[id];
  ProjectSpaceAdjacencyEntity? adjacency(SpaceAdjacencyId id) => adjacencies[id];
  ProjectOverlayClassificationEntity? overlay(OverlayClassificationId id) =>
      overlays[id];

  bool isConsistentWith(ProjectEntityStores stores) {
    if (sites.length != stores.sites.length ||
        buildings.length != stores.buildings.length ||
        levels.length != stores.levels.length ||
        zones.length != stores.zones.length ||
        spaces.length != stores.spaces.length ||
        openings.length != stores.openings.length ||
        adjacencies.length != stores.adjacencies.length ||
        overlays.length != stores.overlays.length) {
      return false;
    }
    for (final building in stores.buildings.values) {
      if (siteByBuilding[building.id] != building.siteId) return false;
    }
    for (final level in stores.levels.values) {
      if (buildingByLevel[level.id] != level.buildingId) return false;
    }
    for (final zone in stores.zones.values) {
      if (levelByZone[zone.id] != zone.levelId) return false;
      for (final spaceId in zone.spaceIds) {
        if (structuralZoneBySpace[spaceId] != zone.id) return false;
      }
    }
    for (final space in stores.spaces.values) {
      if (levelBySpace[space.id] != space.levelId) return false;
    }
    for (final opening in stores.openings.values) {
      for (final spaceId in opening.connectedSpaceIds) {
        if (!(openingsBySpaceId[spaceId]?.contains(opening.id) ?? false)) {
          return false;
        }
      }
    }
    for (final adjacency in stores.adjacencies.values) {
      for (final spaceId in adjacency.spaceIds) {
        if (!(adjacenciesBySpaceId[spaceId]?.contains(adjacency.id) ?? false)) {
          return false;
        }
      }
    }
    for (final overlay in stores.overlays.values) {
      for (final spaceId in overlay.spaceIds) {
        if (!(overlaysBySpaceId[spaceId]?.contains(overlay.id) ?? false)) {
          return false;
        }
      }
    }
    return true;
  }
}

Map<K, Set<V>> _freezeSetMap<K, V>(Map<K, Set<V>> source) => Map.unmodifiable({
      for (final entry in source.entries)
        entry.key: Set<V>.unmodifiable(entry.value),
    });

final class ProjectAggregateRoot {
  ProjectAggregateRoot._({
    required this.id,
    required this.siteId,
    required this.version,
    required this.engineeringMetadata,
    required this.stores,
    required this.index,
  });

  factory ProjectAggregateRoot({
    required ProjectId id,
    required SiteId siteId,
    required LocalProjectVersion version,
    ProjectEngineeringMetadata engineeringMetadata =
        const ProjectEngineeringMetadata(),
    required ProjectEntityStores stores,
  }) {
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: siteId,
      stores: stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectAggregateValidationException(issues);
    }
    final index = ProjectIndex.build(stores);
    assert(index.isConsistentWith(stores));
    return ProjectAggregateRoot._(
      id: id,
      siteId: siteId,
      version: version,
      engineeringMetadata: engineeringMetadata,
      stores: stores,
      index: index,
    );
  }

  final ProjectId id;
  final SiteId siteId;
  final LocalProjectVersion version;
  final ProjectEngineeringMetadata engineeringMetadata;
  final ProjectEntityStores stores;
  final ProjectIndex index;
}
