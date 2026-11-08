import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/engineering_inspector_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact editor exposes engineering drawer without resizing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 628));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: UnifiedWorkspaceEditorScreen(projectStore: _EmptyStore()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-inspector-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('engineering-context-scroll')),
        findsOneWidget);
    expect(find.text('Электрическая группа'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final height in [400.0, 600.0, 760.0]) {
    testWidgets('connected circuit actions scroll at panel height $height',
        (tester) async {
      final editor = EditorController.demo();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: surface,
        position: const SurfacePointMm(300, 2200),
      );
      final load = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1400, 2200),
      );
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      );
      editor.p2.select(load.id, mode: SelectionMode.replace);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 312,
              height: height,
              child: EngineeringInspectorPanel(
                controller: editor,
                semanticsInspector: const SizedBox(
                  height: 250,
                  child: Text('ROOM SEMANTICS: openings, adjacency, usage'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final contextScroll = find.byKey(
        const ValueKey('engineering-context-scroll'),
      );
      final scrollable = find
          .descendant(
            of: contextScroll,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(find.text('Нагрузка'), 180,
          scrollable: scrollable);
      await tester.tap(find.text('Нагрузка'));
      await tester.pumpAndSettle();
      expect(find.text('Параметры · ${load.label}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _EmptyStore implements EditorProjectStore {
  @override
  Future<List<EditorProjectDocument>> list() async => [];
  @override
  Future<EditorProjectDocument?> load(String projectId) async => null;
  @override
  Future<void> save(EditorProjectDocument document) async {}
}
