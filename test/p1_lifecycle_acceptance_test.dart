import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/engine/world_camera.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/electrical_host_geometry_guard.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/editable_spatial_canvas.dart';
import 'package:elecx/src/features/editor/plan_geometry_editor_actions.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};

  @override
  Future<void> save(EditorProjectDocument document) async {
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async =>
      documents[projectId];

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List.unmodifiable(documents.values);
}

final class _MemoryRecoveryStore implements EditorProjectRecoveryStore {
  final Map<String, EditorProjectRecoverySnapshot> snapshots = {};
  int saves = 0;

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    saves++;
    snapshots[snapshot.projectId] = snapshot;
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async =>
      snapshots[projectId];

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async =>
      List.unmodifiable(snapshots.values);

  @override
  Future<void> discard(String projectId) async {
    snapshots.remove(projectId);
  }
}

EditorProjectDocument _savedDocument() {
  final editor = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(editor);
  final document = EditorProjectDocument.capture(
    workspace,
    metadata: EditorProjectMetadata.create(projectName: 'P1 lifecycle'),
  );
  workspace.dispose();
  editor.disposeP2State();
  editor.dispose();
  return document;
}

void main() {
  testWidgets(
    'F01 electrical mutation changes Saved to Modified and autosaves recovery',
    (tester) async {
      final projects = _MemoryProjectStore();
      final recovery = _MemoryRecoveryStore();
      final document = _savedDocument();
      projects.documents[document.projectId] = document;

      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: projects,
            recoveryStore: recovery,
            autosaveDelay: const Duration(milliseconds: 10),
            initialDocument: document,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      final spatialCanvas = tester.widget<SpatialCanvas>(
        find.byType(SpatialCanvas),
      );
      final controller = spatialCanvas.controller;
      controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.floor(controller.selectedSpace!.id),
        position: const SurfacePointMm(1000, 500),
      );
      await tester.pump();

      expect(find.text('Modified'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(recovery.saves, greaterThanOrEqualTo(1));
      expect(recovery.snapshots[document.projectId], isNotNull);
    },
  );

  testWidgets(
    'F01 selection-only and preview-cancel keep saved project clean',
    (tester) async {
      final projects = _MemoryProjectStore();
      final recovery = _MemoryRecoveryStore();
      final document = _savedDocument();
      projects.documents[document.projectId] = document;

      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: projects,
            recoveryStore: recovery,
            autosaveDelay: const Duration(milliseconds: 10),
            initialDocument: document,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      final spatialCanvas = tester.widget<SpatialCanvas>(
        find.byType(SpatialCanvas),
      );
      final controller = spatialCanvas.controller;
      final component = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.floor(controller.selectedSpace!.id),
        position: const SurfacePointMm(1000, 500),
      );
      await tester.pump();
      expect(find.text('Modified'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project-save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      controller.p2.clearSelection();
      controller.p2.select(component.id);
      controller.p2.updateSnap(null);
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);

      expect(controller.componentTransform.begin(), isTrue);
      expect(
        controller.componentTransform.preview(
          const SurfacePointMm(1200, 500),
          isValid: true,
        ),
        isTrue,
      );
      controller.componentTransform.cancel();
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(recovery.snapshots[document.projectId], isNull);
    },
  );

  test(
    'F03 adding an opening across existing cable is rejected atomically',
    () {
      final controller = EditorController.demo();
      addTearDown(() {
        controller.disposeP2State();
        controller.dispose();
      });
      controller.showWall(1);
      final surface = controller.activeSurface!;
      final board = controller.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: surface,
        position: const SurfacePointMm(200, 1000),
      );
      final load = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(2800, 1000),
      );
      controller.p2.select(board.id, mode: SelectionMode.replace);
      controller.p2.select(load.id, mode: SelectionMode.add);
      expect(
        controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
        isTrue,
      );
      final beforeOpenings = List<ArchitecturalOpening>.of(controller.openings);
      final beforeRoute = controller.p2.routes.single;

      expect(
        controller.addOpeningGuarded(
          ArchitecturalOpeningType.door,
          canCommit: (candidate) =>
              ElectricalHostGeometryGuard.openingCandidateAllowed(
                controller,
                candidate,
              ),
        ),
        isFalse,
      );
      expect(controller.openings, orderedEquals(beforeOpenings));
      expect(controller.p2.routes.single.segments, beforeRoute.segments);
    },
  );

  test(
    'F03 shrinking room around electrical component is rejected atomically',
    () {
      final controller = EditorController.demo();
      addTearDown(() {
        controller.disposeP2State();
        controller.dispose();
      });
      final originalBoundary = controller.selectedSpace!.boundary;
      final bounds = originalBoundary.bounds;
      final component = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.floor(controller.selectedSpace!.id),
        position: SurfacePointMm(bounds.width - 100, bounds.height ~/ 2),
      );
      final candidate = MmPolygon.rectangle(
        MmPoint(bounds.left, bounds.bottom),
        MmPoint(bounds.right - 1000, bounds.top),
      );

      expect(controller.commitSelectedBoundary(candidate), isFalse);
      expect(
        controller.selectedSpace!.boundary.vertices,
        originalBoundary.vertices,
      );
      expect(
        controller.p2.components
            .singleWhere((item) => item.id == component.id)
            .position,
        component.position,
      );
    },
  );

  testWidgets('F05 second pointer cancels plan boundary drag without commit', (
    tester,
  ) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.setTool(EditorTool.select);
    final before = controller.selectedSpace!.boundary;
    const size = Size(1000, 700);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(child: SpatialCanvas(controller: controller)),
        ),
      ),
    );
    await tester.pump();

    const camera = WorldCamera(centerMm: MmPoint(5000, 3500), mmPerPixel: 12);
    final vertex = before.vertices.first;
    final screen = camera.worldToScreen(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      point: vertex,
    );
    final canvasTopLeft = tester.getTopLeft(find.byType(SpatialCanvas));
    final start = canvasTopLeft + Offset(screen.x, screen.y);

    final first = await tester.startGesture(start, pointer: 1);
    await first.moveBy(const Offset(80, 0));
    await tester.pump();

    final second = await tester.startGesture(
      canvasTopLeft + const Offset(500, 350),
      pointer: 2,
    );
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pump();

    expect(controller.selectedSpace!.boundary.vertices, before.vertices);
  });

  testWidgets('F06 tool switch cancels active surface component preview', (
    tester,
  ) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final original = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 500),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SurfaceCanvas(controller: controller)),
      ),
    );
    await tester.pump();

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(2200, 500),
        isValid: true,
      ),
      isTrue,
    );
    expect(controller.p2.selectedComponent!.position.xMm, 2200);

    controller.setTool(EditorTool.cableRoute);
    await tester.pump();

    expect(controller.componentTransform.active, isFalse);
    expect(controller.p2.isManipulating, isFalse);
    expect(controller.p2.selectedComponent!.position, original.position);
  });
}
