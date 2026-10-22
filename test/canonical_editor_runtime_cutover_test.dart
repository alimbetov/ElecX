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
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C canonical editor runtime cutover coordinator', () {
    test('push opens exact bound Space and returns phase to idle', () {
      final fixture = _fixture();
      fixture.session.selectRoom(SpaceId('space-1'));

      fixture.coordinator.pushCanonicalToEditor();

      expect(fixture.workspace.editor.level.id, 'legacy-level-1');
      expect(fixture.workspace.editor.selectedSpaceId, 'legacy-space-1');
      expect(fixture.coordinator.phase, CanonicalEditorCutoverPhase.idle);
    });

    test('listener feedback is suppressed during canonical push', () {
      final fixture = _fixture();
      fixture.session.selectRoom(SpaceId('space-1'));
      var listenerCalls = 0;
      var nestedPulls = 0;
      fixture.workspace.addListener(() {
        listenerCalls++;
        if (fixture.coordinator.pullLegacyToCanonical() != null) {
          nestedPulls++;
        }
      });

      fixture.coordinator.pushCanonicalToEditor();

      expect(listenerCalls, greaterThan(0));
      expect(nestedPulls, 0);
      expect(fixture.coordinator.phase, CanonicalEditorCutoverPhase.idle);
      expect(fixture.session.navigation.selectedSpaceId, SpaceId('space-1'));
    });

    test('legacy selection is pulled back into canonical navigation', () {
      final fixture = _fixture();
      fixture.workspace.editor.selectSpace('legacy-space-1');

      final navigation = fixture.coordinator.pullLegacyToCanonical();

      expect(navigation, isNotNull);
      expect(fixture.session.navigation.activeLevelId, LevelId('level-1'));
      expect(fixture.session.navigation.selectedSpaceId, SpaceId('space-1'));
      expect(fixture.coordinator.phase, CanonicalEditorCutoverPhase.idle);
    });

    test(
      'unmaterialized canonical Space is blocked without canvas mutation',
      () {
        final fixture = _fixture(bindSpace: false);
        fixture.session.selectRoom(SpaceId('space-1'));
        final beforeLevel = fixture.workspace.editor.level.id;
        final beforeSpace = fixture.workspace.editor.selectedSpaceId;

        expect(
          fixture.coordinator.inspectCurrentTarget().status,
          CanonicalEditorMaterializationStatus.blockedMissingGeometry,
        );
        expect(
          fixture.coordinator.pushCanonicalToEditor,
          throwsA(
            isA<CanonicalEditorCutoverBlockedException>().having(
              (error) => error.result.status,
              'status',
              CanonicalEditorMaterializationStatus.blockedMissingGeometry,
            ),
          ),
        );
        expect(fixture.workspace.editor.level.id, beforeLevel);
        expect(fixture.workspace.editor.selectedSpaceId, beforeSpace);
        expect(fixture.coordinator.phase, CanonicalEditorCutoverPhase.idle);
      },
    );

    test('materializable is not treated as already openable', () {
      final fixture = _fixture(
        materializer: const _AlwaysMaterializableMaterializer(),
      );
      final readiness = fixture.coordinator.inspectCurrentTarget();

      expect(readiness.canMaterialize, isTrue);
      expect(readiness.canOpen, isFalse);
      expect(
        fixture.coordinator.pushCanonicalToEditor,
        throwsA(
          isA<CanonicalEditorCutoverBlockedException>().having(
            (error) => error.result.status,
            'status',
            CanonicalEditorMaterializationStatus.materializable,
          ),
        ),
      );
    });
  });
}

final class _AlwaysMaterializableMaterializer
    implements CanonicalEditorMaterializer {
  const _AlwaysMaterializableMaterializer();

  @override
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  }) {
    return const CanonicalEditorMaterializationResult(
      status: CanonicalEditorMaterializationStatus.materializable,
    );
  }
}

final class _Fixture {
  const _Fixture({
    required this.session,
    required this.workspace,
    required this.coordinator,
  });

  final ProjectStructureAuthoringSession session;
  final EditorBuildingWorkspace workspace;
  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
}

_Fixture _fixture({
  bool bindSpace = true,
  CanonicalEditorMaterializer materializer =
      const ExistingBindingCanonicalEditorMaterializer(),
}) {
  final project = _project();
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(5)),
  );
  final workspace = _workspace();
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: BuildingId('building-1'),
    legacyBuildingId: 'legacy-building-1',
    legacyLevelIds: <LevelId, String>{LevelId('level-1'): 'legacy-level-1'},
    legacySpaceIds: bindSpace
        ? <SpaceId, String>{SpaceId('space-1'): 'legacy-space-1'}
        : const <SpaceId, String>{},
  );
  final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
    session: session,
    adapter: CanonicalEditorWorkspaceAdapter(
      workspace: workspace,
      binding: binding,
    ),
    materializer: materializer,
  );
  return _Fixture(
    session: session,
    workspace: workspace,
    coordinator: coordinator,
  );
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final spaceId = SpaceId('space-1');
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
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      zones: const <ZoneId, ProjectStructuralZoneEntity>{},
      spaces: <SpaceId, ProjectSpaceEntity>{
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
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
  final geometry = BuildingLevel(
    id: 'legacy-level-1',
    name: 'Floor 1',
    elevationMm: 0,
    spaces: <EngineeringSpace>[space],
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
  final editor = EditorController.restored(level: geometry, openings: const []);
  final site = ComposedProjectSite(
    site: ProjectSite(
      id: 'legacy-site-1',
      name: 'Site',
      buildings: <Building>[buildingGeometry],
    ),
  );
  return EditorBuildingWorkspace(
    editor: editor,
    building: building,
    site: site,
    initialLevelNumber: 1,
  );
}
