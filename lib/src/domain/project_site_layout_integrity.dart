import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'project_site_layout.dart';
import 'rectilinear_polygon_relations.dart';

abstract final class ProjectSiteLayoutIntegrity {
  static void validateOrThrow(
      {required SiteId siteId,
      required ProjectEntityStores stores,
      required ProjectSiteLayout layout}) {
    if (layout.isEmpty) return;
    void require(bool value, String code) {
      if (!value) throw SiteLayoutException('p10.site-layout.$code');
    }

    final ids = layout.placements.keys.toList();
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      final placement = layout.placements[id]!;
      require(stores.buildings[id]?.siteId == siteId, 'foreign-building');
      for (var other = 0; other < index; other++) {
        require(
            !RectilinearPolygonRelations.overlapsInterior(
                placement.siteFootprint,
                layout.placements[ids[other]]!.siteFootprint),
            'overlapping-footprints');
      }
    }
    // One pass over canonical geometry, with the BuildingId ownership index.
    // Unplaced legacy buildings retain their original coordinate interpretation.
    final buildingBySpace = <SpaceId, BuildingId>{
      for (final space in stores.spaces.values)
        space.id: stores.levels[space.levelId]!.buildingId,
    };
    void check(BuildingId id, Iterable<BoundaryPointMm> points) {
      final placement = layout.placements[id];
      if (placement == null) return;
      for (final point in points) {
        require(
            point.xMm >= 0 &&
                point.xMm <= placement.widthMm &&
                point.yMm >= 0 &&
                point.yMm <= placement.depthMm,
            'geometry-outside-local-footprint');
      }
    }

    for (final boundary in stores.boundaries.values) {
      check(buildingBySpace[boundary.spaceId]!,
          boundary.edges.values.map((e) => e.start));
    }
    for (final slab in stores.slabs.values) {
      check(slab.buildingId, slab.footprint);
    }
    for (final core in stores.verticalCores.values) {
      check(core.buildingId, core.footprint);
    }
    for (final entry in layout.sharedAnchors.entries) {
      final anchor = entry.value;
      require(entry.key == anchor.id && anchor.siteId == siteId,
          'invalid-anchor-owner');
      require(
          anchor.servedBuildingIds.every((id) =>
              stores.buildings[id]?.siteId == siteId &&
              layout.placements.containsKey(id)),
          'dangling-served-building');
      for (final placement in layout.placements.values) {
        final footprint = placement.siteFootprint;
        require(
            !(anchor.point.xMm > footprint.minX &&
                anchor.point.xMm < footprint.maxX &&
                anchor.point.yMm > footprint.minY &&
                anchor.point.yMm < footprint.maxY),
            'anchor-inside-building');
      }
    }
  }
}

/// Site view only: editor/navigator contexts keep their canonical BuildingId and
/// LevelId. Local boundaries remain the authority for editing and engineering.
final class ProjectSiteLayoutProjection {
  const ProjectSiteLayoutProjection(this.project);
  final ProjectAggregateRoot project;
  List<BoundaryPointMm> buildingFootprint(BuildingId buildingId) {
    final placement =
        project.engineeringMetadata.siteLayout.placements[buildingId];
    if (placement == null) {
      throw const SiteLayoutException('p10.site-layout.placement-missing');
    }
    return placement.siteFootprint.vertices;
  }

  List<BoundaryPointMm> spaceOutline(SpaceId spaceId) {
    final space = project.stores.spaces[spaceId];
    if (space == null) {
      throw const SiteLayoutException('p10.site-layout.space-missing');
    }
    final buildingId = project.stores.levels[space.levelId]!.buildingId;
    final placement =
        project.engineeringMetadata.siteLayout.placements[buildingId];
    final boundary = project.stores.boundaries[spaceId];
    if (placement == null || boundary == null) {
      throw const SiteLayoutException('p10.site-layout.geometry-missing');
    }
    return List.unmodifiable([
      for (final edge in boundary.orderedEdgeIds)
        placement.toSite(boundary.edges[edge]!.start)
    ]);
  }
}
