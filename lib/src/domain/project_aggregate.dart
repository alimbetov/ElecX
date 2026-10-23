import 'boundary_topology.dart';
import 'project_aggregate_legacy.dart' as legacy;
import 'project_identity.dart';
import 'project_orientation.dart';
import 'project_space_semantics.dart';
import 'slab_topology.dart';
import 'vertical_core.dart';
import 'vertical_core_project_validation.dart';

export 'project_aggregate_legacy.dart'
    hide
        ProjectAggregateIssueCode,
        ProjectAggregateRoot,
        ProjectAggregateValidationException,
        ProjectAggregateValidationIssue,
        ProjectAggregateValidator,
        ProjectEntityStores,
        ProjectIndex,
        ProjectLevelEntity,
        ProjectStructuralZoneEntity,
        ProjectSpaceEntity;

/// Canonical structural role of one building level.
///
/// `unknown` is intentionally available for deterministic migration of legacy
/// projects where no safe level role can be inferred. New authoring should
/// always provide an explicit non-unknown value once the user has classified
/// the level.
enum ProjectLevelKind {
  unknown,
  basement,
  ground,
  residential,
  technical,
  roof,
}

/// Canonical exclusive structural-zone role.
///
/// Engineering overlays such as fire compartments, ACS/security and electrical
/// distribution zones remain separate many-to-many classifications.
enum ProjectStructuralZoneKind {
  unknown,
  apartment,
  common,
  technical,
  parking,
  storage,
  utility,
  commercial,
  office,
  service,
}

/// Canonical structural type of one Space, distinct from semantic SpaceUsage.
///
/// `unknown` is migration-safe and prevents old projects from being silently
/// reclassified as ordinary rooms when the legacy document did not persist the
/// structural type.
enum ProjectSpaceType {
  unknown,
  room,
  corridor,
  hall,
  technicalRoom,
  stair,
  shaft,
  outdoorArea,
}

/// Canonical Level identity and structural attributes.
final class ProjectLevelEntity {
  ProjectLevelEntity({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.levelNumber,
    required this.elevationMm,
    this.kind = ProjectLevelKind.unknown,
    this.floorToFloorHeightMm = 3000,
    this.displayOrder = 0,
    Iterable<ZoneId> zoneIds = const [],
    Iterable<SpaceId> spaceIds = const [],
  })  : zoneIds = Set.unmodifiable(zoneIds),
        spaceIds = Set.unmodifiable(spaceIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Level name must be non-empty.');
    }
    if (levelNumber < -30 || levelNumber > 200) {
      throw RangeError.range(levelNumber, -30, 200, 'levelNumber');
    }
    if (floorToFloorHeightMm <= 0) {
      throw ArgumentError.value(
        floorToFloorHeightMm,
        'floorToFloorHeightMm',
        'Floor-to-floor height must be positive.',
      );
    }
  }

  final LevelId id;
  final BuildingId buildingId;
  final String name;
  final int levelNumber;
  final ProjectLevelKind kind;
  final int floorToFloorHeightMm;
  final int displayOrder;
  final int elevationMm;
  final Set<ZoneId> zoneIds;
  final Set<SpaceId> spaceIds;
}

/// Exclusive structural grouping such as an apartment or common area.
final class ProjectStructuralZoneEntity {
  ProjectStructuralZoneEntity({
    required this.id,
    required this.levelId,
    required this.name,
    required Iterable<SpaceId> spaceIds,
    this.kind = ProjectStructuralZoneKind.unknown,
  }) : spaceIds = Set.unmodifiable(spaceIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Zone name must be non-empty.');
    }
  }

  final ZoneId id;
  final LevelId levelId;
  final String name;
  final ProjectStructuralZoneKind kind;
  final Set<SpaceId> spaceIds;
}

/// Canonical Space identity/hierarchy plus structural type and semantic usage.
final class ProjectSpaceEntity {
  ProjectSpaceEntity({
    required this.id,
    required this.levelId,
    required this.name,
    this.type = ProjectSpaceType.unknown,
    this.usage = SpaceUsage.unknown,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Space name must be non-empty.');
    }
  }

  final SpaceId id;
  final LevelId levelId;
  final String name;
  final ProjectSpaceType type;
  final SpaceUsage usage;
}

