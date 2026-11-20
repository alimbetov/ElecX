import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/remote_board_route_preview.dart';
import 'package:elecx/src/features/editor/apartment_wiring_preview.dart';
import 'package:elecx/src/features/editor/cable_editor_ui_session.dart';
import 'package:elecx/src/features/editor/cable_surface_projection.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_viewport_commands.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Hub creates R4 and all thirteen devices appear on apartment plan',
      (tester) async {
    final store = _MemoryEditorProjectStore();
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: ProjectHubScreen(
      projectStore: store,
      canonicalProjectRepository: _MemoryProjectRepository(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-project')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('new-project-name')), 'R4');
    await tester.tap(find.byKey(const ValueKey('create-project-demo')));
    await tester.pumpAndSettle();
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    final document = store.documents.single;
    expect(document.p2State.components, hasLength(13));
    final canvas = tester.widget<SpatialCanvas>(find.byType(SpatialCanvas));
    canvas.controller.requestViewportCommand(EditorViewportCommand.reset);
    await tester.pumpAndSettle();
    for (final component in document.p2State.components) {
      expect(find.byKey(ValueKey('plan-component-${component.id}')),
          findsOneWidget,
          reason: component.label);
    }
    final load = document.p2State.components.first;
    final board = document.p2State.components.last;
    await tester.tap(find.byKey(ValueKey('plan-component-${load.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('component-connection-actions')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('component-open-host')), findsOneWidget);
    expect(find.byKey(ValueKey('preview-remote-board-route-${board.id}')),
        findsOneWidget);
    final remote =
        find.byKey(ValueKey('preview-remote-board-route-${board.id}'));
    await tester.ensureVisible(remote);
    await tester.tap(remote);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remote-board-route-blocked')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('remote-board-route-apply')), findsNothing);
    expect(canvas.controller.p2.routes, isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(canvas.controller)!;
    final physical =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
            canvas.controller)!;
    final profile = BoundaryConstructionProfile(
        kind: BoundaryConstructionKind.wall,
        thicknessMm: 100,
        materialId: 'test-partition');
    final mutation = coordinator.session.boundaryConstructionEditing
        .setWallConstructions(profiles: {
      BoundaryEdgeHostRef(
          spaceId: physical.canonicalSpaceIdForLegacy(board.surface.spaceId)!,
          edgeId: physical
              .edgeOrderForLegacySpace(board.surface.spaceId)!
              .first): profile,
      BoundaryEdgeHostRef(
          spaceId: physical.canonicalSpaceIdForLegacy(load.surface.spaceId)!,
          edgeId: physical
              .edgeOrderForLegacySpace(load.surface.spaceId)![2]): profile,
    }, expectedVersion: coordinator.session.project.version)!;
    CanonicalRoomSurfaceRuntimeRegistry.canonicalOwnershipFor(
        canvas.controller)!(mutation);
    expect(find.byKey(const ValueKey('apartment-wire')), findsOneWidget);
    final frozen = RemoteBoardRoutePreview.create(
        controller: canvas.controller, board: board, load: load);
    expect(() => frozen.route.segments.first.points.clear(),
        throwsUnsupportedError);
    expect(() => frozen.route.segments.first.anchorIds.clear(),
        throwsUnsupportedError);
    final stale = RemoteBoardRoutePreview.create(
        controller: canvas.controller, board: board, load: load);
    canvas.controller.p2.updateLoadElectricalData(
        componentId: load.id, ratedPowerW: 500, voltageV: 230);
    expect(stale.apply(), isFalse);
    expect(canvas.controller.p2.routes, isEmpty);
    await tester.pumpAndSettle();
    await tester.tap(remote);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('remote-board-route-plan')), findsOneWidget);
    expect(canvas.controller.p2.routes, isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(canvas.controller.p2.routes, isEmpty);
    await tester.tap(remote);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-board-route-apply')));
    await tester.pumpAndSettle();
    final route = canvas.controller.p2.routes.single;
    expect(route.penetrations, hasLength(1));
    expect(canvas.controller.p2.state.circuitBundles, hasLength(1));
    canvas.controller.p2.undo();
    expect(canvas.controller.p2.routes, isEmpty);
    expect(canvas.controller.p2.state.circuitBundles, isEmpty);
    canvas.controller.p2.redo();
    expect(canvas.controller.p2.routes.single.id, route.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    final restored =
        EditorProjectDocument.fromJson(store.documents.single.toJson());
    expect(restored.p2State.routes.single.id, route.id);
    expect(restored.p2State.routes.single.penetrations.single.id,
        route.penetrations.single.id);
    expect(restored.p2State.routes.single.segments.first.anchorIds,
        route.segments.first.anchorIds);
    // Existing route survives cancelled apartment preview and missing walls
    // remain explicit blockers rather than fabricated penetrations.
    await tester.tap(find.byKey(const ValueKey('apartment-wire')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('apartment-wiring-blocked')), findsOneWidget);
    expect(canvas.controller.p2.routes, hasLength(1));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(canvas.controller.p2.routes, hasLength(1));
    final contextNow =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
            canvas.controller)!;
    final moreWalls = <BoundaryEdgeHostRef, BoundaryConstructionProfile>{};
    for (final c in document.p2State.components) {
      if (c.surface.spaceId == board.surface.spaceId) continue;
      final id = contextNow.canonicalSpaceIdForLegacy(c.surface.spaceId)!;
      moreWalls[BoundaryEdgeHostRef(
          spaceId: id,
          edgeId: contextNow
              .edgeOrderForLegacySpace(c.surface.spaceId)![2])] = profile;
    }
    final more = coordinator.session.boundaryConstructionEditing
        .setWallConstructions(
            profiles: moreWalls,
            expectedVersion: coordinator.session.project.version)!;
    CanonicalRoomSurfaceRuntimeRegistry.canonicalOwnershipFor(
        canvas.controller)!(more);
    final all = ApartmentWiringPreview.create(canvas.controller);
    expect(all.routes, hasLength(8));
    expect(all.blockers, isEmpty);
    expect(all.switchCount, 3);
    expect(all.routes.every((p) => p.route.penetrations.length == 1), isTrue);
    final depth = canvas.controller.p2.history.undoDepth;
    expect(all.apply(), isTrue);
    expect(all.apply(), isFalse);
    expect(canvas.controller.p2.history.undoDepth, depth + 1);
    expect(canvas.controller.p2.routes, hasLength(9));
    expect(
        canvas.controller.p2.state.circuitBundles
            .map((b) => b.circuit.id)
            .toSet(),
        hasLength(6));
    final allIds = canvas.controller.p2.routes.map((r) => r.id).toList();
    canvas.controller.p2.undo();
    expect(canvas.controller.p2.routes.single.id, route.id);
    canvas.controller.p2.redo();
    expect(canvas.controller.p2.routes.map((r) => r.id), allIds);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    final allRestored =
        EditorProjectDocument.fromJson(store.documents.single.toJson());
    expect(allRestored.p2State.routes.map((r) => r.id), allIds);
    expect(ApartmentWiringPreview.create(canvas.controller).routes, isEmpty);
    await tester.tap(find.byKey(const ValueKey('cable-trajectory-mode')));
    await tester.pumpAndSettle();
    expect(canvas.controller.cableUi.trajectoryEditing, isTrue);
    expect(
        find.byKey(const ValueKey('trajectory-route-picker')), findsOneWidget);
    canvas.controller.routeSelection.select(route.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trajectory-segment-0')));
    // Selected cables animate direction continuously on their host surface.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SurfaceCanvas), findsOneWidget);
    expect(
        CableSurfaceProjection.same(canvas.controller,
            canvas.controller.activeSurface!, route.segments.first.surface),
        isTrue);
    expect(canvas.controller.routeSelection.selectedRouteId, route.id);
    expect(canvas.controller.p2.routes.map((r) => r.id), allIds);
    await tester.tap(find.byTooltip('Завершить редактирование трасс'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(canvas.controller.cableUi.trajectoryEditing, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

final class _MemoryEditorProjectStore implements EditorProjectStore {
  final List<EditorProjectDocument> documents = [];

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    for (final document in documents) {
      if (document.projectId == projectId) return document;
    }
    return null;
  }

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List<EditorProjectDocument>.unmodifiable(documents);

  @override
  Future<void> save(EditorProjectDocument document) async {
    final index = documents.indexWhere(
      (item) => item.projectId == document.projectId,
    );
    if (index < 0) {
      documents.add(document);
    } else {
      documents[index] = document;
    }
  }
}

final class _MemoryProjectRepository implements ProjectRepository {
  final Map<ProjectId, ProjectSnapshot> _snapshots = {};

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async =>
      _snapshots[projectId];

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    _snapshots[snapshot.id] = snapshot;
  }

  @override
  Future<List<ProjectSummary>> list() async => [
        for (final snapshot in _snapshots.values) snapshot.toSummary(),
      ];
}
