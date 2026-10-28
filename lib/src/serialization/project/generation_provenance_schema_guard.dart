/// Strict schema-v1 key guard for persisted P9 generation provenance.
///
/// Unknown semantic fields must never be silently discarded by an older
/// client. Future provenance semantics therefore require a schema-version bump
/// and an explicit migration path before this decoder may accept them.
abstract final class GenerationProvenanceSchemaGuard {
  static const Set<String> _registryKeys = {
    'schemaVersion',
    'manifests',
    'entities',
  };

  static const Set<String> _manifestKeys = {
    'generationId',
    'originType',
    'providerTemplateId',
    'providerTemplateVersion',
    'catalogVersion',
    'apartmentTemplateId',
    'apartmentTemplateVersion',
    'familyId',
    'variantSeedId',
    'generatorVersion',
    'scoringProfileVersion',
    'allocatorVersion',
    'geometryAlgorithmVersion',
    'normalizedIntentFingerprint',
    'selectedCandidateFingerprint',
    'projectId',
    'buildingId',
    'levelId',
    'apartmentZoneId',
    'generatedEntityIds',
    'removedGenerationKeys',
  };

  static const Set<String> _entityKeys = {
    'entityId',
    'generationId',
    'generationKey',
    'generatedProperties',
    'overriddenProperties',
    'lockedFromRegeneration',
    'generatedBaselineFingerprint',
  };

  static const Set<String> _entityIdKeys = {
    'kind',
    'value',
  };

  static void validate(Object? raw) {
    final registry = _map(raw, 'generationProvenance');
    _rejectUnknownKeys(registry, _registryKeys, 'generationProvenance');

    final manifests = _list(
      registry['manifests'],
      'generationProvenance.manifests',
    );
    for (var index = 0; index < manifests.length; index++) {
      final manifest = _map(
        manifests[index],
        'generationProvenance.manifests[$index]',
      );
      _rejectUnknownKeys(
        manifest,
        _manifestKeys,
        'generationProvenance.manifests[$index]',
      );
      final generatedEntityIds = _list(
        manifest['generatedEntityIds'],
        'generationProvenance.manifests[$index].generatedEntityIds',
      );
      for (var entityIndex = 0;
          entityIndex < generatedEntityIds.length;
          entityIndex++) {
        final entityId = _map(
          generatedEntityIds[entityIndex],
          'generationProvenance.manifests[$index]'
          '.generatedEntityIds[$entityIndex]',
        );
        _rejectUnknownKeys(
          entityId,
          _entityIdKeys,
          'generationProvenance.manifests[$index]'
          '.generatedEntityIds[$entityIndex]',
        );
      }
    }

    final entities = _list(
      registry['entities'],
      'generationProvenance.entities',
    );
    for (var index = 0; index < entities.length; index++) {
      final entity = _map(
        entities[index],
        'generationProvenance.entities[$index]',
      );
      _rejectUnknownKeys(
        entity,
        _entityKeys,
        'generationProvenance.entities[$index]',
      );
      final entityId = _map(
        entity['entityId'],
        'generationProvenance.entities[$index].entityId',
      );
      _rejectUnknownKeys(
        entityId,
        _entityIdKeys,
        'generationProvenance.entities[$index].entityId',
      );
    }
  }

  static void _rejectUnknownKeys(
    Map<String, Object?> value,
    Set<String> allowed,
    String path,
  ) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList()
      ..sort();
    if (unknown.isNotEmpty) {
      throw FormatException(
        '$path contains unsupported field(s): ${unknown.join(', ')}. '
        'Future provenance fields require a schema-version migration.',
      );
    }
  }

  static Map<String, Object?> _map(Object? value, String path) {
    if (value is! Map) {
      throw FormatException('$path must be an object.');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Object?> _list(Object? value, String path) {
    if (value is! List) {
      throw FormatException('$path must be an array.');
    }
    return List<Object?>.from(value);
  }
}
