import '../../application/project/project_snapshot.dart';

/// Versioned persistence representation independent from filesystem/database IO.
final class ProjectDocument {
  ProjectDocument({
    required this.schemaVersion,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload) {
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
abstract interface class ProjectDocumentCodec {
  int get currentSchemaVersion;

  ProjectDocument encode(ProjectSnapshot snapshot);

  ProjectSnapshot decode(ProjectDocument document);
}
