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

    test('round-trips schema v8 without identity or semantic loss', () {
      final north = ProjectEngineeringNorth.fromDegrees(32.5);
      final source = _multiBuildingSnapshot(north: north);

      final first = codec.encode(source);
      final restored = codec.decode(first);
      final second = codec.encode(restored);

      expect(first.schemaVersion, 8);
      expect(restored.id, source.id);
      expect(restored.siteId, source.siteId);
      expect(restored.localVersion, source.localVersion);
      expect(restored.name, source.name);
      expect(restored.createdAt, source.createdAt.toUtc());
      expect(restored.updatedAt, source.updatedAt.toUtc());
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

    test('migrates canonical v1 to v8 with safe semantic defaults', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current)
        ..remove('projectOrientation')
        ..remove('openings')
        ..remove('adjacencies')
        ..remove('overlays')
        ..remove('boundaries')
        ..remove('boundaryEdgeIdentityRegistry')
        ..remove('boundaryHostedObjectRegistry')
        ..remove('boundaryWallProfileRegistry')
        ..remove('boundaryConstructionRegistry');
      for (final raw in payload['spaces']! as List) {
        final space = raw as Map;
        space.remove('usage');
        space.remove('type');
      }
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 1, payload: _stringKeyed(payload)),
      );

      expect(restored.aggregate.engineeringMetadata.projectNorth, isNull);
      expect(
        restored.aggregate.stores.spaces.values
            .every((space) => space.usage == SpaceUsage.unknown),
        isTrue,
      );
      expect(restored.aggregate.stores.openings, isEmpty);
      expect(restored.aggregate.stores.adjacencies, isEmpty);
      expect(restored.aggregate.stores.overlays, isEmpty);
      expect(restored.aggregate.stores.boundaries, isEmpty);
      expect(codec.encode(restored).schemaVersion, 8);
    });

    test('migrates canonical v2 without inferring SpaceUsage from names', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current)
        ..remove('openings')
        ..remove('adjacencies')
        ..remove('overlays')
        ..remove('boundaries')
        ..remove('boundaryEdgeIdentityRegistry')
        ..remove('boundaryHostedObjectRegistry')
        ..remove('boundaryWallProfileRegistry')
        ..remove('boundaryConstructionRegistry');
      for (final raw in payload['spaces']! as List) {
        (raw as Map).remove('usage');
      }
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 2, payload: _stringKeyed(payload)),
      );

      expect(
        restored.aggregate.stores.spaces.values
            .every((space) => space.usage == SpaceUsage.unknown),
        isTrue,
      );
      expect(restored.aggregate.stores.openings, isEmpty);
      expect(restored.aggregate.stores.adjacencies, isEmpty);
      expect(restored.aggregate.stores.overlays, isEmpty);
    });

    test('migrates canonical v3 to v8 with empty P7A state', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current)
        ..remove('boundaries')
        ..remove('boundaryEdgeIdentityRegistry')
        ..remove('boundaryHostedObjectRegistry')
        ..remove('boundaryWallProfileRegistry')
        ..remove('boundaryConstructionRegistry');
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 3, payload: _stringKeyed(payload)),
      );

      expect(restored.aggregate.stores.boundaries, isEmpty);
      expect(
        restored
            .aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry.owners,
        isEmpty,
      );
      expect(
        restored.aggregate.engineeringMetadata.boundaryHostedObjectRegistry
            .references,
        isEmpty,
      );
      expect(codec.encode(restored).schemaVersion, 8);
    });

    test('migrates canonical v4 without inventing hosted state', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current)
        ..remove('boundaryHostedObjectRegistry')
        ..remove('boundaryWallProfileRegistry')
        ..remove('boundaryConstructionRegistry');
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 4, payload: _stringKeyed(payload)),
      );

      expect(
        restored.aggregate.engineeringMetadata.boundaryHostedObjectRegistry
            .references,
        isEmpty,
      );
      expect(
        restored
            .aggregate.engineeringMetadata.boundaryWallProfileRegistry.profiles,
        isEmpty,
      );
      expect(codec.encode(restored).schemaVersion, 8);
    });

    test('migrates canonical v5 without inventing wall profiles', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current)
        ..remove('boundaryWallProfileRegistry')
        ..remove('boundaryConstructionRegistry');
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 5, payload: _stringKeyed(payload)),
      );

      expect(
        restored
            .aggregate.engineeringMetadata.boundaryWallProfileRegistry.profiles,
        isEmpty,
      );
      expect(
        restored.aggregate.engineeringMetadata.boundaryConstructionRegistry
            .profiles,
        isEmpty,
      );
      expect(codec.encode(restored).schemaVersion, 8);
    });

    test('migrates canonical v6 without inventing construction profiles', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current)
        ..remove('boundaryConstructionRegistry');
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 6, payload: _stringKeyed(payload)),
      );

      expect(
        restored.aggregate.engineeringMetadata.boundaryConstructionRegistry
            .profiles,
        isEmpty,
      );
      expect(codec.encode(restored).schemaVersion, 8);
    });

    test('migrates canonical v7 to v8 with deterministic level semantics', () {
      final current = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(current);
      _removeLevelSemantics(payload);

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 7, payload: _stringKeyed(payload)),
      );

      expect(
        restored.aggregate.index.level(LevelId('level-a-2'))!.kind,
        ProjectLevelKind.residential,
      );
      expect(
        restored.aggregate.index
            .level(LevelId('level-a-2'))!
            .floorToFloorHeightMm,
        3000,
      );
      expect(codec.encode(restored).schemaVersion, 8);
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
        (payload['projectOrientation']! as Map)['projectNorthMilliDegrees'] =
            malformed;
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

    test('rejects duplicate relationship ids instead of normalizing them', () {
      final document = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(document);
      final site = (payload['sites']! as List).first as Map;
      site['buildingIds'] = <Object?>['building-a', 'building-a'];

      expect(
        () => codec.decode(
          ProjectDocument(
            schemaVersion: document.schemaVersion,
            payload: _stringKeyed(payload),
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects timestamps without an explicit zone', () {
      final document = codec.encode(_multiBuildingSnapshot());
      final payload = _mutablePayload(document);
      (payload['metadata']! as Map)['createdAt'] = '2026-10-21T06:00:00.000';

      expect(
        () => codec.decode(
          ProjectDocument(
            schemaVersion: document.schemaVersion,
            payload: _stringKeyed(payload),
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
      expect(
        () => (document.payload['boundaries']! as List<Object?>).clear(),
        throwsUnsupportedError,
      );
      expect(
        () =>
            (document.payload['boundaryEdgeIdentityRegistry']! as List<Object?>)
                .clear(),
        throwsUnsupportedError,
      );
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

void _removeLevelSemantics(Map payload) {
  for (final raw in payload['levels']! as List) {
    final level = raw as Map;
    level.remove('kind');
    level.remove('floorToFloorHeightMm');
  }
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
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');

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
            displayOrder: 20,
            elevationMm: 3000,
            kind: ProjectLevelKind.residential,
            floorToFloorHeightMm: 3200,
            spaceIds: <SpaceId>[roomA],
          ),
          levelB: ProjectLevelEntity(
            id: levelB,
            buildingId: buildingB,
            name: 'Floor 2',
            levelNumber: 2,
            displayOrder: 20,
            elevationMm: 3000,
            kind: ProjectLevelKind.residential,
            floorToFloorHeightMm: 3300,
            spaceIds: <SpaceId>[roomB],
          ),
        },
        spaces: <SpaceId, ProjectSpaceEntity>{
          roomA: ProjectSpaceEntity(
            id: roomA,
            levelId: levelA,
            name: 'Bedroom',
            type: ProjectSpaceType.room,
            usage: SpaceUsage.bedroom,
          ),
          roomB: ProjectSpaceEntity(
            id: roomB,
            levelId: levelB,
            name: 'Room B',
            type: ProjectSpaceType.room,
            usage: SpaceUsage.unknown,
          ),
        },
      ),
    ),
    name: 'Canonical Project',
    createdAt: DateTime.utc(2026, 10, 21, 6),
    updatedAt: DateTime.utc(2026, 10, 21, 7),
  );
}