/// Canonical normalized stores extended with P7B vertical physical topology
/// and P4 structural semantics.
///
/// Pre-P7B hierarchy validation is retained through a lossless compatibility
/// projection in [_toLegacyStores]. New semantics stay owned by these canonical
/// entities and are never written back into the frozen legacy model.
final class ProjectEntityStores {
  ProjectEntityStores({
    Map<SiteId, legacy.ProjectSiteEntity> sites = const {},
    Map<BuildingId, legacy.ProjectBuildingEntity> buildings = const {},
    Map<LevelId, ProjectLevelEntity> levels = const {},
    Map<SlabId, ProjectSlab> slabs = const {},
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores = const {},
    Map<ZoneId, ProjectStructuralZoneEntity> zones = const {},
    Map<SpaceId, ProjectSpaceEntity> spaces = const {},
    Map<OpeningId, ProjectOpeningEntity> openings = const {},
    Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies = const {},
    Map<OverlayClassificationId, ProjectOverlayClassificationEntity> overlays =
        const {},
    Map<SpaceId, SpaceBoundaryTopology> boundaries = const {},
  })  : sites = Map.unmodifiable(sites),
        buildings = Map.unmodifiable(buildings),
        levels = Map.unmodifiable(levels),
        slabs = Map.unmodifiable(slabs),
        verticalCores = Map.unmodifiable(verticalCores),
        zones = Map.unmodifiable(zones),
        spaces = Map.unmodifiable(spaces),
        openings = Map.unmodifiable(openings),
        adjacencies = Map.unmodifiable(adjacencies),
        overlays = Map.unmodifiable(overlays),
        boundaries = Map.unmodifiable(boundaries);

  final Map<SiteId, legacy.ProjectSiteEntity> sites;
  final Map<BuildingId, legacy.ProjectBuildingEntity> buildings;
  final Map<LevelId, ProjectLevelEntity> levels;
  final Map<SlabId, ProjectSlab> slabs;
  final Map<VerticalCoreId, ProjectVerticalCore> verticalCores;
  final Map<ZoneId, ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, ProjectSpaceEntity> spaces;
  final Map<OpeningId, ProjectOpeningEntity> openings;
  final Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies;
  final Map<OverlayClassificationId, ProjectOverlayClassificationEntity>
      overlays;
  final Map<SpaceId, SpaceBoundaryTopology> boundaries;
}

