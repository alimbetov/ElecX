import 'package:elecx/src/application/project/project_navigation_state.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C canonical editor workspace cutover adapter', () {
    test('opens exact legacy level through explicit LevelId binding', () {
      final project = _canonicalProject();
      final workspace = _legacyWorkspace();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: _binding(),
      );
      final navigation = ProjectNavigationState.initial(project)
          .activateLevel(project, LevelId('level-2'));

      adapter.applyCanonicalNavigation(
        project: project,
        navigation: navigation,
      );

      expect(workspace.activeLevelNumber, 7);
      expect(workspace.editor.level.id, 'legacy-level-seven');
      expect(workspace.editor.selectedSpaceId, isNull);
    });

    test('does not fall back to matching levelNumber when binding is wrong', () {
      final project = _canonicalProject();
      final workspace = _legacyWorkspace();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: CanonicalEditorWorkspaceBinding(
          buildingId: BuildingId('building-a'),
          legacyBuildingId: 'legacy-building-a',
          legacyLevelIds: <LevelId, String>{
            LevelId('level-1'): 'legacy-level-one',
            LevelId('level-2'): 'missing-legacy-level',
          },
        ),
      );
      final navigation = ProjectNavigationState.initial(project)
          .activateLevel(project, LevelId('level-2'));

      expect(
        () => adapter.applyCanonicalNavigation(
          project: project,
          navigation: navigation,
        ),
        throwsA(
          isA<CanonicalEditorWorkspaceException>().having(
            (error) => error.code,
            'code',
            CanonicalEditorWorkspaceIssueCode.legacyLevelMissing,
          ),
        ),
      );

      expect(workspace.editor.level.id, 'legacy-level-one');
    });

    test('opens exact canonical Space and its Zone on the canvas', () {
      final project = _canonicalProject();
      final workspace = _legacyWorkspace();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: _binding(),
      );
      final navigation = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-bedroom'));

      adapter.applyCanonicalNavigation(
        project: project,
        navigation: navigation,
      );

      expect(workspace.editor.level.id, 'legacy-level-one');
      expect(workspace.selectedZoneId, 'legacy-zone-apartment');
      expect(workspace.editor.selectedSpaceId, 'legacy-space-bedroom');
    });

    test('zone-only canonical selection does not invent a selected Room', () {
      final project = _canonicalProject();
      final workspace = _legacyWorkspace();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: _binding(),
      );
      final navigation = ProjectNavigationState.initial(project)
          .selectZone(project, ZoneId('zone-apartment'));

      adapter.applyCanonicalNavigation(
        project: project,
        navigation: navigation,
      );

      expect(workspace.selectedZoneId, 'legacy-zone-apartment');
      expect(workspace.editor.selectedSpaceId, isNull);
    });

    test('legacy canvas Space selection is projected back to canonical ids', () {
      final project = _canonicalProject();
      final workspace = _legacyWorkspace();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: _binding(),
      );
      var navigation = ProjectNavigationState.initial(project)
          .activateLevel(project, LevelId('level-2'));

      workspace.selectLevel(1);
      workspace.editor.selectSpace('legacy-space-bedroom');
      navigation = adapter.pullLegacySelection(
        project: project,
        navigation: navigation,
      );

      expect(navigation.activeBuildingId, BuildingId('building-a'));
      expect(navigation.activeLevelId, LevelId('level-1'));
      expect(navigation.selectedZoneId, ZoneId('zone-apartment'));
      expect(navigation.selectedSpaceId, SpaceId('space-bedroom'));
    });

    test('a different canonical Building fails closed', () {
      final project = _twoBuildingCanonicalProject();
      final workspace = _legacyWorkspace();
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: _binding(),
      );
      final navigation = ProjectNavigationState.initial(project)
          .activateLevel(project, LevelId('building-b-level'));

      expect(
        () => adapter.applyCanonicalNavigation(
          project: project,
          navigation: navigation,
        ),
        throwsA(
          isA<CanonicalEditorWorkspaceException>().having(
            (error) => error.code,
            'code',
            CanonicalEditorWorkspaceIssueCode.unsupportedBuilding,
          ),
        ),
      );
    });

    test('duplicate reverse legacy bindings are rejected', () {
      expect(
        () => CanonicalEditorWorkspaceBinding(
          buildingId: BuildingId('building-a'),
          legacyBuildingId: 'legacy-building-a',
          legacyLevelIds: <LevelId, String>{
            LevelId('level-1'): 'same',
            LevelId('level-2'): 'same',
          },
        ),
        throwsA(
          isA<CanonicalEditorWorkspaceException>().having(
            (error) => error.code,
            'code',
            CanonicalEditorWorkspaceIssueCode.ambiguousLegacyBinding,
          ),
        ),
      );
    });
  });
}

