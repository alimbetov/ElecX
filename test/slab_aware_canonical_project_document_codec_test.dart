import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/slab_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = SlabAwareCanonicalProjectDocumentCodec();

  group('schema v8 slab persistence', () {
    test('round-trips stable slab identity, geometry and reverse indexes', () {
      final fixture = _CodecFixture();
      final snapshot = fixture.snapshotWithSlab();

      final document = codec.encode(snapshot);
      final restored = codec.decode(document);
      final slab = restored.aggregate.index.slab(fixture.slabId);

      expect(document.schemaVersion, 8);
      expect(document.payload['slabs'], isA<List<Object?>>());
      expect(slab, isNotNull);
      expect(slab!.id, fixture.slabId);
      expect(slab.buildingId, fixture.buildingId);
      expect(slab.belowLevelId, fixture.lowerLevelId);
      expect(slab.aboveLevelId, fixture.upperLevelId);
      expect(slab.bottomElevationMm, 3000);
      expect(slab.topElevationMm, 3200);
      expect(slab.thicknessMm, 200);
      expect(slab.materialId, 'reinforced-concrete');
      expect(slab.footprint, hasLength(4));
      expect(slab.belowFace.opposite, slab.aboveFace);
      expect(
        restored.aggregate.index.slabsForBuilding(fixture.buildingId),
        {fixture.slabId},
      );
      expect(
        restored.aggregate.index.slabsForLevel(fixture.lowerLevelId),
        {fixture.slabId},
      );
      expect(
        restored.aggregate.index.slabsForLevel(fixture.upperLevelId),
        {fixture.slabId},
      );
    });

    test('reads legacy schema v7 with empty slab store and upgrades on save',
        () {
      final fixture = _CodecFixture();
      final legacySnapshot = fixture.snapshotWithoutSlabs();
      const legacyCodec = CanonicalProjectDocumentCodec();
      final legacyDocument = legacyCodec.encode(legacySnapshot);

      expect(legacyDocument.schemaVersion, 7);

      final migrated = codec.decode(legacyDocument);
      expect(migrated.aggregate.stores.slabs, isEmpty);

      final upgraded = codec.encode(migrated);
      expect(upgraded.schemaVersion, 8);
      expect(upgraded.payload['slabs'], isEmpty);
    });

    test('fails closed when schema v8 omits slab array', () {
      final fixture = _CodecFixture();
      final encoded = codec.encode(fixture.snapshotWithoutSlabs());
      final payload = Map<String, Object?>.of(encoded.payload)..remove('slabs');

      expect(
        () => codec.decode(
          ProjectDocument(schemaVersion: 8, payload: payload),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fails closed on duplicate slab identity', () {
      final fixture = _CodecFixture();
      final encoded = codec.encode(fixture.snapshotWithSlab());
      final slabs = List<Object?>.of(encoded.payload['slabs']! as List);
      slabs.add(
        Map<String, Object?>.of(
          slabs.single! as Map<String, Object?>,
        ),
      );
      final payload = Map<String, Object?>.of(encoded.payload)
        ..['slabs'] = slabs;

      expect(
        () => codec.decode(
          ProjectDocument(schemaVersion: 8, payload: payload),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fails closed when persisted slab points to another building level',
        () {
      final fixture = _CodecFixture();
      final encoded = codec.encode(fixture.snapshotWithSlab());
      final slabs = List<Object?>.of(encoded.payload['slabs']! as List);
      final slab = Map<String, Object?>.of(
        slabs.single! as Map<String, Object?>,
      )..['aboveLevelId'] = 'foreign-level';
      slabs[0] = slab;

      final legacyPayload = Map<String, Object?>.of(encoded.payload)
        ..remove('slabs');
      final foreignLevel = <String, Object?>{
        'id': 'foreign-level',
        'buildingId': 'foreign-building',
        'name': 'Foreign level',
        'levelNumber': 2,
        'displayOrder': 0,
        'elevationMm': 3200,
        'zoneIds': <Object?>[],
        'spaceIds': <Object?>[],
      };
      final foreignBuilding = <String, Object?>{
        'id': 'foreign-building',
        'siteId': fixture.siteId.value,
        'name': 'Foreign building',
        'displayOrder': 1,
        'levelIds': <Object?>['foreign-level'],
      };
      final sites = List<Object?>.of(legacyPayload['sites']! as List);
      final site = Map<String, Object?>.of(
        sites.single! as Map<String, Object?>,
      );
      site['buildingIds'] = <Object?>[
        ...(site['buildingIds']! as List<Object?>),
        'foreign-building',
      ];
      sites[0] = site;
      legacyPayload['sites'] = sites;
      legacyPayload['buildings'] = <Object?>[
        ...(legacyPayload['buildings']! as List<Object?>),
        foreignBuilding,
      ];
      legacyPayload['levels'] = <Object?>[
        ...(legacyPayload['levels']! as List<Object?>),
        foreignLevel,
      ];

      final payload = <String, Object?>{
        ...legacyPayload,
        'slabs': slabs,
      };

      expect(
        () => codec.decode(
          ProjectDocument(schemaVersion: 8, payload: payload),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

final class _CodecFixture {
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building-a');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SlabId slabId = SlabId('slab-01-02');

  ProjectSnapshot snapshotWithSlab() => _snapshot(
        slabs: {slabId: _slab()},
      );

  ProjectSnapshot snapshotWithoutSlabs() => _snapshot();

  ProjectSnapshot _snapshot({Map<SlabId, ProjectSlab> slabs = const {}}) {
    final aggregate = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(4),
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
            name: 'Building A',
            levelIds: [lowerLevelId, upperLevelId],
          ),
        },
        levels: {
          lowerLevelId: ProjectLevelEntity(
            id: lowerLevelId,
            buildingId: buildingId,
            name: 'Level 1',
            levelNumber: 1,
            elevationMm: 0,
          ),
          upperLevelId: ProjectLevelEntity(
            id: upperLevelId,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
          ),
        },
        slabs: slabs,
      ),
    );
    return ProjectSnapshot(
      aggregate: aggregate,
      name: 'Slab persistence',
      createdAt: DateTime.utc(2026, 10, 23, 6),
      updatedAt: DateTime.utc(2026, 10, 23, 7),
    );
  }

  ProjectSlab _slab() => ProjectSlab(
        id: slabId,
        buildingId: buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: lowerLevelId,
        aboveLevelId: upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 6000, yMm: 0),
          BoundaryPointMm(xMm: 6000, yMm: 4000),
          BoundaryPointMm(xMm: 0, yMm: 4000),
        ],
      );
}
