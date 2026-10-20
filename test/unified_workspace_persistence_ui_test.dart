import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};
  int saveCount = 0;
  int loadCount = 0;

  @override
  Future<void> save(EditorProjectDocument document) async {
    saveCount++;
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    loadCount++;
    return documents[projectId];
  }

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List<EditorProjectDocument>.unmodifiable(documents.values);
}

void main() {
  testWidgets('desktop Save and Open use canonical project store',
      (tester) async {
    final store = _MemoryProjectStore();
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(projectStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('project-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('project-open')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(store.saveCount, 1);
    expect(store.documents, hasLength(1));
    expect(find.text('Проект сохранён'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-open')));
    await tester.pumpAndSettle();
    expect(store.loadCount, 1);
    expect(find.text('Проект открыт из сохранённой версии'), findsOneWidget);

    // The restored controller/workspace must still render the real editor.
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('project-save')), findsOneWidget);
  });
}