CanonicalEditorWorkspaceBinding _binding() => CanonicalEditorWorkspaceBinding(
      buildingId: BuildingId('building-a'),
      legacyBuildingId: 'legacy-building-a',
      legacyLevelIds: <LevelId, String>{
        LevelId('level-1'): 'legacy-level-one',
        LevelId('level-2'): 'legacy-level-seven',
      },
      legacyZoneIds: <ZoneId, String>{
        ZoneId('zone-apartment'): 'legacy-zone-apartment',
      },
      legacySpaceIds: <SpaceId, String>{
        SpaceId('space-bedroom'): 'legacy-space-bedroom',
        SpaceId('space-corridor'): 'legacy-space-corridor',
      },
    );

ProjectAggregateRoot _canonicalProject() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final zoneId = ZoneId('zone-apartment');
  final bedroom = SpaceId('space-bedroom');
  final corridor = SpaceId('space-corridor');

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
          name: 'Building A',
          levelIds: <LevelId>[level1, level2],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        level1: ProjectLevelEntity(
          id: level1,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          zoneIds: <ZoneId>[zoneId],
          spaceIds: <SpaceId>[bedroom, corridor],
        ),
        level2: ProjectLevelEntity(
          id: level2,
          buildingId: buildingId,
          name: 'Technical',
          levelNumber: 7,
          elevationMm: 21000,
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: level1,
          name: 'Apartment',
          spaceIds: <SpaceId>[bedroom],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        bedroom: ProjectSpaceEntity(
          id: bedroom,
          levelId: level1,
          name: 'Bedroom',
        ),
        corridor: ProjectSpaceEntity(
          id: corridor,
          levelId: level1,
          name: 'Corridor',
        ),
      },
    ),
  );
}

ProjectAggregateRoot _twoBuildingCanonicalProject() {
  final base = _canonicalProject();
  final siteId = base.siteId;
  final buildingB = BuildingId('building-b');
  final levelB = LevelId('building-b-level');
  final site = base.index.site(siteId)!;

  return ProjectAggregateRoot(
    id: base.id,
    siteId: siteId,
    version: base.version,
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: site.name,
          buildingIds: <BuildingId>[...site.buildingIds, buildingB],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        ...base.stores.buildings,
        buildingB: ProjectBuildingEntity(
          id: buildingB,
          siteId: siteId,
          name: 'Building B',
          levelIds: <LevelId>[levelB],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        ...base.stores.levels,
        levelB: ProjectLevelEntity(
          id: levelB,
          buildingId: buildingB,
          name: 'Floor 1 B',
          levelNumber: 1,
          elevationMm: 0,
        ),
      },
      zones: base.stores.zones,
      spaces: base.stores.spaces,
    ),
  );
}

EditorBuildingWorkspace _legacyWorkspace() {
  final bedroom = _legacySpace('legacy-space-bedroom', 'Bedroom');
  final corridor = _legacySpace('legacy-space-corridor', 'Corridor');
  final levelOneGeometry = BuildingLevel(
    id: 'legacy-level-one',
    name: 'Legacy floor one',
    elevationMm: 0,
    spaces: <EngineeringSpace>[bedroom, corridor],
  );
  final levelSevenGeometry = BuildingLevel(
    id: 'legacy-level-seven',
    name: 'Legacy floor seven',
    elevationMm: 21000,
    spaces: const <EngineeringSpace>[],
  );
  final levelOne = ComposedBuildingLevel(
    level: levelOneGeometry,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
    zones: <BuildingZone>[
      BuildingZone(
        id: 'legacy-zone-apartment',
        name: 'Apartment',
        kind: BuildingZoneKind.apartment,
        apartmentNumber: '1',
        spaceIds: const <String>{'legacy-space-bedroom'},
      ),
    ],
  );
  final levelSeven = ComposedBuildingLevel(
    level: levelSevenGeometry,
    levelNumber: 7,
    kind: BuildingLevelKind.technical,
  );
  final geometry = Building(
    id: 'legacy-building-a',
    name: 'Legacy building A',
    levels: <BuildingLevel>[levelOneGeometry, levelSevenGeometry],
  );
  final building = ComposedBuilding(
    building: geometry,
    levels: <ComposedBuildingLevel>[levelOne, levelSeven],
  );
  final site = ComposedProjectSite(
    site: ProjectSite(
      id: 'legacy-site',
      name: 'Legacy site',
      buildings: <Building>[geometry],
    ),
  );
  final editor = EditorController.restored(
    level: levelOneGeometry,
    openings: const [],
  );

  return EditorBuildingWorkspace(
    editor: editor,
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
