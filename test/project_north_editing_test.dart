import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectNorthEditingPort', () {
    test('shares the exact P3 timeline with structure authoring', () {
      final mutations = ProjectMutationSession(_project());
      final session = ProjectStructureAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(11)),
      );
      final editing = session.projectNorthEditing;

      expect(editing.projectId, session.project.id);
      expect(editing.version, session.project.version);
      expect(editing.currentProjectNorth, isNull);

      final result = editing.setProjectNorth(
        ProjectEngineeringNorth.fromDegrees(32.5),
      );

      expect(result, isNotNull);
      expect(session.project.version.value, 1);
      expect(editing.version, session.project.version);
      expect(
        session.project.engineeringMetadata.projectNorth?.degrees,
        32.5,
      );
    });

    test('same normalized value is a no-op and clear is canonical', () {
      final mutations = ProjectMutationSession(_project());
      final session = ProjectStructureAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(12)),
      );
      final editing = session.projectNorthEditing;

      expect(
        editing.setProjectNorth(ProjectEngineeringNorth.fromDegrees(90)),
        isNotNull,
      );
      expect(
        editing.setProjectNorth(ProjectEngineeringNorth.fromDegrees(450)),
        isNull,
      );
      expect(session.project.version.value, 1);

      expect(editing.clearProjectNorth(), isNotNull);
      expect(editing.currentProjectNorth, isNull);
      expect(session.project.version.value, 2);
    });
  });
}

ProjectAggregateRoot _project() {
  final projectId = ProjectId('p5d-edit-port');
  final siteId = SiteId('site');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const [],
        ),
      },
    ),
  );
}
