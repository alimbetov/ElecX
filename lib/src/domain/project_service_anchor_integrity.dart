import 'dart:convert';

import 'apartment_topology/apartment_geometry.dart';
import 'boundary_host_migration.dart';
import 'boundary_host_registry.dart';
import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'project_service_anchor.dart';
import 'rectilinear_polygon_relations.dart';

abstract final class ServiceAnchorRules {
  static void site(ProjectAggregateRoot project, BoundaryPointMm point,
      Set<BuildingId> served) {
    validateServiceAnchorPoint(point);
    for (final id in served) {
      _require(
          project.stores.buildings[id]?.siteId == project.siteId &&
              project.engineeringMetadata.siteLayout.placements.containsKey(id),
          'unresolved-served-building');
    }
    for (final placement
        in project.engineeringMetadata.siteLayout.placements.values) {
      _require(
          !RectilinearPolygonRelations.containsPoint(
              placement.siteFootprint, point,
              includeBoundary: false),
          'site-anchor-inside-building');
    }
  }

  static void owner(ProjectAggregateRoot project, BuildingId buildingId,
      LevelId levelId, SpaceId spaceId, int heightMm) {
    _require(
        project.stores.buildings[buildingId]?.siteId == project.siteId &&
            project.stores.levels[levelId]?.buildingId == buildingId &&
            project.stores.spaces[spaceId]?.levelId == levelId,
        'invalid-host-owner');
    _require(
        heightMm >= 0 &&
            heightMm <= project.stores.levels[levelId]!.floorToFloorHeightMm,
        'height-outside-level');
  }

  static void space(ProjectAggregateRoot project, BuildingId buildingId,
      LevelId levelId, SpaceId spaceId, BoundaryPointMm point, int heightMm) {
    owner(project, buildingId, levelId, spaceId, heightMm);
    validateServiceAnchorPoint(point);
    final topology = project.stores.boundaries[spaceId];
    _require(topology != null, 'host-geometry-missing');
    try {
      final polygon = RectilinearPolygonMm.normalized([
        for (final id in topology!.orderedEdgeIds) topology.edges[id]!.start,
      ], gridMm: 1);
      _require(RectilinearPolygonRelations.containsPoint(polygon, point),
          'point-outside-space');
    } on ArgumentError {
      throw const ServiceAnchorException(
          'p10.service-anchor.unsupported-space-geometry');
    }
  }

  static BoundaryPointMm boundary(
      ProjectAggregateRoot project,
      BuildingId buildingId,
      LevelId levelId,
      SpaceId spaceId,
      ServiceAnchorBoundaryBinding binding,
      int heightMm) {
    owner(project, buildingId, levelId, spaceId, heightMm);
    _require(binding.host.spaceId == spaceId, 'host-space-mismatch');
    final edge = project.stores.boundaries[spaceId]?.edges[binding.host.edgeId];
    _require(edge != null && edge.spaceId == spaceId, 'host-edge-missing');
    final dx = edge!.end.xMm - edge.start.xMm;
    final dy = edge.end.yMm - edge.start.yMm;
    _require(dx == 0 || dy == 0, 'unsupported-diagonal-host');
    _require(binding.offsetMm <= dx.abs() + dy.abs(), 'offset-outside-edge');
    final profile =
        project.engineeringMetadata.boundaryWallProfileRegistry[binding.host];
    _require(
        profile == null || profile.containsPoint(binding.offsetMm, heightMm),
        'wall-profile-rejects-anchor');
    for (final opening in project.stores.openings.values) {
      if (!opening.connectedSpaceIds.contains(spaceId)) continue;
      final host = project.engineeringMetadata.boundaryHostedObjectRegistry
          .openingHost(opening.id, spaceId);
      if (host?.host == binding.host &&
          host!.geometryKind == BoundaryHostGeometryKind.interval &&
          binding.offsetMm > host.startOffsetMm! &&
          binding.offsetMm < host.endOffsetMm! &&
          heightMm > opening.baseElevationMm &&
          heightMm < opening.baseElevationMm + opening.heightMm) {
        throw const ServiceAnchorException(
            'p10.service-anchor.opening-conflict');
      }
    }
    return BoundaryPointMm(
        xMm: edge.start.xMm + dx.sign * binding.offsetMm,
        yMm: edge.start.yMm + dy.sign * binding.offsetMm);
  }
}

