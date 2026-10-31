import 'dart:io';

import 'package:elecx/src/application/project/project_room_rectangle_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/engineering_state_aware_canonical_project_document_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE-P12 PQ11 adversarial production qualification', () {
    test('too-small and wrong-level rectangles fail before canonical mutation',
        () async {
      final root = await Directory.systemTemp.createTemp('elecx-pre-p12-pq11-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final legacy = _blankDocument('pre-p12-pq11', 'PRE-P12 PQ11');
      final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy,
        repository: _repository(root),
      );
      final service = RoomRectangleAuthoringService(
        session: handle.session,
        mutations: handle.wizardMutations,
      );
      final before = handle.session.project;
      final levelId = handle.session.navigation.activeLevelId!;

      expect(
        () => service.commit(
          RoomRectangleAuthoringIntent(
            levelId: levelId,
            first: const BoundaryPointMm(xMm: 1000, yMm: 1000),
            second: const BoundaryPointMm(xMm: 1200, yMm: 5000),
            name: 'Too narrow',
          ),
        ),
        throwsArgumentError,
      );
      expect(handle.session.project, same(before));
      expect(handle.session.project.stores.spaces, isEmpty);

      expect(
        () => service.commit(
          RoomRectangleAuthoringIntent(
            levelId: LevelId('foreign-level'),
            first: const BoundaryPointMm(xMm: 1000, yMm: 1000),
            second: const BoundaryPointMm(xMm: 5000, yMm: 5000),
            name: 'Wrong level',
          ),
        ),
        throwsStateError,
      );
      expect(handle.session.project, same(before));
      expect(handle.session.project.stores.spaces, isEmpty);
    });

    test('production owner rejects a foreign authoring session fail-closed',
        () async {
      final mainRoot =
          await Directory.systemTemp.createTemp('elecx-pre-p12-owner-main-');
      final foreignRoot =
          await Directory.systemTemp.createTemp('elecx-pre-p12-owner-foreign-');
      addTearDown(() async {
        if (await mainRoot.exists()) await mainRoot.delete(recursive: true);
        if (await foreignRoot.exists()) {
          await foreignRoot.delete(recursive: true);
        }
      });
      final legacy = _blankDocument('pre-p12-owner', 'PRE-P12 owner');
      final main = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy,
        repository: _repository(mainRoot),
      );
      final foreign = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy,
        repository: _repository(foreignRoot),
      );
      final mainVersion = main.owner.version;
      final foreignLevelId = foreign.session.navigation.activeLevelId!;
      final foreignCommit = RoomRectangleAuthoringService(
        session: foreign.session,
        mutations: foreign.wizardMutations,
      ).commit(
        RoomRectangleAuthoringIntent(
          levelId: foreignLevelId,
          first: const BoundaryPointMm(xMm: 1000, yMm: 1000),
          second: const BoundaryPointMm(xMm: 5000, yMm: 4000),
          name: 'Foreign room',
        ),
      );

      expect(
        () => main.runtimeConfig.onCanonicalMutationCommitted!(
          foreign.session,
          foreignCommit.commit.mutation,
        ),
        throwsStateError,
      );
      expect(main.owner.version, mainVersion);
      expect(main.owner.project.stores.spaces, isEmpty);
    });

    test('fresh production bootstrap rejects divergent bound legacy geometry',
        () async {
      final root =
          await Directory.systemTemp.createTemp('elecx-pre-p12-divergence-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final original = _roomDocument(
        projectId: 'pre-p12-divergence',
        projectName: 'PRE-P12 divergence',
        first: const MmPoint(0, 0),
        second: const MmPoint(4000, 3000),
      );
      await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: original,
        repository: _repository(root),
      );
      final divergent = _roomDocument(
        projectId: 'pre-p12-divergence',
        projectName: 'PRE-P12 divergence',
        first: const MmPoint(0, 0),
        second: const MmPoint(4500, 3000),
      );

      await expectLater(
        CanonicalEditorProductionHandle.loadOrBootstrap(
          legacyDocument: divergent,
          repository: _repository(root),
        ),
        throwsStateError,
      );
    });
  });

  group('PRE-P12 PQ12 production reachability qualification', () {
    test(
        'two-click rectangle crosses real cutover, owner, materializer and history',
        () async {
      final root = await Directory.systemTemp.createTemp('elecx-pre-p12-pq12-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final legacy = _blankDocument('pre-p12-pq12', 'PRE-P12 PQ12');
      final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy,
        repository: _repository(root),
      );
      final restored = legacy.restore();
      final controller = restored.editor;
      final workspace = restored.workspace;
      addTearDown(() {
        workspace.dispose();
        controller.disposeP2State();
        controller.dispose();
      });
      final resolved =
          handle.runtimeConfig.resolveRuntime(workspace, legacy.metadata)!;
      final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
        session: resolved.session,
        adapter: CanonicalEditorWorkspaceAdapter(
          workspace: workspace,
          binding: resolved.binding,
        ),
        materializer: resolved.materializer,
      );
      final cutover = CanonicalEditorScreenCutoverBinding(
        coordinator: coordinator,
        onCanonicalMutationReplayed: (result) {
          handle.runtimeConfig.onCanonicalMutationCommitted!(
            resolved.session,
            result,
          );
        },
      );
      addTearDown(cutover.dispose);
      cutover.start();

      final beforeVersion = handle.owner.version;
      controller.setTool(EditorTool.roomRectangle);
      controller.canvasTap(const MmPoint(1200, 1400));
      expect(handle.session.project.stores.spaces, isEmpty);
      controller.canvasTap(const MmPoint(5200, 4600));

      expect(handle.owner.version, beforeVersion.next());
      expect(handle.owner.project, same(handle.session.project));
      expect(handle.session.project.stores.spaces, hasLength(1));
      expect(handle.session.project.stores.boundaries, hasLength(1));
      final roomId = handle.session.project.stores.spaces.keys.single;
      final topology = handle.session.project.index.boundary(roomId)!;
      final edgeIds = List<BoundaryEdgeId>.of(topology.orderedEdgeIds);
      expect(topology.validate(), isEmpty);
      expect(
        [
          for (final id in topology.orderedEdgeIds)
            (topology.edges[id]!.start.xMm, topology.edges[id]!.start.yMm),
        ],
        const <(int, int)>[
          (1200, 1400),
          (5200, 1400),
          (5200, 4600),
          (1200, 4600),
        ],
      );
      final legacyRoomId = coordinator.adapter.binding.legacySpaceIds[roomId];
      expect(legacyRoomId, isNotNull);
      expect(controller.level.spaces, hasLength(1));
      expect(controller.level.spaces.single.id, legacyRoomId);
      expect(
        controller.documentHistory.undoLabel,
        'project.space.create-room-rectangle',
      );
      expect(controller.documentHistory.undoDepth, 1);

      expect(controller.documentHistory.undo(), isTrue);
      expect(handle.owner.project, same(handle.session.project));
      expect(handle.session.project.stores.spaces, isEmpty);
      expect(handle.session.project.stores.boundaries, isEmpty);
      expect(
        controller.level.spaces,
        isEmpty,
        reason: 'Canonical Undo must not leave a phantom legacy room.',
      );

      expect(controller.documentHistory.redo(), isTrue);
      expect(handle.owner.project, same(handle.session.project));
      expect(handle.session.project.stores.spaces.keys.single, roomId);
      expect(
        handle.session.project.index.boundary(roomId)!.orderedEdgeIds,
        edgeIds,
      );
      expect(controller.level.spaces, hasLength(1));

      await handle.saveCanonical();
      final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy,
        repository: _repository(root),
      );
      expect(reopened.owner.project.stores.spaces.keys.single, roomId);
      expect(
        reopened.owner.project.index.boundary(roomId)!.orderedEdgeIds,
        edgeIds,
      );
    });

    testWidgets(
        'real production runtime is reachable from toolbar and survives UI Undo/Redo',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Directory root;
      late EditorProjectDocument legacy;
      late CanonicalEditorProductionHandle handle;
      await tester.runAsync(() async {
        root =
            await Directory.systemTemp.createTemp('elecx-pre-p12-ui-smoke-');
        legacy = _blankDocument('pre-p12-ui-smoke', 'PRE-P12 UI smoke');
        handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
          legacyDocument: legacy,
          repository: _repository(root),
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: _MemoryEditorProjectStore(legacy),
            initialDocument: legacy,
            canonicalRuntime: handle.runtimeConfig,
          ),
        ),
      );
      await _boundedPump(tester);

      expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
      expect(find.byTooltip('Комната (R)'), findsOneWidget);
      final directRoom = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Room'),
      );
      expect(
        directRoom.onPressed,
        isNull,
        reason: 'Geometry-less +Room must remain fail-closed in production.',
      );

      await tester.tap(find.byTooltip('Комната (R)'));
      await _boundedPump(tester);
      final canvas = find.byType(SpatialCanvas);
      expect(canvas, findsOneWidget);
      final rect = tester.getRect(canvas);
      await tester.tapAt(rect.center + const Offset(-120, -80));
      await _boundedPump(tester);
      expect(handle.session.project.stores.spaces, isEmpty);
      await tester.tapAt(rect.center + const Offset(120, 80));
      await _boundedPump(tester);

      expect(handle.session.project.stores.spaces, hasLength(1));
      final roomId = handle.session.project.stores.spaces.keys.single;
      expect(handle.session.project.index.boundary(roomId), isNotNull);
      expect(
        find.byTooltip('Отменить: project.space.create-room-rectangle'),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip('Отменить: project.space.create-room-rectangle'),
      );
      await _boundedPump(tester);
      expect(handle.session.project.stores.spaces, isEmpty);
      expect(
        find.byTooltip('Повторить: project.space.create-room-rectangle'),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip('Повторить: project.space.create-room-rectangle'),
      );
      await _boundedPump(tester);
      expect(handle.session.project.stores.spaces.keys.single, roomId);
      expect(
        find.byKey(const ValueKey('canonical-cutover-blocked')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
    });
  });
}

