import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'concave boundary rejects segment that exits through polygon vertices',
    () {
      final context = RouteNormativeContext(
        surface: RoomSurfaceRef.floor('room'),
        widthMm: 10000,
        heightMm: 6000,
        edgeClearanceMm: 0,
        boundary: const [
          SurfacePointMm(0, 1500),
          SurfacePointMm(1000, 1500),
          SurfacePointMm(1000, 3000),
          SurfacePointMm(3000, 3000),
          SurfacePointMm(3000, 1500),
          SurfacePointMm(10000, 1500),
          SurfacePointMm(10000, 6000),
          SurfacePointMm(0, 6000),
        ],
      );
      final result = NormativeRouteEngine.validate(
        points: const [SurfacePointMm(500, 1500), SurfacePointMm(9500, 1500)],
        context: context,
      );
      expect(result.isValid, isFalse);
    },
  );

  test(
    'assigned cable route rebind updates engineering identity atomically',
    () {
      final editor = EditorController.demo();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: surface,
        position: const SurfacePointMm(200, 2000),
      );
      final loadA = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1200, 2000),
      );
      final loadB = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1200, 2000),
      );
      final bundle = editor.p2.connectLoadToBoard(
        loadComponentId: loadA.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      );
      expect(bundle, isNotNull);
      final before = editor.p2.routes.singleWhere(
        (route) => route.id == bundle!.cable.routeId,
      );
      final after = ElectricalCableRoute(
        id: before.id,
        source: before.source,
        target: ElectricalEndpointRef(
          componentId: loadB.id,
          portId: before.target.portId,
        ),
        segments: before.segments,
        cableType: before.cableType,
        medium: before.medium,
        reservePercent: before.reservePercent,
      );

      expect(editor.p2.replaceCableRoute(before, after), isTrue);
      final rebound = editor.p2.circuitBundleForRoute(before.id)!;
      expect(rebound.cable.endB.componentId, loadB.id);
      expect(rebound.cable.endB.portId, after.target.portId);
      expect(
        editor.p2.routes
            .singleWhere((route) => route.id == before.id)
            .target
            .componentId,
        loadB.id,
      );

      editor.p2.undo();
      final restored = editor.p2.circuitBundleForRoute(before.id)!;
      expect(restored.cable.endB.componentId, loadA.id);
    },
  );

  test(
    'recovery load falls back to backup after interrupted publication',
    () async {
      final root = await Directory.systemTemp.createTemp('elecx-recovery-');
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
      final metadata = EditorProjectMetadata.create(
        projectName: 'Recovery test',
      );
      final document = EditorProjectDocument.capture(
        workspace,
        metadata: metadata,
      );
      final snapshot = EditorProjectRecoverySnapshot(
        capturedAt: DateTime.utc(2026, 10, 20, 12),
        revision: 7,
        document: document,
      );
      final store = JsonFileEditorProjectRecoveryStore(root);
      await store.save(snapshot);

      final encodedId =
          base64Url.encode(utf8.encode(metadata.projectId)).replaceAll('=', '');
      final target = File('${root.path}/$encodedId.elecx.recovery.json');
      final backup = File('${target.path}.bak');
      await target.rename(backup.path);
      await File('${target.path}.tmp').writeAsString('{broken', flush: true);

      final recovered = await store.load(metadata.projectId);
      expect(recovered, isNotNull);
      expect(recovered!.revision, 7);
      expect(recovered.projectId, metadata.projectId);
    },
  );
}
