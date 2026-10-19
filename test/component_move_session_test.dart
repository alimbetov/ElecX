import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_move_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel restores original component position exactly', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    final surface = controller.activeSurface!;
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1200, 300),
    );

    expect(controller.componentMove.begin(), isTrue);
    expect(
      controller.componentMove.preview(
        const SurfacePointMm(1800, 500),
        isValid: true,
      ),
      isTrue,
    );
    expect(controller.p2.selectedComponent!.position.xMm, 1800);

    controller.componentMove.cancel();
    final restored = controller.p2.components.singleWhere(
      (item) => item.id == component.id,
    );
    expect(restored.position.xMm, 1200);
    expect(restored.position.yMm, 300);
  });

  test('commit stores preview as one completed move', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 300),
    );

    expect(controller.componentMove.begin(), isTrue);
    expect(
      controller.componentMove.preview(
        const SurfacePointMm(1500, 300),
        isValid: true,
      ),
      isTrue,
    );
    expect(controller.componentMove.commit(), isTrue);
    expect(controller.componentMove.active, isFalse);
    expect(controller.p2.selectedComponent!.position.xMm, 1500);
  });

  test('invalid preview is exposed but cannot be committed', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 300),
    );

    expect(controller.componentMove.begin(), isTrue);
    expect(
      controller.componentMove.preview(
        const SurfacePointMm(-100, 300),
        isValid: false,
      ),
      isFalse,
    );
    expect(controller.componentMove.state!.isValid, isFalse);
    expect(controller.componentMove.commit(), isFalse);

    controller.componentMove.cancel();
    expect(controller.p2.selectedComponent!.position.xMm, 1000);
  });
}
