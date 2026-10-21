import '../../application/project/project_snapshot.dart';

/// Versioned persistence representation independent from filesystem/database IO.
final class ProjectDocument {
  ProjectDocument({
    required this.schemaVersion,
    required Map<String, Object?> payload,
  }) : payload = _freezeMap(payload) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Must be greater than zero.',
      );
    }
  }

  final int schemaVersion;
  final Map<String, Object?> payload;
}

/// Converts canonical snapshots to/from a versioned document representation.
///
/// This boundary deliberately has no `dart:io`, `path_provider`, SQLite, HTTP
/// or Flutter dependency. Infrastructure adapters own byte/file/database IO.
/// Implementations must reject unsupported or malformed persisted input with a
/// [FormatException] rather than returning a partial snapshot.
abstract interface class ProjectDocumentCodec {
  int get currentSchemaVersion;

  ProjectDocument encode(ProjectSnapshot snapshot);

  ProjectSnapshot decode(ProjectDocument document);
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in source.entries) entry.key: _freezeValue(entry.value),
    });

Object? _freezeValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _freezeValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  if (value is Set) {
    return Set<Object?>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
