import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_legacy_structure_projector.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'canonical-first crash window is recovered on the next Project Hub open',
    (tester) async {
      final canonicalRepository = _MemoryProjectRepository();
      final legacyStore = _MemoryEditorProjectStore([]);
      final initial = createInitialEditorProjectDocument(
        EditorProjectMetadata.create(
          projectId: 'p8-crash-window-project',
          projectName: 'Crash Window Project',
          now: DateTime.utc(2026, 10, 24, 11),
        ),
      );
      await legacyStore.save(initial);

      final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: initial,
        repository: canonicalRepository,
      );
      final project = handle.session.project;
      final wizard = WizardSession(
        target: NewProjectWizardTarget(
          projectId: project.id,
          siteId: project.siteId,
          baseVersion: project.version,
        ),
        registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
        mutations: handle.wizardMutations,
      );
      expect(wizard.begin(), isTrue);
      expect(
        wizard.selectFamily(BasicBuildingWizardProvider.familyId),
        isTrue,
      );
      expect(
        wizard.updateParameters(
          const BasicBuildingWizardParameters(
            buildingName: 'Recovered Tower',
            aboveGroundLevelCount: 2,
            basementLevelCount: 1,
            floorToFloorHeightMm: 3000,
            createGroundLevel: true,
          ),
        ),
        isTrue,
      );
      expect(wizard.generatePreview(), isTrue);
      expect(wizard.confirm(), isTrue);
      handle.acceptWizardCommit(wizard.commitResult!);
      await handle.saveCanonical();

      final canonicalLevelIds = handle.owner.project.stores.levels.keys.toSet();
      expect(canonicalLevelIds, hasLength(4));
      expect(legacyStore.documents.single.building.levels, hasLength(1));
      expect(
        const CanonicalLegacyStructureProjector().requiresProjection(
          legacy: legacyStore.documents.single,
          canonical: handle.owner.project,
          binding: handle.binding,
        ),
        isTrue,
      );

      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectHubScreen(
            projectStore: legacyStore,
            canonicalProjectRepository: canonicalRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('continue-project-p8-crash-window-project'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
      final recovered = legacyStore.documents.single;
      expect(recovered.building.levels, hasLength(4));

      final rebound = handle.rebindToLegacy(recovered);
      expect(rebound.binding.legacyLevelIds.keys.toSet(), canonicalLevelIds);
      expect(
          rebound.owner.project.stores.levels.keys.toSet(), canonicalLevelIds);
    },
  );
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

final class _MemoryEditorProjectStore implements EditorProjectStore {
  _MemoryEditorProjectStore(this.documents);

  final List<EditorProjectDocument> documents;

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
