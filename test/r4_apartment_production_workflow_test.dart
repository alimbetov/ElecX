import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_identity.dart';
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
