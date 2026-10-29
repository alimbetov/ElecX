import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/generation_provenance_integrity.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();

  group('PRE10-CQ23 generation manifest target lineage', () {
    test('valid project/building/level/apartment-zone lineage round-trips', () {
      final fixture = _fixture();

      expect(
        GenerationProvenanceIntegrityValidator.validate(
          fixture.registry,
          project: fixture.snapshot.aggregate,
        ),
        isEmpty,
      );
      expect(
          () => codec.decode(codec.encode(fixture.snapshot)), returnsNormally);
    });

    test('foreign level under a different building is rejected before Save',
        () {
      final fixture = _fixture(
        manifestBuildingId: BuildingId('building-a'),
        manifestLevelId: LevelId('level-b'),
        manifestZoneId: ZoneId('zone-b'),
      );

      final issues = GenerationProvenanceIntegrityValidator.validate(
        fixture.registry,
        project: fixture.snapshot.aggregate,
      );
      expect(
        issues.any(
          (issue) =>
              issue.code ==
                  GenerationProvenanceIssueCode.entityManifestMismatch &&
              issue.message.contains('does not belong to building'),
        ),
        isTrue,
      );
      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('dangling target building is rejected before Save', () {
      final fixture = _fixture(
        manifestBuildingId: BuildingId('missing-building'),
      );

      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('foreign generated entity outside the apartment target is rejected',
        () {
      final fixture = _fixture(generatedEntityId: SpaceId('space-b'));

      final issues = GenerationProvenanceIntegrityValidator.validate(
        fixture.registry,
        project: fixture.snapshot.aggregate,
      );
      expect(
        issues.any(
          (issue) =>
              issue.entityId == SpaceId('space-b') &&
              issue.code ==
                  GenerationProvenanceIssueCode.entityManifestMismatch,
        ),
        isTrue,
      );
      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });

    test('tampered persisted target lineage is rejected on Reopen', () {
      final fixture = _fixture();
      final document = codec.encode(fixture.snapshot);
      final tampered = _tamperTarget(
        document,
        buildingId: 'building-a',
        levelId: 'level-b',
        zoneId: 'zone-b',
      );

      expect(
        () => codec.decode(tampered),
        throwsA(isA<GenerationProvenanceValidationException>()),
      );
    });
  });
}

_Cq23Fixture _fixture({
  BuildingId? manifestBuildingId,
  LevelId? manifestLevelId,
  ZoneId? manifestZoneId,
  EntityId? generatedEntityId,
}) {
  final projectId = ProjectId('project-cq23');
  final siteId = SiteId('site-cq23');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('level-a');
  final levelB = LevelId('level-b');
  final zoneA = ZoneId('zone-a');
  final zoneB = ZoneId('zone-b');
  final spaceA = SpaceId('space-a');
  final spaceB = SpaceId('space-b');
  final generationId = GenerationId('generation-cq23');
  final generatedId = generatedEntityId ?? zoneA;

  final manifest = GenerationManifest(
    provenanceSchemaVersion: 1,
    generationId: generationId,
    originType: GenerationOriginType.wizard,
    providerTemplateId: TemplateId('provider-cq23'),
    providerTemplateVersion: 1,
    catalogVersion: 1,
    apartmentTemplateId: TemplateId('template-cq23'),
    apartmentTemplateVersion: 1,
    familyId: 'apartment',
    variantSeedId: 'seed-cq23',
    generatorVersion: 'generator-v1',
    scoringProfileVersion: 'score-v1',
    allocatorVersion: 'allocator-v1',
    geometryAlgorithmVersion: 'geometry-v1',
    normalizedIntentFingerprint: _sha('a'),
    selectedCandidateFingerprint: _sha('b'),
    projectId: projectId,
    buildingId: manifestBuildingId ?? buildingA,
    levelId: manifestLevelId ?? levelA,
    apartmentZoneId: manifestZoneId ?? zoneA,
    generatedEntityIds: {generatedId},
  );
  final provenance = EntityGenerationProvenance(
    entityId: generatedId,
    generationId: generationId,
    generationKey: 'generated:${generatedId.value}',
    generatedProperties: const {GenerationPropertyKey.name},
    generatedBaselineFingerprint: _sha('c'),
  );
  final registry = GenerationProvenanceRegistry(
    manifests: {generationId: manifest},
    entities: {generatedId: provenance},
  );

  final stores = ProjectEntityStores(
    sites: {
      siteId: ProjectSiteEntity(
        id: siteId,
        name: 'Site',
        buildingIds: {buildingA, buildingB},
      ),
    },
    buildings: {
      buildingA: ProjectBuildingEntity(
        id: buildingA,
        siteId: siteId,
        name: 'Building A',
        levelIds: {levelA},
      ),
      buildingB: ProjectBuildingEntity(
        id: buildingB,
        siteId: siteId,
        name: 'Building B',
        levelIds: {levelB},
      ),
    },
    levels: {
      levelA: ProjectLevelEntity(
        id: levelA,
        buildingId: buildingA,
        name: 'Level A',
        levelNumber: 1,
        elevationMm: 0,
        kind: ProjectLevelKind.residential,
        zoneIds: {zoneA},
        spaceIds: {spaceA},
      ),
      levelB: ProjectLevelEntity(
        id: levelB,
        buildingId: buildingB,
        name: 'Level B',
        levelNumber: 1,
        elevationMm: 0,
        kind: ProjectLevelKind.residential,
        zoneIds: {zoneB},
        spaceIds: {spaceB},
      ),
    },
    zones: {
      zoneA: ProjectStructuralZoneEntity(
        id: zoneA,
        levelId: levelA,
        name: 'Apartment A',
        kind: ProjectStructuralZoneKind.apartment,
        spaceIds: {spaceA},
      ),
      zoneB: ProjectStructuralZoneEntity(
        id: zoneB,
        levelId: levelB,
        name: 'Apartment B',
        kind: ProjectStructuralZoneKind.apartment,
        spaceIds: {spaceB},
      ),
    },
    spaces: {
      spaceA: ProjectSpaceEntity(
        id: spaceA,
        levelId: levelA,
        name: 'Room A',
        type: ProjectSpaceType.room,
      ),
      spaceB: ProjectSpaceEntity(
        id: spaceB,
        levelId: levelB,
        name: 'Room B',
        type: ProjectSpaceType.room,
      ),
    },
  );
  final baseAggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(1),
    stores: stores,
  );
  final aggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(1),
    engineeringMetadata: baseAggregate.engineeringMetadata
        .withGenerationProvenanceRegistry(registry),
    stores: stores,
  );

  final now = DateTime.utc(2026, 10, 28, 20);
  return _Cq23Fixture(
    registry: registry,
    snapshot: ProjectSnapshot(
      aggregate: aggregate,
      name: 'CQ23 lineage',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

ProjectDocument _tamperTarget(
  ProjectDocument source, {
  required String buildingId,
  required String levelId,
  required String zoneId,
}) {
  final payload = Map<String, Object?>.from(source.payload);
  final registry = Map<String, Object?>.from(
    payload['generationProvenance']! as Map,
  );
  final manifests = List<Object?>.from(registry['manifests']! as List);
  final manifest = Map<String, Object?>.from(manifests.single! as Map);
  manifest['buildingId'] = buildingId;
  manifest['levelId'] = levelId;
  manifest['apartmentZoneId'] = zoneId;
  manifests[0] = manifest;
  registry['manifests'] = manifests;
  payload['generationProvenance'] = registry;
  return ProjectDocument(schemaVersion: source.schemaVersion, payload: payload);
}

final class _Cq23Fixture {
  const _Cq23Fixture({required this.registry, required this.snapshot});

  final GenerationProvenanceRegistry registry;
  final ProjectSnapshot snapshot;
}

String _sha(String character) => List.filled(64, character).join();