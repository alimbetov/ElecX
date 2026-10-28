import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
import 'package:elecx/src/features/editor/project_structure_authoring_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE10-CQ22 authoring publication ownership boundary', () {
    testWidgets(
      'committed authoring callback failure escapes navigator without rollback',
      (tester) async {
        final project = _project();
        final session = ProjectStructureAuthoringSession(
          mutations: ProjectMutationSession(project),
          idFactory: SecureRandomEntityIdFactory(random: Random(22022)),
          navigation: ProjectNavigationState.restore(project),
        );
        final sentinel = StateError('publication-owner-failed');
        var callbackCount = 0;
        var requestCount = 0;
        var operationErrorCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: CanonicalProjectNavigator(
                  session: session,
                  requestBuilding: (_) async {
                    requestCount++;
                    return CreateBuildingRequest(
                      name: 'Committed Building $requestCount',
                      displayOrder: requestCount - 1,
                    );
                  },
                  onAuthoringCommitted: (_, __) async {
                    callbackCount++;
                    if (callbackCount == 1) {
                      throw sentinel;
                    }
                  },
                  onError: (_) => operationErrorCount++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ProjectStructureAuthoringControls keeps the navigator's Future-aware
        // action before adapting it to Flutter's VoidCallback button surface.
        // Await that boundary directly so the qualification observes exactly
        // the Future that the navigator returns to its host. Do not introduce a
        // fake-async Timer here: testWidgets only advances timers during pump().
        final controls = tester.widget<ProjectStructureAuthoringControls>(
          find.byType(ProjectStructureAuthoringControls),
        );
        await expectLater(
          Future<void>.sync(controls.onAddBuilding!),
          throwsA(same(sentinel)),
        );
        await tester.pump();

        expect(callbackCount, 1);
        expect(requestCount, 1);
        expect(operationErrorCount, 0);

        // Publication happens after the canonical transaction boundary. A host
        // failure is observable, but it must not pretend the commit rolled back.
        expect(session.project.version, LocalProjectVersion(1));
        expect(session.project.stores.buildings, hasLength(1));
        expect(
          session.project.stores.buildings.values.single.name,
          'Committed Building 1',
        );

        // A propagated owner failure does not poison subsequent navigator use.
        // The second callback succeeds and the ordinary UI path can commit again.
        await tester.tap(find.text('+ Building'));
        await tester.pumpAndSettle();

        expect(requestCount, 2);
        expect(callbackCount, 2);
        expect(operationErrorCount, 0);
        expect(session.project.version, LocalProjectVersion(2));
        expect(session.project.stores.buildings, hasLength(2));
      },
    );
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('pre10-def022-site');
  return ProjectAggregateRoot(
    id: ProjectId('pre10-def022-project'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const [],
        ),
      },
    ),
  );
}
