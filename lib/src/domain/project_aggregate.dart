import 'project_identity.dart';

/// Local monotonic version of the canonical in-memory project state.
///
/// This is deliberately separate from any future backend/base revision. Every
/// successful canonical commit increments this value exactly once; failed or
/// cancelled mutations keep the previous value.
final class LocalProjectVersion {
  LocalProjectVersion(this.value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Version must be non-negative.');
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

/// Canonical site metadata. Building state is owned by [ProjectEntityStores],
/// while the site keeps only stable building identities.
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

/// Canonical building metadata. Levels are authoritative entities in the
/// project store and are referenced only by stable [LevelId] values.
final class ProjectBuildingEntity {
  ProjectBuildingEntity({
    required this.id,
    required this.siteId,
    required this.name,
    required Iterable<LevelId> levelIds,
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
  final Set<LevelId> levelIds;
}

/// Canonical level identity and hierarchy metadata.
///
/// [levelNumber] is a display/order attribute. It is never used as the entity
/// identity or as a foreign key.
final class ProjectLevelEntity {
  ProjectLevelEntity({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.levelNumber,
    required this.elevationMm,
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
  final int elevationMm;
  final Set<ZoneId> zoneIds;
  final Set<SpaceId> spaceIds;
}

/// Exclusive structural grouping such as an apartment or common area.
/// Cross-discipline overlays are intentionally not represented by this type.
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

/// Minimal canonical space identity/hierarchy record for the P1 foundation.
/// Geometry and semantic [SpaceUsage] integration are added in later stages.
final class ProjectSpaceEntity {
  ProjectSpaceEntity({
    required this.id,
    required this.levelId,
    required this.name,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Space name must be non-empty.');
    }
  }

  final SpaceId id;
  final LevelId levelId;
  final String name;
}

/// Normalized authoritative entity stores for the canonical project state.
///
/// A single source of truth does not imply one giant nested object. These maps
/// form one consistency boundary while allowing O(1) identity lookup and future
/// incremental persistence/projection work.
final class ProjectEntityStores {
  ProjectEntityStores({
    Map<SiteId, ProjectSiteEntity> sites = const {},
    Map<BuildingId, ProjectBuildingEntity> buildings = const {},
    Map<LevelId, ProjectLevelEntity> levels = const {},
    Map<ZoneId, ProjectStructuralZoneEntity> zones = const {},
    Map<SpaceId, ProjectSpaceEntity> spaces = const {},
  })  : sites = Map.unmodifiable(sites),
        buildings = Map.unmodifiable(buildings),
        levels = Map.unmodifiable(levels),
        zones = Map.unmodifiable(zones),
        spaces = Map.unmodifiable(spaces);

  final Map<SiteId, ProjectSiteEntity> sites;
  final Map<BuildingId, ProjectBuildingEntity> buildings;
  final Map<LevelId, ProjectLevelEntity> levels;
  final Map<ZoneId, ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, ProjectSpaceEntity> spaces;
}

enum ProjectAggregateIssueCode {
  missingRootSite,
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
}

final class ProjectAggregateValidationIssue {
  const ProjectAggregateValidationIssue(this.code, this.message);

  final ProjectAggregateIssueCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

final class ProjectAggregateValidationException implements Exception {
  ProjectAggregateValidationException(this.issues);

  final List<ProjectAggregateValidationIssue> issues;

  @override
  String toString() =>
      'Invalid canonical project aggregate:\n${issues.join('\n')}';
}

/// Validates referential and ownership invariants for the P1 canonical graph.
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
          ProjectAggregateIssueCode.missingRootSite,
          'Root site $rootSiteId does not exist.',
        ),
      );
    }

    for (final site in stores.sites.values) {
      for (final buildingId in site.buildingIds) {
        final building = stores.buildings[buildingId];
        if (building == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.danglingBuilding,
              'Site ${site.id} references missing building $buildingId.',
            ),
          );
          continue;
        }
        if (building.siteId != site.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.buildingSiteMismatch,
              'Building ${building.id} belongs to ${building.siteId}, '
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
            ProjectAggregateIssueCode.danglingBuilding,
            'Building ${building.id} references missing site ${building.siteId}.',
          ),
        );
      } else if (!site.buildingIds.contains(building.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            ProjectAggregateIssueCode.siteBuildingBackReferenceMissing,
            'Site ${site.id} does not reference building ${building.id}.',
          ),
        );
      }

