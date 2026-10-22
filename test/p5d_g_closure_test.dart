import 'dart:io';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/editor_shell_state.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5D-G closure qualification', () {
    test('canonical explicit null round-trips as unspecified', () {
      const codec = CanonicalProjectDocumentCodec();
      final source = _snapshot();

      final encoded = codec.encode(source);
      expect(
        encoded.schemaVersion,
        CanonicalProjectDocumentCodec.schemaVersion,
      );
      expect(encoded.payload['projectOrientation'], <String, Object?>{
        'projectNorthMilliDegrees': null,
      });

      final restored = codec.decode(encoded);
      expect(restored.aggregate.engineeringMetadata.projectNorth, isNull);
    });

    test('canonical repository preserves specified Project North', () async {
      final root = await Directory.systemTemp.createTemp('elecx-p5d-g-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final repository = JsonProjectRepository(
        rootDirectory: root,
        codec: const CanonicalProjectDocumentCodec(),
      );
      final north = ProjectEngineeringNorth.fromDegrees(32.5);
      final source = _snapshot(north: north);

      await repository.save(source);
      final restored = await repository.load(source.id);

      expect(restored, isNotNull);
      expect(restored!.aggregate.engineeringMetadata.projectNorth, north);
      expect(restored.localVersion, source.localVersion);
    });

    test('compass visibility remains presentation-only canonical state', () {
      final project = _snapshot(north: ProjectEngineeringNorth.fromDegrees(90))
          .aggregate;
      final mutations = ProjectMutationSession(project);
      final shell = EditorShellState();
      final versionBefore = mutations.current.version;
      final northBefore = mutations.current.engineeringMetadata.projectNorth;

      shell.toggleCompass();
      shell.setFocusMode(true);
      shell.toggleCompass();
      shell.setCompassRequestedVisible(true);
      shell.exitFocusMode();

      expect(mutations.current.version, versionBefore);
      expect(mutations.current.engineeringMetadata.projectNorth, northBefore);
      expect(mutations.undoDepth, 0);
      expect(mutations.redoDepth, 0);
    });

    test('same-number levels in different buildings do not alias identity', () {
      final snapshot = _multiBuildingSnapshot();
      final project = snapshot.aggregate;

      final levelA = LevelId('level-a');
      final levelB = LevelId('level-b');

      expect(project.index.level(levelA)?.levelNumber, 1);
      expect(project.index.level(levelB)?.levelNumber, 1);
      expect(project.index.buildingByLevel[levelA], BuildingId('building-a'));
      expect(project.index.buildingByLevel[levelB], BuildingId('building-b'));
      expect(project.engineeringMetadata.projectNorth?.degrees, 15);
    });
  });
}

ProjectSnapshot _snapshot({ProjectEngineeringNorth? north}) {
  final projectId = ProjectId('p5d-g-project');
  final siteId = SiteId('p5d-g-site');
  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(7),
      engineeringMetadata: ProjectEngineeringMetadata(projectNorth: north),
      stores: ProjectEntityStores(
        sites: <SiteId, ProjectSiteEntity>{
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: const <BuildingId>[],
          ),
        },
      ),
    ),
    name: 'P5D-G project',
    createdAt: DateTime.utc(2026, 10, 21, 17),
    updatedAt: DateTime.utc(2026, 10, 21, 17, 1),
  );
}

ProjectSnapshot _multiBuildingSnapshot() {
  final projectId = ProjectId('p5d-g-multi');
  final siteId = SiteId('site-root');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('level-a');
  final levelB = LevelId('level-b');

  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(3),
      engineeringMetadata: ProjectEngineeringMetadata(
        projectNorth: ProjectEngineeringNorth.fromDegrees(15),
      ),
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
            name: 'Floor 1 A',
            levelNumber: 1,
            elevationMm: 0,
          ),
          levelB: ProjectLevelEntity(
            id: levelB,
            buildingId: buildingB,
            name: 'Floor 1 B',
            levelNumber: 1,
            elevationMm: 0,
          ),
        },
      ),
    ),
    name: 'P5D-G multi-building',
    createdAt: DateTime.utc(2026, 10, 21, 17),
    updatedAt: DateTime.utc(2026, 10, 21, 17, 1),
  );
}
