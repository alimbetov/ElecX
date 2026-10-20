import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/cable_edit_access.dart';
import 'package:elecx/src/features/editor/cable_editor_ui_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewportSize = Size(800, 600);
  const fitPaddingPx = 88.0;
  const gestureDrain = Duration(milliseconds: 60);

  double mmPerPixel(EditorController controller) {
    final wall = controller.activeWall!;
    final usableWidth = viewportSize.width - fitPaddingPx * 2;
    final usableHeight = viewportSize.height - fitPaddingPx * 2;
    final widthScale = wall.lengthMm / usableWidth;
    final heightScale = wall.heightMm / usableHeight;
    return widthScale > heightScale ? widthScale : heightScale;
  }

  Offset viewportPoint(
    EditorController controller,
    SurfacePointMm point,
  ) {
    final wall = controller.activeWall!;
    final scale = mmPerPixel(controller);
    return Offset(
      viewportSize.width / 2 + (point.xMm - wall.lengthMm / 2) / scale,
      viewportSize.height / 2 - (point.yMm - wall.heightMm / 2) / scale,
    );
  }

  Future<void> pumpCanvas(
    WidgetTester tester,
    EditorController controller,
  ) async {
    await tester.binding.setSurfaceSize(viewportSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorKeyboardScope(
            controller: controller,
            child: SurfaceCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'mandatory waypoint stays fixed while an unrelated segment is dragged',
    (tester) async {
      final controller = EditorController.demo();
      controller.showWall(1);
      addTearDown(controller.dispose);
      final surface = controller.activeSurface!;

      final source = controller.p2.placeComponent(
        type: ElectricalComponentType.powerSource,
        surface: surface,
        position: const SurfacePointMm(600, 400),
      );
      final target = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(2600, 2200),
      );
      controller.p2.select(source.id);
      controller.p2.select(target.id, mode: SelectionMode.add);
      expect(
        controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
        isTrue,
      );

      final generated = controller.p2.routes.single;
      const waypoint = SurfacePointMm(1400, 1000);
      final engineered = ElectricalCableRoute(
        id: generated.id,
        source: generated.source,
        target: generated.target,
        segments: [
          ElectricalRouteSegment(
            surface: surface,
            points: const [
              SurfacePointMm(600, 400),
              SurfacePointMm(600, 1000),
              waypoint,
              SurfacePointMm(1400, 2200),
              SurfacePointMm(2600, 2200),
            ],
          ),
        ],
        cableType: generated.cableType,
        medium: generated.medium,
        reservePercent: generated.reservePercent,
      );
      expect(controller.p2.replaceCableRoute(generated, engineered), isTrue);
      expect(
        controller.p2.toggleRouteWaypoint(
          routeId: engineered.id,
          segmentIndex: 0,
          pointIndex: 2,
          point: waypoint,
        ),
        isTrue,
      );
      controller.routeSelection.select(engineered.id);
      controller.cableUi.setMode(CableRoutingMode.assisted);
      final depthBefore = controller.p2.history.undoDepth;

      await pumpCanvas(tester, controller);
      final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
      const edgeMidpoint = SurfacePointMm(2000, 2200);
      const dragTarget = SurfacePointMm(2000, 2500);

      final gesture = await tester.startGesture(
        origin + viewportPoint(controller, edgeMidpoint),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(origin + viewportPoint(controller, dragTarget));
      await tester.pump();

      expect(controller.cableRouteEdit.active, isTrue);
      final preview = controller.cableRouteEdit.previewState;
      expect(preview, isNotNull);
      expect(preview!.validation.isValid, isTrue);
      expect(preview.route.segments.single.points, contains(waypoint));
      expect(
        preview.route.segments.single.points.first,
        engineered.segments.single.points.first,
      );
      expect(
        preview.route.segments.single.points.last,
        engineered.segments.single.points.last,
      );

      await gesture.up();
      await tester.pump(gestureDrain);

      final committed = controller.p2.routes.single;
      expect(committed.segments.single.points, contains(waypoint));
      expect(
        committed.segments.single.points,
        isNot(engineered.segments.single.points),
      );
      expect(controller.p2.history.undoDepth, depthBefore + 1);
      expect(
        controller.p2.routeConstraintsFor(committed.id).mandatoryWaypoints,
        hasLength(1),
      );
      expect(
        controller.p2.routeConstraintsFor(committed.id).mandatoryWaypoints.single.point,
        waypoint,
      );

      controller.p2.undo();
      expect(controller.p2.routes.single.segments.single.points,
          engineered.segments.single.points);
      expect(
        controller.p2.routeConstraintsFor(engineered.id).mandatoryWaypoints.single.point,
        waypoint,
      );
    },
  );
}