Future<void> _boundedPump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

JsonProjectRepository _repository(Directory root) => JsonProjectRepository(
      rootDirectory: root,
      codec: const EngineeringStateAwareCanonicalProjectDocumentCodec(),
    );

EditorProjectDocument _blankDocument(String projectId, String projectName) =>
    createInitialEditorProjectDocument(
      EditorProjectMetadata.create(
        projectName: projectName,
        projectId: projectId,
        now: DateTime.utc(2026, 10, 31, 13),
      ),
    );

EditorProjectDocument _roomDocument({
  required String projectId,
  required String projectName,
  required MmPoint first,
  required MmPoint second,
}) {
  final boundary = MmPolygon.rectangle(first, second);
  final controller = EditorController.restored(
    level: BuildingLevel(
      id: 'level-$projectId-1',
      name: 'Этаж 1',
      elevationMm: 0,
      spaces: <EngineeringSpace>[
        EngineeringSpace(
          id: 'room-existing',
          name: 'Existing room',
          type: SpaceType.room,
          boundary: boundary,
          referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
        ),
      ],
    ),
    openings: const <ArchitecturalOpening>[],
  );
  final workspace = EditorBuildingWorkspace.blank(
    controller,
    projectId: projectId,
    projectName: projectName,
  );
  final document = EditorProjectDocument.capture(
    workspace,
    metadata: EditorProjectMetadata.create(
      projectName: projectName,
      projectId: projectId,
      now: DateTime.utc(2026, 10, 31, 13),
    ),
  );
  workspace.dispose();
  controller.disposeP2State();
  controller.dispose();
  return document;
}

final class _MemoryEditorProjectStore implements EditorProjectStore {
  _MemoryEditorProjectStore(this.document);

  EditorProjectDocument? document;

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    final current = document;
    return current?.projectId == projectId ? current : null;
  }

  @override
  Future<List<EditorProjectDocument>> list() async => document == null
      ? const <EditorProjectDocument>[]
      : <EditorProjectDocument>[document!];

  @override
  Future<void> save(EditorProjectDocument document) async {
    this.document = document;
  }
}
