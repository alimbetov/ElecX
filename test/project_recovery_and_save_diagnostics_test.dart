import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/project_save_diagnostics.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};
  int saves = 0;

  @override
  Future<void> save(EditorProjectDocument document) async {
    saves++;
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
  int discards = 0;

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
    discards++;
    snapshots.remove(projectId);
  }
}

EditorProjectDocument _invalidCableDocument() {
  final controller = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(controller);
  final metadata = EditorProjectMetadata.create(projectName: 'Invalid cable');
  final base = EditorProjectDocument.capture(workspace, metadata: metadata);
  final surface = RoomSurfaceRef.wall(controller.level.spaces.first.id, 1);
  final source = ElectricalComponentPlacement(
    id: 'source',
    type: ElectricalComponentType.powerSource,
    surface: surface,
    position: const SurfacePointMm(200, 600),
    label: 'Источник',
    ports: ElectricalComponentDefaults.portsFor(
      ElectricalComponentType.powerSource,
    ),
  );
  final target = ElectricalComponentPlacement(
    id: 'light',
    type: ElectricalComponentType.lightingPoint,
    surface: surface,
    position: const SurfacePointMm(1200, 1200),
    label: 'Светильник',
    ports: ElectricalComponentDefaults.portsFor(
      ElectricalComponentType.lightingPoint,
    ),
  );
  final invalidState = EditorP2State(
    components: [source, target],
    routes: [
      ElectricalCableRoute(
        id: 'route-wrong-port',
        source: const ElectricalEndpointRef(
          componentId: 'source',
          portId: 'power-out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'light',
          portId: 'control-in',
        ),
        segments: [
          ElectricalRouteSegment(
            surface: surface,
            points: const [SurfacePointMm(200, 600), SurfacePointMm(1200, 600)],
          ),
        ],
      ),
    ],
  );
  final document = EditorProjectDocument(
    schemaVersion: base.schemaVersion,
    metadata: base.metadata,
    building: base.building,
    site: base.site,
    workspaceContext: base.workspaceContext,
    activeLevelNumber: base.activeLevelNumber,
    selectedZoneId: base.selectedZoneId,
    activeOutdoorZoneId: base.activeOutdoorZoneId,
    openingsByLevel: base.openingsByLevel,
    resume: base.resume,
    p2State: invalidState,
  );
  workspace.dispose();
  controller.disposeP2State();
  controller.dispose();
  return document;
}

void main() {
  test('save diagnostics explain incompatible cable ports', () {
    final document = _invalidCableDocument();
    final restored = document.restore();
    final issues = EditorProjectSaveDiagnostics.validate(restored.workspace);
    expect(issues, hasLength(1));
    expect(issues.single.code, EditorProjectSaveIssueCode.incompatiblePorts);
    expect(issues.single.detail, contains('powerOut'));
    expect(issues.single.detail, contains('controlIn'));
    expect(issues.single.detail, contains('route-wrong-port'));
    restored.workspace.dispose();
    restored.editor.disposeP2State();
    restored.editor.dispose();
  });

  test('recovery snapshot round-trips separately from project save', () async {
    final temp = await Directory.systemTemp.createTemp('elecx-recovery-');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final controller = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(controller);
    final document = EditorProjectDocument.capture(
      workspace,
      metadata: EditorProjectMetadata.create(projectName: 'Recovery'),
    );
    final store = JsonFileEditorProjectRecoveryStore(temp);
    final snapshot = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2026, 10, 20, 10, 30),
      revision: 7,
      document: document,
    );
    await store.save(snapshot);
    final loaded = await store.load(document.projectId);
    expect(loaded, isNotNull);
    expect(loaded!.revision, 7);
    expect(loaded.projectId, document.projectId);
    expect(loaded.document.updatedAt, document.updatedAt);
    await store.discard(document.projectId);
    expect(await store.load(document.projectId), isNull);
    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  });

  testWidgets('autosave writes recovery but never marks project Saved',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recovery = _MemoryRecoveryStore();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projects,
          recoveryStore: recovery,
          autosaveDelay: const Duration(milliseconds: 10),
          initialMetadata: EditorProjectMetadata.create(
            projectName: 'Autosave project',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(recovery.saves, greaterThanOrEqualTo(1));
    expect(projects.saves, 0);
    expect(find.text('Modified'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(projects.saves, 1);
    expect(recovery.snapshots, isEmpty);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('Save failed shows actionable incompatible cable hint',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recovery = _MemoryRecoveryStore();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projects,
          recoveryStore: recovery,
          initialDocument: _invalidCableDocument(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-failure-dialog')), findsOneWidget);
    expect(find.text('Кабель подключён не к тому типу порта'), findsOneWidget);
    expect(find.textContaining('powerOut'), findsOneWidget);
    expect(find.textContaining('controlIn'), findsOneWidget);
    expect(find.text('Save failed'), findsOneWidget);
    expect(projects.saves, 0);
  });
}
