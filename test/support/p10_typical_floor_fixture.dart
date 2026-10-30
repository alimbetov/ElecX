import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/typical_floor_commands.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/typical_floor.dart';

final class P10TypicalFloorFixture {
  P10TypicalFloorFixture._(this.project, this.definition, this.instances);

  final ProjectAggregateRoot project;
  final TypicalFloorDefinition definition;
  final List<TypicalFloorInstance> instances;

  RegisterTypicalFloorCommand get command =>
      RegisterTypicalFloorCommand(definition: definition, instances: instances);
  LevelId get firstLevelId => instances.first.levelId;
  LevelId get secondLevelId => instances.last.levelId;
  SpaceId get firstRoomId => instances.first.entities['space:room']! as SpaceId;
  SpaceId get secondRoomId => instances.last.entities['space:room']! as SpaceId;

  ProjectMutationSession registeredSession() {
    final session = ProjectMutationSession(project);
    session.commit(ProjectMutationRequest(
        expectedVersion: project.version, command: command));
    return session;
  }

  factory P10TypicalFloorFixture.create() {
    final factory = SecureRandomEntityIdFactory(random: Random(1004));
    final siteId = factory.newSiteId();
    final buildingId = factory.newBuildingId();
    final levels = <LevelId, ProjectLevelEntity>{};
    final zones = <ZoneId, ProjectStructuralZoneEntity>{};
    final spaces = <SpaceId, ProjectSpaceEntity>{};
    final boundaries = <SpaceId, SpaceBoundaryTopology>{};
    final openings = <OpeningId, ProjectOpeningEntity>{};
    final adjacencies = <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{};
    final mappings = <Map<String, EntityId>>[];
    for (var index = 0; index < 2; index++) {
      final levelId = factory.newLevelId();
      final zoneId = factory.newZoneId();
      final roomId = factory.newSpaceId();
      final hallId = factory.newSpaceId();
      final openingId = factory.newOpeningId();
      final adjacencyId = factory.newSpaceAdjacencyId();
      final mapping = <String, EntityId>{
        'level': levelId,
        'zone:apartment': zoneId,
        'space:room': roomId,
        'space:hall': hallId,
        'opening:door': openingId,
        'adjacency:room-hall': adjacencyId
      };
      for (final entry in {'room': roomId, 'hall': hallId}.entries) {
        final x = entry.key == 'room' ? 0 : 4000;
        final width = entry.key == 'room' ? 4000 : 2000;
        final points = [
          BoundaryPointMm(xMm: x, yMm: 0),
          BoundaryPointMm(xMm: x + width, yMm: 0),
          BoundaryPointMm(xMm: x + width, yMm: 4000),
          BoundaryPointMm(xMm: x, yMm: 4000)
        ];
        final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
        for (var edge = 0; edge < points.length; edge++) {
          final id = factory.newBoundaryEdgeId();
          mapping['edge:${entry.key}:$edge'] = id;
          edges[id] = ProjectBoundaryEdge(
              id: id,
              spaceId: entry.value,
              start: points[edge],
              end: points[(edge + 1) % points.length]);
        }
        boundaries[entry.value] = SpaceBoundaryTopology(
            spaceId: entry.value, orderedEdgeIds: edges.keys, edges: edges);
      }
      spaces[roomId] = ProjectSpaceEntity(
          id: roomId,
          levelId: levelId,
          name: 'Living room',
          type: ProjectSpaceType.room,
          usage: SpaceUsage.livingRoom);
      spaces[hallId] = ProjectSpaceEntity(
          id: hallId,
          levelId: levelId,
          name: 'Hall',
          type: ProjectSpaceType.hall,
          usage: SpaceUsage.entranceHall);
      zones[zoneId] = ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: 'Apartment 1',
          spaceIds: [roomId, hallId],
          kind: ProjectStructuralZoneKind.apartment);
      levels[levelId] = ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor ${index + 1}',
          levelNumber: index + 1,
          elevationMm: index * 3000,
          kind: ProjectLevelKind.residential,
          displayOrder: index,
          zoneIds: [zoneId],
          spaceIds: [roomId, hallId]);
      openings[openingId] = ProjectOpeningEntity(
          id: openingId,
          levelId: levelId,
          kind: OpeningKind.door,
          connectedSpaceIds: [roomId, hallId],
          widthMm: 900,
          heightMm: 2100);
      adjacencies[adjacencyId] = ProjectSpaceAdjacencyEntity(
          id: adjacencyId,
          spaceAId: roomId,
          spaceBId: hallId,
          kind: SpaceAdjacencyKind.opening,
          openingId: openingId);
      mappings.add(mapping);
    }
    final stores = ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
              id: siteId, name: 'Site', buildingIds: [buildingId])
        },
        buildings: {
          buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Tower',
              levelIds: levels.keys)
        },
        levels: levels,
        zones: zones,
        spaces: spaces,
        boundaries: boundaries,
        openings: openings,
        adjacencies: adjacencies);
    final project = ProjectAggregateRoot(
        id: factory.newProjectId(),
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: stores,
        engineeringMetadata: ProjectEngineeringMetadata(
            boundaryEdgeIdentityRegistry:
                const BoundaryEdgeIdentityRegistry.empty()
                    .registerActiveBoundaries(boundaries)));
    final definition = TypicalFloorDefinition(
        id: factory.newTypicalFloorDefinitionId(),
        buildingId: buildingId,
        templateId: TemplateId('p10.tower'),
        templateVersion: 1,
        definitionKey: 'residential.standard',
        patternFingerprint: TypicalFloorPattern.fingerprint(
            stores: stores, entities: mappings.first),
        entityKinds: {
          for (final entry in mappings.first.entries)
            entry.key: typicalFloorEntityKind(entry.value)
        });
    final instances = [
      for (var index = 0; index < mappings.length; index++)
        TypicalFloorInstance(
            levelId: mappings[index]['level']! as LevelId,
            definitionId: definition.id,
            generationKey: 'residential.${index + 1}',
            patternFingerprint: definition.patternFingerprint,
            entities: mappings[index])
    ];
    return P10TypicalFloorFixture._(project, definition, instances);
  }
}

GenerationProvenanceRegistry p10Registry(ProjectMutationSession session) =>
    session.current.engineeringMetadata.generationProvenanceRegistry;

ProjectSnapshot p10Snapshot(ProjectAggregateRoot project) => ProjectSnapshot(
    aggregate: project,
    name: 'P10 typical floors',
    createdAt: DateTime.utc(2026, 10, 29),
    updatedAt: DateTime.utc(2026, 10, 29));
