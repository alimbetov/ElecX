import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/projects/platform_project_hub_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _EmptyProjectStore implements EditorProjectStore {
  @override
  Future<EditorProjectDocument?> load(String projectId) async => null;

  @override
  Future<List<EditorProjectDocument>> list() async => const [];

  @override
  Future<void> save(EditorProjectDocument document) async {}
}

final class _EmptyRecoveryStore implements EditorProjectRecoveryStore {
  @override
  Future<void> discard(String projectId) async {}

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async => null;

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async => const [];

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {}
}

final class _EmptyCanonicalRepository implements ProjectRepository {
  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async => null;

  @override
  Future<List<ProjectSummary>> list() async => const [];

  @override
  Future<void> save(ProjectSnapshot snapshot) async {}
}

void main() {
  testWidgets(
    'PRE10-Q06 platform storage init failure retries in the same app session',
    (tester) async {
      var projectStoreAttempts = 0;

      Future<EditorProjectStore> openProjectStore() async {
        projectStoreAttempts++;
        if (projectStoreAttempts == 1) {
          throw const FileSystemExceptionForTest('simulated native storage failure');
        }
        return _EmptyProjectStore();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformProjectHubScreen(
            projectStoreOpener: openProjectStore,
            recoveryStoreOpener: () async => _EmptyRecoveryStore(),
            canonicalRepositoryOpener: () async => _EmptyCanonicalRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(projectStoreAttempts, 1);
      expect(
        find.text('ElecX local storage could not be initialized.'),
        findsOneWidget,
      );
      expect(find.textContaining('simulated native storage failure'), findsNothing);
      expect(find.byKey(const ValueKey('platform-storage-retry')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('platform-storage-retry')));
      await tester.pumpAndSettle();

      expect(projectStoreAttempts, 2);
      expect(find.byType(ProjectHubScreen), findsOneWidget);
      expect(find.text('ElecX local storage could not be initialized.'), findsNothing);
    },
  );
}

/// Deliberately non-filesystem exception with a technical message that must not
/// leak into the user-facing storage initialization error contract.
final class FileSystemExceptionForTest implements Exception {
  const FileSystemExceptionForTest(this.message);

  final String message;

  @override
  String toString() => message;
}
