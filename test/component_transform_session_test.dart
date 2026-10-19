import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transform commit records one accepted preview', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 300),
    );

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.nudge(dxMm: 100, dyMm: 0),
      isTrue,
    );
    expect(controller.componentTransform.validate(), isTrue);
    expect(controller.componentTransform.commit(), isTrue);
    expect(controller.p2.selectedComponent!.position.xMm, 1100);
  });

  test('invalid transform preview can be cancelled exactly', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 300),
    );

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(-100, 300),
        isValid: false,
      ),
      isFalse,
    );
    expect(controller.componentTransform.commit(), isFalse);
    controller.componentTransform.cancel();
    expect(controller.p2.selectedComponent!.position.xMm, 1000);
  });
}
