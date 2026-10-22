import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/space_semantics_inspector.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected canonical room exposes read-only semantics without owner',
      (tester) async {
    _useDesktopSurface(tester);
    final fixture = _fixture(projectId: 'p6f-read-only');

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: fixture.store,
          initialDocument: fixture.document,
          canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
            resolveRuntime: (_, __) => fixture.runtime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SpaceSemanticsInspector), findsOneWidget);
    expect(
      find.byKey(const ValueKey('space-semantics-production-inspector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('space-semantics-usage')), findsNothing);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(fixture.session.project.version.value, 0);
  });

  testWidgets('owned usage edit commits once and leaves legacy document saved',
      (tester) async {
    _useDesktopSurface(tester);
    final fixture = _fixture(projectId: 'p6f-owned');
    var ownershipReceipts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: fixture.store,
          initialDocument: fixture.document,
          canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
            resolveRuntime: (_, __) => fixture.runtime,
            onSpaceSemanticsCommitted: (editing, result) {
              ownershipReceipts++;
              expect(editing.projectId, fixture.session.project.id);
              expect(result.project.version.value, 1);
              return const CanonicalAuthoringOwnershipReceipt.accepted();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final usage = find.byKey(const ValueKey('space-semantics-usage'));
    expect(usage, findsOneWidget);
    expect(fixture.session.project.version.value, 0);

    await tester.tap(usage);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bedroom').last);
    await tester.pumpAndSettle();

    expect(ownershipReceipts, 1);
    expect(fixture.session.project.version.value, 1);
    expect(
      fixture.session.project.index.space(fixture.spaceId)!.usage,
      SpaceUsage.bedroom,
    );
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('persistence owner mismatch keeps semantics inspector read only',
      (tester) async {
    _useDesktopSurface(tester);
    final fixture = _fixture(
      projectId: 'p6f-owner-mismatch',
      persistenceOwnerProjectId: ProjectId('different-owner'),
    );
    var ownershipReceipts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: fixture.store,
          initialDocument: fixture.document,
          canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
            resolveRuntime: (_, __) => fixture.runtime,
            onSpaceSemanticsCommitted: (_, __) {
              ownershipReceipts++;
              return const CanonicalAuthoringOwnershipReceipt.accepted();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SpaceSemanticsInspector), findsOneWidget);
    expect(find.byKey(const ValueKey('space-semantics-usage')), findsNothing);
    expect(ownershipReceipts, 0);
    expect(fixture.session.project.version.value, 0);
  });
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final class _Fixture {
  const _Fixture({
    required this.document,
    required this.store,
    required this.session,
    required this.runtime,
    required this.spaceId,
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
  final SpaceId spaceId;
}

_Fixture _fixture({
  required String projectId,
  ProjectId? persistenceOwnerProjectId,
}) {
  final timestamp = DateTime.utc(2026, 10, 22, 3);
  final metadata = EditorProjectMetadata(
    projectId: projectId,
    projectName: 'P6F Production',
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  final legacyController = EditorController.demo();
  final legacyWorkspace = EditorBuildingWorkspace.blank(
    legacyController,
    projectId: projectId,
    projectName: metadata.projectName,
  );
  final document = EditorProjectDocument.capture(
    legacyWorkspace,
    metadata: metadata,
  );
  legacyWorkspace.dispose();
  legacyController.disposeP2State();
  legacyController.dispose();

  final siteId = SiteId('canonical-site');
  final buildingId = BuildingId('canonical-building');
  final levelId = LevelId('canonical-level');
  final spaceId = SpaceId('canonical-room-101');
  final project = ProjectAggregateRoot(
    id: ProjectId(projectId),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: <BuildingId>[buildingId],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
          name: 'Room 101',
          usage: SpaceUsage.kitchen,
        ),
      },
    ),
  );
  final navigation = ProjectNavigationState.restore(
    project,
    activeBuildingId: buildingId,
    activeLevelId: levelId,
    selectedSpaceId: spaceId,
  );
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(606)),
    navigation: navigation,
  );
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: buildingId,
    legacyBuildingId: 'building-$projectId',
    legacyLevelIds: <LevelId, String>{levelId: 'level-1'},
    legacySpaceIds: <SpaceId, String>{spaceId: 'room-101'},
  );
  final runtime = CanonicalEditorResolvedRuntime(
    session: session,
    binding: binding,
    persistenceOwnerProjectId:
        persistenceOwnerProjectId ?? ProjectId(projectId),
  );

  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
    session: session,
    runtime: runtime,
    spaceId: spaceId,
  );
}

final class _MemoryProjectStore implements EditorProjectStore {
  _MemoryProjectStore(this.document);

  EditorProjectDocument? document;

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    final current = document;
    if (current == null || current.projectId != projectId) return null;
    return current;
  }

  @override
  Future<List<EditorProjectDocument>> list() async =>
      document == null ? const [] : <EditorProjectDocument>[document!];

  @override
  Future<void> save(EditorProjectDocument document) async {
    this.document = document;
  }
}
