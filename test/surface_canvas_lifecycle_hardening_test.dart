import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disposing canvas cancels active component preview exactly',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(1);
    final original = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 500),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SurfaceCanvas(controller: controller))),
    );
    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(2000, 500),
        isValid: true,
      ),
      isTrue,
    );
    expect(controller.p2.selectedComponent!.position.xMm, 2000);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(controller.componentTransform.active, isFalse);
    expect(controller.p2.isManipulating, isFalse);
    expect(controller.p2.selectedComponent!.position, original.position);
  });
}
