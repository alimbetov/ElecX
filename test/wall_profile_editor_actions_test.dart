import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/wall_profile_editor_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active wall notch can be applied and reset from editor actions', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    controller.showWall(0);

    final applied = controller.addActiveWallTopNotch(
      startMm: 2000,
      widthMm: 600,
      depthMm: 300,
    );

    expect(applied, isTrue);
    expect(controller.selectedSpace!.wallProfiles.containsKey(0), isTrue);

    final reset = controller.resetActiveWallProfile();

    expect(reset, isTrue);
    expect(controller.selectedSpace!.wallProfiles.containsKey(0), isFalse);
  });

  test('invalid notch does not mutate wall profile', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    controller.showWall(0);

    final applied = controller.addActiveWallTopNotch(
      startMm: 4000,
      widthMm: 1000,
      depthMm: 300,
    );

    expect(applied, isFalse);
    expect(controller.selectedSpace!.wallProfiles.containsKey(0), isFalse);
  });

  test('notch that would intersect an existing door is rejected atomically',
      () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    controller.showWall(0);

    final applied = controller.addActiveWallTopNotch(
      startMm: 500,
      widthMm: 1200,
      depthMm: 1000,
    );

    expect(applied, isFalse);
    expect(controller.selectedSpace!.wallProfiles.containsKey(0), isFalse);
    expect(controller.activeWallOpenings, hasLength(1));
  });
}
