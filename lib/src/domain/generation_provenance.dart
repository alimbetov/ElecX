import 'project_identity.dart';

enum GenerationOriginType { wizard }

enum GenerationPropertyKey {
  name,
  spaceType,
  spaceUsage,
  geometry,
  zoneMembership,
  openingRelations,
  adjacencyRelations,
}

final class GenerationManifest {
  GenerationManifest({
    required this.provenanceSchemaVersion,
    required this.generationId,
    required this.originType,
    required this.providerTemplateId,
    required this.providerTemplateVersion,
    required this.catalogVersion,
    required this.apartmentTemplateId,
    required this.apartmentTemplateVersion,
    required String familyId,
    required String variantSeedId,
    required String generatorVersion,
    required String scoringProfileVersion,
    required String allocatorVersion,
    required String geometryAlgorithmVersion,
    required String normalizedIntentFingerprint,
    required String selectedCandidateFingerprint,
    required this.projectId,
    required this.buildingId,
    required this.levelId,
    required this.apartmentZoneId,
    required Iterable<EntityId> generatedEntityIds,
    Iterable<String> removedGenerationKeys = const [],
  })  : familyId = _nonEmpty(familyId, 'familyId'),
        variantSeedId = _nonEmpty(variantSeedId, 'variantSeedId'),
        generatorVersion = _nonEmpty(generatorVersion, 'generatorVersion'),
        scoringProfileVersion =
            _nonEmpty(scoringProfileVersion, 'scoringProfileVersion'),
        allocatorVersion = _nonEmpty(allocatorVersion, 'allocatorVersion'),
        geometryAlgorithmVersion =
            _nonEmpty(geometryAlgorithmVersion, 'geometryAlgorithmVersion'),
        normalizedIntentFingerprint = _nonEmpty(
          normalizedIntentFingerprint,
          'normalizedIntentFingerprint',
        ),
        selectedCandidateFingerprint = _nonEmpty(
          selectedCandidateFingerprint,
          'selectedCandidateFingerprint',
        ),
        generatedEntityIds = Set.unmodifiable(generatedEntityIds),
        removedGenerationKeys = Set.unmodifiable(
          removedGenerationKeys.map((value) => _nonEmpty(value, 'generationKey')),
        ) {
    if (provenanceSchemaVersion <= 0) {
      throw ArgumentError.value(
        provenanceSchemaVersion,
        'provenanceSchemaVersion',
        'Must be positive.',
      );
    }
    if (providerTemplateVersion <= 0 ||
        catalogVersion <= 0 ||
        apartmentTemplateVersion <= 0) {
      throw ArgumentError('Generation manifest versions must be positive.');
    }
    if (this.generatedEntityIds.isEmpty) {
      throw ArgumentError('generatedEntityIds must be non-empty.');
    }
  }

  final int provenanceSchemaVersion;
  final GenerationId generationId;
  final GenerationOriginType originType;
  final TemplateId providerTemplateId;
  final int providerTemplateVersion;
  final int catalogVersion;
  final TemplateId apartmentTemplateId;
  final int apartmentTemplateVersion;
  final String familyId;
  final String variantSeedId;
  final String generatorVersion;
  final String scoringProfileVersion;
  final String allocatorVersion;
  final String geometryAlgorithmVersion;
  final String normalizedIntentFingerprint;
  final String selectedCandidateFingerprint;
  final ProjectId projectId;
  final BuildingId buildingId;
  final LevelId levelId;
  final ZoneId apartmentZoneId;
  final Set<EntityId> generatedEntityIds;
  final Set<String> removedGenerationKeys;

