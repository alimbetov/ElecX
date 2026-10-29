import 'dart:math';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/apartment_placement.dart';
import 'package:elecx/src/application/project/wizard/building/level_apartment_composition.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/level_apartment_composition.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';

final class P105CompositionFixture {
  P105CompositionFixture._(this.project, this.target, this.candidateSet,
      this.accessSpaceId, this.slots, this.horizontalEntry);
  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
  final ApartmentCandidateSet candidateSet;
  final SpaceId accessSpaceId;
  final List<ApartmentPlacementSlot> slots;
  final bool horizontalEntry;
  LevelApartmentCompositionCommand command(
          {Iterable<ApartmentPlacementSlot>? slots}) =>
      LevelApartmentCompositionCommand(
          project: project,
          target: target,
          compositionKey: 'floor.apartments',
          slots: slots ?? this.slots);

  factory P105CompositionFixture.create(
      {int quarterTurns = 0, bool touching = false}) {
    final ids = SecureRandomEntityIdFactory(random: Random(105));
    final projectId = ids.newProjectId();
    final siteId = ids.newSiteId();
    final buildingId = ids.newBuildingId();
    final levelId = ids.newLevelId();
    final accessId = ids.newSpaceId();
    final zoneId = ids.newZoneId();
    var stores = ProjectEntityStores(sites: {
      siteId:
          ProjectSiteEntity(id: siteId, name: 'Site', buildingIds: [buildingId])
    }, buildings: {
      buildingId: ProjectBuildingEntity(
          id: buildingId, siteId: siteId, name: 'Building', levelIds: [levelId])
    }, levels: {
      levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          kind: ProjectLevelKind.residential)
    });
    final target = LevelWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: buildingId,
        levelId: levelId,
        baseVersion: LocalProjectVersion(0));
    final empty = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: target.baseVersion,
        stores: stores);
    final result = const ApartmentCandidateSetService().generate(
        input: ApartmentRequestInput.productionDefaults,
        target: target,
        project: empty);
    if (!result.accepted) {
      throw StateError(
          'P9 production defaults must produce a qualified candidate.');
    }
    final set = result.candidateSet!;
    ApartmentPlacementSlot slot(
            String key, ApartmentPlacementTransform transform) =>
        ApartmentPlacementSlot.fromCandidateSet(
            key: key,
            displayName: 'Apartment $key',
            candidateSet: set,
            selection: set.selectionFor(set.recommendedCandidate),
            transform: transform,
            accessSpaceId: accessId);
    final first = slot(
        'a',
        ApartmentPlacementTransform(
            xMm: 50000, yMm: 50000, clockwiseQuarterTurns: quarterTurns));
    final placed = PlacedApartmentCandidate(first).geometry;
    final all = [...placed.interiorSpaces, ...placed.exteriorAppendages]
        .map((space) => space.polygon)
        .toList();
    final minX = all.map((polygon) => polygon.minX).reduce(min);
    final maxX = all.map((polygon) => polygon.maxX).reduce(max);
    final minY = all.map((polygon) => polygon.minY).reduce(min);
    final maxY = all.map((polygon) => polygon.maxY).reduce(max);
    final entry = placed.openingIntents
        .singleWhere(
            (intent) => intent.kind == GeometryOpeningKind.primaryEntry)
        .hostSegment;
    final horizontal = !entry.vertical;
    final width = maxX - minX;
    final height = maxY - minY;
    final gap = touching ? 0 : 1000;
    late RectilinearPolygonMm corridor;
    if (horizontal) {
      if (entry.start.yMm != minY && entry.start.yMm != maxY) {
        throw StateError('Expected exterior P9 primary entry.');
      }
      corridor = RectilinearPolygonMm.rectangle(
          xMm: minX - 1000,
          yMm: entry.start.yMm == minY ? minY - 2000 : maxY,
          widthMm: 2 * width + gap + 2000,
          heightMm: 2000);
    } else {
      if (entry.start.xMm != minX && entry.start.xMm != maxX) {
        throw StateError('Expected exterior P9 primary entry.');
      }
      corridor = RectilinearPolygonMm.rectangle(
          xMm: entry.start.xMm == minX ? minX - 2000 : maxX,
          yMm: minY - 1000,
          widthMm: 2000,
          heightMm: 2 * height + gap + 2000);
    }
    final second = slot(
        'b',
        ApartmentPlacementTransform(
            xMm: 50000 + (horizontal ? width + gap : 0),
            yMm: 50000 + (horizontal ? 0 : height + gap),
            clockwiseQuarterTurns: quarterTurns));
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (final segment in corridor.segments) {
      final id = ids.newBoundaryEdgeId();
      edges[id] = ProjectBoundaryEdge(
          id: id, spaceId: accessId, start: segment.start, end: segment.end);
    }
    final boundaries = {
      accessId: SpaceBoundaryTopology(
          spaceId: accessId, orderedEdgeIds: edges.keys, edges: edges)
    };
    stores = stores.copyWith(levels: {
      levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          kind: ProjectLevelKind.residential,
          zoneIds: [zoneId],
          spaceIds: [accessId])
    }, spaces: {
      accessId: ProjectSpaceEntity(
          id: accessId,
          levelId: levelId,
          name: 'Common corridor',
          type: ProjectSpaceType.corridor,
          usage: SpaceUsage.corridor)
    }, zones: {
      zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: 'Common area',
          kind: ProjectStructuralZoneKind.common,
          spaceIds: [accessId])
    }, boundaries: boundaries);
    final project = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: target.baseVersion,
        stores: stores,
        engineeringMetadata: ProjectEngineeringMetadata(
            boundaryEdgeIdentityRegistry:
                const BoundaryEdgeIdentityRegistry.empty()
                    .registerActiveBoundaries(boundaries)));
    return P105CompositionFixture._(project, target, set, accessId,
        List.unmodifiable([first, second]), horizontal);
  }
}

ProjectSnapshot p105Snapshot(ProjectAggregateRoot project) => ProjectSnapshot(
    aggregate: project,
    name: 'P10.5 apartments',
    createdAt: DateTime.utc(2026, 10, 29),
    updatedAt: DateTime.utc(2026, 10, 29));
