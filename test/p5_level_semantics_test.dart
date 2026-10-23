import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5 canonical level semantics', () {
    test('authoring persists explicit technical level semantics', () {
      final project = _project();
      final session = ProjectStructureAuthoringSession(
        mutations: ProjectMutationSession(project),
        idFactory: SecureRandomEntityIdFactory(random: Random(5)),
      );

      final result = session.createLevel(
        const CreateLevelRequest(
          name: 'Technical floor',
          levelNumber: 10,
          elevationMm: 30000,
          kind: ProjectLevelKind.technical,
          floorToFloorHeightMm: 4200,
        ),
      );

      final level = result.project.index.level(result.createdId)!;
      expect(level.kind, ProjectLevelKind.technical);
      expect(level.floorToFloorHeightMm, 4200);
      expect(level.levelNumber, 10);
      expect(level.elevationMm, 30000);
    });

    test('authoring without explicit kind infers physical role deterministically',
        () {
      ProjectLevelKind createKind(int number) {
        final session = ProjectStructureAuthoringSession(
          mutations: ProjectMutationSession(_project()),
          idFactory: SecureRandomEntityIdFactory(random: Random(number + 40)),
        );
        final result = session.createLevel(
          CreateLevelRequest(
            name: 'Level $number',
            levelNumber: number,
            elevationMm: number * 3000,
          ),
        );
        return result.project.index.level(result.createdId)!.kind;
      }

      expect(createKind(-1), ProjectLevelKind.basement);
      expect(createKind(0), ProjectLevelKind.ground);
      expect(createKind(1), ProjectLevelKind.residential);
      expect(_level(1).kind, ProjectLevelKind.unknown);
      expect(_level(1).floorToFloorHeightMm, 3000);
    });

    test('invalid floor-to-floor height fails closed', () {
      expect(
        () => ProjectLevelEntity(
          id: LevelId('invalid-height'),
          buildingId: BuildingId('building-a'),
          name: 'Invalid',
          levelNumber: 1,
          elevationMm: 0,
          floorToFloorHeightMm: 0,
        ),
        throwsArgumentError,
      );
    });

    test('schema v8 round-trip preserves explicit level semantics', () {
      const codec = CanonicalProjectDocumentCodec();
      final source = ProjectSnapshot(
        aggregate: _project(
          level: ProjectLevelEntity(
            id: LevelId('level-technical'),
            buildingId: BuildingId('building-a'),
            name: 'Technical',
            levelNumber: 5,
            elevationMm: 15000,
            kind: ProjectLevelKind.technical,
            floorToFloorHeightMm: 4500,
          ),
        ),
        name: 'P5 semantics',
        createdAt: DateTime.utc(2026, 10, 23, 10),
        updatedAt: DateTime.utc(2026, 10, 23, 10),
      );

      final encoded = codec.encode(source);
      expect(encoded.schemaVersion, 8);
      final levelJson =
          (encoded.payload['levels']! as List).single as Map<String, Object?>;
      expect(levelJson['kind'], 'technical');
      expect(levelJson['floorToFloorHeightMm'], 4500);

      final restored = codec.decode(encoded);
      final level = restored.aggregate.index.level(LevelId('level-technical'))!;
      expect(level.kind, ProjectLevelKind.technical);
      expect(level.floorToFloorHeightMm, 4500);
    });

    test('schema v7 migration supplies deterministic safe defaults', () {
      const codec = CanonicalProjectDocumentCodec();
      final baseline = codec.encode(
        ProjectSnapshot(
          aggregate: _project(level: _level(-2)),
          name: 'Legacy v7',
          createdAt: DateTime.utc(2026, 10, 23, 10),
          updatedAt: DateTime.utc(2026, 10, 23, 10),
        ),
      );
      final payload = Map<String, Object?>.from(baseline.payload);
      payload['levels'] = <Object?>[
        for (final raw in baseline.payload['levels']! as List)
          () {
            final level = Map<String, Object?>.from(raw as Map);
            level.remove('kind');
            level.remove('floorToFloorHeightMm');
            return level;
          }(),
      ];

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 7, payload: payload),
      );
      final level = restored.aggregate.index.level(LevelId('level-1'))!;
      expect(level.kind, ProjectLevelKind.basement);
      expect(level.floorToFloorHeightMm, 3000);
    });
  });
}

ProjectLevelEntity _level(int number) => ProjectLevelEntity(
      id: LevelId('level-1'),
      buildingId: BuildingId('building-a'),
      name: 'Level $number',
      levelNumber: number,
      elevationMm: number * 3000,
    );

ProjectAggregateRoot _project({ProjectLevelEntity? level}) {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final selectedLevel = level;
  return ProjectAggregateRoot(
    id: ProjectId('p5-level-semantics'),
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
          levelIds: selectedLevel == null
              ? const <LevelId>[]
              : <LevelId>[selectedLevel.id],
        ),
      },
      levels: selectedLevel == null
          ? const <LevelId, ProjectLevelEntity>{}
          : <LevelId, ProjectLevelEntity>{selectedLevel.id: selectedLevel},
    ),
  );
}