abstract final class ProjectServiceAnchorIntegrity {
  static void validateOrThrow(ProjectAggregateRoot project) {
    final metadata = project.engineeringMetadata;
    final anchors = metadata.siteLayout.serviceAnchors;
    final references = metadata.boundaryHostedObjectRegistry.references.values
        .where((r) => r.objectKind == BoundaryHostedObjectKind.serviceEntry);
    if (anchors.isEmpty && references.isEmpty) return;
    final expected = <String>{};
    final physical = <String>{};
    for (final entry in anchors.entries) {
      final anchor = entry.value;
      _require(entry.key == anchor.id && anchor.siteId == project.siteId,
          'invalid-anchor-owner');
      _require(!metadata.siteLayout.sharedAnchors.containsKey(anchor.id),
          'duplicate-anchor-identity');
      final position =
          ProjectServiceAnchorResolver.position(project, anchor.id);
      switch (anchor) {
        case ProjectSiteServiceAnchor():
          ServiceAnchorRules.site(
              project, anchor.point, anchor.servedBuildingIds);
        case ProjectSpaceServiceAnchor():
          ServiceAnchorRules.space(project, anchor.buildingId, anchor.levelId,
              anchor.spaceId, anchor.point, anchor.heightMm);
        case ProjectBoundaryServiceAnchor():
          expected.add(
              BoundaryHostedObjectRegistry.serviceEntryObjectKey(anchor.id));
      }
      final key = jsonEncode({
        'kind': anchor.kind.name,
        'frame': position.frame.name,
        'buildingId': position.buildingId?.value,
        'levelId': position.levelId?.value,
        'spaceId': position.spaceId?.value,
        'xMm': position.point.xMm,
        'yMm': position.point.yMm,
        'elevationMm': position.elevationMm
      });
      _require(physical.add(key), 'duplicate-physical-anchor');
    }
    for (final reference in references) {
      _require(expected.contains(reference.objectKey), 'orphan-wall-binding');
    }
  }
}

enum ServiceAnchorCoordinateFrame { site, building }

final class ProjectServiceAnchorPosition {
  const ProjectServiceAnchorPosition(
      {required this.anchorId,
      required this.siteId,
      required this.frame,
      required this.point,
      required this.elevationMm,
      this.buildingId,
      this.levelId,
      this.spaceId,
      this.boundaryHost});
  final ServiceEntryId anchorId;
  final SiteId siteId;
  final BuildingId? buildingId;
  final LevelId? levelId;
  final SpaceId? spaceId;
  final BoundaryEdgeHostRef? boundaryHost;
  final ServiceAnchorCoordinateFrame frame;
  final BoundaryPointMm point;
  final int elevationMm;
}

/// Resolves the live canonical physical location suitable for later P11/P12
/// attachment. No cached XY duplicates the wall host registry's authority.
abstract final class ProjectServiceAnchorResolver {
  static ProjectServiceAnchorPosition position(
      ProjectAggregateRoot project, ServiceEntryId anchorId,
      {bool siteCoordinates = false}) {
    final anchor =
        project.engineeringMetadata.siteLayout.serviceAnchors[anchorId];
    if (anchor == null) {
      throw const ServiceAnchorException('p10.service-anchor.not-found');
    }
    BoundaryPointMm point;
    BuildingId? buildingId;
    LevelId? levelId;
    SpaceId? spaceId;
    BoundaryEdgeHostRef? host;
    var elevation = 0;
    switch (anchor) {
      case ProjectSiteServiceAnchor():
        point = anchor.point;
      case ProjectSpaceServiceAnchor():
        buildingId = anchor.buildingId;
        levelId = anchor.levelId;
        spaceId = anchor.spaceId;
        ServiceAnchorRules.owner(
            project, buildingId, levelId, spaceId, anchor.heightMm);
        point = anchor.point;
        elevation =
            project.stores.levels[levelId]!.elevationMm + anchor.heightMm;
      case ProjectBoundaryServiceAnchor():
        buildingId = anchor.buildingId;
        levelId = anchor.levelId;
        spaceId = anchor.spaceId;
        final reference = project
            .engineeringMetadata.boundaryHostedObjectRegistry
            .serviceEntryHost(anchor.id);
        _require(
            reference != null &&
                reference.objectKind == BoundaryHostedObjectKind.serviceEntry &&
                reference.geometryKind == BoundaryHostGeometryKind.point,
            'wall-binding-missing');
        host = reference!.host;
        point = ServiceAnchorRules.boundary(
            project,
            buildingId,
            levelId,
            spaceId,
            ServiceAnchorBoundaryBinding(
                host: host, offsetMm: reference.startOffsetMm!),
            anchor.heightMm);
        elevation =
            project.stores.levels[levelId]!.elevationMm + anchor.heightMm;
    }
    if (siteCoordinates && buildingId != null) {
      final placement =
          project.engineeringMetadata.siteLayout.placements[buildingId];
      _require(placement != null, 'site-placement-missing');
      point = placement!.toSite(point);
    }
    return ProjectServiceAnchorPosition(
        anchorId: anchorId,
        siteId: project.siteId,
        buildingId: buildingId,
        levelId: levelId,
        spaceId: spaceId,
        boundaryHost: host,
        frame: buildingId == null || siteCoordinates
            ? ServiceAnchorCoordinateFrame.site
            : ServiceAnchorCoordinateFrame.building,
        point: point,
        elevationMm: elevation);
  }
}

void _require(bool condition, String code) {
  if (!condition) throw ServiceAnchorException('p10.service-anchor.$code');
}
