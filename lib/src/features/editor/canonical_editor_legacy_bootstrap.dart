import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_edge_identity_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/geometry.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'editor_project_document.dart';

final class CanonicalEditorLegacyBootstrapResult {
  const CanonicalEditorLegacyBootstrapResult({
    required this.snapshot,
    required this.binding,
  });

  final ProjectSnapshot snapshot;
  final CanonicalEditorWorkspaceBinding binding;
}

/// One-time deterministic migration from the persisted legacy editor document
/// into the canonical P7A aggregate.
///
/// This is intentionally a bootstrap only. Once the canonical sidecar exists,
/// production must load that snapshot instead of rebuilding identities from
/// legacy ordinals. The deterministic initial IDs make interrupted first-run
/// migration retryable without inventing a different canonical project.
abstract final class CanonicalEditorLegacyBootstrap {
  static CanonicalEditorLegacyBootstrapResult create(
    EditorProjectDocument document,
  ) {
    final projectId = ProjectId(document.projectId);
    final legacySite = document.site.site;
    final siteId = SiteId(_id('site', legacySite.id));

    final buildings = <BuildingId, ProjectBuildingEntity>{};
    final levels = <LevelId, ProjectLevelEntity>{};
    final zones = <ZoneId, ProjectStructuralZoneEntity>{};
    final spaces = <SpaceId, ProjectSpaceEntity>{};
    final boundaries = <SpaceId, SpaceBoundaryTopology>{};

    final legacyLevelIds = <LevelId, String>{};
    final legacyZoneIds = <ZoneId, String>{};
    final legacySpaceIds = <SpaceId, String>{};

    final composedBuilding = document.building;
    final composedByLegacyLevel = {
      for (final item in composedBuilding.levels) item.level.id: item,
    };

    for (var buildingIndex = 0;
        buildingIndex < legacySite.buildings.length;
        buildingIndex++) {
      final legacyBuilding = legacySite.buildings[buildingIndex];
      final buildingId = BuildingId(
        _id('building', legacyBuilding.id),
      );
      final canonicalLevelIds = <LevelId>[];

      for (var levelIndex = 0;
          levelIndex < legacyBuilding.levels.length;
          levelIndex++) {
        final legacyLevel = legacyBuilding.levels[levelIndex];
        final levelId = LevelId(
          _id('level', legacyBuilding.id, legacyLevel.id),
        );
        canonicalLevelIds.add(levelId);
        if (legacyBuilding.id == composedBuilding.building.id) {
          legacyLevelIds[levelId] = legacyLevel.id;
        }

        final canonicalSpaceIds = <SpaceId>[];
        for (final legacySpace in legacyLevel.spaces) {
          final spaceId = SpaceId(
            _id(
              'space',
              legacyBuilding.id,
              legacyLevel.id,
              legacySpace.id,
            ),
          );
          canonicalSpaceIds.add(spaceId);
          spaces[spaceId] = ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: legacySpace.name,
          );
          if (legacyBuilding.id == composedBuilding.building.id) {
            legacySpaceIds[spaceId] = legacySpace.id;
          }
          boundaries[spaceId] = _boundary(
            spaceId: spaceId,
            buildingId: legacyBuilding.id,
            levelId: legacyLevel.id,
            legacySpaceId: legacySpace.id,
            vertices: legacySpace.boundary.vertices,
          );
        }

        final canonicalZoneIds = <ZoneId>[];
        final composed = legacyBuilding.id == composedBuilding.building.id
            ? composedByLegacyLevel[legacyLevel.id]
            : null;
        if (composed != null) {
          for (final legacyZone in composed.zones) {
            final zoneId = ZoneId(
              _id(
                'zone',
                legacyBuilding.id,
                legacyLevel.id,
                legacyZone.id,
              ),
            );
            final zoneSpaceIds = <SpaceId>[];
            for (final legacySpaceId in legacyZone.spaceIds) {
              final spaceId = SpaceId(
                _id(
                  'space',
                  legacyBuilding.id,
                  legacyLevel.id,
                  legacySpaceId,
                ),
              );
              if (!spaces.containsKey(spaceId)) {
                throw StateError(
                  'Legacy zone ${legacyZone.id} references missing space '
                  '$legacySpaceId on level ${legacyLevel.id}.',
                );
              }
              zoneSpaceIds.add(spaceId);
            }
            zones[zoneId] = ProjectStructuralZoneEntity(
              id: zoneId,
              levelId: levelId,
              name: legacyZone.name,
              spaceIds: zoneSpaceIds,
            );
            canonicalZoneIds.add(zoneId);
            legacyZoneIds[zoneId] = legacyZone.id;
          }
        }

        final levelNumber = composed?.levelNumber ?? levelIndex;
        levels[levelId] = ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: legacyLevel.name,
          levelNumber: levelNumber,
          elevationMm: legacyLevel.elevationMm,
          displayOrder: levelIndex,
          zoneIds: canonicalZoneIds,
          spaceIds: canonicalSpaceIds,
        );
      }

