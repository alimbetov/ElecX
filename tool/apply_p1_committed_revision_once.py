from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor missing in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))

# CommandHistory: expose committed mutation revision. replaceState() is preview/transient and must not advance it.
replace_once(
    'lib/src/engine/command_history.dart',
    "  final List<EditorCommand<T>> _undo = [];\n  final List<EditorCommand<T>> _redo = [];\n\n  T get state => _state;\n",
    "  final List<EditorCommand<T>> _undo = [];\n  final List<EditorCommand<T>> _redo = [];\n  int _mutationRevision = 0;\n\n  T get state => _state;\n  int get mutationRevision => _mutationRevision;\n",
)
replace_once(
    'lib/src/engine/command_history.dart',
    "    _redo.clear();\n    return _state;\n  }\n\n  T undo() {\n",
    "    _redo.clear();\n    _mutationRevision++;\n    return _state;\n  }\n\n  T undo() {\n",
)
replace_once(
    'lib/src/engine/command_history.dart',
    "    _state = command.undo(_state);\n    _redo.add(command);\n    return _state;\n  }\n\n  T redo() {\n",
    "    _state = command.undo(_state);\n    _redo.add(command);\n    _mutationRevision++;\n    return _state;\n  }\n\n  T redo() {\n",
)
replace_once(
    'lib/src/engine/command_history.dart',
    "    _state = command.execute(_state);\n    _undo.add(command);\n    return _state;\n  }\n\n  void replaceState",
    "    _state = command.execute(_state);\n    _undo.add(command);\n    _mutationRevision++;\n    return _state;\n  }\n\n  void replaceState",
)

# Screen listens to P2 notifications only as a trigger, but dirty advances only when history revision advances.
replace_once(
    'lib/src/features/editor/unified_workspace_editor_screen.dart',
    "  int _projectRevision = 0;\n  int _savedRevision = 0;\n  bool _allowPop = false;\n",
    "  int _projectRevision = 0;\n  int _savedRevision = 0;\n  int _lastP2CommittedRevision = 0;\n  bool _allowPop = false;\n",
)
replace_once(
    'lib/src/features/editor/unified_workspace_editor_screen.dart',
    "    controller.p2.addListener(_onProjectChanged);\n    siteInteraction = SiteMapInteractionController();\n",
    "    _lastP2CommittedRevision = controller.p2.history.mutationRevision;\n    controller.p2.addListener(_onP2Changed);\n    siteInteraction = SiteMapInteractionController();\n",
)
replace_once(
    'lib/src/features/editor/unified_workspace_editor_screen.dart',
    "  void _onProjectChanged() {\n    _projectRevision++;\n",
    "  void _onP2Changed() {\n    final committed = controller.p2.history.mutationRevision;\n    if (committed == _lastP2CommittedRevision) {\n      _refresh();\n      return;\n    }\n    _lastP2CommittedRevision = committed;\n    _onProjectChanged();\n  }\n\n  void _onProjectChanged() {\n    _projectRevision++;\n",
)
replace_once(
    'lib/src/features/editor/unified_workspace_editor_screen.dart',
    "    previousController.p2.removeListener(_onProjectChanged);\n",
    "    previousController.p2.removeListener(_onP2Changed);\n",
)
replace_once(
    'lib/src/features/editor/unified_workspace_editor_screen.dart',
    "    controller.p2.addListener(_onProjectChanged);\n    _projectMetadata = metadata;\n",
    "    _lastP2CommittedRevision = controller.p2.history.mutationRevision;\n    controller.p2.addListener(_onP2Changed);\n    _projectMetadata = metadata;\n",
)
replace_once(
    'lib/src/features/editor/unified_workspace_editor_screen.dart',
    "    workspace.removeListener(_onProjectChanged);\n    workspace.dispose();\n    controller.removeListener(_onProjectChanged);\n    controller.disposeP2State();\n",
    "    workspace.removeListener(_onProjectChanged);\n    workspace.dispose();\n    controller.removeListener(_onProjectChanged);\n    controller.p2.removeListener(_onP2Changed);\n    controller.disposeP2State();\n",
)

# Acceptance: transient P2 notifications must not dirty a saved project.
p = Path('test/p1_lifecycle_acceptance_test.dart')
text = p.read_text()
anchor = "  test('F03 shrinking room around electrical component is rejected atomically',"
addition = r'''  testWidgets(
      'F01 selection-only and preview-cancel keep saved project clean',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recovery = _MemoryRecoveryStore();
    final document = _savedDocument();
    projects.documents[document.projectId] = document;

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projects,
          recoveryStore: recovery,
          autosaveDelay: const Duration(milliseconds: 10),
          initialDocument: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    final spatialCanvas = tester.widget<SpatialCanvas>(find.byType(SpatialCanvas));
    final controller = spatialCanvas.controller;
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.floor(controller.selectedSpace!.id),
      position: const SurfacePointMm(1000, 500),
    );
    await tester.pump();
    expect(find.text('Modified'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    controller.p2.clearSelection();
    controller.p2.select(component.id);
    controller.p2.updateSnap(null);
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(1200, 500),
        isValid: true,
      ),
      isTrue,
    );
    controller.componentTransform.cancel();
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(recovery.snapshots[document.projectId], isNull);
  });

'''
index = text.find(anchor)
if index == -1:
    raise SystemExit('acceptance anchor missing')
p.write_text(text[:index] + addition + text[index:])
