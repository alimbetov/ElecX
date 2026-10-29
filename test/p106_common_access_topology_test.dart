import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/apartment_placement.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/level_apartment_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/level_apartment_composition.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/rectilinear_polygon_relations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P10-Q07 apartment entry reaches a generated common corridor explicitly',
    () {
      final ids = SecureRandomEntityIdFactory(random: Random(10670));
      final projectId = ids.newProjectId();
      final siteId = ids.newSiteId();
      final buildingId = ids.newBuildingId();
      final levelId = ids.newLevelId();
      final empty = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Q07 Site',
              buildingIds: [buildingId],
            ),
          },
          buildings: {
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Q07 Building',
              levelIds: [levelId],
            ),
          },
          levels: {
            levelId: ProjectLevelEntity(
              id: levelId,
              buildingId: buildingId,
              name: 'Floor 1',
              levelNumber: 1,
              elevationMm: 0,
              kind: ProjectLevelKind.residential,
            ),
          },
        ),
      );
      final initialLevelTarget = LevelWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: buildingId,
        levelId: levelId,
        baseVersion: empty.version,
      );
      final result = const ApartmentCandidateSetService().generate(
        input: ApartmentRequestInput.productionDefaults,
        target: initialLevelTarget,
        project: empty,
      );
      expect(result.accepted, isTrue);
      final candidateSet = result.candidateSet!;
      final source =
          candidateSet.recommendedCandidate.rankedCandidate.candidate;
      final primary = source.openingIntents.singleWhere(
        (intent) => intent.kind == GeometryOpeningKind.primaryEntry,
      );

      late ApartmentPlacementTransform transform;
      late GeometrySegmentMm placedEntry;
      late int minX;
      late int maxX;
      late int maxY;
      var found = false;
      final sourcePoints = <BoundaryPointMm>[
        for (final space in [
          ...source.interiorSpaces,
          ...source.exteriorAppendages,
        ])
          ...space.polygon.vertices,
      ];
      for (var turns = 0; turns < 4; turns++) {
        final candidateTransform = ApartmentPlacementTransform(
          xMm: 50000,
          yMm: 50000,
          clockwiseQuarterTurns: turns,
        );
        final points = sourcePoints.map(candidateTransform.apply).toList();
        final entry = GeometrySegmentMm(
          start: candidateTransform.apply(primary.hostSegment.start),
          end: candidateTransform.apply(primary.hostSegment.end),
        );
        final candidateMaxY = points.map((point) => point.yMm).reduce(max);
        if (!entry.vertical &&
            entry.start.yMm == candidateMaxY &&
            entry.end.yMm == candidateMaxY) {
          transform = candidateTransform;
          placedEntry = entry;
          minX = points.map((point) => point.xMm).reduce(min);
          maxX = points.map((point) => point.xMm).reduce(max);
          maxY = candidateMaxY;
          found = true;
          break;
        }
      }
      expect(found, isTrue,
          reason: 'P9 entry must support a top-edge placement');

      final session = ProjectMutationSession(empty);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10671)),
      );
      final commonTarget = BuildingWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: buildingId,
        baseVersion: session.current.version,
      );
      final common = BuildingCommonCoreCompositionCommand.create(
        project: session.current,
        target: commonTarget,
        compositionKey: 'q07.common',
        parameters: CommonCoreParameters.v2(
          stairCount: 0,
          liftCount: 0,
          serviceShaftCount: 0,
          electricalRiserCount: 0,
          telecomRiserCount: 0,
          corridorWidthMm: 1800,
          serviceSpacePolicy: const CommonServiceSpacePolicy.none(),
        ),
        layout: CommonCoreLayoutParameters(
          originXmm: minX - 1000,
          originYmm: maxY,
          corridorLengthMm: maxX - minX + 2000,
        ),
        servedLevelIds: [levelId],
      );
      port.commitPreview(port.preview(common));
      final corridor = session.current.stores.spaces.values.singleWhere(
        (space) =>
            space.levelId == levelId && space.usage == SpaceUsage.corridor,
      );
      final corridorBoundary = session.current.stores.boundaries[corridor.id]!;
      expect(
        corridorBoundary.edges.values.any(
          (edge) => RectilinearPolygonRelations.containsSegment(
            GeometrySegmentMm(start: edge.start, end: edge.end),
            placedEntry,
          ),
        ),
        isTrue,
      );

      final apartmentTarget = LevelWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: buildingId,
        levelId: levelId,
        baseVersion: session.current.version,
      );
      final slot = ApartmentPlacementSlot.fromCandidateSet(
        key: 'apartment-a',
        displayName: 'Apartment A',
        candidateSet: candidateSet,
        selection: candidateSet.selectionFor(candidateSet.recommendedCandidate),
        transform: transform,
        accessSpaceId: corridor.id,
      );
      final apartments = LevelApartmentCompositionCommand(
        project: session.current,
        target: apartmentTarget,
        compositionKey: 'q07.apartment',
        slots: [slot],
      );
      port.commitPreview(port.preview(apartments));

      final parent = session.current.engineeringMetadata
          .generationProvenanceRegistry.levelCompositions.values.single;
      final apartmentZoneId = parent.apartments['apartment-a']!.apartmentZoneId;
      final apartmentSpaceIds =
          session.current.stores.zones[apartmentZoneId]!.spaceIds;
      final entryOpening = session.current.stores.openings.values.singleWhere(
        (opening) =>
            opening.connectedSpaceIds.contains(corridor.id) &&
            opening.connectedSpaceIds.any(apartmentSpaceIds.contains),
      );
      final accessAdjacency =
          session.current.stores.adjacencies.values.singleWhere(
        (adjacency) =>
            adjacency.kind == SpaceAdjacencyKind.opening &&
            adjacency.openingId == entryOpening.id,
      );

      expect(entryOpening.connectedSpaceIds, hasLength(2));
      expect(accessAdjacency.spaceIds, contains(corridor.id));
      expect(accessAdjacency.spaceIds.any(apartmentSpaceIds.contains), isTrue);
      expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry
            .openingHost(entryOpening.id, corridor.id),
        isNotNull,
      );
    },
  );
}