      buildings[buildingId] = ProjectBuildingEntity(
        id: buildingId,
        siteId: siteId,
        name: legacyBuilding.name,
        displayOrder: buildingIndex,
        levelIds: canonicalLevelIds,
      );
    }

    final stores = ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: legacySite.name,
          buildingIds: buildings.keys,
        ),
      },
      buildings: buildings,
      levels: levels,
      zones: zones,
      spaces: spaces,
      boundaries: boundaries,
    );
    final identity = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    final aggregate = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: identity,
      ),
      stores: stores,
    );

    final activeLegacyBuildingId = composedBuilding.building.id;
    final activeBuildingId = BuildingId(
      _id('building', activeLegacyBuildingId),
    );
    if (!buildings.containsKey(activeBuildingId)) {
      throw StateError(
        'Editable legacy building $activeLegacyBuildingId is not part of the '
        'persisted site.',
      );
    }

    return CanonicalEditorLegacyBootstrapResult(
      snapshot: ProjectSnapshot(
        aggregate: aggregate,
        name: document.projectName,
        createdAt: document.createdAt,
        updatedAt: document.updatedAt,
      ),
      binding: CanonicalEditorWorkspaceBinding(
        buildingId: activeBuildingId,
        legacyBuildingId: activeLegacyBuildingId,
        legacyLevelIds: legacyLevelIds,
        legacyZoneIds: legacyZoneIds,
        legacySpaceIds: legacySpaceIds,
      ),
    );
  }

  static SpaceBoundaryTopology _boundary({
    required SpaceId spaceId,
    required String buildingId,
    required String levelId,
    required String legacySpaceId,
    required List<MmPoint> vertices,
  }) {
    if (vertices.length < 3) {
      throw StateError(
        'Legacy space $legacySpaceId must have at least three boundary points.',
      );
    }
    final edgeIds = <BoundaryEdgeId>[
      for (var index = 0; index < vertices.length; index++)
        BoundaryEdgeId(
          _id(
            'edge',
            buildingId,
            levelId,
            legacySpaceId,
            index.toString(),
          ),
        ),
    ];
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < edgeIds.length; index++) {
      final start = vertices[index];
      final end = vertices[(index + 1) % vertices.length];
      final edgeId = edgeIds[index];
      edges[edgeId] = ProjectBoundaryEdge(
        id: edgeId,
        spaceId: spaceId,
        start: BoundaryPointMm(xMm: start.x, yMm: start.y),
        end: BoundaryPointMm(xMm: end.x, yMm: end.y),
      );
    }
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: edges,
    );
    topology.validateOrThrow();
    return topology;
  }

  static String _id(
    String kind,
    String first, [
    String? second,
    String? third,
    String? fourth,
  ]) {
    final parts = <String>[kind, first];
    if (second != null) parts.add(second);
    if (third != null) parts.add(third);
    if (fourth != null) parts.add(fourth);
    return parts.map(_escape).join(':');
  }

  static String _escape(String value) => Uri.encodeComponent(value);
}