enum ProjectAggregateIssueCode {
  storeKeyIdMismatch,
  missingRootSite,
  unexpectedSite,
  danglingBuilding,
  buildingSiteMismatch,
  siteBuildingBackReferenceMissing,
  danglingLevel,
  levelBuildingMismatch,
  buildingLevelBackReferenceMissing,
  duplicateLevelNumber,
  danglingSlabBuilding,
  danglingSlabLevel,
  slabLevelBuildingMismatch,
  slabLevelOrderMismatch,
  invalidSlabTopology,
  invalidVerticalCoreTopology,
  danglingVerticalCoreBuilding,
  danglingVerticalCoreLevel,
  verticalCoreLevelBuildingMismatch,
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
  verticalAdjacencyLevelMismatch,
  verticalAdjacencyBuildingMismatch,
  duplicateAdjacencyPair,
  danglingAdjacencyOpening,
  adjacencyOpeningSpaceMismatch,
  danglingOverlaySpace,
  danglingBoundarySpace,
  boundarySpaceKeyMismatch,
  invalidBoundaryTopology,
  duplicateBoundaryEdgeIdentity,
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

/// P7B-compatible aggregate validator.
///
/// Existing hierarchy, slab and P7A boundary validation is delegated to the
/// frozen pre-P7B validator. VerticalCore topology and project ownership are
/// then validated additively.
abstract final class ProjectAggregateValidator {
  static List<ProjectAggregateValidationIssue> validate({
    required SiteId rootSiteId,
    required ProjectEntityStores stores,
  }) {
    final issues = <ProjectAggregateValidationIssue>[];
    for (final issue in legacy.ProjectAggregateValidator.validate(
      rootSiteId: rootSiteId,
      stores: _toLegacyStores(stores),
    )) {
      // The frozen pre-P7B validator historically framed an unordered Space
      // pair as a single string separated by NUL. EntityId intentionally accepts
      // arbitrary non-empty legacy identifiers, including separator characters,
      // so two distinct pairs can collide in that representation. P6 canonical
      // entities already normalize endpoints; only retain a duplicate issue when
      // the referenced adjacency entities really own the same typed pair.
      if (issue.code == legacy.ProjectAggregateIssueCode.duplicateAdjacencyPair &&
          !_isActualDuplicateAdjacencyPair(issue, stores.adjacencies)) {
        continue;
      }
      issues.add(
        ProjectAggregateValidationIssue(
          code: _legacyIssueCode(issue.code),
          entityId: issue.entityId,
          relatedEntityId: issue.relatedEntityId,
          message: issue.message,
        ),
      );
    }

    for (final issue
        in VerticalCoreTopologyValidator.validate(stores.verticalCores)) {
      issues.add(
        ProjectAggregateValidationIssue(
          code: switch (issue.code) {
            VerticalCoreTopologyIssueCode.storeKeyIdMismatch =>
              ProjectAggregateIssueCode.storeKeyIdMismatch,
            VerticalCoreTopologyIssueCode.duplicateCoreIdentity =>
              ProjectAggregateIssueCode.invalidVerticalCoreTopology,
          },
          entityId: issue.verticalCoreId,
          message: issue.message,
        ),
      );
    }

    for (final issue in VerticalCoreProjectValidator.validate(
      verticalCores: stores.verticalCores,
      buildingExists: stores.buildings.containsKey,
      levelBuildingResolver: (levelId) => stores.levels[levelId]?.buildingId,
    )) {
      issues.add(
        ProjectAggregateValidationIssue(
          code: switch (issue.code) {
            VerticalCoreProjectIssueCode.danglingBuilding =>
              ProjectAggregateIssueCode.danglingVerticalCoreBuilding,
            VerticalCoreProjectIssueCode.danglingLevel =>
              ProjectAggregateIssueCode.danglingVerticalCoreLevel,
            VerticalCoreProjectIssueCode.levelBuildingMismatch =>
              ProjectAggregateIssueCode.verticalCoreLevelBuildingMismatch,
          },
          entityId: issue.verticalCoreId,
          relatedEntityId: issue.relatedEntityId,
          message: issue.message,
        ),
      );
    }

    return List.unmodifiable(issues);
  }
}

bool _isActualDuplicateAdjacencyPair(
  legacy.ProjectAggregateValidationIssue issue,
  Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies,
) {
  final currentId = issue.entityId;
  final previousId = issue.relatedEntityId;
  if (currentId is! SpaceAdjacencyId || previousId is! SpaceAdjacencyId) {
    return true;
  }
  final current = adjacencies[currentId];
  final previous = adjacencies[previousId];
  if (current == null || previous == null) return true;
  return current.spaceAId == previous.spaceAId &&
      current.spaceBId == previous.spaceBId;
}

ProjectAggregateIssueCode _legacyIssueCode(
  legacy.ProjectAggregateIssueCode code,
) =>
    ProjectAggregateIssueCode.values.firstWhere(
      (candidate) => candidate.name == code.name,
    );

legacy.ProjectEntityStores _toLegacyStores(ProjectEntityStores stores) =>
    legacy.ProjectEntityStores(
      sites: stores.sites,
      buildings: stores.buildings,
      levels: <LevelId, legacy.ProjectLevelEntity>{
        for (final entry in stores.levels.entries)
          entry.key: legacy.ProjectLevelEntity(
            id: entry.value.id,
            buildingId: entry.value.buildingId,
            name: entry.value.name,
            levelNumber: entry.value.levelNumber,
            displayOrder: entry.value.displayOrder,
            elevationMm: entry.value.elevationMm,
            zoneIds: entry.value.zoneIds,
            spaceIds: entry.value.spaceIds,
          ),
      },
      slabs: stores.slabs,
      zones: <ZoneId, legacy.ProjectStructuralZoneEntity>{
        for (final entry in stores.zones.entries)
          entry.key: legacy.ProjectStructuralZoneEntity(
            id: entry.value.id,
            levelId: entry.value.levelId,
            name: entry.value.name,
            spaceIds: entry.value.spaceIds,
          ),
      },
      spaces: <SpaceId, legacy.ProjectSpaceEntity>{
        for (final entry in stores.spaces.entries)
          entry.key: legacy.ProjectSpaceEntity(
            id: entry.value.id,
            levelId: entry.value.levelId,
            name: entry.value.name,
            usage: entry.value.usage,
          ),
      },
      openings: stores.openings,
      adjacencies: stores.adjacencies,
      overlays: stores.overlays,
      boundaries: stores.boundaries,
    );

/// Read-optimized canonical index extended with VerticalCore reverse indexes.
final class ProjectIndex {
  ProjectIndex._({
    required legacy.ProjectIndex legacyIndex,
    required this.levels,
    required this.zones,
    required this.spaces,
    required this.verticalCores,
    required this.verticalCoresByBuildingId,
    required this.verticalCoresByLevelId,
  }) : _legacy = legacyIndex;

