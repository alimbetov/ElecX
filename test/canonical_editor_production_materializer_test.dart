import 'package:elecx/src/application/project/project_navigation_state.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_materializer.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_legacy_identity_codec.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE-P12 standalone Room production materializer', () {
    test('materializes exact canonical topology once and establishes binding', () {
      final project = _project();
      final navigation = _navigation(project);
      final workspace = _workspace();
      addTearDown(workspace.dispose);
      final binding = _binding();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: binding,
      );
      const materializer = CanonicalEditorProductionMaterializer();

      final before = materializer.inspect(
        project: project,
        navigation: navigation,
        binding: binding,
      );
      expect(before.status, CanonicalEditorMaterializationStatus.materializable);
      expect(before.canOpen, isFalse);

      final after = materializer.materialize(
        project: project,
        navigation: navigation,
        adapter: adapter,
      );

      expect(after.canOpen, isTrue);
      final expectedLegacyId =
          CanonicalLegacyIdentityCodec.encodeSpaceId(SpaceId('room-1'));
      expect(binding.legacySpaceIds[SpaceId('room-1')], expectedLegacyId);
      expect(workspace.editor.level.spaces, hasLength(1));
      final room = workspace.editor.level.spaces.single;
      expect(room.id, expectedLegacyId);
      expect(room.name, 'Canonical room');
      expect(room.type, SpaceType.room);
      expect(
        room.boundary.vertices,
        const <MmPoint>[
          MmPoint(1000, 2000),
          MmPoint(5000, 2000),
          MmPoint(5000, 6000),
          MmPoint(1000, 6000),
        ],
      );

      final repeated = materializer.materialize(
        project: project,
        navigation: navigation,
        adapter: adapter,
      );
      expect(repeated.canOpen, isTrue);
      expect(workspace.editor.level.spaces, hasLength(1));
    });

    test('fails closed when encoded legacy identity already belongs to runtime',
        () {
      final project = _project();
      final navigation = _navigation(project);
      final encoded =
          CanonicalLegacyIdentityCodec.encodeSpaceId(SpaceId('room-1'));
      final workspace = _workspace(
        spaces: <EngineeringSpace>[
          _legacyRoom(
            id: encoded,
            name: 'Foreign legacy room',
            first: const MmPoint(-4000, -4000),
            second: const MmPoint(-1000, -1000),
          ),
        ],
      );
      addTearDown(workspace.dispose);
      final binding = _binding();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: binding,
      );
      const materializer = CanonicalEditorProductionMaterializer();

      final readiness = materializer.inspect(
        project: project,
        navigation: navigation,
        binding: binding,
      );
      expect(readiness.canMaterialize, isTrue);

      final result = materializer.materialize(
        project: project,
        navigation: navigation,
        adapter: adapter,
      );
      expect(
        result.status,
        CanonicalEditorMaterializationStatus.blockedMissingRuntimeRepresentation,
      );
      expect(binding.legacySpaceIds, isEmpty);
      expect(workspace.editor.level.spaces, hasLength(1));
      expect(workspace.editor.level.spaces.single.name, 'Foreign legacy room');
    });

    test('invalid canonical boundary is not materializable', () {
      final project = _project(includeBoundary: false);
      final navigation = _navigation(project);
      final workspace = _workspace();
      addTearDown(workspace.dispose);
      final binding = _binding();
      const materializer = CanonicalEditorProductionMaterializer();

      final readiness = materializer.inspect(
        project: project,
        navigation: navigation,
        binding: binding,
      );

      expect(
        readiness.status,
        CanonicalEditorMaterializationStatus.blockedMissingGeometry,
      );
      expect(readiness.canMaterialize, isFalse);
      expect(workspace.editor.level.spaces, isEmpty);
    });
  });
}

ProjectNavigationState _navigation(ProjectAggregateRoot project) =>
    ProjectNavigationState.restore(
      project,
      activeBuildingId: BuildingId('building-1'),
      activeLevelId: LevelId('level-1'),
      selectedSpaceId: SpaceId('room-1'),
    );

CanonicalEditorWorkspaceBinding _binding() => CanonicalEditorWorkspaceBinding(
      buildingId: BuildingId('building-1'),
      legacyBuildingId: 'legacy-building-1',
      legacyLevelIds: <LevelId, String>{
        LevelId('level-1'): 'legacy-level-1',
      },
      legacySpaceIds: const <SpaceId, String>{},
    );

ProjectAggregateRoot _project({bool includeBoundary = true}) {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomId = SpaceId('room-1');
  final edgeIds = <BoundaryEdgeId>[
    BoundaryEdgeId('edge-1'),
    BoundaryEdgeId('edge-2'),
    BoundaryEdgeId('edge-3'),
    BoundaryEdgeId('edge-4'),
  ];
  final points = const <BoundaryPointMm>[
    BoundaryPointMm(xMm: 1000, yMm: 2000),
    BoundaryPointMm(xMm: 5000, yMm: 2000),
    BoundaryPointMm(xMm: 5000, yMm: 6000),
    BoundaryPointMm(xMm: 1000, yMm: 6000),
  ];
  final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{
    for (var index = 0; index < edgeIds.length; index++)
      edgeIds[index]: ProjectBoundaryEdge(
        id: edgeIds[index],
        spaceId: roomId,
        start: points[index],
        end: points[(index + 1) % points.length],
      ),
  };

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(1),
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
          spaceIds: <SpaceId>[roomId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomId: ProjectSpaceEntity(
          id: roomId,
          levelId: levelId,
          name: 'Canonical room',
        ),
      },
      boundaries: includeBoundary
          ? <SpaceId, SpaceBoundaryTopology>{
              roomId: SpaceBoundaryTopology(
                spaceId: roomId,
                orderedEdgeIds: edgeIds,
                edges: edges,
              ),
            }
          : const <SpaceId, SpaceBoundaryTopology>{},
    ),
  );
}

EditorBuildingWorkspace _workspace({
  List<EngineeringSpace> spaces = const <EngineeringSpace>[],
}) {
  final geometry = BuildingLevel(
    id: 'legacy-level-1',
    name: 'Floor 1',
    elevationMm: 0,
    spaces: spaces,
  );
  final composedLevel = ComposedBuildingLevel(
    level: geometry,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
  );
  final buildingGeometry = Building(
    id: 'legacy-building-1',
    name: 'Building',
    levels: <BuildingLevel>[geometry],
  );
  final building = ComposedBuilding(
    building: buildingGeometry,
    levels: <ComposedBuildingLevel>[composedLevel],
  );
  final site = ComposedProjectSite(
    site: ProjectSite(
      id: 'legacy-site-1',
      name: 'Site',
      buildings: <Building>[buildingGeometry],
    ),
  );
  final editor = EditorController.restored(
    level: geometry,
    openings: const <ArchitecturalOpening>[],
  );
  return EditorBuildingWorkspace(
    editor: editor,
    building: building,
    site: site,
    initialLevelNumber: 1,
  );
}

EngineeringSpace _legacyRoom({
  required String id,
  required String name,
  required MmPoint first,
  required MmPoint second,
}) {
  final boundary = MmPolygon.rectangle(first, second);
  return EngineeringSpace(
    id: id,
    name: name,
    type: SpaceType.room,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}
