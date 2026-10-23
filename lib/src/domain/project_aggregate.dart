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
        ProjectIndex;

/// Canonical normalized stores extended with P7B vertical physical topology.
///
/// The pre-P7B structural stores remain source-compatible. [verticalCores]
/// owns stable building-scoped riser/shaft identity and must be preserved by
/// every project mutation.
final class ProjectEntityStores {
  ProjectEntityStores({
    Map<SiteId, legacy.ProjectSiteEntity> sites = const {},
    Map<BuildingId, legacy.ProjectBuildingEntity> buildings = const {},
    Map<LevelId, legacy.ProjectLevelEntity> levels = const {},
    Map<SlabId, ProjectSlab> slabs = const {},
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores = const {},
    Map<ZoneId, legacy.ProjectStructuralZoneEntity> zones = const {},
    Map<SpaceId, legacy.ProjectSpaceEntity> spaces = const {},
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
  final Map<LevelId, legacy.ProjectLevelEntity> levels;
  final Map<SlabId, ProjectSlab> slabs;
  final Map<VerticalCoreId, ProjectVerticalCore> verticalCores;
  final Map<ZoneId, legacy.ProjectStructuralZoneEntity> zones;
  final Map<SpaceId, legacy.ProjectSpaceEntity> spaces;
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
    final issues = <ProjectAggregateValidationIssue>[
      for (final issue in legacy.ProjectAggregateValidator.validate(
        rootSiteId: rootSiteId,
        stores: _toLegacyStores(stores),
      ))
        ProjectAggregateValidationIssue(
          code: _legacyIssueCode(issue.code),
          entityId: issue.entityId,
          relatedEntityId: issue.relatedEntityId,
          message: issue.message,
        ),
    ];

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
      levels: stores.levels,
      slabs: stores.slabs,
      zones: stores.zones,
      spaces: stores.spaces,
      openings: stores.openings,
      adjacencies: stores.adjacencies,
      overlays: stores.overlays,
      boundaries: stores.boundaries,
    );

/// Read-optimized canonical index extended with VerticalCore reverse indexes.
final class ProjectIndex {
  ProjectIndex._({
    required legacy.ProjectIndex legacyIndex,
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
      verticalCores: stores.verticalCores,
      verticalCoresByBuildingId: _freezeSetMap(verticalCoresByBuildingId),
      verticalCoresByLevelId: _freezeSetMap(verticalCoresByLevelId),
    );
  }

  final legacy.ProjectIndex _legacy;
  final Map<VerticalCoreId, ProjectVerticalCore> verticalCores;
  final Map<BuildingId, Set<VerticalCoreId>> verticalCoresByBuildingId;
  final Map<LevelId, Set<VerticalCoreId>> verticalCoresByLevelId;

  Map<SiteId, legacy.ProjectSiteEntity> get sites => _legacy.sites;
  Map<BuildingId, legacy.ProjectBuildingEntity> get buildings =>
      _legacy.buildings;
  Map<LevelId, legacy.ProjectLevelEntity> get levels => _legacy.levels;
  Map<SlabId, ProjectSlab> get slabs => _legacy.slabs;
  Map<ZoneId, legacy.ProjectStructuralZoneEntity> get zones => _legacy.zones;
  Map<SpaceId, legacy.ProjectSpaceEntity> get spaces => _legacy.spaces;
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
  legacy.ProjectBuildingEntity? building(BuildingId id) =>
      _legacy.building(id);
  legacy.ProjectLevelEntity? level(LevelId id) => _legacy.level(id);
  ProjectSlab? slab(SlabId id) => _legacy.slab(id);
  ProjectVerticalCore? verticalCore(VerticalCoreId id) => verticalCores[id];
  legacy.ProjectStructuralZoneEntity? zone(ZoneId id) => _legacy.zone(id);
  legacy.ProjectSpaceEntity? space(SpaceId id) => _legacy.space(id);
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

  Set<SlabId> slabsForBuilding(BuildingId id) =>
      _legacy.slabsForBuilding(id);

  Set<SlabId> slabsForLevel(LevelId id) => _legacy.slabsForLevel(id);

  Set<VerticalCoreId> verticalCoresForBuilding(BuildingId id) =>
      verticalCoresByBuildingId[id] ?? const <VerticalCoreId>{};

  Set<VerticalCoreId> verticalCoresForLevel(LevelId id) =>
      verticalCoresByLevelId[id] ?? const <VerticalCoreId>{};

  bool isConsistentWith(ProjectEntityStores stores) {
    if (!_legacy.isConsistentWith(_toLegacyStores(stores)) ||
        verticalCores.length != stores.verticalCores.length) {
      return false;
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
