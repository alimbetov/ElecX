import 'dart:convert';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/legacy_v4_project_compatibility.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalProjectDocumentCodec', () {
    const codec = CanonicalProjectDocumentCodec();

    test('round-trips a canonical multi-building snapshot without identity loss', () {
      final snapshot = _multiBuildingSnapshot();

      final first = codec.encode(snapshot);
      final restored = codec.decode(first);
      final second = codec.encode(restored);

      expect(restored.id, snapshot.id);
      expect(restored.siteId, snapshot.siteId);
      expect(restored.localVersion, snapshot.localVersion);
      expect(restored.name, snapshot.name);
      expect(restored.createdAt, snapshot.createdAt.toUtc());
      expect(restored.updatedAt, snapshot.updatedAt.toUtc());
      expect(restored.aggregate.stores.buildings, hasLength(2));
      expect(restored.aggregate.stores.levels, hasLength(2));
      expect(
        restored.aggregate.index.buildingByLevel[LevelId('level-a-2')],
        BuildingId('building-a'),
      );
      expect(
        restored.aggregate.index.buildingByLevel[LevelId('level-b-2')],
        BuildingId('building-b'),
      );

      // Canonical encode order makes the serialized semantic fingerprint
      // stable enough to prove encode/decode/encode equivalence for P2D.
      expect(jsonEncode(second.payload), jsonEncode(first.payload));
    });

    test('rejects unsupported canonical schema fail closed', () {
      final document = codec.encode(_multiBuildingSnapshot());

      expect(
        () => codec.decode(
          ProjectDocument(
            schemaVersion: document.schemaVersion + 1,
            payload: document.payload,
          ),
        ),
        throwsFormatException,
      );
    });

    test('project document deeply freezes nested payload collections', () {
      final document = codec.encode(_multiBuildingSnapshot());
      final metadata = document.payload['metadata']! as Map<String, Object?>;
      final buildings = document.payload['buildings']! as List<Object?>;
      final firstBuilding = buildings.first! as Map<String, Object?>;
      final levelIds = firstBuilding['levelIds']! as List<Object?>;

      expect(() => metadata['name'] = 'Changed', throwsUnsupportedError);
      expect(() => buildings.clear(), throwsUnsupportedError);
      expect(() => firstBuilding['name'] = 'Changed', throwsUnsupportedError);
      expect(() => levelIds.clear(), throwsUnsupportedError);
    });
  });

  group('LegacyV4ProjectCompatibilityBoundary', () {
    test('keeps legacy v4 in legacy runtime instead of lossy migration', () {
      final source = <String, Object?>{
        'schemaVersion': 4,
        'metadata': <String, Object?>{
          'projectId': 'legacy-project',
        },
        'building': <String, Object?>{},
        'site': <String, Object?>{},
        'workspace': <String, Object?>{},
        'p2': <String, Object?>{},
      };

      final assessment = LegacyV4ProjectCompatibilityBoundary.assess(source);

      expect(
        assessment.status,
        LegacyProjectCompatibilityStatus.legacyRuntimeRequired,
      );
      expect(assessment.projectId, 'legacy-project');
      expect(assessment.canMigrateLosslessly, isFalse);
      expect(assessment.reasons, isNotEmpty);
      expect(
        () => LegacyV4ProjectCompatibilityBoundary.requireLosslessMigration(
          source,
        ),
        throwsA(isA<LosslessLegacyMigrationUnavailable>()),
      );
    });

    test('rejects future legacy schemas explicitly', () {
      final assessment = LegacyV4ProjectCompatibilityBoundary.assess(
        <String, Object?>{
          'schemaVersion': 5,
          'metadata': <String, Object?>{'projectId': 'future-project'},
        },
      );

      expect(
        assessment.status,
        LegacyProjectCompatibilityStatus.unsupportedSchema,
      );
      expect(assessment.canMigrateLosslessly, isFalse);
    });
  });
}

ProjectSnapshot _multiBuildingSnapshot() {
  final projectId = ProjectId('project-1');
  final siteId = SiteId('site-1');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('level-a-2');
  final levelB = LevelId('level-b-2');
  final zoneA = ZoneId('zone-a');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');

  final aggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(7),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Main Site',
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
          name: 'Floor 2',
          levelNumber: 2,
          displayOrder: 2,
          elevationMm: 3000,
          zoneIds: <ZoneId>[zoneA],
          spaceIds: <SpaceId>[roomA],
        ),
        levelB: ProjectLevelEntity(
          id: levelB,
          buildingId: buildingB,
          name: 'Floor 2',
          levelNumber: 2,
          displayOrder: 2,
          elevationMm: 3200,
          spaceIds: <SpaceId>[roomB],
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneA: ProjectStructuralZoneEntity(
          id: zoneA,
          levelId: levelA,
          name: 'Apartment 201',
          spaceIds: <SpaceId>[roomA],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(
          id: roomA,
          levelId: levelA,
          name: 'Bedroom',
        ),
        roomB: ProjectSpaceEntity(
          id: roomB,
          levelId: levelB,
          name: 'Office',
        ),
      },
    ),
  );

  return ProjectSnapshot(
    aggregate: aggregate,
    name: 'Two Buildings',
    createdAt: DateTime.utc(2026, 10, 21, 6),
    updatedAt: DateTime.utc(2026, 10, 21, 7),
  );
}