  GenerationManifest copyWith({Set<String>? removedGenerationKeys}) =>
      GenerationManifest(
        provenanceSchemaVersion: provenanceSchemaVersion,
        generationId: generationId,
        originType: originType,
        providerTemplateId: providerTemplateId,
        providerTemplateVersion: providerTemplateVersion,
        catalogVersion: catalogVersion,
        apartmentTemplateId: apartmentTemplateId,
        apartmentTemplateVersion: apartmentTemplateVersion,
        familyId: familyId,
        variantSeedId: variantSeedId,
        generatorVersion: generatorVersion,
        scoringProfileVersion: scoringProfileVersion,
        allocatorVersion: allocatorVersion,
        geometryAlgorithmVersion: geometryAlgorithmVersion,
        normalizedIntentFingerprint: normalizedIntentFingerprint,
        selectedCandidateFingerprint: selectedCandidateFingerprint,
        projectId: projectId,
        buildingId: buildingId,
        levelId: levelId,
        apartmentZoneId: apartmentZoneId,
        generatedEntityIds: generatedEntityIds,
        removedGenerationKeys:
            removedGenerationKeys ?? this.removedGenerationKeys,
      );
}

final class EntityGenerationProvenance {
  EntityGenerationProvenance({
    required this.entityId,
    required this.generationId,
    required String generationKey,
    required Iterable<GenerationPropertyKey> generatedProperties,
    Iterable<GenerationPropertyKey> overriddenProperties = const [],
    this.lockedFromRegeneration = false,
    required String generatedBaselineFingerprint,
  })  : generationKey = _nonEmpty(generationKey, 'generationKey'),
        generatedProperties = Set.unmodifiable(generatedProperties),
        overriddenProperties = Set.unmodifiable(overriddenProperties),
        generatedBaselineFingerprint = _nonEmpty(
          generatedBaselineFingerprint,
          'generatedBaselineFingerprint',
        ) {
    if (this.generatedProperties.isEmpty) {
      throw ArgumentError('generatedProperties must be non-empty.');
    }
    if (!this.generatedProperties.containsAll(this.overriddenProperties)) {
      throw ArgumentError(
        'overriddenProperties must be a subset of generatedProperties.',
      );
    }
  }

  final EntityId entityId;
  final GenerationId generationId;
  final String generationKey;
  final Set<GenerationPropertyKey> generatedProperties;
  final Set<GenerationPropertyKey> overriddenProperties;
  final bool lockedFromRegeneration;
  final String generatedBaselineFingerprint;

  EntityGenerationProvenance copyWith({
    Set<GenerationPropertyKey>? overriddenProperties,
    bool? lockedFromRegeneration,
  }) =>
      EntityGenerationProvenance(
        entityId: entityId,
        generationId: generationId,
        generationKey: generationKey,
        generatedProperties: generatedProperties,
        overriddenProperties:
            overriddenProperties ?? this.overriddenProperties,
        lockedFromRegeneration:
            lockedFromRegeneration ?? this.lockedFromRegeneration,
        generatedBaselineFingerprint: generatedBaselineFingerprint,
      );
}

enum GenerationProvenanceIssueCode {
  manifestMissing,
  duplicateGenerationKey,
  entityManifestMismatch,
  overrideNotGenerated,
  danglingEntity,
  invalidBaseline,
}

final class GenerationProvenanceIssue {
  const GenerationProvenanceIssue({
    required this.code,
    required this.message,
    this.entityId,
    this.generationId,
  });

  final GenerationProvenanceIssueCode code;
  final String message;
  final EntityId? entityId;
  final GenerationId? generationId;
}

final class GenerationProvenanceValidationException implements Exception {
  GenerationProvenanceValidationException(Iterable<GenerationProvenanceIssue> issues)
      : issues = List.unmodifiable(issues);

  final List<GenerationProvenanceIssue> issues;

  @override
  String toString() => 'Invalid generation provenance:\n${issues.map((e) => e.message).join('\n')}';
}

final class GenerationProvenanceRegistry {
  const GenerationProvenanceRegistry.empty()
      : manifests = const {},
        entities = const {};

