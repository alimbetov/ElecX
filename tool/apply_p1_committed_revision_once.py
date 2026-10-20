from pathlib import Path

screen = Path('lib/src/features/editor/unified_workspace_editor_screen.dart')
text = screen.read_text()

if '_lastP2CommittedRevision' not in text:
    text = text.replace(
        '  int _projectRevision = 0;\n  int _savedRevision = 0;\n',
        '  int _projectRevision = 0;\n  int _savedRevision = 0;\n  int _lastP2CommittedRevision = 0;\n',
        1,
    )

text = text.replace(
    '    controller.p2.addListener(_onProjectChanged);\n    siteInteraction = SiteMapInteractionController();\n',
    '    _lastP2CommittedRevision = controller.p2.history.mutationRevision;\n'
    '    controller.p2.addListener(_onP2Changed);\n'
    '    siteInteraction = SiteMapInteractionController();\n',
    1,
)

if 'void _onP2Changed()' not in text:
    marker = '  void _onProjectChanged() {\n'
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit('screen _onProjectChanged anchor missing')
    method = '''  void _onP2Changed() {\n    final committed = controller.p2.history.mutationRevision;\n    if (committed == _lastP2CommittedRevision) {\n      _refresh();\n      return;\n    }\n    _lastP2CommittedRevision = committed;\n    _onProjectChanged();\n  }\n\n'''
    text = text[:idx] + method + text[idx:]

text = text.replace(
    '    previousController.p2.removeListener(_onProjectChanged);\n',
    '    previousController.p2.removeListener(_onP2Changed);\n',
)
text = text.replace(
    '    controller.p2.addListener(_onProjectChanged);\n    _projectMetadata = metadata;\n',
    '    _lastP2CommittedRevision = controller.p2.history.mutationRevision;\n'
    '    controller.p2.addListener(_onP2Changed);\n'
    '    _projectMetadata = metadata;\n',
)
text = text.replace(
    '    controller.p2.removeListener(_onProjectChanged);\n    controller.disposeP2State();\n',
    '    controller.p2.removeListener(_onP2Changed);\n'
    '    controller.disposeP2State();\n',
)

if 'controller.p2.addListener(_onProjectChanged)' in text or 'controller.p2.removeListener(_onProjectChanged)' in text:
    raise SystemExit('stale p2 project-change listener remains')
if 'controller.p2.addListener(_onP2Changed)' not in text:
    raise SystemExit('p2 committed listener was not installed')
screen.write_text(text)

# Acceptance: transient P2 notifications must not dirty a saved project.
test_path = Path('test/p1_lifecycle_acceptance_test.dart')
test = test_path.read_text()
case_name = 'F01 selection-only and preview-cancel keep saved project clean'
if case_name not in test:
    anchor = "  test('F03 shrinking room around electrical component is rejected atomically',"
    idx = test.find(anchor)
    if idx == -1:
        raise SystemExit('acceptance F03 anchor missing')
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
    test = test[:idx] + addition + test[idx:]
test_path.write_text(test)