  factory ProjectIndex.build(ProjectEntityStores stores) {
    final verticalCoresByBuildingId = <BuildingId, Set<VerticalCoreId>>{};
    final verticalCoresByLevelId = <LevelId, Set<VerticalCoreId>>{};

    for (final core in stores.verticalCores.values) {
      (verticalCoresByBuildingId[core.buildingId] ??= <VerticalCoreId>{})
          .add(core.id);
      for (final levelId in core.levelIds) {
        (verticalCoresByLevelId[levelId] ??= <VerticalCoreId>{}).add(core.id);
      }
    }

    return ProjectIndex._(
      legacyIndex: legacy.ProjectIndex.build(_toLegacyStores(stores)),
      levels: stores.levels,
      zones: stores.zones,
      spaces: stores.spaces,
      verticalCores: stores.verticalCores,
      verticalCoresByBuildingId: _freezeSetMap(verticalCoresByBuildingId),
      verticalCoresByLevelId: _freezeSetMap(verticalCoresByLevelId),
    );
  }

  final legacy.ProjectIndex _legacy;
  final Map<LevelId, ProjectLevelEntity> levels;
  final Map<ZoneId, ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, ProjectSpaceEntity> spaces;
  final Map<VerticalCoreId, ProjectVerticalCore> verticalCores;
  final Map<BuildingId, Set<VerticalCoreId>> verticalCoresByBuildingId;
  final Map<LevelId, Set<VerticalCoreId>> verticalCoresByLevelId;

  Map<SiteId, legacy.ProjectSiteEntity> get sites => _legacy.sites;
  Map<BuildingId, legacy.ProjectBuildingEntity> get buildings =>
      _legacy.buildings;
  Map<SlabId, ProjectSlab> get slabs => _legacy.slabs;
  Map<OpeningId, ProjectOpeningEntity> get openings => _legacy.openings;
  Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> get adjacencies =>
      _legacy.adjacencies;
  Map<OverlayClassificationId, ProjectOverlayClassificationEntity>
      get overlays => _legacy.overlays;
  Map<SpaceId, SpaceBoundaryTopology> get boundaries => _legacy.boundaries;
  Map<BoundaryEdgeId, ProjectBoundaryEdge> get boundaryEdges =>
      _legacy.boundaryEdges;
  Map<BuildingId, SiteId> get siteByBuilding => _legacy.siteByBuilding;
  Map<LevelId, BuildingId> get buildingByLevel => _legacy.buildingByLevel;
  Map<ZoneId, LevelId> get levelByZone => _legacy.levelByZone;
  Map<SpaceId, LevelId> get levelBySpace => _legacy.levelBySpace;
  Map<SpaceId, ZoneId> get structuralZoneBySpace =>
      _legacy.structuralZoneBySpace;
  Map<SpaceId, Set<OpeningId>> get openingsBySpaceId =>
      _legacy.openingsBySpaceId;
  Map<SpaceId, Set<SpaceAdjacencyId>> get adjacenciesBySpaceId =>
      _legacy.adjacenciesBySpaceId;
  Map<SpaceId, Set<OverlayClassificationId>> get overlaysBySpaceId =>
      _legacy.overlaysBySpaceId;
  Map<BoundaryEdgeId, SpaceId> get spaceByBoundaryEdgeId =>
      _legacy.spaceByBoundaryEdgeId;
  Map<BuildingId, Set<SlabId>> get slabsByBuildingId =>
      _legacy.slabsByBuildingId;
  Map<LevelId, Set<SlabId>> get slabsByLevelId => _legacy.slabsByLevelId;