  GenerationProvenanceRegistry({
    Map<GenerationId, GenerationManifest> manifests = const {},
    Map<EntityId, EntityGenerationProvenance> entities = const {},
  })  : manifests = Map.unmodifiable(manifests),
        entities = Map.unmodifiable(entities);

  final Map<GenerationId, GenerationManifest> manifests;
  final Map<EntityId, EntityGenerationProvenance> entities;

  GenerationProvenanceRegistry addGeneration({
    required GenerationManifest manifest,
    required Iterable<EntityGenerationProvenance> provenances,
  }) {
    if (manifests.containsKey(manifest.generationId)) {
      throw ArgumentError('Generation ${manifest.generationId} already exists.');
    }
    final nextEntities = Map<EntityId, EntityGenerationProvenance>.from(entities);
    final keys = <String>{};
    for (final provenance in provenances) {
      if (provenance.generationId != manifest.generationId) {
        throw ArgumentError('Entity provenance generationId does not match manifest.');
      }
      if (!manifest.generatedEntityIds.contains(provenance.entityId)) {
        throw ArgumentError('Manifest does not contain generated entity ${provenance.entityId}.');
      }
      if (!keys.add(provenance.generationKey)) {
        throw ArgumentError('Duplicate generationKey ${provenance.generationKey}.');
      }
      if (nextEntities.containsKey(provenance.entityId)) {
        throw ArgumentError('Entity ${provenance.entityId} already has generation provenance.');
      }
      nextEntities[provenance.entityId] = provenance;
    }
    if (keys.length != manifest.generatedEntityIds.length) {
      throw ArgumentError('Every manifest generated entity requires provenance.');
    }
    return GenerationProvenanceRegistry(
      manifests: {...manifests, manifest.generationId: manifest},
      entities: nextEntities,
    );
  }

  GenerationProvenanceRegistry markOverridden(
    EntityId entityId,
    Iterable<GenerationPropertyKey> properties,
  ) {
    final current = entities[entityId];
    if (current == null) return this;
    final requested = properties.toSet();
    if (!current.generatedProperties.containsAll(requested)) {
      throw ArgumentError('Cannot override a property not owned by generation.');
    }
    final next = {...current.overriddenProperties, ...requested};
    if (next.length == current.overriddenProperties.length &&
        current.overriddenProperties.containsAll(next)) {
      return this;
    }
    return GenerationProvenanceRegistry(
      manifests: manifests,
      entities: {
        ...entities,
        entityId: current.copyWith(overriddenProperties: next),
      },
    );
  }

  GenerationProvenanceRegistry setLocked(
    EntityId entityId, {
    required bool locked,
  }) {
    final current = entities[entityId];
    if (current == null || current.lockedFromRegeneration == locked) return this;
    return GenerationProvenanceRegistry(
      manifests: manifests,
      entities: {
        ...entities,
        entityId: current.copyWith(lockedFromRegeneration: locked),
      },
    );
  }

