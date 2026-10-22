import 'dart:convert';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/legacy_v4_project_compatibility.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalProjectDocumentCodec', () {
    const codec = CanonicalProjectDocumentCodec();

    test('round-trips multi-building snapshot and Project North without identity loss', () {
      final north = ProjectEngineeringNorth.fromDegrees(32.5);
      final snapshot = _multiBuildingSnapshot(north: north);

      final first = codec.encode(snapshot);
      final restored = codec.decode(first);
      final second = codec.encode(restored);

      expect(first.schemaVersion, 3);
      expect(restored.id, snapshot.id);
      expect(restored.siteId, snapshot.siteId);
      expect(restored.localVersion, snapshot.localVersion);
      expect(restored.name, snapshot.name);
      expect(restored.createdAt, snapshot.createdAt.toUtc());
      expect(restored.updatedAt, snapshot.updatedAt.toUtc());
      expect(restored.aggregate.engineeringMetadata.projectNorth, north);
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
      expect(
        restored.aggregate.stores.spaces[SpaceId('room-a')]!.usage,
        SpaceUsage.bedroom,
      );

      expect(jsonEncode(second.payload), jsonEncode(first.payload));
    });

    test('migrates canonical v1 to v3 with safe P6 defaults', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final v1Payload = Map<String, Object?>.from(current.payload)
        ..remove('projectOrientation')
        ..remove('openings')
        ..remove('adjacencies')
        ..remove('overlays');
      final oldSpaces = <Object?>[
        for (final raw in v1Payload['spaces']! as List<Object?>)
          Map<String, Object?>.from(raw! as Map)..remove('usage'),
      ];
      v1Payload['spaces'] = oldSpaces;

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 1, payload: v1Payload),
      );

      expect(restored.aggregate.engineeringMetadata.projectNorth, isNull);
      expect(
        restored.aggregate.stores.spaces.values.every(
          (space) => space.usage == SpaceUsage.unknown,
        ),
        isTrue,
      );
      expect(restored.aggregate.stores.openings, isEmpty);
      expect(restored.aggregate.stores.adjacencies, isEmpty);
      expect(restored.aggregate.stores.overlays, isEmpty);

      final reencoded = codec.encode(restored);
      expect(reencoded.schemaVersion, 3);
      expect(reencoded.payload['projectOrientation'], <String, Object?>{
        'projectNorthMilliDegrees': null,
      });
    });

    test('migrates canonical v2 to v3 without inferring usage from names', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final v2Payload = _mutablePayload(current)
        ..remove('openings')
        ..remove('adjacencies')
        ..remove('overlays');
      for (final raw in v2Payload['spaces']! as List) {
        (raw as Map).remove('usage');
      }

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 2, payload: _stringKeyed(v2Payload)),
      );

      expect(
        restored.aggregate.stores.spaces[SpaceId('room-a')]!.usage,
        SpaceUsage.unknown,
      );
      expect(
        restored.aggregate.stores.spaces[SpaceId('room-b')]!.usage,
        SpaceUsage.unknown,
      );
      expect(restored.aggregate.stores.openings, isEmpty);
      expect(restored.aggregate.stores.adjacencies, isEmpty);
      expect(restored.aggregate.stores.overlays, isEmpty);
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

    test('rejects malformed or out-of-range persisted Project North', () {
      final document = codec.encode(_multiBuildingSnapshot());

      for (final malformed in <Object?>['90000', 90.0, -1, 360000]) {
        final payload = _mutablePayload(document);
        final orientation = payload['projectOrientation']! as Map;
        orientation['projectNorthMilliDegrees'] = malformed;

        expect(
          () => codec.decode(
            ProjectDocument(
              schemaVersion: document.schemaVersion,
              payload: _stringKeyed(payload),
            ),
          ),
          throwsFormatException,
          reason: 'persisted value $malformed must fail closed',
        );
      }
    });

    test(
      'rejects missing or malformed orientation object in current schema',
      () {
        final document = codec.encode(_multiBuildingSnapshot());

        final missing = _mutablePayload(document)..remove('projectOrientation');
        expect(
          () => codec.decode(
            ProjectDocument(
              schemaVersion: document.schemaVersion,
              payload: _stringKeyed(missing),
            ),
          ),
          throwsFormatException,
        );

        final malformed = _mutablePayload(document);
        malformed['projectOrientation'] = 'north';
        expect(
          () => codec.decode(
            ProjectDocument(
              schemaVersion: document.schemaVersion,
              payload: _stringKeyed(malformed),
            ),
          ),
          throwsFormatException,
        );
      },
    );

    test('semantic fingerprint changes when only Project North changes', () {
      final north0 = codec.encode(
        _multiBuildingSnapshot(north: ProjectEngineeringNorth.fromDegrees(0)),
      );
      final north90 = codec.encode(
        _multiBuildingSnapshot(north: ProjectEngineeringNorth.fromDegrees(90)),
      );

      expect(jsonEncode(north0.payload), isNot(jsonEncode(north90.payload)));
    });

    test(
      'rejects duplicate relationship ids instead of silently normalizing',
      () {
        final document = codec.encode(_multiBuildingSnapshot());
        final mutablePayload = _mutablePayload(document);
        final sites = mutablePayload['sites']! as List;
        final firstSite = sites.first! as Map;
        firstSite['buildingIds'] = <Object?>['building-a', 'building-a'];

        expect(
          () => codec.decode(
            ProjectDocument(
              schemaVersion: document.schemaVersion,
              payload: _stringKeyed(mutablePayload),
            ),
          ),
          throwsFormatException,
        );
      },
    );

    test('rejects timestamps without an explicit zone', () {
      final document = codec.encode(_multiBuildingSnapshot());
      final mutablePayload = _mutablePayload(document);
      final metadata = mutablePayload['metadata']! as Map;
      metadata['createdAt'] = '2026-10-21T06:00:00.000';

      expect(
        () => codec.decode(
          ProjectDocument(
            schemaVersion: document.schemaVersion,
            payload: _stringKeyed(mutablePayload),
          ),
        ),
        throwsFormatException,
      );
    });

    test('project document deeply freezes nested payload collections', () {
      final document = codec.encode(_multiBuildingSnapshot());
      final metadata = document.payload['metadata']! as Map<String, Object?>;
      final orientation =
          document.payload['projectOrientation']! as Map<String, Object?>;
      final buildings = document.payload['buildings']! as List<Object?>;
      final firstBuilding = buildings.first! as Map<String, Object?>;
      final levelIds = firstBuilding['levelIds']! as List<Object?>;

      expect(() => metadata['name'] = 'Changed', throwsUnsupportedError);
      expect(
        () => orientation['projectNorthMilliDegrees'] = 90000,
        throwsUnsupportedError,
      );
      expect(() => buildings.clear(), throwsUnsupportedError);
      expect(() => firstBuilding['name'] = 'Changed', throwsUnsupportedError);
      expect(() => levelIds.clear(), throwsUnsupportedError);
    });
  });

  group('LegacyV4ProjectCompatibilityBoundary', () {
    test('keeps legacy v4 in legacy runtime instead of lossy migration', () {
      final source = <String, Object?>{
        'schemaVersion': 4,
        'metadata': <String, Object?>{'projectId': 'legacy-project'},
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

Map _mutablePayload(ProjectDocument document) =>
    jsonDecode(jsonEncode(document.payload)) as Map;

Map<String, Object?> _stringKeyed(Map source) =>
    source.map((key, value) => MapEntry(key.toString(), value));

ProjectSnapshot _multiBuildingSnapshot({ProjectEngineeringNorth? north}) {
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
    engineeringMetadata: ProjectEngineeringMetadata(projectNorth: north),
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
          usage: SpaceUsage.bedroom,
        ),
        roomB: ProjectSpaceEntity(
          id: roomB,
          levelId: levelB,
          name: 'Office',
          usage: SpaceUsage.office,
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
