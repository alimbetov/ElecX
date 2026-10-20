import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace switches deterministically between floor 7 B1 and B30', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(workspace.dispose);
    addTearDown(editor.dispose);

    workspace.selectLevel(7);
    expect(workspace.activeLevelNumber, 7);
    expect(editor.level.name, 'Этаж 7');
    expect(editor.level.spaces, isNotEmpty);

    workspace.selectLevel(-1);
    expect(workspace.activeLevelNumber, -1);
    expect(editor.level.name, 'Подвал 1');
    expect(
      editor.level.spaces.any((space) => space.type == SpaceType.corridor),
      isTrue,
    );

    workspace.selectLevel(-30);
    expect(workspace.activeLevelNumber, -30);
    expect(editor.level.name, 'Подвал 30');
  });

  test('residential level keeps apartments and common corridor separate', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(workspace.dispose);
    addTearDown(editor.dispose);

    workspace.selectLevel(7);
    final level = workspace.activeLevel!;
    expect(level.apartments, hasLength(2));

    final common = level.zones.singleWhere(
      (zone) => zone.kind == BuildingZoneKind.common,
    );
    expect(common.spaceIds, hasLength(1));
    final corridorId = common.spaceIds.single;
    final corridor = level.level.spaces.singleWhere(
      (space) => space.id == corridorId,
    );
    expect(corridor.type, SpaceType.corridor);

    for (final apartment in level.apartments) {
      expect(apartment.spaceIds.contains(corridorId), isFalse);
    }
  });

  test('selecting an apartment selects one of its rooms in editor', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(workspace.dispose);
    addTearDown(editor.dispose);

    workspace.selectLevel(5);
    final apartment = workspace.activeLevel!.apartments.first;
    workspace.selectZone(apartment.id);

    expect(workspace.selectedZoneId, apartment.id);
    expect(apartment.spaceIds.contains(editor.selectedSpaceId), isTrue);
  });

  test('yard context projects site geometry into the shared plan editor', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(workspace.dispose);
    addTearDown(editor.dispose);

    workspace.selectOutdoorZone('yard-main');

    expect(workspace.context, EditorWorkspaceContext.siteOutdoor);
    expect(workspace.activeOutdoorZoneId, 'yard-main');
    expect(editor.level.id, 'site:yard-main');
    expect(editor.level.spaces, hasLength(1));
    expect(editor.level.spaces.single.type, SpaceType.outdoorArea);
    expect(editor.viewMode, EditorViewMode.plan);
  });

  test('project north updates site state and survives level switches', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(workspace.dispose);
    addTearDown(editor.dispose);

    workspace.updateProjectNorth(
      workspace.site.site.projectNorth.copyWith(northAzimuthDegrees: 37.5),
    );
    expect(workspace.site.site.projectNorth.northAzimuthDegrees, 37.5);

    workspace.selectLevel(7);
    workspace.selectLevel(-1);
    expect(workspace.site.site.projectNorth.northAzimuthDegrees, 37.5);
  });

  test('next and previous level traverse physical level order', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(workspace.dispose);
    addTearDown(editor.dispose);

    workspace.selectLevel(-2);
    workspace.nextLevel();
    expect(workspace.activeLevelNumber, -1);

    workspace.nextLevel();
    expect(workspace.activeLevelNumber, 1);

    workspace.previousLevel();
    expect(workspace.activeLevelNumber, -1);
  });
}