  List<GenerationProvenanceIssue> validate({
    required ProjectId projectId,
    required bool Function(EntityId id) entityExists,
  }) {
    final issues = <GenerationProvenanceIssue>[];
    final keysByGeneration = <GenerationId, Set<String>>{};
    for (final entry in manifests.entries) {
      final manifest = entry.value;
      if (entry.key != manifest.generationId || manifest.projectId != projectId) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            generationId: manifest.generationId,
            message: 'Generation manifest identity/project mismatch.',
          ),
        );
      }
    }
    for (final entry in entities.entries) {
      final provenance = entry.value;
      if (entry.key != provenance.entityId) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            entityId: entry.key,
            generationId: provenance.generationId,
            message: 'Entity provenance map key does not match entityId.',
          ),
        );
      }
      final manifest = manifests[provenance.generationId];
      if (manifest == null) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.manifestMissing,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Entity provenance references a missing generation manifest.',
          ),
        );
        continue;
      }
      if (!manifest.generatedEntityIds.contains(provenance.entityId)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Manifest does not list the generated entity.',
          ),
        );
      }
      if (!entityExists(provenance.entityId)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.danglingEntity,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Generated entity does not exist in canonical state.',
          ),
        );
      }
      if (!provenance.generatedProperties
          .containsAll(provenance.overriddenProperties)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.overrideNotGenerated,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Override references a property not owned by generation.',
          ),
        );
      }
      final keys = keysByGeneration.putIfAbsent(
        provenance.generationId,
        () => <String>{},
      );
      if (!keys.add(provenance.generationKey)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.duplicateGenerationKey,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'generationKey ${provenance.generationKey} is duplicated.',
          ),
        );
      }
    }
    for (final manifest in manifests.values) {
      final active = entities.values
          .where((item) => item.generationId == manifest.generationId)
          .map((item) => item.entityId)
          .toSet();
      if (active.length != manifest.generatedEntityIds.length ||
          !active.containsAll(manifest.generatedEntityIds)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            generationId: manifest.generationId,
            message: 'Manifest generatedEntityIds do not match active provenance.',
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  void validateOrThrow({
    required ProjectId projectId,
    required bool Function(EntityId id) entityExists,
  }) {
    final issues = validate(projectId: projectId, entityExists: entityExists);
    if (issues.isNotEmpty) {
      throw GenerationProvenanceValidationException(issues);
    }
  }

  bool sameAs(GenerationProvenanceRegistry other) {
    if (identical(this, other)) return true;
    if (manifests.length != other.manifests.length ||
        entities.length != other.entities.length) {
      return false;
    }
    for (final entry in manifests.entries) {
      final right = other.manifests[entry.key];
      if (right == null || !_sameManifest(entry.value, right)) return false;
    }
    for (final entry in entities.entries) {
      final right = other.entities[entry.key];
      if (right == null || !_sameEntity(entry.value, right)) return false;
    }
    return true;
  }
}

bool _sameManifest(GenerationManifest a, GenerationManifest b) =>
    a.provenanceSchemaVersion == b.provenanceSchemaVersion &&
    a.generationId == b.generationId &&
    a.originType == b.originType &&
    a.providerTemplateId == b.providerTemplateId &&
    a.providerTemplateVersion == b.providerTemplateVersion &&
    a.catalogVersion == b.catalogVersion &&
    a.apartmentTemplateId == b.apartmentTemplateId &&
    a.apartmentTemplateVersion == b.apartmentTemplateVersion &&
    a.familyId == b.familyId &&
    a.variantSeedId == b.variantSeedId &&
    a.generatorVersion == b.generatorVersion &&
    a.scoringProfileVersion == b.scoringProfileVersion &&
    a.allocatorVersion == b.allocatorVersion &&
    a.geometryAlgorithmVersion == b.geometryAlgorithmVersion &&
    a.normalizedIntentFingerprint == b.normalizedIntentFingerprint &&
    a.selectedCandidateFingerprint == b.selectedCandidateFingerprint &&
    a.projectId == b.projectId &&
    a.buildingId == b.buildingId &&
    a.levelId == b.levelId &&
    a.apartmentZoneId == b.apartmentZoneId &&
    _setEquals(a.generatedEntityIds, b.generatedEntityIds) &&
    _setEquals(a.removedGenerationKeys, b.removedGenerationKeys);

bool _sameEntity(EntityGenerationProvenance a, EntityGenerationProvenance b) =>
    a.entityId == b.entityId &&
    a.generationId == b.generationId &&
    a.generationKey == b.generationKey &&
    _setEquals(a.generatedProperties, b.generatedProperties) &&
    _setEquals(a.overriddenProperties, b.overriddenProperties) &&
    a.lockedFromRegeneration == b.lockedFromRegeneration &&
    a.generatedBaselineFingerprint == b.generatedBaselineFingerprint;

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

String _nonEmpty(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return normalized;
}
