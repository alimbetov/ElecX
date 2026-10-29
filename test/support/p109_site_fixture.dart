import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_level_stack_generator.dart';
import 'package:elecx/src/application/project/wizard/building/building_shell_composition.dart';
import 'package:elecx/src/application/project/wizard/building/site_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_site_layout.dart';

import 'p108_tower_fixture.dart';

final class P109SiteFixture {
  final tower = P108TowerFixture();
  ProjectId get projectId => tower.projectId;
  SiteId get siteId => tower.siteId;
  ProjectAggregateRoot get project {
    final base = tower.project;
    return ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: ProjectEngineeringMetadata(
            projectNorth: ProjectEngineeringNorth.fromDegrees(37.5)));
  }

  SiteBuildingSlot towerSlot(
          {String key = 'tower.a',
          int x = 100000,
          int y = 100000,
          double angle = 0}) =>
      SiteBuildingSlot(
          key: key,
          parameters: tower.parameters(
              placement: BuildingSitePlacement(
                  xMm: x,
                  yMm: y,
                  orientation: ProjectEngineeringNorth.fromDegrees(angle))),
          layout: tower.layout(),
          apartments: tower.requests);
  SiteBuildingSlot cottageSlot(
          {String key = 'cottage.b',
          int x = 220000,
          int y = 110000,
          double angle = 90}) =>
      SiteBuildingSlot(
          key: key,
          parameters: BuildingGenerationParameters(
              kind: BuildingCompositionKind.detachedHouse,
              siteId: siteId,
              displayName: 'Cottage $key',
              placement: BuildingSitePlacement(
                  xMm: x,
                  yMm: y,
                  orientation: ProjectEngineeringNorth.fromDegrees(angle)),
              levelStack: const BuildingLevelStackGenerator()
                  .residentialParameters(upperResidentialLevels: 1),
              commonCore: CommonCoreParameters.v2(
                  stairCount: 1,
                  liftCount: 0,
                  serviceShaftCount: 1,
                  electricalRiserCount: 1,
                  telecomRiserCount: 1,
                  corridorWidthMm: 1800,
                  includeTechnicalRoom: true,
                  serviceSpacePolicy: const CommonServiceSpacePolicy(
                      includeCommonHall: true,
                      includeElevatorHall: false,
                      includeElectricalRoomCandidate: false,
                      includeTelecomRoomCandidate: false,
                      includeFireControlRoomCandidate: false,
                      includeUtilityRoomCandidate: false)),
              serviceAnchors: ServiceAnchorParameters()),
          layout: BuildingCompositionLayout(
              footprintWidthMm: 12000,
              footprintDepthMm: 12000,
              commonCore: CommonCoreLayoutParameters(
                  originXmm: 1000, originYmm: 4000, corridorLengthMm: 10000)));
  List<SiteBuildingSlot> get slots => [
        towerSlot(),
        cottageSlot(),
        cottageSlot(key: 'cottage.c', x: 280000, y: 120000, angle: 180)
      ];
  List<SharedSiteAnchorRequest> get anchors => [
        SharedSiteAnchorRequest(
            key: 'shared.service',
            name: 'Shared service area',
            kind: ProjectSiteAnchorKind.sharedServiceArea,
            point: const BoundaryPointMm(xMm: 200000, yMm: 80000),
            buildingKeys: slots.map((s) => s.key)),
        SharedSiteAnchorRequest(
            key: 'shared.access',
            name: 'Shared pedestrian access',
            kind: ProjectSiteAnchorKind.sharedAccessPoint,
            point: const BoundaryPointMm(xMm: 200000, yMm: 60000),
            buildingKeys: slots.map((s) => s.key)),
      ];
  SiteCompositionCommand command(
          {ProjectAggregateRoot? project,
          Iterable<SiteBuildingSlot>? slots,
          Iterable<SharedSiteAnchorRequest>? anchors}) =>
      SiteCompositionCommand.create(
          project: project ?? this.project,
          compositionKey: 'site.main',
          slots: slots ?? this.slots,
          anchors: anchors ?? this.anchors);
  ProjectMutationSession compose({int seed = 109}) {
    final basis = project;
    final session = ProjectMutationSession(basis);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)));
    port.commitPreview(port.preview(command(project: basis)));
    return session;
  }
}

ProjectSnapshot p109Snapshot(ProjectAggregateRoot project) => ProjectSnapshot(
    aggregate: project,
    name: 'P10.9 Site',
    createdAt: DateTime.utc(2026, 10, 29),
    updatedAt: DateTime.utc(2026, 10, 29));

/// Historical v17/v18 state has no P10.12 parent evidence. Never use this
/// projection for production writes; current-state downgrade is tested to fail.
ProjectSnapshot p10HistoricalSnapshot(ProjectSnapshot snapshot) {
  final p = snapshot.aggregate;
  return snapshot.copyWith(
      aggregate: ProjectAggregateRoot(
          id: p.id,
          siteId: p.siteId,
          version: p.version,
          stores: p.stores,
          engineeringMetadata: p.engineeringMetadata
              .withGenerationProvenanceRegistry(p
                  .engineeringMetadata.generationProvenanceRegistry
                  .copyWith(compositions: {}))));
}
