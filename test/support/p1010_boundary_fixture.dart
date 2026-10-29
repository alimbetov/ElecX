import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/building/service_anchor_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_site_layout.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';

final class P1010BoundaryFixture {
  P1010BoundaryFixture() {
    projectId = ids.newProjectId();
    siteId = ids.newSiteId();
    buildingId = ids.newBuildingId();
    levelId = ids.newLevelId();
    spaceId = ids.newSpaceId();
    final zoneId = ids.newZoneId();
    final points = [
      const BoundaryPointMm(xMm: 0, yMm: 0),
      const BoundaryPointMm(xMm: 4000, yMm: 0),
      const BoundaryPointMm(xMm: 4000, yMm: 3000),
      const BoundaryPointMm(xMm: 0, yMm: 3000)
    ];
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var i = 0; i < 4; i++) {
      final id = ids.newBoundaryEdgeId();
      edges[id] = ProjectBoundaryEdge(
          id: id, spaceId: spaceId, start: points[i], end: points[(i + 1) % 4]);
    }
    edgeId = edges.keys.first;
    final boundaries = {
      spaceId: SpaceBoundaryTopology(
          spaceId: spaceId, orderedEdgeIds: edges.keys, edges: edges)
    };
    project = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(sites: {
          siteId: ProjectSiteEntity(
              id: siteId, name: 'Site', buildingIds: [buildingId])
        }, buildings: {
          buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Building',
              levelIds: [levelId])
        }, levels: {
          levelId: ProjectLevelEntity(
              id: levelId,
              buildingId: buildingId,
              name: 'G',
              levelNumber: 0,
              elevationMm: 0,
              kind: ProjectLevelKind.ground,
              zoneIds: [zoneId],
              spaceIds: [spaceId])
        }, zones: {
          zoneId: ProjectStructuralZoneEntity(
              id: zoneId,
              levelId: levelId,
              name: 'Technical',
              kind: ProjectStructuralZoneKind.technical,
              spaceIds: [spaceId])
        }, spaces: {
          spaceId: ProjectSpaceEntity(
              id: spaceId,
              levelId: levelId,
              name: 'Electrical candidate',
              type: ProjectSpaceType.technicalRoom,
              usage: SpaceUsage.electricalRoom)
        }, boundaries: boundaries),
        engineeringMetadata: ProjectEngineeringMetadata(
            boundaryEdgeIdentityRegistry:
                const BoundaryEdgeIdentityRegistry.empty()
                    .registerActiveBoundaries(boundaries),
            siteLayout: ProjectSiteLayout(placements: {
              buildingId: ProjectBuildingSitePlacement(
                  xMm: 10000,
                  yMm: 10000,
                  orientation: ProjectEngineeringNorth.fromDegrees(0),
                  widthMm: 4000,
                  depthMm: 3000)
            })));
  }
  final ids = SecureRandomEntityIdFactory(random: Random(101040));
  late final ProjectId projectId;
  late final SiteId siteId;
  late final BuildingId buildingId;
  late final LevelId levelId;
  late final SpaceId spaceId;
  late final BoundaryEdgeId edgeId;
  late final ProjectAggregateRoot project;
  BoundaryEdgeHostRef get host =>
      BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId);
  ServiceAnchorRequest request({int offset = 2500, int height = 1000}) =>
      ServiceAnchorRequest(
          key: 'electrical.main',
          name: 'Main electrical entry',
          kind: ProjectServiceAnchorKind.electricalEntry,
          target: BoundaryServiceAnchorTarget(
              buildingId: buildingId,
              levelId: levelId,
              spaceId: spaceId,
              binding:
                  ServiceAnchorBoundaryBinding(host: host, offsetMm: offset),
              heightMm: height));
  ProjectMutationSession compose() {
    final session = ProjectMutationSession(project);
    final port =
        SharedProjectWizardMutationPort(mutations: session, idFactory: ids);
    port.commitPreview(port.preview(ServiceAnchorCompositionCommand.create(
        project: project,
        compositionKey: 'building.services',
        requests: [request()])));
    return session;
  }
}
