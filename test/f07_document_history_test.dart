import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F07 document undo/redo follows architecture and electrical chronology',
    () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);
      final history = controller.documentHistory;

      controller.showWall(0);
      final surface = controller.activeSurface!;
      final component = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1000, 300),
      );
      expect(history.undoDepth, 1);

      controller.showPlan();
      controller.addRectangleRoom(
        const MmPoint(12000, 1000),
        const MmPoint(15000, 4000),
      );
      controller.selectSpace(controller.selectedSpaceId);
      expect(history.undoDepth, 2);
      final addedRoomId = controller.selectedSpaceId;
      expect(
        controller.level.spaces.any((space) => space.id == addedRoomId),
        isTrue,
      );

      controller.showWall(0);
      controller.p2.select(component.id);
      expect(controller.p2.beginMoveSelectedComponent(), isTrue);
      expect(
        controller.p2.previewMoveSelectedComponent(
          const SurfacePointMm(1200, 400),
        ),
        isTrue,
      );
      expect(controller.p2.commitMoveSelectedComponent(), isTrue);
      expect(history.undoDepth, 3);

      expect(history.undo(), isTrue);
      expect(controller.p2.selectedComponent!.position, component.position);
      expect(
        controller.level.spaces.any((space) => space.id == addedRoomId),
        isTrue,
      );

      expect(history.undo(), isTrue);
      expect(
        controller.level.spaces.any((space) => space.id == addedRoomId),
        isFalse,
      );
      expect(controller.p2.components.single.id, component.id);

      expect(history.undo(), isTrue);
      expect(controller.p2.components, isEmpty);
      expect(history.canUndo, isFalse);

      expect(history.redo(), isTrue);
      expect(controller.p2.components.single.id, component.id);
      expect(history.redo(), isTrue);
      expect(
        controller.level.spaces.any((space) => space.id == addedRoomId),
        isTrue,
      );
      expect(history.redo(), isTrue);
      expect(
        controller.p2.components.single.position,
        const SurfacePointMm(1200, 400),
      );
    },
  );

  test(
    'F07 transient selection and viewport changes do not create history',
    () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);
      final history = controller.documentHistory;

      controller.selectSpace('corridor-1');
      controller.setZoom(2);
      controller.setSnapEnabled(false);
      controller.showPlan();
      expect(history.undoDepth, 0);

      controller.showWall(0);
      final component = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: controller.activeSurface!,
        position: const SurfacePointMm(600, 300),
      );
      expect(history.undoDepth, 1);
      controller.p2.select(component.id);
      controller.p2.clearSelection();
      expect(history.undoDepth, 1);
    },
  );

  test(
    'F07 local P2 undo outside journal fails closed by clearing timeline',
    () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);
      final history = controller.documentHistory;

      controller.showWall(0);
      controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: controller.activeSurface!,
        position: const SurfacePointMm(600, 300),
      );
      expect(history.canUndo, isTrue);

      controller.p2.undo();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    },
  );
}
