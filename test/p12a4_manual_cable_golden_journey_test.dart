import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surface_navigation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P12A.4 manual cable Golden Journey', () {
    test(
        'exact board-to-socket port route survives Undo/Redo and fresh Save/Reopen',
        () async {
      final root = await Directory.systemTemp.createTemp('elecx-p12a4-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final editor = EditorController.demo();
      final workspace = EditorBuildingWorkspace.demo(editor);
      editor.showWall(0);
      final wall = editor.activeSurface!;
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: wall,
        position: const SurfacePointMm(500, 1200),
      );
      final socket = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(2200, 1200),
      );
      editor.p2.select(board.id);
      final revision = editor.p2.history.mutationRevision;

      expect(editor.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
      editor.surfaceTap(const SurfacePointMm(1400, 1200));
      expect(
        editor.snapPortDrivenCableCompletionTarget(
          componentId: socket.id,
          portId: 'power-in',
        ),
        isTrue,
      );
      expect(editor.portDrivenCableReadyToFinish, isTrue);
      expect(editor.p2.history.mutationRevision, revision);
      expect(editor.p2.routes, isEmpty);
      expect(() => EditorProjectDocument.capture(workspace), throwsStateError);

      expect(editor.finishManualCableDraft(endpointSnapRadiusMm: 40), isTrue);
      expect(editor.p2.history.mutationRevision, revision + 1);
      expect(editor.p2.routes, hasLength(1));
      final committed = editor.p2.routes.single;
      expect(committed.source.componentId, board.id);
      expect(committed.source.portId, 'power-out');
      expect(committed.target.componentId, socket.id);
      expect(committed.target.portId, 'power-in');
      expect(committed.segments, hasLength(1));
      expect(committed.segments.single.surface, wall);
      expect(committed.segments.single.points.first, board.position);
      expect(committed.segments.single.points.last, socket.position);
      expect(editor.portDrivenCableCompletionBinding, isNull);
      expect(editor.routeSegments, isEmpty);

      editor.p2.undo();
      expect(editor.p2.routes, isEmpty);
      editor.p2.redo();
      expect(editor.p2.routes.single.id, committed.id);

      final document = EditorProjectDocument.capture(workspace);
      final store = JsonFileEditorProjectStore(root);
      await store.save(document);
      final savedRoute = document.p2State.routes.single;
      expect(savedRoute.id, committed.id);
      expect(savedRoute.source.portId, 'power-out');
      expect(savedRoute.target.portId, 'power-in');

      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();

      final reopenedDocument = await store.load(document.projectId);
      expect(reopenedDocument, isNotNull);
      final restored = reopenedDocument!.restore();
      addTearDown(() {
        restored.editor.disposeP2State();
        restored.workspace.dispose();
        restored.editor.dispose();
      });
      expect(restored.editor.p2.components, hasLength(2));
      expect(restored.editor.p2.routes, hasLength(1));
      final reopened = restored.editor.p2.routes.single;
      expect(reopened.id, committed.id);
      expect(reopened.source.componentId, board.id);
      expect(reopened.source.portId, 'power-out');
      expect(reopened.target.componentId, socket.id);
      expect(reopened.target.portId, 'power-in');
      expect(reopened.segments.single.surface, wall);
      expect(reopened.segments.single.points, committed.segments.single.points);
      expect(restored.editor.routeSegments, isEmpty);
      expect(restored.editor.portDrivenCableStartBinding, isNull);

      final repeated = EditorProjectDocument.capture(restored.workspace);
      expect(repeated.p2State.routes.single.id, committed.id);
      expect(repeated.p2State.routes.single.segments.single.points,
          committed.segments.single.points);
    });

    test(
        'target-first guided completion preserves electrical direction and identity',
        () {
      final editor = EditorController.demo();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      editor.showWall(0);
      final wall = editor.activeSurface!;
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: wall,
        position: const SurfacePointMm(500, 1200),
      );
      final socket = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(2200, 1200),
      );
      editor.p2.select(socket.id);
      final revision = editor.p2.history.mutationRevision;
      expect(editor.beginPortDrivenCableFromSelectedPort('power-in'), isTrue);
      editor.surfaceTap(const SurfacePointMm(1400, 1200));
      expect(
        editor.snapPortDrivenCableCompletionTarget(
          componentId: board.id,
          portId: 'power-out',
        ),
        isTrue,
      );
      expect(editor.p2.history.mutationRevision, revision);
      expect(editor.portDrivenCableReadyToFinish, isTrue);
      expect(editor.finishManualCableDraft(endpointSnapRadiusMm: 40), isTrue);
      expect(editor.p2.history.mutationRevision, revision + 1);

      final cable = editor.p2.routes.single;
      expect(cable.source.componentId, board.id);
      expect(cable.source.portId, 'power-out');
      expect(cable.target.componentId, socket.id);
      expect(cable.target.portId, 'power-in');
      expect(cable.segments.single.points.first, board.position);
      expect(cable.segments.single.points.last, socket.position);
      editor.p2.undo();
      expect(editor.p2.routes, isEmpty);
      editor.p2.redo();
      expect(editor.p2.routes.single.id, cable.id);
    });

    test('same-room wall-to-ceiling cable requires proven physical transition',
        () {
      final editor = EditorController.demo();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      editor.showWall(0);
      final wall = editor.activeSurface!;
      final ceiling = RoomSurfaceRef.ceiling(editor.selectedSpace!.id);
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: wall,
        position: const SurfacePointMm(2500, 1200),
      );
      final light = editor.p2.placeComponent(
        type: ElectricalComponentType.lightingPoint,
        surface: ceiling,
        position: const SurfacePointMm(3000, 1300),
      );
      editor.p2.select(board.id);
      expect(editor.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
      // Wall-edge navigation appends the boundary point exactly once.
      editor.navigateWallEdge(
        WallNavigationEdge.ceiling,
        const SurfacePointMm(3000, 3000),
      );
      expect(editor.activeSurface, ceiling);
      expect(editor.routeSegments, hasLength(2));
      expect(editor.routeSegments[1].surface, ceiling);
      expect(
        editor.snapPortDrivenCableCompletionTarget(
          componentId: light.id,
          portId: 'power-in',
        ),
        isTrue,
      );
      expect(editor.portDrivenCableReadyToFinish, isTrue);
      expect(editor.finishManualCableDraft(endpointSnapRadiusMm: 40), isTrue);
      expect(editor.p2.routes, hasLength(1));
      final cable = editor.p2.routes.single;
      expect(cable.segments, hasLength(2));
      expect(cable.segments.first.surface, wall);
      expect(cable.segments.last.surface, ceiling);
      expect(cable.source.componentId, board.id);
      expect(cable.target.componentId, light.id);
      expect(cable.penetrations, isEmpty);
      editor.p2.undo();
      expect(editor.p2.routes, isEmpty);
      editor.p2.redo();
      expect(editor.p2.routes.single.id, cable.id);
    });

    test('stale port binding blocks commit without losing unfinished draft',
        () {
      final editor = EditorController.demo();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      editor.showWall(0);
      final wall = editor.activeSurface!;
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: wall,
        position: const SurfacePointMm(500, 1200),
      );
      final socket = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(2200, 1200),
      );
      editor.p2.select(board.id);
      expect(editor.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
      editor.surfaceTap(const SurfacePointMm(1400, 1200));
      expect(
        editor.snapPortDrivenCableCompletionTarget(
          componentId: socket.id,
          portId: 'power-in',
        ),
        isTrue,
      );
      final original = editor.routeSegments.single.points.toList();
      editor.p2.placeComponent(
        type: ElectricalComponentType.junctionBox,
        surface: wall,
        position: const SurfacePointMm(3100, 1300),
      );
      expect(editor.portDrivenCableReadyToFinish, isFalse);
      expect(editor.finishManualCableDraft(), isFalse);
      expect(editor.routeSegments.single.points, original);
      expect(editor.p2.routes, isEmpty);
      editor.cancelManualCableDraft(exitTool: true);
      expect(editor.routeSegments, isEmpty);
      expect(editor.portDrivenCableCompletionBinding, isNull);
      expect(editor.tool, EditorTool.select);
    });
  });
}
