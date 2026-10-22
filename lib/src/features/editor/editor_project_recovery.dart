import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'editor_project_document.dart';

final class EditorProjectRecoverySnapshot {
  const EditorProjectRecoverySnapshot({
    required this.capturedAt,
    required this.revision,
    required this.document,
  });

  static const formatVersion = 1;

  final DateTime capturedAt;
  final int revision;
  final EditorProjectDocument document;

  String get projectId => document.projectId;

  Map<String, Object?> toJson() => {
    'recoveryVersion': formatVersion,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'revision': revision,
    'document': document.toJson(),
  };

  factory EditorProjectRecoverySnapshot.fromJson(Map<String, Object?> json) {
    final version = json['recoveryVersion'];
    if (version != formatVersion) {
      throw FormatException('Unsupported ElecX recovery version $version.');
    }
    final rawDocument = json['document'];
    if (rawDocument is! Map) {
      throw const FormatException('Recovery document must be a JSON object.');
    }
    final revision = json['revision'];
    if (revision is! int || revision < 0) {
      throw const FormatException('Recovery revision must be non-negative.');
    }
    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is! String) {
      throw const FormatException('Recovery capturedAt must be a string.');
    }
    return EditorProjectRecoverySnapshot(
      capturedAt: DateTime.parse(capturedAtRaw).toUtc(),
      revision: revision,
      document: EditorProjectDocument.fromJson(
        rawDocument.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }
}

abstract interface class EditorProjectRecoveryStore {
  Future<void> save(EditorProjectRecoverySnapshot snapshot);
  Future<EditorProjectRecoverySnapshot?> load(String projectId);
  Future<List<EditorProjectRecoverySnapshot>> list();
  Future<void> discard(String projectId);
}

final class JsonFileEditorProjectRecoveryStore
    implements EditorProjectRecoveryStore {
  JsonFileEditorProjectRecoveryStore(this.rootDirectory);

  final Directory rootDirectory;

  static Future<JsonFileEditorProjectRecoveryStore> openDefault() async {
    final documents = await getApplicationDocumentsDirectory();
    return JsonFileEditorProjectRecoveryStore(
      Directory(path.join(documents.path, 'ElecX', 'recovery')),
    );
  }

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    await rootDirectory.create(recursive: true);
    final encoded = jsonEncode(snapshot.toJson());
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw StateError('Encoded ElecX recovery is not a JSON object.');
    }
    EditorProjectRecoverySnapshot.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );

    final target = _target(snapshot.projectId);
    final temp = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    if (await temp.exists()) await temp.delete();
    await temp.writeAsString(encoded, flush: true);
    if (await backup.exists()) await backup.delete();
    if (await target.exists()) {
      await target.rename(backup.path);
    }
    try {
      await temp.rename(target.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async {
    final target = _target(projectId);
    final candidates = <File>[
      target,
      File('${target.path}.bak'),
      File('${target.path}.tmp'),
    ];
    EditorProjectRecoverySnapshot? best;
    for (final file in candidates) {
      final snapshot = await _tryRead(file, expectedProjectId: projectId);
      if (snapshot != null &&
          (best == null || snapshot.capturedAt.isAfter(best.capturedAt))) {
        best = snapshot;
      }
    }
    return best;
  }

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async {
    if (!await rootDirectory.exists()) return const [];
    final result = <EditorProjectRecoverySnapshot>[];
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! File ||
          (!entity.path.endsWith('.elecx.recovery.json') &&
              !entity.path.endsWith('.elecx.recovery.json.bak') &&
              !entity.path.endsWith('.elecx.recovery.json.tmp'))) {
        continue;
      }
      final snapshot = await _tryRead(entity);
      if (snapshot == null) continue;
      final existingIndex = result.indexWhere(
        (item) => item.projectId == snapshot.projectId,
      );
      if (existingIndex == -1) {
        result.add(snapshot);
      } else if (snapshot.capturedAt.isAfter(
        result[existingIndex].capturedAt,
      )) {
        result[existingIndex] = snapshot;
      }
    }
    result.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(result);
  }

  @override
  Future<void> discard(String projectId) async {
    final target = _target(projectId);
    final temp = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    if (await target.exists()) await target.delete();
    if (await temp.exists()) await temp.delete();
    if (await backup.exists()) await backup.delete();
  }

  Future<EditorProjectRecoverySnapshot?> _tryRead(
    File file, {
    String? expectedProjectId,
  }) async {
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final snapshot = EditorProjectRecoverySnapshot.fromJson(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (expectedProjectId != null &&
          snapshot.projectId != expectedProjectId) {
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  File _target(String projectId) {
    final encoded = base64Url
        .encode(utf8.encode(projectId))
        .replaceAll('=', '');
    return File(path.join(rootDirectory.path, '$encoded.elecx.recovery.json'));
  }
}
