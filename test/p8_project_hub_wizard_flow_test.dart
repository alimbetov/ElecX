import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:elecx/src/features/projects/project_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Project Hub New Project enters production Wizard and opens projected result',
    (tester) async {
      final legacyStore = _MemoryEditorProjectStore();
      final canonicalRepository = _MemoryProjectRepository();

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

      await tester.tap(find.byKey(const ValueKey('create-project')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-project-dialog')), findsOneWidget);
      expect(find.text('Создать через Wizard'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('create-project-blank')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('new-project-name')),
        'Hub Wizard Tower',
      );
      await tester.tap(find.byKey(const ValueKey('create-project-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectWizardScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wizard-building-name')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('wizard-floor-count')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wizard-basement-count')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wizard-floor-height')),
        '3200',
      );
      await tester.tap(find.byKey(const ValueKey('wizard-generate')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('wizard-diff-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard-apply')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wizard-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
      expect(legacyStore.documents, hasLength(1));
      final projected = legacyStore.documents.single;
      expect(projected.projectName, 'Hub Wizard Tower');
      expect(projected.building.levels.length, greaterThan(1));

      final canonical = await canonicalRepository.load(
        ProjectId(projected.projectId),
      );
      expect(canonical, isNotNull);
      expect(
        canonical!.aggregate.stores.levels.length,
        projected.building.levels.length,
      );
      expect(
        canonical.aggregate.stores.levels.keys.map((id) => id.value).toSet(),
        isNotEmpty,
      );
    },
  );
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
