import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/wall_profile_editor_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('existing top notch is replaced by new X width and depth parameters', () {
    final controller = EditorController.demo();
    controller.showWall(1);

    expect(
      controller.addActiveWallTopNotch(
        startMm: 600,
        widthMm: 700,
        depthMm: 250,
      ),
      isTrue,
    );
    expect(controller.activeWallTopNotch, isNotNull);

    expect(
      controller.addActiveWallTopNotch(
        startMm: 900,
        widthMm: 850,
        depthMm: 400,
      ),
      isTrue,
    );

    final edited = controller.activeWallTopNotch!;
    expect(edited.startMm, 900);
    expect(edited.widthMm, 850);
    expect(edited.depthMm, 400);
    expect(edited.endMm, 1750);
  });

  test('invalid beam parameters leave existing notch unchanged', () {
    final controller = EditorController.demo();
    controller.showWall(1);
    expect(
      controller.addActiveWallTopNotch(
        startMm: 600,
        widthMm: 700,
        depthMm: 250,
      ),
      isTrue,
    );
    final before = controller.activeWallTopNotch!;

    expect(
      controller.addActiveWallTopNotch(
        startMm: 50000,
        widthMm: 700,
        depthMm: 250,
      ),
      isFalse,
    );

    final after = controller.activeWallTopNotch!;
    expect(after.startMm, before.startMm);
    expect(after.widthMm, before.widthMm);
    expect(after.depthMm, before.depthMm);
  });
}
