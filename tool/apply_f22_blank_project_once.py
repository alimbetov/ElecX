from pathlib import Path

# 1) A real blank editor controller. Demo remains available for examples/tests,
# but must never be the implicit source of a user-created project.
p = Path('lib/src/features/editor/editor_controller.dart')
text = p.read_text()
anchor = '''  EditorController.restored({
    required this.level,
    required List<ArchitecturalOpening> openings,
  }) {
'''
blank = '''  EditorController.blank({
    String levelId = 'level-1',
    String levelName = 'Этаж 1',
  }) : level = BuildingLevel(
          id: levelId,
          name: levelName,
          elevationMm: 0,
          spaces: const [],
        ) {
    openings = <ArchitecturalOpening>[];
    roomSequence = 1;
    openingSequence = 1;
    selectedSpaceId = null;
    selectedOpeningId = null;
    activeSurface = null;
    viewMode = EditorViewMode.plan;
    tool = EditorTool.select;
  }

'''
if anchor not in text:
    raise SystemExit('restored constructor anchor not found')
text = text.replace(anchor, blank + anchor, 1)
p.write_text(text)

# 2) Minimal but valid workspace: one empty level as an authoring container,
# no template rooms/zones/cores, no outdoor zones, no demo connections.
p = Path('lib/src/features/editor/editor_building_workspace.dart')
text = p.read_text()
anchor = '''  factory EditorBuildingWorkspace.demo(EditorController editor) {
'''
blank = '''  factory EditorBuildingWorkspace.blank(
    EditorController editor, {
    required String projectId,
    required String projectName,
  }) {
    final level = ComposedBuildingLevel(
      level: editor.level,
      levelNumber: 1,
      kind: BuildingLevelKind.residential,
      zones: const [],
    );
    final buildingGeometry = Building(
      id: 'building-$projectId',
      name: projectName,
      levels: [level.level],
    );
    final building = ComposedBuilding(
      building: buildingGeometry,
      levels: [level],
    );
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'site-$projectId',
        name: projectName,
        buildings: [buildingGeometry],
      ),
      outdoorZones: const [],
      connections: const [],
    );
    return EditorBuildingWorkspace(
      editor: editor,
      building: building,
      site: site,
      initialLevelNumber: 1,
    );
  }

'''
if anchor not in text:
    raise SystemExit('demo workspace anchor not found')
text = text.replace(anchor, blank + anchor, 1)
p.write_text(text)

# 3) New-project UI now starts from the blank factories. Existing persisted
# documents/recovery still use restore(), so migration behavior is unchanged.
p = Path('lib/src/features/editor/unified_workspace_editor_screen.dart')
text = p.read_text()
old = '''      controller = EditorController.demo()..addListener(_onProjectChanged);
      workspace = EditorBuildingWorkspace.demo(controller)
        ..addListener(_onProjectChanged);
'''
new = '''      controller = EditorController.blank(
        levelId: 'level-${_projectMetadata.projectId}-1',
      )..addListener(_onProjectChanged);
      workspace = EditorBuildingWorkspace.blank(
        controller,
        projectId: _projectMetadata.projectId,
        projectName: _projectMetadata.projectName,
      )..addListener(_onProjectChanged);
'''
if old not in text:
    raise SystemExit('new project demo initialization anchor not found')
text = text.replace(old, new, 1)
p.write_text(text)

# 4) Acceptance covers domain state, first-room authoring, canonical save and UI
# save path. This guards against demo content leaking back into new projects.
Path('test/f22_blank_project_test.dart').write_text(r'''import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _F22MemoryStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};

  @override
  Future<void> save(EditorProjectDocument document) async {
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async =>
      documents[projectId];

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List.unmodifiable(documents.values);
}

void main() {
  test('F22 blank workspace contains no demo-derived engineering content', () {
    final controller = EditorController.blank(levelId: 'blank-level');
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);
    final workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'blank-project',
      projectName: 'Blank project',
    );
    addTearDown(workspace.dispose);

    expect(controller.level.spaces, isEmpty);
    expect(controller.openings, isEmpty);
    expect(controller.selectedSpaceId, isNull);
    expect(controller.p2.components, isEmpty);
    expect(controller.p2.routes, isEmpty);
    expect(workspace.building.levels, hasLength(1));
    expect(workspace.building.verticalCores, isEmpty);
    expect(workspace.activeLevel!.zones, isEmpty);
    expect(workspace.site.outdoorZones, isEmpty);
    expect(workspace.site.connections, isEmpty);
  });

  test('F22 first authored room starts at room-1 and persists canonically', () {
    final controller = EditorController.blank(levelId: 'blank-level');
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);
    final workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'blank-project',
      projectName: 'Blank project',
    );
    addTearDown(workspace.dispose);

    controller.addRectangleRoom(
      const MmPoint(1000, 1000),
      const MmPoint(5000, 4000),
    );
    expect(controller.level.spaces, hasLength(1));
    expect(controller.level.spaces.single.id, 'room-1');
    expect(controller.level.spaces.single.name, 'Комната 1');
    expect(controller.selectedSpaceId, 'room-1');

    final metadata = EditorProjectMetadata.create(
      projectId: 'blank-project',
      projectName: 'Blank project',
    );
    final document = EditorProjectDocument.capture(
      workspace,
      metadata: metadata,
    );
    expect(document.building.levels.single.level.spaces, hasLength(1));
    expect(document.p2State.components, isEmpty);
    expect(document.p2State.routes, isEmpty);
  });

  testWidgets('F22 new-project screen saves a truly blank document', (tester) async {
    final store = _F22MemoryStore();
    final metadata = EditorProjectMetadata.create(
      projectId: 'ui-blank-project',
      projectName: 'UI blank project',
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: store,
          initialMetadata: metadata,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Комната 101'), findsNothing);
    expect(find.text('Коридор'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();

    final document = store.documents['ui-blank-project'];
    expect(document, isNotNull);
    expect(document!.building.levels.single.level.spaces, isEmpty);
    expect(document.openingsByLevel.values.expand((items) => items), isEmpty);
    expect(document.p2State.components, isEmpty);
    expect(document.p2State.routes, isEmpty);
    expect(document.site.outdoorZones, isEmpty);
    expect(document.site.connections, isEmpty);
  });
}
''')
