import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C canonical runtime navigator', () {
    testWidgets('renders canonical tree, breadcrumb and labeled authoring actions',
        (tester) async {
      final session = _session(_project());

      await tester.pumpWidget(_host(session));
      await tester.pump();

      expect(find.byKey(const ValueKey('canonical-project-tree')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('canonical-project-breadcrumb')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-node-site-site-root')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-node-building-building-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-node-level-a-level-1')),
        findsOneWidget,
      );
      expect(find.text('+ Building'), findsOneWidget);
      expect(find.text('+ Level'), findsOneWidget);
      expect(find.text('+ Room'), findsOneWidget);
    });

    testWidgets('equal level numbers navigate by stable LevelId', (tester) async {
      final session = _session(_project());
      final observed = <String>[];

      await tester.pumpWidget(
        _host(
          session,
          onNavigationChanged: (navigation) {
            observed.add(
              '${navigation.activeBuildingId}:${navigation.activeLevelId}',
            );
          },
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('project-node-building-building-b')),
      );
      await tester.pumpAndSettle();

      expect(session.navigation.activeBuildingId, BuildingId('building-b'));
      expect(session.navigation.activeLevelId, LevelId('b-level-1'));
      expect(observed, contains('building-b:b-level-1'));
      expect(
        find.byKey(const ValueKey('breadcrumb-level-b-level-1')),
        findsOneWidget,
      );
    });

    testWidgets('Building action commits canonically and reveals created node',
        (tester) async {
      final session = _session(_project());
      EntityId? committedId;

      await tester.pumpWidget(
        _host(
          session,
          requestBuilding: (_) async =>
              const CreateBuildingRequest(name: 'Building C', displayOrder: 2),
          onAuthoringCommitted: (_, createdId) => committedId = createdId,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('+ Building'));
      await tester.pumpAndSettle();

      expect(committedId, isA<BuildingId>());
      expect(session.navigation.activeBuildingId, committedId);
      expect(session.navigation.activeLevelId, isNull);
      expect(session.project.index.building(committedId! as BuildingId), isNotNull);
      expect(find.text('Building C'), findsWidgets);
    });

    testWidgets('Level action targets exact active BuildingId', (tester) async {
      final session = _session(_project());
      BuildingId? requestedParent;

      session.activateBuilding(BuildingId('building-b'));
      await tester.pumpWidget(
        _host(
          session,
          requestLevel: (_, buildingId) async {
            requestedParent = buildingId;
            return const CreateLevelRequest(
              name: 'Floor 2 B',
              levelNumber: 2,
              elevationMm: 3000,
              displayOrder: 1,
            );
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text('+ Level'));
      await tester.pumpAndSettle();

      expect(requestedParent, BuildingId('building-b'));
      final activeLevel = session.navigation.activeLevelId!;
      expect(session.project.index.level(activeLevel)!.buildingId, requestedParent);
      expect(session.project.index.level(activeLevel)!.levelNumber, 2);
      expect(find.text('Floor 2 B'), findsWidgets);
    });

    testWidgets('Room action targets active LevelId and selects created Space',
        (tester) async {
      final session = _session(_project());
      LevelId? requestedParent;

      await tester.pumpWidget(
        _host(
          session,
          requestRoom: (_, levelId) async {
            requestedParent = levelId;
            return const CreateRoomRequest(name: 'New room');
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text('+ Room'));
      await tester.pumpAndSettle();

      expect(requestedParent, LevelId('a-level-1'));
      final selectedSpaceId = session.navigation.selectedSpaceId!;
      expect(session.project.index.space(selectedSpaceId)!.levelId, requestedParent);
      expect(find.text('New room'), findsWidgets);
      expect(
        find.byKey(ValueKey('project-node-space-${selectedSpaceId.value}')),
        findsOneWidget,
      );
    });

    testWidgets('missing request resolver keeps corresponding control disabled',
        (tester) async {
      final session = _session(_project());

      await tester.pumpWidget(_host(session));
      await tester.pump();

      final buildingButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Building'),
      );
      final levelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Level'),
      );
      final roomButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Room'),
      );

      expect(buildingButton.onPressed, isNull);
      expect(levelButton.onPressed, isNull);
      expect(roomButton.onPressed, isNull);
    });
  });
}

Widget _host(
  ProjectStructureAuthoringSession session, {
  BuildingRequestResolver? requestBuilding,
  LevelRequestResolver? requestLevel,
  RoomRequestResolver? requestRoom,
  ValueChanged<ProjectNavigationState>? onNavigationChanged,
  ProjectAuthoringCommittedCallback? onAuthoringCommitted,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 700,
        child: CanonicalProjectNavigator(
          session: session,
          requestBuilding: requestBuilding,
          requestLevel: requestLevel,
          requestRoom: requestRoom,
          onNavigationChanged: onNavigationChanged,
          onAuthoringCommitted: onAuthoringCommitted,
        ),
      ),
    ),
  );
}

ProjectStructureAuthoringSession _session(ProjectAggregateRoot project) {
  return ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(17)),
  );
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-root');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('a-level-1');
  final levelB = LevelId('b-level-1');

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: <BuildingId>[buildingA, buildingB],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        buildingA: ProjectBuildingEntity(
          id: buildingA,
          siteId: siteId,
          name: 'Building A',
          displayOrder: 0,
          levelIds: <LevelId>[levelA],
        ),
        buildingB: ProjectBuildingEntity(
          id: buildingB,
          siteId: siteId,
          name: 'Building B',
          displayOrder: 1,
          levelIds: <LevelId>[levelB],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelA: ProjectLevelEntity(
          id: levelA,
          buildingId: buildingA,
          name: 'Floor 1 A',
          levelNumber: 1,
          displayOrder: 0,
          elevationMm: 0,
        ),
        levelB: ProjectLevelEntity(
          id: levelB,
          buildingId: buildingB,
          name: 'Floor 1 B',
          levelNumber: 1,
          displayOrder: 0,
          elevationMm: 0,
        ),
      },
      zones: const <ZoneId, ProjectStructuralZoneEntity>{},
      spaces: const <SpaceId, ProjectSpaceEntity>{},
    ),
  );
}