  legacy.ProjectSiteEntity? site(SiteId id) => _legacy.site(id);
  legacy.ProjectBuildingEntity? building(BuildingId id) => _legacy.building(id);
  ProjectLevelEntity? level(LevelId id) => levels[id];
  ProjectSlab? slab(SlabId id) => _legacy.slab(id);
  ProjectVerticalCore? verticalCore(VerticalCoreId id) => verticalCores[id];
  ProjectStructuralZoneEntity? zone(ZoneId id) => zones[id];
  ProjectSpaceEntity? space(SpaceId id) => spaces[id];
  ProjectOpeningEntity? opening(OpeningId id) => _legacy.opening(id);
  ProjectSpaceAdjacencyEntity? adjacency(SpaceAdjacencyId id) =>
      _legacy.adjacency(id);
  ProjectOverlayClassificationEntity? overlay(
    OverlayClassificationId id,
  ) =>
      _legacy.overlay(id);
  SpaceBoundaryTopology? boundary(SpaceId id) => _legacy.boundary(id);
  ProjectBoundaryEdge? boundaryEdge(BoundaryEdgeId id) =>
      _legacy.boundaryEdge(id);

  Set<SlabId> slabsForBuilding(BuildingId id) => _legacy.slabsForBuilding(id);

  Set<SlabId> slabsForLevel(LevelId id) => _legacy.slabsForLevel(id);

  Set<VerticalCoreId> verticalCoresForBuilding(BuildingId id) =>
      verticalCoresByBuildingId[id] ?? const <VerticalCoreId>{};

  Set<VerticalCoreId> verticalCoresForLevel(LevelId id) =>
      verticalCoresByLevelId[id] ?? const <VerticalCoreId>{};

  bool isConsistentWith(ProjectEntityStores stores) {
    if (!_legacy.isConsistentWith(_toLegacyStores(stores)) ||
        levels.length != stores.levels.length ||
        zones.length != stores.zones.length ||
        spaces.length != stores.spaces.length ||
        verticalCores.length != stores.verticalCores.length) {
      return false;
    }
    for (final entry in stores.levels.entries) {
      if (!identical(levels[entry.key], entry.value)) return false;
    }
    for (final entry in stores.zones.entries) {
      if (!identical(zones[entry.key], entry.value)) return false;
    }
    for (final entry in stores.spaces.entries) {
      if (!identical(spaces[entry.key], entry.value)) return false;
    }
    for (final core in stores.verticalCores.values) {
      if (!identical(verticalCores[core.id], core)) return false;
      if (!(verticalCoresByBuildingId[core.buildingId]?.contains(core.id) ??
          false)) {
        return false;
      }
      for (final levelId in core.levelIds) {
        if (!(verticalCoresByLevelId[levelId]?.contains(core.id) ?? false)) {
          return false;
        }
      }
    }

    final expectedByBuilding = <BuildingId, Set<VerticalCoreId>>{};
    final expectedByLevel = <LevelId, Set<VerticalCoreId>>{};
    for (final core in stores.verticalCores.values) {
      (expectedByBuilding[core.buildingId] ??= <VerticalCoreId>{}).add(core.id);
      for (final levelId in core.levelIds) {
        (expectedByLevel[levelId] ??= <VerticalCoreId>{}).add(core.id);
      }
    }
    return _setMapEquals(verticalCoresByBuildingId, expectedByBuilding) &&
        _setMapEquals(verticalCoresByLevelId, expectedByLevel);
  }
}

bool _setMapEquals<K, V>(Map<K, Set<V>> left, Map<K, Set<V>> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null || entry.value.length != other.length) return false;
    if (!entry.value.containsAll(other)) return false;
  }
  return true;
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
    required legacy.LocalProjectVersion version,
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
    engineeringMetadata.boundaryHostedObjectRegistry.validateAgainst(
      stores.boundaries,
    );
    engineeringMetadata.boundaryWallProfileRegistry.validateAgainst(
      stores.boundaries,
    );
    engineeringMetadata.boundaryConstructionRegistry.validateAgainst(
      stores.boundaries,
    );
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
  final legacy.LocalProjectVersion version;
  final ProjectEngineeringMetadata engineeringMetadata;
  final ProjectEntityStores stores;
  final ProjectIndex index;
}
