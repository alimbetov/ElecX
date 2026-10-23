import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/slab_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/vertical_core_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = VerticalCoreAwareCanonicalProjectDocumentCodec();

  test(
      'schema v9 round-trip preserves stable VerticalCore identity and geometry',
      () {
    final fixture = _Fixture();
    final core = fixture.core();
    final snapshot = fixture.snapshot(verticalCores: {core.id: core});

    final document = codec.encode(snapshot);
    final restored = codec.decode(document);

    expect(document.schemaVersion, 9);
    final restoredCore = restored.aggregate.index.verticalCore(fixture.coreId);
    expect(restoredCore, isNotNull);
    expect(restoredCore!.id, fixture.coreId);
    expect(restoredCore.buildingId, fixture.buildingId);
    expect(restoredCore.kind, VerticalCoreKind.riser);
    expect(restoredCore.name, 'Main riser');
    expect(restoredCore.levelIds, {fixture.level1Id, fixture.level2Id});
    expect(restoredCore.footprint, hasLength(4));
    expect(
      restored.aggregate.index.verticalCoresForBuilding(fixture.buildingId),
      {fixture.coreId},
    );
  });

  test('schema v8 migration never invents a VerticalCore', () {
    final fixture = _Fixture();
    const v8 = SlabAwareCanonicalProjectDocumentCodec();
    final legacyDocument = v8.encode(fixture.snapshot());

    final restored = codec.decode(legacyDocument);

    expect(legacyDocument.schemaVersion, 8);
    expect(restored.aggregate.stores.verticalCores, isEmpty);
  });

  test('schema v9 rejects duplicate VerticalCore identity', () {
    final fixture = _Fixture();
    final core = fixture.core();
    final encoded = codec.encode(
      fixture.snapshot(verticalCores: {core.id: core}),
    );
    final payload = Map<String, Object?>.from(encoded.payload);
    final cores = List<Object?>.from(payload['verticalCores']! as List)
      ..add((payload['verticalCores']! as List).first);
    payload['verticalCores'] = cores;

    expect(
      () => codec.decode(ProjectDocument(schemaVersion: 9, payload: payload)),
      throwsFormatException,
    );
  });
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId level1Id = LevelId('level-01');
  final LevelId level2Id = LevelId('level-02');
  final VerticalCoreId coreId = VerticalCoreId('core-01');

  ProjectVerticalCore core() => ProjectVerticalCore(
        id: coreId,
        buildingId: buildingId,
        kind: VerticalCoreKind.riser,
        levelIds: [level1Id, level2Id],
        footprint: const [
          BoundaryPointMm(xMm: 1000, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1400),
          BoundaryPointMm(xMm: 1000, yMm: 1400),
        ],
        name: 'Main riser',
      );

  ProjectSnapshot snapshot({
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores = const {},
  }) {
    final aggregate = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: [buildingId],
          ),
        },
        buildings: {
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'Building',
            levelIds: [level1Id, level2Id],
          ),
        },
        levels: {
          level1Id: ProjectLevelEntity(
            id: level1Id,
            buildingId: buildingId,
            name: 'Level 1',
            levelNumber: 1,
            elevationMm: 0,
          ),
          level2Id: ProjectLevelEntity(
            id: level2Id,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
          ),
        },
        verticalCores: verticalCores,
      ),
    );
    final now = DateTime.utc(2026, 1, 1);
    return ProjectSnapshot(
      aggregate: aggregate,
      name: 'Vertical Core Project',
      createdAt: now,
      updatedAt: now,
    );
  }
}
