import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/site_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'save close open restores canonical engineering state and continues edit',
      () async {
    final root = await Directory.systemTemp.createTemp('elecx-project-store-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    workspace.updateProjectNorth(const ProjectNorth(northAzimuthDegrees: 90));

    final space = editor.selectedSpace!;
    editor.showWall(0);
    editor.addOpening(ArchitecturalOpeningType.door);
    final wall = editor.activeSurface!;
    final source = editor.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(200, 1200),
    );
    final target = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(1600, 2400),
    );
    editor.p2.select(source.id);
    editor.p2.select(
      target.id,
      mode: SelectionMode.add,
    );
    expect(editor.p2.autoRouteSelectedPair(), isTrue);
    final route = editor.p2.routes.single;
    final interiorPoint = route.segments.single.points.length > 2
        ? route.segments.single.points[1]
        : route.segments.single.points.first;
    final pointIndex = route.segments.single.points.indexOf(interiorPoint);
    expect(
      editor.p2.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: pointIndex,
        point: interiorPoint,
      ),
      isTrue,
    );

    final savedSpaceId = space.id;
    final document = EditorProjectDocument.capture(workspace);
    final store = JsonFileEditorProjectStore(root);
    await store.save(document);

    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();

    final loaded = await store.load(document.projectId);
    expect(loaded, isNotNull);
    final restored = loaded!.restore();
    addTearDown(() {
      restored.editor.disposeP2State();
      restored.workspace.dispose();
      restored.editor.dispose();
    });

    expect(
      restored.workspace.site.site.projectNorth.northAzimuthDegrees,
      90,
    );
    expect(restored.editor.selectedSpaceId, savedSpaceId);
    expect(restored.editor.openings, hasLength(1));
    expect(restored.editor.p2.components, hasLength(2));
    expect(restored.editor.p2.routes, hasLength(1));
    expect(
      restored.editor.p2.routeConstraintsFor(route.id).mandatoryWaypoints,
      hasLength(1),
    );

    // Reopen starts a fresh history, but continued edits remain undoable and
    // restored id sequences must never collide with persisted identities.
    final newComponent = restored.editor.p2.placeComponent(
      type: ElectricalComponentType.junctionBox,
      surface: wall,
      position: const SurfacePointMm(1700, 1800),
    );
    expect(newComponent.id, isNot(source.id));
    expect(newComponent.id, isNot(target.id));
    expect(restored.editor.p2.canUndo, isTrue);
    restored.editor.p2.undo();
    expect(
      restored.editor.p2.components.any((item) => item.id == newComponent.id),
      isFalse,
    );
  });

  test('workspace level switch persists edited geometry and openings', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });

    final originalCount = editor.level.spaces.length;
    editor.addRectangleRoom(
      const MmPoint(20000, 0),
      const MmPoint(23000, 3000),
    );
    editor.selectSpace(editor.level.spaces.first.id);
    editor.showWall(0);
    editor.addOpening(ArchitecturalOpeningType.window);
    expect(editor.level.spaces, hasLength(originalCount + 1));
    expect(editor.openings, hasLength(1));

    workspace.selectLevel(2);
    workspace.selectLevel(1);

    expect(editor.level.spaces, hasLength(originalCount + 1));
    expect(editor.openings, hasLength(1));
  });

  test('capture rejects active transform and unfinished route draft', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.p2.cancelMoveSelectedComponent();
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });

    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 0);
    final component = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    editor.p2.select(component.id);
    expect(editor.p2.beginMoveSelectedComponent(), isTrue);
    expect(
      () => EditorProjectDocument.capture(workspace),
      throwsStateError,
    );
    editor.p2.cancelMoveSelectedComponent();

    editor.showWall(0);
    editor.setTool(EditorTool.cableRoute);
    editor.surfaceTap(const SurfacePointMm(100, 100));
    expect(
      () => EditorProjectDocument.capture(workspace),
      throwsStateError,
    );
  });

  test('file store lists saved projects for application restart', () async {
    final root = await Directory.systemTemp.createTemp('elecx-project-list-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final document = EditorProjectDocument.capture(workspace);
    final store = JsonFileEditorProjectStore(root);

    await store.save(document);
    final listed = await store.list();

    expect(listed, hasLength(1));
    expect(listed.single.projectId, document.projectId);
    expect(listed.single.projectName, document.projectName);
  });

  test('unsupported schema is rejected explicitly', () {
    expect(
      () => EditorProjectDocument.fromJson(const {
        'schemaVersion': 99,
      }),
      throwsFormatException,
    );
  });
}
