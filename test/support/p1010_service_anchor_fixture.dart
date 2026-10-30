import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/service_anchor_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';

import 'p109_site_fixture.dart';

final class P1010ServiceAnchorFixture {
  P1010ServiceAnchorFixture() {
    project = P109SiteFixture().compose(seed: 101000).current;
    buildingId = project.stores.buildings.values
        .singleWhere((b) => b.name == 'Production Tower')
        .id;
    levelId = project.stores.buildings[buildingId]!.levelIds
        .map((id) => project.stores.levels[id]!)
        .singleWhere((l) => l.kind == ProjectLevelKind.ground)
        .id;
    spaceId = project.stores.levels[levelId]!.spaceIds.singleWhere(
        (id) => project.stores.spaces[id]!.usage == SpaceUsage.corridor);
    final edges = project.stores.boundaries[spaceId]!.edges.values;
    final minX = edges.map((e) => e.start.xMm).reduce(min);
    edge = edges.singleWhere((e) => e.start.xMm == minX && e.end.xMm == minX);
    technicalSpaceId = project.stores.levels[levelId]!.spaceIds.firstWhere(
        (id) =>
            project.stores.spaces[id]!.type == ProjectSpaceType.technicalRoom);
    final points = project.stores.boundaries[technicalSpaceId]!.edges.values
        .map((e) => e.start)
        .toList();
    roomPoint = BoundaryPointMm(
        xMm: (points.map((p) => p.xMm).reduce(min) +
                points.map((p) => p.xMm).reduce(max)) ~/
            2,
        yMm: (points.map((p) => p.yMm).reduce(min) +
                points.map((p) => p.yMm).reduce(max)) ~/
            2);
  }
  late final ProjectAggregateRoot project;
  late final BuildingId buildingId;
  late final LevelId levelId;
  late final SpaceId spaceId;
  late final SpaceId technicalSpaceId;
  late final ProjectBoundaryEdge edge;
  late final BoundaryPointMm roomPoint;
  BoundaryServiceAnchorTarget boundary({int offset = 333, int height = 1200}) =>
      BoundaryServiceAnchorTarget(
          buildingId: buildingId,
          levelId: levelId,
          spaceId: spaceId,
          binding: ServiceAnchorBoundaryBinding(
              host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edge.id),
              offsetMm: offset),
          heightMm: height);
  SpaceServiceAnchorTarget room({BoundaryPointMm? point, int height = 0}) =>
      SpaceServiceAnchorTarget(
          buildingId: buildingId,
          levelId: levelId,
          spaceId: technicalSpaceId,
          point: point ?? roomPoint,
          heightMm: height);
  SiteServiceAnchorTarget outdoor({int x = 10000, int y = 10000}) =>
      SiteServiceAnchorTarget(
          point: BoundaryPointMm(xMm: x, yMm: y),
          servedBuildingIds: project.stores.buildings.keys);
  List<ServiceAnchorRequest> get requests => [
        for (final (index, kind) in ProjectServiceAnchorKind.values.indexed)
          ServiceAnchorRequest(
              key: kind.name,
              name: 'Architectural ${kind.name}',
              kind: kind,
              target: isServiceEntryKind(kind)
                  ? boundary(offset: 300 + index * 400)
                  : kind == ProjectServiceAnchorKind.pvInverterArea ||
                          kind == ProjectServiceAnchorKind.batteryUpsArea
                      ? room()
                      : outdoor(x: 10000 + index * 2000)),
      ];
  ServiceAnchorCompositionCommand command(
          {ProjectAggregateRoot? project,
          Iterable<ServiceAnchorRequest>? requests}) =>
      ServiceAnchorCompositionCommand.create(
          project: project ?? this.project,
          compositionKey: 'building.services',
          requests: requests ?? this.requests);
  ProjectMutationSession compose({int seed = 101001}) {
    final session = ProjectMutationSession(project);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)));
    port.commitPreview(port.preview(command()));
    return session;
  }

  Map<BuildingServiceAnchorKind, ServiceAnchorTarget> get locations => {
        for (final request in requests)
          BuildingServiceAnchorKind.values.byName(request.kind.name):
              request.target,
      };
}
