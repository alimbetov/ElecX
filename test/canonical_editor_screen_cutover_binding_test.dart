import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C controlled screen cutover binding', () {
    test('initial canonical location is pushed into the legacy canvas', () {
      final fixture = _fixture(initialLevelId: 'level-2');

      fixture.binding.start();

      expect(fixture.workspace.editor.level.id, 'legacy-level-2');
      expect(fixture.binding.isStarted, isTrue);
      expect(fixture.binding.isBoundTo(fixture.workspace), isTrue);
    });

    test('legacy room selection is pulled into canonical navigation once', () {
      final observed = <ProjectNavigationState>[];
      final fixture = _fixture(
        onNavigationChanged: observed.add,
      );
      fixture.binding.start();
      observed.clear();

      fixture.workspace.editor.selectSpace('legacy-space-1');

      expect(fixture.session.navigation.selectedSpaceId, SpaceId('space-1'));
      expect(observed, hasLength(1));
      expect(observed.single.selectedSpaceId, SpaceId('space-1'));
    });

    test('non-navigation editor notifications do not trigger canonical pull', () {
      final observed = <ProjectNavigationState>[];
      final fixture = _fixture(onNavigationChanged: observed.add);
      fixture.binding.start();
      observed.clear();

      fixture.workspace.editor.notifyListeners();
      fixture.workspace.editor.notifyListeners();

      expect(observed, isEmpty);
    });

    test(
      'unmaterialized canonical target is reported without canvas mutation',
      () {
        CanonicalEditorMaterializationResult? blocked;
        final fixture = _fixture(
          bindSpace: false,
          onBlocked: (result) => blocked = result,
        );
        fixture.binding.start(pushInitialCanonicalState: false);
        fixture.session.selectRoom(SpaceId('space-1'));
        final beforeLevel = fixture.workspace.editor.level.id;
        final beforeSpace = fixture.workspace.editor.selectedSpaceId;

        final readiness = fixture.binding.pushCanonicalToEditor();

        expect(
          readiness.status,
          CanonicalEditorMaterializationStatus.blockedMissingGeometry,
        );
        expect(blocked, same(readiness));
        expect(fixture.workspace.editor.level.id, beforeLevel);
        expect(fixture.workspace.editor.selectedSpaceId, beforeSpace);
      },
    );

    test('unexpected initial push failure rolls listeners back', () {
      final errors = <Object>[];
      final fixture = _fixture(
        legacyBuildingId: 'wrong-legacy-building',
        onError: (error, _) => errors.add(error),
      );

      expect(fixture.binding.start, throwsA(anything));
      expect(fixture.binding.isStarted, isFalse);
      expect(errors, hasLength(1));

      fixture.workspace.editor.notifyListeners();
      expect(errors, hasLength(1));
    });

    test('dispose detaches legacy listeners', () {
      final observed = <ProjectNavigationState>[];
      final fixture = _fixture(onNavigationChanged: observed.add);
      fixture.binding.start();
      observed.clear();
      fixture.binding.dispose();

      fixture.workspace.editor.selectSpace('legacy-space-1');

      expect(observed, isEmpty);
      expect(fixture.binding.isStarted, isFalse);
    });
  });
}

final class _Fixture {
  const _Fixture({
    required this.session,
    required this.workspace,
    required this.binding,
  });

  final ProjectStructureAuthoringSession session;
  final EditorBuildingWorkspace workspace;
  final CanonicalEditorScreenCutoverBinding binding;
}

_Fixture _fixture({
  String initialLevelId = 'level-1',
  bool bindSpace = true,
  String legacyBuildingId = 'legacy-building-1',
  void Function(ProjectNavigationState navigation)? onNavigationChanged,
  void Function(CanonicalEditorMaterializationResult result)? onBlocked,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  final project = _project();
  final initialNavigation = ProjectNavigationState.initial(project)
      .activateLevel(project, LevelId(initialLevelId));
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(31)),
    navigation: initialNavigation,
  );
  final workspace = _workspace();
  final adapter = CanonicalEditorWorkspaceAdapter(
    workspace: workspace,
    binding: CanonicalEditorWorkspaceBinding(
      buildingId: BuildingId('building-1'),
      legacyBuildingId: legacyBuildingId,
      legacyLevelIds: <LevelId, String>{
        LevelId('level-1'): 'legacy-level-1',
        LevelId('level-2'): 'legacy-level-2',
      },
      legacySpaceIds: bindSpace
          ? <SpaceId, String>{SpaceId('space-1'): 'legacy-space-1'}
          : const <SpaceId, String>{},
    ),
  );
  final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
    session: session,
    adapter: adapter,
  );
  final binding = CanonicalEditorScreenCutoverBinding(
    coordinator: coordinator,
    onCanonicalNavigationChanged: onNavigationChanged,
    onBlocked: onBlocked,
    onError: onError,
  );
  return _Fixture(session: session, workspace: workspace, binding: binding);
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final space1 = SpaceId('space-1');
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
          spaceIds: <SpaceId>[space1],
        ),
        level2: ProjectLevelEntity(
          id: level2,
          buildingId: buildingId,
          name: 'Floor 2',
          levelNumber: 2,
          elevationMm: 3000,
        ),
      },
      zones: const <ZoneId, ProjectStructuralZoneEntity>{},
      spaces: <SpaceId, ProjectSpaceEntity>{
        space1: ProjectSpaceEntity(
          id: space1,
          levelId: level1,
          name: 'Room',
        ),
      },
    ),
  );
}

EditorBuildingWorkspace _workspace() {
  final boundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(3000, 3000),
  );
  final space = EngineeringSpace(
    id: 'legacy-space-1',
    name: 'Room',
    type: SpaceType.room,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
  final level1Geometry = BuildingLevel(
    id: 'legacy-level-1',
    name: 'Floor 1',
    elevationMm: 0,
    spaces: <EngineeringSpace>[space],
  );
  final level2Geometry = BuildingLevel(
    id: 'legacy-level-2',
    name: 'Floor 2',
    elevationMm: 3000,
    spaces: const <EngineeringSpace>[],
  );
  final level1 = ComposedBuildingLevel(
    level: level1Geometry,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
  );
  final level2 = ComposedBuildingLevel(
    level: level2Geometry,
    levelNumber: 2,
    kind: BuildingLevelKind.residential,
  );
  final buildingGeometry = Building(
    id: 'legacy-building-1',
    name: 'Building',
    levels: <BuildingLevel>[level1Geometry, level2Geometry],
  );
  final building = ComposedBuilding(
    building: buildingGeometry,
    levels: <ComposedBuildingLevel>[level1, level2],
  );
  final site = ComposedProjectSite(
    site: ProjectSite(
      id: 'legacy-site-1',
      name: 'Site',
      buildings: <Building>[buildingGeometry],
    ),
  );
  final editor = EditorController.restored(
    level: level1Geometry,
    openings: const [],
  );
  return EditorBuildingWorkspace(
    editor: editor,
    building: building,
    site: site,
    initialLevelNumber: 1,
  );
}