      final levelNumbers = <int>{};
      for (final levelId in building.levelIds) {
        final level = stores.levels[levelId];
        if (level == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.danglingLevel,
              'Building ${building.id} references missing level $levelId.',
            ),
          );
          continue;
        }
        if (level.buildingId != building.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.levelBuildingMismatch,
              'Level ${level.id} belongs to ${level.buildingId}, '
                  'not building ${building.id}.',
            ),
          );
        }
        if (!levelNumbers.add(level.levelNumber)) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.duplicateLevelNumber,
              'Building ${building.id} contains duplicate level number '
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
            ProjectAggregateIssueCode.danglingLevel,
            'Level ${level.id} references missing building ${level.buildingId}.',
          ),
        );
      } else if (!building.levelIds.contains(level.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            ProjectAggregateIssueCode.buildingLevelBackReferenceMissing,
            'Building ${building.id} does not reference level ${level.id}.',
          ),
        );
      }

      for (final zoneId in level.zoneIds) {
        final zone = stores.zones[zoneId];
        if (zone == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.danglingZone,
              'Level ${level.id} references missing zone $zoneId.',
            ),
          );
        } else if (zone.levelId != level.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.zoneLevelMismatch,
              'Zone ${zone.id} belongs to ${zone.levelId}, '
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
              ProjectAggregateIssueCode.danglingSpace,
              'Level ${level.id} references missing space $spaceId.',
            ),
          );
        } else if (space.levelId != level.id) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.spaceLevelMismatch,
              'Space ${space.id} belongs to ${space.levelId}, '
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
            ProjectAggregateIssueCode.danglingZone,
            'Zone ${zone.id} references missing level ${zone.levelId}.',
          ),
        );
        continue;
      }
      if (!level.zoneIds.contains(zone.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            ProjectAggregateIssueCode.levelZoneBackReferenceMissing,
            'Level ${level.id} does not reference zone ${zone.id}.',
          ),
        );
      }
      for (final spaceId in zone.spaceIds) {
        final space = stores.spaces[spaceId];
        if (space == null) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.danglingSpace,
              'Zone ${zone.id} references missing space $spaceId.',
            ),
          );
        } else if (space.levelId != zone.levelId) {
          issues.add(
            ProjectAggregateValidationIssue(
              ProjectAggregateIssueCode.spaceLevelMismatch,
              'Zone ${zone.id} references space ${space.id} from '
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
            ProjectAggregateIssueCode.danglingSpace,
            'Space ${space.id} references missing level ${space.levelId}.',
          ),
        );
      } else if (!level.spaceIds.contains(space.id)) {
        issues.add(
          ProjectAggregateValidationIssue(
            ProjectAggregateIssueCode.levelSpaceBackReferenceMissing,
            'Level ${level.id} does not reference space ${space.id}.',
          ),
        );
      }
    }

    for (final level in stores.levels.values) {
      final claimedSpaces = <SpaceId>{};
      for (final zoneId in level.zoneIds) {
        final zone = stores.zones[zoneId];
        if (zone == null || zone.levelId != level.id) continue;
        for (final spaceId in zone.spaceIds) {
          if (!claimedSpaces.add(spaceId)) {
            issues.add(
              ProjectAggregateValidationIssue(
                ProjectAggregateIssueCode.duplicateStructuralZoneMembership,
                'Space $spaceId belongs to more than one structural zone '
                    'on level ${level.id}.',
              ),
            );
          }
        }
      }
    }

    return List.unmodifiable(issues);
  }
}

/// Read-optimized identity/parent index built from one validated project graph.
final class ProjectIndex {
  ProjectIndex._({
    required this.buildings,
    required this.levels,
    required this.zones,
    required this.spaces,
    required this.siteByBuilding,
    required this.buildingByLevel,
    required this.levelByZone,
    required this.levelBySpace,
  });

  factory ProjectIndex.build(ProjectEntityStores stores) {
    return ProjectIndex._(
      buildings: stores.buildings,
      levels: stores.levels,
      zones: stores.zones,
      spaces: stores.spaces,
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
    );
  }

  final Map<BuildingId, ProjectBuildingEntity> buildings;
  final Map<LevelId, ProjectLevelEntity> levels;
  final Map<ZoneId, ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, ProjectSpaceEntity> spaces;
  final Map<BuildingId, SiteId> siteByBuilding;
  final Map<LevelId, BuildingId> buildingByLevel;
  final Map<ZoneId, LevelId> levelByZone;
  final Map<SpaceId, LevelId> levelBySpace;

  ProjectBuildingEntity? building(BuildingId id) => buildings[id];
  ProjectLevelEntity? level(LevelId id) => levels[id];
  ProjectStructuralZoneEntity? zone(ZoneId id) => zones[id];
  ProjectSpaceEntity? space(SpaceId id) => spaces[id];
}

/// Authoritative canonical project root introduced alongside the legacy editor.
///
/// Legacy workspace classes remain transitional projections/adapters. New
/// structural authoring code must use this aggregate rather than adding another
/// independently mutable building/site graph.
final class ProjectAggregateRoot {
  ProjectAggregateRoot._({
    required this.id,
    required this.siteId,
    required this.version,
    required this.stores,
    required this.index,
  });

  factory ProjectAggregateRoot({
    required ProjectId id,
    required SiteId siteId,
    required LocalProjectVersion version,
    required ProjectEntityStores stores,
  }) {
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: siteId,
      stores: stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectAggregateValidationException(issues);
    }
    return ProjectAggregateRoot._(
      id: id,
      siteId: siteId,
      version: version,
      stores: stores,
      index: ProjectIndex.build(stores),
    );
  }

  final ProjectId id;
  final SiteId siteId;
  final LocalProjectVersion version;
  final ProjectEntityStores stores;
  final ProjectIndex index;
}
