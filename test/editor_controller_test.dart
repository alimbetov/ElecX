import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/engine/snap_engine.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan snap prefers nearby endpoint over grid', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    final result = controller.resolvePlanSnap(const MmPoint(1040, 1240));

    expect(result, isNotNull);
    expect(result!.kind, SnapKind.endpoint);
    expect(result.point, const MmPoint(1000, 1200));
  });

  test('plan snap uses grid when no higher-priority geometry is in range', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    expect(
      controller.snap(const MmPoint(6749, 3262)),
      const MmPoint(6700, 3300),
    );
  });

  test('rectangle room gets a centered local reference frame', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    controller.addRectangleRoom(
      const MmPoint(6000, 1000),
      const MmPoint(9000, 4000),
    );
    final room = controller.selectedSpace!;
    expect(room.referenceFrame.origin, const MmPoint(7500, 2500));
    expect(room.boundary.bounds.width, 3000);
    expect(room.boundary.bounds.height, 3000);
  });
}
