import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elecx/src/features/editor/canonical_project_navigator.dart';

void main() {
  group('CanonicalProjectNavigator', () {
    testWidgets('tree and breadcrumb follow canonical navigation', (
      tester,
    ) async {
      final session = _session(_project());
      final observed = <String>[];

      await tester.pumpWidget(
        _host(
          session,
          onNavigationChanged: (navigation) {
            observed.add(
              '${navigation.activeBuildingId?.value}:'
              '${navigation.activeLevelId?.value}',
            );
          },
        ),
      );
      await tester.pump();

      expect(find.text('Site'), findsOneWidget);
      expect(find.text('Building A'), findsOneWidget);
      expect(find.text('Building B'), findsOneWidget);
      expect(find.text('Level A1'), findsOneWidget);
      expect(find.text('Room A'), findsOneWidget);
      expect(find.text('Zone A'), findsOneWidget);

      await tester.tap(find.text('Building B'));
      await tester.pumpAndSettle();
      expect(session.navigation.activeBuildingId, BuildingId('building-b'));
      expect(session.navigation.activeLevelId, isNull);

      await tester.tap(find.text('Level B1'));
      await tester.pumpAndSettle();
      expect(session.navigation.activeBuildingId, BuildingId('building-b'));
      expect(session.navigation.activeLevelId, LevelId('b-level-1'));
      expect(observed, contains('building-b:b-level-1'));
      expect(
        find.byKey(const ValueKey('breadcrumb-level-b-level-1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Building action commits canonically and reveals created node',
      (tester) async {
        final session = _session(_project());
        EntityId? committedId;

        await tester.pumpWidget(
          _host(
            session,
            requestBuilding: (_) async => const CreateBuildingRequest(
              name: 'Building C',
              displayOrder: 2,
            ),
            onAuthoringCommitted: (_, result) => committedId = result.createdId,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('+ Building'));
        await tester.pumpAndSettle();

        expect(committedId, isA<BuildingId>());
        expect(session.navigation.activeBuildingId, committedId);
        expect(session.navigation.activeLevelId, isNull);
        expect(
          session.project.index.building(committedId! as BuildingId),
          isNotNull,
        );
        expect(find.text('Building C'), findsWidgets);
      },
    );

    testWidgets(
      'stale Level authoring context fails closed after active Building changes',
      (tester) async {
        final session = _session(_project());
        Object? error;

        await tester.pumpWidget(
          _host(
            session,
            requestLevel: (_, buildingId) async {
              session.activateBuilding(BuildingId('building-b'));
              return const CreateLevelRequest(
                name: 'stale',
                levelNumber: 99,
                elevationMm: 999,
              );
            },
            onError: (value) => error = value,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('+ Level'));
        await tester.pumpAndSettle();

        expect(
          error,
          isA<ProjectStructureAuthoringException>().having(
            (value) => value.code,
            'code',
            ProjectStructureAuthoringIssueCode.authoringContextChanged,
          ),
        );
        expect(
          session.project.stores.levels.keys,
          isNot(contains(LevelId('level-generated'))),
        );
      },
    );
  });
}

Widget _host(
  ProjectStructureAuthoringSession session, {
  BuildingRequestResolver? requestBuilding,
  LevelRequestResolver? requestLevel,
  RoomRequestResolver? requestRoom,
  ValueChanged<ProjectNavigationState>? onNavigationChanged,
  ProjectAuthoringCommittedCallback? onAuthoringCommitted,
  ValueChanged<Object>? onError,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: CanonicalProjectNavigator(
            session: session,
            requestBuilding: requestBuilding,
            requestLevel: requestLevel,
            requestRoom: requestRoom,
            onNavigationChanged: onNavigationChanged,
            onAuthoringCommitted: onAuthoringCommitted,
            onError: onError,
          ),
        ),
      ),
    );

ProjectStructureAuthoringSession _session(ProjectAggregateRoot project) =>
    ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(project),
      idFactory: SecureRandomEntityIdFactory(random: Random(17)),
      navigation: ProjectNavigationState.restore(
        project,
        activeBuildingId: BuildingId('building-a'),
        activeLevelId: LevelId('a-level-1'),
        selectedSpaceId: SpaceId('room-a'),
      ),
    );

ProjectAggregateRoot _project() {
  final siteId = SiteId('site');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('a-level-1');
  final levelB = LevelId('b-level-1');
  final zoneA = ZoneId('zone-a');
  final roomA = SpaceId('room-a');

  return ProjectAggregateRoot(
    id: ProjectId('project'),
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
          levelIds: <LevelId>[levelA],
        ),
        buildingB: ProjectBuildingEntity(
          id: buildingB,
          siteId: siteId,
          name: 'Building B',
          levelIds: <LevelId>[levelB],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelA: ProjectLevelEntity(
          id: levelA,
          buildingId: buildingA,
          name: 'Level A1',
          levelNumber: 1,
          elevationMm: 0,
          structuralZoneIds: <ZoneId>[zoneA],
          spaceIds: <SpaceId>[roomA],
        ),
        levelB: ProjectLevelEntity(
          id: levelB,
          buildingId: buildingB,
          name: 'Level B1',
          levelNumber: 1,
          elevationMm: 0,
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneA: ProjectStructuralZoneEntity(
          id: zoneA,
          levelId: levelA,
          name: 'Zone A',
          spaceIds: <SpaceId>[roomA],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(
          id: roomA,
          levelId: levelA,
          name: 'Room A',
          structuralZoneId: zoneA,
        ),
      },
    ),
  );
}
