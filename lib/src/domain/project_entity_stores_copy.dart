import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'project_space_semantics.dart';
import 'slab_topology.dart';
import 'vertical_core.dart';

/// Lossless reconstruction contract for canonical normalized stores.
///
/// Every project mutation must use this helper instead of constructing a fresh
/// [ProjectEntityStores] with only the stores it currently knows about. That
/// pattern silently drops newly introduced stores such as `slabs` or
/// `verticalCores`.
extension ProjectEntityStoresCopy on ProjectEntityStores {
  ProjectEntityStores copyWith({
    Map<SiteId, ProjectSiteEntity>? sites,
    Map<BuildingId, ProjectBuildingEntity>? buildings,
    Map<LevelId, ProjectLevelEntity>? levels,
    Map<SlabId, ProjectSlab>? slabs,
    Map<VerticalCoreId, ProjectVerticalCore>? verticalCores,
    Map<ZoneId, ProjectStructuralZoneEntity>? zones,
    Map<SpaceId, ProjectSpaceEntity>? spaces,
    Map<OpeningId, ProjectOpeningEntity>? openings,
    Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>? adjacencies,
    Map<OverlayClassificationId, ProjectOverlayClassificationEntity>? overlays,
    Map<SpaceId, SpaceBoundaryTopology>? boundaries,
  }) =>
      ProjectEntityStores(
        sites: sites ?? this.sites,
        buildings: buildings ?? this.buildings,
        levels: levels ?? this.levels,
        slabs: slabs ?? this.slabs,
        verticalCores: verticalCores ?? this.verticalCores,
        zones: zones ?? this.zones,
        spaces: spaces ?? this.spaces,
        openings: openings ?? this.openings,
        adjacencies: adjacencies ?? this.adjacencies,
        overlays: overlays ?? this.overlays,
        boundaries: boundaries ?? this.boundaries,
      );
}
