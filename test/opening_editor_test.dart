import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/electrical_host_geometry_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening position and dimensions update when they fit wall', () {
    final controller = EditorController.demo();
    controller.showWall(0);
    final opening = controller.activeWallOpenings.single;
    controller.selectOpening(opening.id);

    final updated = controller.updateSelectedOpeningGuarded(
      offsetFromStartMm: 900,
      widthMm: 1000,
      heightMm: 2200,
    );

    expect(updated, isTrue);
    expect(controller.selectedOpening?.offsetFromStartMm, 900);
    expect(controller.selectedOpening?.widthMm, 1000);
    expect(controller.selectedOpening?.heightMm, 2200);
  });

  test('opening edit is rejected when opening exceeds wall', () {
    final controller = EditorController.demo();
    controller.showWall(0);
    final opening = controller.activeWallOpenings.single;
    controller.selectOpening(opening.id);

    final updated = controller.updateSelectedOpeningGuarded(
      offsetFromStartMm: 3900,
      widthMm: 1000,
    );

    expect(updated, isFalse);
    expect(controller.selectedOpening?.offsetFromStartMm, 650);
    expect(controller.selectedOpening?.widthMm, 900);
  });

  test('window sill plus height cannot exceed wall height', () {
    final controller = EditorController.demo();
    controller.showWall(2);
    final opening = controller.activeWallOpenings.single;
    controller.selectOpening(opening.id);

    final updated = controller.updateSelectedOpeningGuarded(
      sillHeightMm: 2000,
      heightMm: 1400,
    );

    expect(updated, isFalse);
    expect(controller.selectedOpening?.sillHeightMm, 900);
  });
}
