import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snap rounds coordinates to the selected room grid', () {
    final controller = EditorController.demo();
    expect(controller.snap(const MmPoint(1149, 1262)), const MmPoint(1100, 1300));
  });

  test('rectangle room gets a centered local reference frame', () {
    final controller = EditorController.demo();
    controller.addRectangleRoom(const MmPoint(6000, 1000), const MmPoint(9000, 4000));
    final room = controller.selectedSpace!;
    expect(room.referenceFrame.origin, const MmPoint(7500, 2500));
    expect(room.boundary.bounds.width, 3000);
    expect(room.boundary.bounds.height, 3000);
  });
}
