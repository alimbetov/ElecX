import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_space_semantics_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6E canonical space semantics adapter', () {
    test('combines canonical semantics with exact bound legacy geometry', () {
      final project = _project();
      final adapter = CanonicalSpaceSemanticsAdapter(
        workspace: _workspace(),
        binding: _binding(),
      );

      final projection = adapter.resolve(
        project: project,
        spaceId: SpaceId('space-bedroom'),
      );

      expect(projection.spaceId, SpaceId('space-bedroom'));
      expect(projection.usage, SpaceUsage.bedroom);
      expect(projection.legacySpace.id, 'legacy-space-bedroom');
      expect(projection.legacySpace.boundary.vertices, hasLength(4));
      expect(projection.openings.map((item) => item.id), [OpeningId('door-1')]);
      expect(projection.adjacencies.map((item) => item.id), [
        SpaceAdjacencyId('adj-1'),
      ]);
      expect(projection.overlays.map((item) => item.id), [
        OverlayClassificationId('fire-1'),
      ]);
    });

    test('missing Space binding fails closed', () {
      final adapter = CanonicalSpaceSemanticsAdapter(
        workspace: _workspace(),
        binding: CanonicalEditorWorkspaceBinding(
          buildingId: BuildingId('building-a'),
          legacyBuildingId: 'legacy-building-a',
          legacyLevelIds: <LevelId, String>{
            LevelId('level-1'): 'legacy-level-one',
          },
        ),
      );

      expect(
        () => adapter.resolve(
          project: _project(),
          spaceId: SpaceId('space-bedroom'),
        ),
        throwsA(
          isA<CanonicalSpaceSemanticsException>().having(
            (error) => error.code,
            'code',
            CanonicalSpaceSemanticsIssueCode.legacySpaceBindingMissing,
          ),
        ),
      );
    });

    test('binding cannot resolve a Space from another canonical Building', () {
      final project = _projectWithForeignSpace();
      final adapter = CanonicalSpaceSemanticsAdapter(
        workspace: _workspace(),
        binding: _binding(),
      );

      expect(
        () => adapter.resolve(
          project: project,
          spaceId: SpaceId('foreign-space'),
        ),
        throwsA(
          isA<CanonicalSpaceSemanticsException>().having(
            (error) => error.code,
            'code',
            CanonicalSpaceSemanticsIssueCode.canonicalLevelMissing,
          ),
        ),
      );
    });
  });
}

CanonicalEditorWorkspaceBinding _binding() => CanonicalEditorWorkspaceBinding(
      buildingId: BuildingId('building-a'),
      legacyBuildingId: 'legacy-building-a',
      legacyLevelIds: <LevelId, String>{LevelId('level-1'): 'legacy-level-one'},
      legacySpaceIds: <SpaceId, String>{
        SpaceId('space-bedroom'): 'legacy-space-bedroom',
        SpaceId('space-corridor'): 'legacy-space-corridor',
      },
    );

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
  final bedroomId = SpaceId('space-bedroom');
  final corridorId = SpaceId('space-corridor');
  final openingId = OpeningId('door-1');
  final adjacencyId = SpaceAdjacencyId('adj-1');
  final overlayId = OverlayClassificationId('fire-1');

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: <BuildingId>[buildingId],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[bedroomId, corridorId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        bedroomId: ProjectSpaceEntity(
          id: bedroomId,
          levelId: levelId,
          name: 'Bedroom',
          usage: SpaceUsage.bedroom,
        ),
        corridorId: ProjectSpaceEntity(
          id: corridorId,
          levelId: levelId,
          name: 'Corridor',
          usage: SpaceUsage.corridor,
        ),
      },
      openings: <OpeningId, ProjectOpeningEntity>{
        openingId: ProjectOpeningEntity(
          id: openingId,
          levelId: levelId,
          kind: OpeningKind.door,
          connectedSpaceIds: <SpaceId>[bedroomId, corridorId],
          widthMm: 900,
          heightMm: 2100,
        ),
      },
      adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
        adjacencyId: ProjectSpaceAdjacencyEntity(
          id: adjacencyId,
          spaceAId: bedroomId,
          spaceBId: corridorId,
          kind: SpaceAdjacencyKind.opening,
          openingId: openingId,
        ),
      },
      overlays: <OverlayClassificationId, ProjectOverlayClassificationEntity>{
        overlayId: ProjectOverlayClassificationEntity(
          id: overlayId,
          name: 'FC-01',
          discipline: OverlayDiscipline.fireSafety,
          kind: OverlayClassificationKind.fireCompartment,
          spaceIds: <SpaceId>[bedroomId],
        ),
      },
    ),
  );
}

ProjectAggregateRoot _projectWithForeignSpace() {
  final base = _project();
  final foreignBuilding = BuildingId('building-b');
  final foreignLevel = LevelId('level-b');
  final foreignSpace = SpaceId('foreign-space');
  final site = base.index.site(base.siteId)!;

  return ProjectAggregateRoot(
    id: base.id,
    siteId: base.siteId,
    version: base.version,
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        base.siteId: ProjectSiteEntity(
          id: base.siteId,
          name: site.name,
          buildingIds: <BuildingId>[...site.buildingIds, foreignBuilding],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        ...base.stores.buildings,
        foreignBuilding: ProjectBuildingEntity(
          id: foreignBuilding,
          siteId: base.siteId,
          name: 'Building B',
          levelIds: <LevelId>[foreignLevel],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        ...base.stores.levels,
        foreignLevel: ProjectLevelEntity(
          id: foreignLevel,
          buildingId: foreignBuilding,
          name: 'Floor B',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[foreignSpace],
        ),
      },
      zones: base.stores.zones,
      spaces: <SpaceId, ProjectSpaceEntity>{
        ...base.stores.spaces,
        foreignSpace: ProjectSpaceEntity(
          id: foreignSpace,
          levelId: foreignLevel,
          name: 'Foreign Room',
        ),
      },
      openings: base.stores.openings,
      adjacencies: base.stores.adjacencies,
      overlays: base.stores.overlays,
    ),
  );
}

EditorBuildingWorkspace _workspace() {
  final bedroom = _legacySpace('legacy-space-bedroom', 'Bedroom');
  final corridor = _legacySpace('legacy-space-corridor', 'Corridor');
  final levelGeometry = BuildingLevel(
    id: 'legacy-level-one',
    name: 'Legacy Floor',
    elevationMm: 0,
    spaces: <EngineeringSpace>[bedroom, corridor],
  );
  final composedLevel = ComposedBuildingLevel(
    level: levelGeometry,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
  );
  final geometry = Building(
    id: 'legacy-building-a',
    name: 'Legacy Building',
    levels: <BuildingLevel>[levelGeometry],
  );
  final building = ComposedBuilding(
    building: geometry,
    levels: <ComposedBuildingLevel>[composedLevel],
  );
  final site = ComposedProjectSite(
    site: ProjectSite(
      id: 'legacy-site',
      name: 'Legacy Site',
      buildings: <Building>[geometry],
    ),
  );

  return EditorBuildingWorkspace(
    editor: EditorController.restored(level: levelGeometry, openings: const []),
    building: building,
    site: site,
    initialLevelNumber: 1,
  );
}

EngineeringSpace _legacySpace(String id, String name) {
  final boundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(3000, 3000),
  );
  return EngineeringSpace(
    id: id,
    name: name,
    type: SpaceType.room,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}
