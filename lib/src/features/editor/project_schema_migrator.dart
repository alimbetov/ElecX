final class EditorProjectSchemaMigrator {
  const EditorProjectSchemaMigrator._();

  static const int currentSchemaVersion = 2;

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
        _ => throw FormatException(
            'No ElecX migration registered from schema $version.',
          ),
      };
      version = result['schemaVersion']! as int;
    }
    return result;
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
