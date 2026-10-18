import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/plan_geometry_editor_actions.dart';
import 'package:elecx/src/features/editor/wall_profile_editor_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active wall nudges only along its normal', () {
    final controller = EditorController.demo();
    controller.showWall(0);
    final before = controller.selectedSpace!.boundary.vertices;

    expect(controller.nudgeActiveWallNormal(100), isTrue);

    final after = controller.selectedSpace!.boundary.vertices;
    expect(after[0].x, before[0].x);
    expect(after[1].x, before[1].x);
    expect(after[0].y, before[0].y + 100);
    expect(after[1].y, before[1].y + 100);
  });

  test('external boundary is movable but shared boundary hides movement', () {
    final controller = EditorController.demo();
    final roomA = _space('a', 0, 0, 4000, 3000);
    final roomB = _space('b', 4000, 0, 8000, 3000);
    controller.level = BuildingLevel(
      id: 'shared',
      name: 'Shared',
      elevationMm: 0,
      spaces: [roomA, roomB],
    );
    controller.openings = [];
    controller.selectSpace(roomA.id);

    expect(controller.isSelectedWallExternal(0), isTrue);
    expect(controller.isSelectedWallExternal(1), isFalse);

    final sharedBefore = controller.selectedSpace!.boundary.vertices;
    expect(controller.nudgeSelectedBoundaryEdgeNormal(1, 100), isFalse);
    expect(controller.selectedSpace!.boundary.vertices, sharedBefore);

    expect(controller.nudgeSelectedBoundaryEdgeNormal(0, 100), isTrue);
  });

  test('partial collinear overlap is treated as shared wall', () {
    final controller = EditorController.demo();
    final roomA = _space('a', 0, 0, 4000, 3000);
    final roomB = _space('b', 4000, 1000, 7000, 2500);
    controller.level = BuildingLevel(
      id: 'partial-shared',
      name: 'Partial shared',
      elevationMm: 0,
      spaces: [roomA, roomB],
    );
    controller.openings = [];
    controller.selectSpace(roomA.id);

    expect(controller.isSelectedWallExternal(1), isFalse);
  });

  test('opening nudges along host wall and rejects outside position', () {
    final controller = EditorController.demo();
    final opening = controller.openings.first;
    controller.selectOpening(opening.id);

    expect(controller.nudgeSelectedOpening(100), isTrue);
    expect(
      controller.selectedOpening!.offsetFromStartMm,
      opening.offsetFromStartMm + 100,
    );

    final beforeInvalid = controller.selectedOpening!.offsetFromStartMm;
    expect(controller.nudgeSelectedOpening(100000), isFalse);
    expect(controller.selectedOpening!.offsetFromStartMm, beforeInvalid);
  });

  test('beam notch nudges horizontally and by depth', () {
    final controller = EditorController.demo();
    controller.showWall(1);

    expect(
      controller.addActiveWallTopNotch(
        startMm: 600,
        widthMm: 700,
        depthMm: 200,
      ),
      isTrue,
    );
    final initial = controller.activeWallTopNotch!;

    expect(controller.nudgeActiveWallTopNotchX(100), isTrue);
    final moved = controller.activeWallTopNotch!;
    expect(moved.startMm, initial.startMm + 100);
    expect(moved.widthMm, initial.widthMm);
    expect(moved.depthMm, initial.depthMm);

    expect(controller.nudgeActiveWallTopNotchDepth(100), isTrue);
    final deeper = controller.activeWallTopNotch!;
    expect(deeper.startMm, moved.startMm);
    expect(deeper.widthMm, moved.widthMm);
    expect(deeper.depthMm, moved.depthMm + 100);
  });

  test('beam notch cannot leave wall bounds', () {
    final controller = EditorController.demo();
    controller.showWall(1);
    expect(
      controller.addActiveWallTopNotch(
        startMm: 600,
        widthMm: 700,
        depthMm: 200,
      ),
      isTrue,
    );
    final before = controller.activeWallTopNotch!;

    expect(controller.nudgeActiveWallTopNotchX(100000), isFalse);
    final after = controller.activeWallTopNotch!;
    expect(after.startMm, before.startMm);
    expect(after.widthMm, before.widthMm);
    expect(after.depthMm, before.depthMm);
  });
}

EngineeringSpace _space(
  String id,
  int left,
  int bottom,
  int right,
  int top,
) {
  final boundary = MmPolygon.rectangle(
    MmPoint(left, bottom),
    MmPoint(right, top),
  );
  return EngineeringSpace(
    id: id,
    name: id,
    type: SpaceType.room,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}
