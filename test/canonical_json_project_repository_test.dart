import 'dart:io';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical JSON repository preserves multi-building identity graph',
      () async {
    final root =
        await Directory.systemTemp.createTemp('elecx-canonical-project-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final repository = JsonProjectRepository(
      rootDirectory: root,
      codec: const CanonicalProjectDocumentCodec(),
    );
    final source = _snapshot();

    await repository.save(source);
    final restored = await repository.load(source.id);

    expect(restored, isNotNull);
    expect(restored!.id, source.id);
    expect(restored.siteId, source.siteId);
    expect(restored.localVersion, source.localVersion);
    expect(restored.aggregate.stores.buildings, hasLength(2));
    expect(restored.aggregate.stores.levels, hasLength(2));
    expect(
      restored.aggregate.index.buildingByLevel[LevelId('level-a')],
      BuildingId('building-a'),
    );
    expect(
      restored.aggregate.index.buildingByLevel[LevelId('level-b')],
      BuildingId('building-b'),
    );

    final summaries = await repository.list();
    expect(summaries, hasLength(1));
    expect(summaries.single.id, source.id);
  });
}

ProjectSnapshot _snapshot() {
  final siteId = SiteId('site-root');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('level-a');
  final levelB = LevelId('level-b');

  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: ProjectId('project-canonical'),
      siteId: siteId,
      version: LocalProjectVersion(11),
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
            displayOrder: 10,
            levelIds: <LevelId>[levelA],
          ),
          buildingB: ProjectBuildingEntity(
            id: buildingB,
            siteId: siteId,
            name: 'Building B',
            displayOrder: 20,
            levelIds: <LevelId>[levelB],
          ),
        },
        levels: <LevelId, ProjectLevelEntity>{
          levelA: ProjectLevelEntity(
            id: levelA,
            buildingId: buildingA,
            name: 'Floor 1',
            levelNumber: 1,
            displayOrder: 1,
            elevationMm: 0,
          ),
          levelB: ProjectLevelEntity(
            id: levelB,
            buildingId: buildingB,
            name: 'Floor 1',
            levelNumber: 1,
            displayOrder: 1,
            elevationMm: 0,
          ),
        },
      ),
    ),
    name: 'Canonical project',
    createdAt: DateTime.utc(2026, 10, 21, 8),
    updatedAt: DateTime.utc(2026, 10, 21, 9),
  );
}
