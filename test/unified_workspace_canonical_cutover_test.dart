import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_site_navigator.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C production screen cutover', () {
    testWidgets(
      'canonical runtime stays read-only without a persistence owner',
      (tester) async {
        _useDesktopSurface(tester);
        final fixture = _fixture();
        final beforeVersion = fixture.session.project.version;

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedWorkspaceEditorScreen(
              projectStore: fixture.store,
              initialDocument: fixture.document,
              canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
                resolveRuntime: (_, __) => fixture.runtime,
                requestBuilding: (_) async =>
                    const CreateBuildingRequest(name: 'Should stay disabled'),
                requestLevel: (_, __) async => const CreateLevelRequest(
                  name: 'Should stay disabled',
                  levelNumber: 2,
                  elevationMm: 3000,
                ),
                requestRoom: (_, __) async =>
                    const CreateRoomRequest(name: 'Should stay disabled'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
        expect(find.byType(UnifiedSiteNavigator), findsNothing);
        expect(find.text('Saved'), findsOneWidget);

        for (final label in ['+ Building', '+ Level', '+ Room']) {
          final button = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, label),
          );
          expect(button.onPressed, isNull, reason: '$label must fail closed');
        }
        expect(fixture.session.project.version, beforeVersion);
        expect(fixture.session.project.stores.buildings, hasLength(1));
        expect(fixture.session.project.stores.levels, hasLength(1));
        expect(fixture.session.project.stores.spaces, isEmpty);
      },
    );

    testWidgets(
      'authoring with persistence owner publishes once and blocks missing geometry',
      (tester) async {
        _useDesktopSurface(tester);
        final fixture = _fixture();
        var published = 0;
        EntityId? publishedId;

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedWorkspaceEditorScreen(
              projectStore: fixture.store,
              initialDocument: fixture.document,
              canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
                resolveRuntime: (_, __) => fixture.runtime,
                requestRoom: (_, __) async =>
                    const CreateRoomRequest(name: 'Canonical room'),
                onAuthoringCommitted: (session, createdId) {
                  published++;
                  publishedId = createdId;
                  return const CanonicalAuthoringOwnershipReceipt.accepted();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final roomButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '+ Room'),
        );
        expect(roomButton.onPressed, isNotNull);

        await tester.tap(find.text('+ Room'));
        await tester.pumpAndSettle();

        expect(published, 1);
        expect(publishedId, isA<SpaceId>());
        expect(
          fixture.session.project.index.space(publishedId! as SpaceId),
          isNotNull,
        );
        expect(
          find.byKey(const ValueKey('canonical-cutover-blocked')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'open replaces workspace and resolves canonical runtime again',
      (tester) async {
        _useDesktopSurface(tester);
        final fixture = _fixture();
        var resolverCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedWorkspaceEditorScreen(
              projectStore: fixture.store,
              initialDocument: fixture.document,
              canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
                resolveRuntime: (_, __) {
                  resolverCalls++;
                  return fixture.runtime;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final callsBeforeOpen = resolverCalls;

        await tester.tap(find.byKey(const ValueKey('project-open')));
        await tester.pumpAndSettle();

        expect(resolverCalls, greaterThan(callsBeforeOpen));
        expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
        expect(find.byType(UnifiedSiteNavigator), findsNothing);
      },
    );

    testWidgets('unresolved canonical runtime falls back to legacy navigator', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final fixture = _fixture();

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CanonicalProjectNavigator), findsNothing);
      expect(find.byType(UnifiedSiteNavigator), findsOneWidget);
    });
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
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
}

_Fixture _fixture() {
  final timestamp = DateTime.utc(2026, 10, 21, 12);
  const projectId = 'p5c-screen';
  final metadata = EditorProjectMetadata(
    projectId: projectId,
    projectName: 'P5C Screen',
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  final legacyController = EditorController.blank(
    levelId: 'level-$projectId-1',
  );
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

  final project = _canonicalProject();
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(73)),
  );
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: BuildingId('canonical-building'),
    legacyBuildingId: 'building-$projectId',
    legacyLevelIds: <LevelId, String>{
      LevelId('canonical-level'): 'level-$projectId-1',
    },
  );
  final runtime = CanonicalEditorResolvedRuntime(
    session: session,
    binding: binding,
  );
  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
    session: session,
    runtime: runtime,
  );
}

ProjectAggregateRoot _canonicalProject() {
  final siteId = SiteId('canonical-site');
  final buildingId = BuildingId('canonical-building');
  final levelId = LevelId('canonical-level');
  return ProjectAggregateRoot(
    id: ProjectId('canonical-project'),
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
        ),
      },
      zones: const <ZoneId, ProjectStructuralZoneEntity>{},
      spaces: const <SpaceId, ProjectSpaceEntity>{},
    ),
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
