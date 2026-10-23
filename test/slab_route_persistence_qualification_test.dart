import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surface_routing.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical slab route persistence qualification', () {
    test('undo redo reopen preserves SlabId and full physical cable length',
        () {
      final editor = EditorController.demo();
      final workspace = EditorBuildingWorkspace.demo(editor);
      addTearDown(() {
        editor.disposeP2State();
        workspace.dispose();
        editor.dispose();
      });

      final spaceId = editor.selectedSpace!.id;
      final ceiling = RoomSurfaceRef.ceiling(spaceId);
      final floor = RoomSurfaceRef.floor(spaceId);
      editor.p2.placeComponent(
        type: ElectricalComponentType.powerSource,
        surface: ceiling,
        position: const SurfacePointMm(600, 1200),
      );
      editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: floor,
        position: const SurfacePointMm(2400, 1200),
      );

      editor.setTool(EditorTool.cableRoute);
      editor.routeSegments.addAll([
        SurfaceRouteSegmentDraft(
          surface: ceiling,
          points: const [
            SurfacePointMm(600, 1200),
            SurfacePointMm(1500, 1200),
          ],
        ),
        SurfaceRouteSegmentDraft(
          surface: floor,
          points: const [
            SurfacePointMm(1500, 1200),
            SurfacePointMm(2400, 1200),
          ],
        ),
      ]);

      expect(
        editor.finishPhysicalManualCableDraft(
          routeId: 'C-slab-persist',
          resolveTransition: (fromSurface, fromPoint, toSurface, toPoint) =>
              SurfaceTransitionCandidate(
            id: 'slab-transition',
            kind: SurfaceTransitionKind.levelPenetration,
            fromSurface: fromSurface,
            fromPoint: fromPoint,
            toSurface: toSurface,
            toPoint: toPoint,
            penetrationRequirement: BoundaryPenetrationRequirement(
              hostKind: BoundaryPenetrationHostKind.slab,
              hostThicknessMm: 200,
              materialId: 'reinforced-concrete',
              slabId: SlabId('slab-01-02'),
            ),
          ),
        ),
        isTrue,
      );

      final committed = editor.p2.routes.single;
      expect(committed.visibleLengthMm, 1800);
      expect(committed.hiddenPenetrationLengthMm, 200);
      expect(committed.geometricLengthMm, 2000);
      expect(committed.installationLengthMm, 2100);
      expect(committed.penetrations.single.slabId, SlabId('slab-01-02'));

      editor.p2.undo();
      expect(editor.p2.routes, isEmpty);
      editor.p2.redo();
      final redone = editor.p2.routes.single;
      expect(redone.id, committed.id);
      expect(redone.penetrations.single.id, committed.penetrations.single.id);
      expect(redone.penetrations.single.slabId, SlabId('slab-01-02'));
      expect(redone.geometricLengthMm, 2000);

      final document = EditorProjectDocument.capture(workspace);
      expect(document.schemaVersion, 8);
      final json = document.toJson();
      final routeJson =
          (((json['p2']! as Map)['routes']! as List).single as Map);
      final penetrationJson =
          ((routeJson['penetrations']! as List).single as Map);
      expect(penetrationJson['slabId'], 'slab-01-02');

      final decoded = EditorProjectDocument.fromJson(json);
      final decodedRoute = decoded.p2State.routes.single;
      expect(decodedRoute.id, committed.id);
      expect(decodedRoute.penetrations.single.slabId, SlabId('slab-01-02'));
      expect(decodedRoute.geometricLengthMm, 2000);
      expect(decodedRoute.installationLengthMm, 2100);

      final restored = decoded.restore();
      addTearDown(() {
        restored.editor.disposeP2State();
        restored.workspace.dispose();
        restored.editor.dispose();
      });
      final reopenedRoute = restored.editor.p2.routes.single;
      expect(reopenedRoute.id, committed.id);
      expect(
        reopenedRoute.penetrations.single.slabId,
        SlabId('slab-01-02'),
      );
      expect(reopenedRoute.geometricLengthMm, 2000);
      expect(reopenedRoute.installationLengthMm, 2100);
    });

    test('schema v7 migration never guesses stable SlabId', () {
      final editor = EditorController.demo();
      final workspace = EditorBuildingWorkspace.demo(editor);
      addTearDown(() {
        editor.disposeP2State();
        workspace.dispose();
        editor.dispose();
      });

      final json = EditorProjectDocument.capture(workspace).toJson();
      json['schemaVersion'] = 7;
      final p2 = json['p2']! as Map<String, Object?>;
      final routes = p2['routes']! as List;
      expect(routes, isEmpty);

      final decoded = EditorProjectDocument.fromJson(json);
      expect(decoded.schemaVersion, 8);
      expect(decoded.p2State.routes, isEmpty);
    });
  });
}
