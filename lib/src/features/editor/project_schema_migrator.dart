final class EditorProjectSchemaMigrator {
  const EditorProjectSchemaMigrator._();

  static const int currentSchemaVersion = 3;

  static Map<String, Object?> migrate(
    Map<String, Object?> source, {
    DateTime? legacyTimestamp,
  }) {
    final rawVersion = source['schemaVersion'];
    if (rawVersion is! int) {
      throw const FormatException('schemaVersion must be an integer.');
    }
    if (rawVersion < 1) {
      throw FormatException('Unsupported ElecX project schema $rawVersion.');
    }
    if (rawVersion > currentSchemaVersion) {
      throw FormatException(
        'Unsupported ElecX project schema $rawVersion; latest supported is '
        '$currentSchemaVersion.',
      );
    }

    var version = rawVersion;
    var result = Map<String, Object?>.from(source);
    while (version < currentSchemaVersion) {
      result = switch (version) {
        1 => _v1ToV2(result, legacyTimestamp: legacyTimestamp),
        2 => _v2ToV3(result),
        _ => throw FormatException(
            'No ElecX migration registered from schema $version.',
          ),
      };
      version = result['schemaVersion']! as int;
    }
    return result;
  }

  static Map<String, Object?> _v2ToV3(Map<String, Object?> source) {
    final p2Raw = source['p2'];
    if (p2Raw is! Map) {
      throw const FormatException('p2 must be an object for schema v2.');
    }
    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));
    return <String, Object?>{
      ...source,
      'schemaVersion': 3,
      'p2': <String, Object?>{...p2, 'circuitBundles': const <Object?>[]},
    };
  }

  static Map<String, Object?> _v1ToV2(
    Map<String, Object?> source, {
    DateTime? legacyTimestamp,
  }) {
    final projectId = source['projectId'];
    final projectName = source['projectName'];
    if (projectId is! String || projectId.trim().isEmpty) {
      throw const FormatException('Legacy projectId must be non-empty.');
    }
    if (projectName is! String || projectName.trim().isEmpty) {
      throw const FormatException('Legacy projectName must be non-empty.');
    }
    final timestamp =
        (legacyTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
            .toUtc()
            .toIso8601String();
    return <String, Object?>{
      ...source,
      'schemaVersion': 2,
      'metadata': <String, Object?>{
        'projectId': projectId,
        'projectName': projectName,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
    };
  }
}
