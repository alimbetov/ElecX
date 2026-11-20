import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('floor room button creates exact width and length on plan',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1360, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(projectStore: _InMemoryStore()),
      ),
    );
    await tester.pumpAndSettle();
    final canvas = tester.widget<SpatialCanvas>(find.byType(SpatialCanvas));
    final originalCount = canvas.controller.level.spaces.length;
    await tester.tap(find.byKey(const ValueKey('create-room-dimensions')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('room-dimensions-dialog')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('room-name-input')), 'Комната по размерам');
    await tester.enterText(
        find.byKey(const ValueKey('room-width-input')), '4200');
    await tester.enterText(
        find.byKey(const ValueKey('room-length-input')), '3600');
    await tester.enterText(find.byKey(const ValueKey('room-x-input')), '1000');
    await tester.enterText(find.byKey(const ValueKey('room-y-input')), '2000');
    await tester.tap(find.byKey(const ValueKey('room-dimensions-submit')));
    await tester.pumpAndSettle();
    expect(canvas.controller.level.spaces.length, originalCount + 1);
    final created = canvas.controller.level.spaces.last;
    expect(created.name, 'Комната по размерам');
    expect(created.boundary.bounds.width, 4200);
    expect(created.boundary.bounds.height, 3600);
    expect(created.boundary.bounds.left, 1000);
    expect(created.boundary.bounds.bottom, 2000);
    expect(canvas.controller.selectedSpaceId, created.id);
    expect(canvas.controller.documentHistory.canUndo, isTrue);
    expect(canvas.controller.documentHistory.undo(), isTrue);
    await tester.pump();
    expect(canvas.controller.level.spaces.length, originalCount);
    expect(canvas.controller.documentHistory.redo(), isTrue);
    await tester.pump();
    expect(canvas.controller.level.spaces.last.name, 'Комната по размерам');
    expect(tester.takeException(), isNull);
  });
}

class _InMemoryStore implements EditorProjectStore {
  @override
  Future<List<EditorProjectDocument>> list() async => [];

  @override
  Future<EditorProjectDocument?> load(String projectId) async => null;

  @override
  Future<void> save(EditorProjectDocument document) async {}
}
