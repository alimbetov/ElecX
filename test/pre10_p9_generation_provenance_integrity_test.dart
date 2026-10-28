import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/generation_provenance_integrity.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();

  group('PRE10 P9 generation provenance integrity', () {
    test('PRE10-CQ24 malformed baseline SHA is rejected before Save', () {
      final fixture = _fixture(baselineFingerprint: 'not-a-sha256');

      final issues = GenerationProvenanceIntegrityValidator.validate(
        fixture.registry,
      );
      expect(
        issues.map((issue) => issue.code),
        contains(GenerationProvenanceIssueCode.invalidBaseline),
      );
      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('PRE10-CQ24 tampered persisted baseline SHA is rejected on Reopen',
        () {
      final fixture = _fixture();
      final document = codec.encode(fixture.snapshot);
      final tampered = _tamperBaseline(document, 'tampered-baseline');

      expect(
        () => codec.decode(tampered),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('PRE10-CQ25 active generationKey cannot also be tombstoned', () {
      final fixture = _fixture(tombstoneActiveKey: true);

      final issues = GenerationProvenanceIntegrityValidator.validate(
        fixture.registry,
      );
      expect(
        issues.any(
          (issue) =>
              issue.code ==
                  GenerationProvenanceIssueCode.entityManifestMismatch &&
              issue.message.contains('also recorded as removed'),
        ),
        isTrue,
      );
      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('PRE10-CQ25 removed key tombstone without active reuse round-trips',
        () {
      final fixture = _fixture(removedSpaceTombstone: true);

      expect(
        () => GenerationProvenanceIntegrityValidator.validateOrThrow(
          fixture.registry,
        ),
        returnsNormally,
      );
      final reopened = codec.decode(codec.encode(fixture.snapshot));
      final restored =
          reopened.aggregate.engineeringMetadata.generationProvenanceRegistry;
      final manifest = restored.manifests.values.single;

      expect(manifest.removedGenerationKeys, contains('space:removed:1'));
      expect(
        restored.entities.values.map((provenance) => provenance.generationKey),
        isNot(contains('space:removed:1')),
      );
    });
  });

  group('PRE10 P9 provenance forward compatibility', () {
    test('PRE10-CQ26 unknown manifest field is rejected, never discarded', () {
      final fixture = _fixture();
      final document = codec.encode(fixture.snapshot);
      final tampered = _addUnknownManifestField(document);

      expect(() => codec.decode(tampered), throwsFormatException);
    });

    test('PRE10-CQ26 unknown entity field is rejected, never discarded', () {
      final fixture = _fixture();
      final document = codec.encode(fixture.snapshot);
      final tampered = _addUnknownEntityField(document);

      expect(() => codec.decode(tampered), throwsFormatException);
    });

    test('PRE10-CQ26 unknown provenance root field is rejected', () {
      final fixture = _fixture();
      final document = codec.encode(fixture.snapshot);
      final tampered = _addUnknownRegistryField(document);

      expect(() => codec.decode(tampered), throwsFormatException);
    });
  });
}

ProjectDocument _tamperBaseline(ProjectDocument source, String value) {
  final payload = Map<String, Object?>.from(source.payload);
  final registry = Map<String, Object?>.from(
    payload['generationProvenance']! as Map,
  );
  final entities = List<Object?>.from(registry['entities']! as List);
  final entity = Map<String, Object?>.from(entities.single! as Map);
  entity['generatedBaselineFingerprint'] = value;
  entities[0] = entity;
  registry['entities'] = entities;
  payload['generationProvenance'] = registry;
  return ProjectDocument(schemaVersion: source.schemaVersion, payload: payload);
}

ProjectDocument _addUnknownManifestField(ProjectDocument source) {
  final payload = Map<String, Object?>.from(source.payload);
  final registry = Map<String, Object?>.from(
    payload['generationProvenance']! as Map,
  );
  final manifests = List<Object?>.from(registry['manifests']! as List);
  final manifest = Map<String, Object?>.from(manifests.single! as Map);
  manifest['futureSelectiveRegenerationPolicy'] = 'future-v2';
  manifests[0] = manifest;
  registry['manifests'] = manifests;
  payload['generationProvenance'] = registry;
  return ProjectDocument(schemaVersion: source.schemaVersion, payload: payload);
}

ProjectDocument _addUnknownEntityField(ProjectDocument source) {
  final payload = Map<String, Object?>.from(source.payload);
  final registry = Map<String, Object?>.from(
    payload['generationProvenance']! as Map,
  );
  final entities = List<Object?>.from(registry['entities']! as List);
  final entity = Map<String, Object?>.from(entities.single! as Map);
  entity['futureOverridePolicy'] = 'future-v2';
  entities[0] = entity;
  registry['entities'] = entities;
  payload['generationProvenance'] = registry;
  return ProjectDocument(schemaVersion: source.schemaVersion, payload: payload);
}

ProjectDocument _addUnknownRegistryField(ProjectDocument source) {
  final payload = Map<String, Object?>.from(source.payload);
  final registry = Map<String, Object?>.from(
    payload['generationProvenance']! as Map,
  );
  registry['futureSchemaMetadata'] = {'revision': 2};
  payload['generationProvenance'] = registry;
  return ProjectDocument(schemaVersion: source.schemaVersion, payload: payload);
}

_Pre10ProvenanceFixture _fixture({
  String? baselineFingerprint,
  bool tombstoneActiveKey = false,
  bool removedSpaceTombstone = false,
}) {
  final projectId = ProjectId('pre10-provenance-project');
  final siteId = SiteId('pre10-provenance-site');
  final buildingId = BuildingId('pre10-provenance-building');
  final levelId = LevelId('pre10-provenance-level');
  final zoneId = ZoneId('pre10-provenance-zone');
  final generationId = GenerationId('pre10-provenance-generation');
  const activeGenerationKey = 'zone:apartment';

  final manifest = GenerationManifest(
    provenanceSchemaVersion: 1,
    generationId: generationId,
    originType: GenerationOriginType.wizard,
    providerTemplateId: TemplateId('p9-apartment-provider'),
    providerTemplateVersion: 1,
    catalogVersion: 1,
    apartmentTemplateId: TemplateId('pre10-template'),
    apartmentTemplateVersion: 1,
    familyId: 'compact',
    variantSeedId: 'seed-1',
    generatorVersion: 'generator-v1',
    scoringProfileVersion: 'score-v1',
    allocatorVersion: 'allocator-v1',
    geometryAlgorithmVersion: 'geometry-v1',
    normalizedIntentFingerprint: _sha('a'),
    selectedCandidateFingerprint: _sha('b'),
    projectId: projectId,
    buildingId: buildingId,
    levelId: levelId,
    apartmentZoneId: zoneId,
    generatedEntityIds: {zoneId},
    removedGenerationKeys: {
      if (tombstoneActiveKey) activeGenerationKey,
      if (removedSpaceTombstone) 'space:removed:1',
    },
  );
  final provenance = EntityGenerationProvenance(
    entityId: zoneId,
    generationId: generationId,
    generationKey: activeGenerationKey,
    generatedProperties: const {
      GenerationPropertyKey.name,
      GenerationPropertyKey.zoneMembership,
    },
    generatedBaselineFingerprint: baselineFingerprint ?? _sha('c'),
  );
  final registry = GenerationProvenanceRegistry(
    manifests: {generationId: manifest},
    entities: {zoneId: provenance},
  );
  final aggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(1),
    engineeringMetadata: ProjectEngineeringMetadata(
      generationProvenanceRegistry: registry,
    ),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: {levelId},
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 0,
          kind: ProjectLevelKind.residential,
          zoneIds: {zoneId},
        ),
      },
      zones: {
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: 'Apartment 1',
          kind: ProjectStructuralZoneKind.apartment,
          spaceIds: const {},
        ),
      },
    ),
  );
  final now = DateTime.utc(2026, 10, 28, 16);
  return _Pre10ProvenanceFixture(
    registry: registry,
    snapshot: ProjectSnapshot(
      aggregate: aggregate,
      name: 'PRE10 provenance integrity',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

final class _Pre10ProvenanceFixture {
  const _Pre10ProvenanceFixture({
    required this.registry,
    required this.snapshot,
  });

  final GenerationProvenanceRegistry registry;
  final ProjectSnapshot snapshot;
}

String _sha(String character) => List.filled(64, character).join();
