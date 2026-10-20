import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/electrical_host_geometry_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('door parameters mutate selected opening and preserve selection', () {
    final controller = EditorController.demo();
    controller.showWall(0);
    controller.selectOpening('door-101-a');

    expect(controller.selectedOpening, isNotNull);
    expect(
      controller.updateSelectedOpeningGuarded(
        offsetFromStartMm: 800,
        widthMm: 1000,
        heightMm: 2200,
        sillHeightMm: 0,
      ),
      isTrue,
    );

    final edited = controller.selectedOpening!;
    expect(edited.id, 'door-101-a');
    expect(edited.type, ArchitecturalOpeningType.door);
    expect(edited.offsetFromStartMm, 800);
    expect(edited.widthMm, 1000);
    expect(edited.heightMm, 2200);
    expect(edited.sillHeightMm, 0);
    expect(controller.selectedOpeningId, 'door-101-a');
  });

  test('window sill and dimensions mutate selected opening', () {
    final controller = EditorController.demo();
    controller.showWall(2);
    controller.selectOpening('window-101-a');

    expect(
      controller.updateSelectedOpeningGuarded(
        offsetFromStartMm: 1200,
        widthMm: 1500,
        heightMm: 1300,
        sillHeightMm: 850,
      ),
      isTrue,
    );

    final edited = controller.selectedOpening!;
    expect(edited.type, ArchitecturalOpeningType.window);
    expect(edited.offsetFromStartMm, 1200);
    expect(edited.widthMm, 1500);
    expect(edited.heightMm, 1300);
    expect(edited.sillHeightMm, 850);
  });

  test('invalid opening dimensions are rejected without mutating model', () {
    final controller = EditorController.demo();
    controller.showWall(0);
    controller.selectOpening('door-101-a');
    final before = controller.selectedOpening!;

    expect(controller.updateSelectedOpeningGuarded(widthMm: 99999), isFalse);

    final after = controller.selectedOpening!;
    expect(after.widthMm, before.widthMm);
    expect(after.offsetFromStartMm, before.offsetFromStartMm);
  });
}
