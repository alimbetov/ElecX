import 'dart:convert';

import 'editor_project_document.dart';
import 'editor_project_recovery.dart';

/// Minimal browser persistence primitive kept separate from browser APIs so
/// project/recovery semantics can be unit-tested on the Dart VM.
abstract interface class BrowserKeyValueStore {
  Iterable<String> get keys;
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

final class BrowserEditorProjectStore implements EditorProjectStore {
  BrowserEditorProjectStore(this.storage);

  static const _prefix = 'elecx.project.v1.';

  final BrowserKeyValueStore storage;

  @override
  Future<void> save(EditorProjectDocument document) async {
    final encoded = jsonEncode(document.toJson());
    final raw = jsonDecode(encoded);
    if (raw is! Map) {
      throw StateError('Encoded ElecX project is not a JSON object.');
    }
    // Fail closed before replacing the previously durable browser value.
    EditorProjectDocument.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    storage.write(_key(document.projectId), encoded);
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    final encoded = storage.read(_key(projectId));
    if (encoded == null) return null;
    final raw = jsonDecode(encoded);
    if (raw is! Map) {
      throw const FormatException('ElecX project root must be a JSON object.');
    }
    final document = EditorProjectDocument.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (document.projectId != projectId) {
      throw const FormatException(
        'Persisted project id does not match requested id.',
      );
    }
    return document;
  }

  @override
  Future<List<EditorProjectDocument>> list() async {
    final result = <EditorProjectDocument>[];
    for (final key in storage.keys.where((item) => item.startsWith(_prefix))) {
      final encoded = storage.read(key);
      if (encoded == null) continue;
      try {
        final raw = jsonDecode(encoded);
        if (raw is! Map) continue;
        result.add(
          EditorProjectDocument.fromJson(
            raw.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      } on FormatException {
        // One damaged browser record must not hide every healthy project.
        continue;
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<EditorProjectDocument>.unmodifiable(result);
  }

  String _key(String projectId) => '$_prefix${_encodeId(projectId)}';
}

final class BrowserEditorProjectRecoveryStore
    implements EditorProjectRecoveryStore {
  BrowserEditorProjectRecoveryStore(this.storage);

  static const _prefix = 'elecx.recovery.v1.';

  final BrowserKeyValueStore storage;

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    final encoded = jsonEncode(snapshot.toJson());
    final raw = jsonDecode(encoded);
    if (raw is! Map) {
      throw StateError('Encoded ElecX recovery is not a JSON object.');
    }
    EditorProjectRecoverySnapshot.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    storage.write(_key(snapshot.projectId), encoded);
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async {
    final encoded = storage.read(_key(projectId));
    if (encoded == null) return null;
    final raw = jsonDecode(encoded);
    if (raw is! Map) {
      throw const FormatException('ElecX recovery root must be a JSON object.');
    }
    final snapshot = EditorProjectRecoverySnapshot.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (snapshot.projectId != projectId) {
      throw const FormatException(
        'Persisted recovery id does not match requested id.',
      );
    }
    return snapshot;
  }

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async {
    final result = <EditorProjectRecoverySnapshot>[];
    for (final key in storage.keys.where((item) => item.startsWith(_prefix))) {
      final encoded = storage.read(key);
      if (encoded == null) continue;
      try {
        final raw = jsonDecode(encoded);
        if (raw is! Map) continue;
        result.add(
          EditorProjectRecoverySnapshot.fromJson(
            raw.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      } on FormatException {
        continue;
      }
    }
    result.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List<EditorProjectRecoverySnapshot>.unmodifiable(result);
  }

  @override
  Future<void> discard(String projectId) async {
    storage.remove(_key(projectId));
  }

  String _key(String projectId) => '$_prefix${_encodeId(projectId)}';
}

String _encodeId(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');
