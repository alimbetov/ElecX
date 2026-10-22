import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../application/project/project_repository.dart';
import '../../application/project/project_snapshot.dart';
import '../../domain/project_identity.dart';
import '../../serialization/project/project_document_codec.dart';

/// Native JSON infrastructure adapter for [ProjectRepository].
///
/// The repository owns filesystem concerns only. Canonical serialization and
/// migration semantics belong to [ProjectDocumentCodec]. The adapter is not
/// wired into the production editor yet; P2D must provide a lossless canonical
/// document/migration path before replacing the legacy editor store.
final class JsonProjectRepository implements ProjectRepository {
  JsonProjectRepository({required this.rootDirectory, required this.codec});

  final Directory rootDirectory;
  final ProjectDocumentCodec codec;

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    await rootDirectory.create(recursive: true);

    final document = codec.encode(snapshot);
    final envelope = <String, Object?>{
      'schemaVersion': document.schemaVersion,
      'payload': document.payload,
    };
    final encoded = jsonEncode(envelope);

    // Prove the complete serialized representation is decodable and stable
    // before touching the current on-disk project. Identity-only validation is
    // insufficient once canonical root metadata (for example Project North)
    // participates in persistence: a lossy decoder could keep ProjectId while
    // silently dropping engineering state.
    final validated = _documentFromJson(jsonDecode(encoded));
    final roundTrip = codec.decode(validated);
    if (roundTrip.id != snapshot.id) {
      throw StateError(
        'Project codec changed project identity during save validation.',
      );
    }

    final reencoded = codec.encode(roundTrip);
    final reencodedEnvelope = <String, Object?>{
      'schemaVersion': reencoded.schemaVersion,
      'payload': reencoded.payload,
    };
    if (jsonEncode(reencodedEnvelope) != encoded) {
      throw StateError(
        'Project codec changed canonical document during save validation.',
      );
    }

    final target = _target(snapshot.id);
    final temp = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');

    if (await temp.exists()) {
      await temp.delete();
    }
    await temp.writeAsString(encoded, flush: true);
    if (await backup.exists()) {
      await backup.delete();
    }

    var backedUp = false;
    try {
      if (await target.exists()) {
        await target.rename(backup.path);
        backedUp = true;
      }
      await temp.rename(target.path);
      if (backedUp && await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async {
    final target = _target(projectId);
    final backup = File('${target.path}.bak');
    final candidates = <File>[
      if (await target.exists()) target,
      if (await backup.exists()) backup,
    ];

    Object? lastFailure;
    for (final source in candidates) {
      try {
        final snapshot = await _read(source);
        if (snapshot.id != projectId) {
          throw FormatException(
            'Persisted project id ${snapshot.id} does not match requested '
            'id $projectId.',
          );
        }
        return snapshot;
      } on FormatException catch (error) {
        lastFailure = error;
      } on FileSystemException catch (error) {
        lastFailure = error;
      }
    }

    if (candidates.isEmpty) {
      return null;
    }
    if (lastFailure != null) {
      throw lastFailure;
    }
    return null;
  }

  @override
  Future<List<ProjectSummary>> list() async {
    if (!await rootDirectory.exists()) {
      return const [];
    }

    final candidatesByBasePath = <String, List<File>>{};
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final isPrimary = entity.path.endsWith('.elecx.project.json');
      final isBackup = entity.path.endsWith('.elecx.project.json.bak');
      if (!isPrimary && !isBackup) {
        continue;
      }
      final basePath = isBackup
          ? entity.path.substring(0, entity.path.length - '.bak'.length)
          : entity.path;
      final candidates = candidatesByBasePath.putIfAbsent(
        basePath,
        () => <File>[],
      );
      if (isPrimary) {
        candidates.insert(0, entity);
      } else {
        candidates.add(entity);
      }
    }

    final summaries = <ProjectSummary>[];
    for (final candidates in candidatesByBasePath.values) {
      ProjectSnapshot? snapshot;
      for (final candidate in candidates) {
        try {
          snapshot = await _read(candidate);
          break;
        } on FormatException {
          // One corrupt project must not hide healthy projects from the Hub.
        } on FileSystemException {
          // A file can disappear between enumeration and read.
        }
      }
      if (snapshot != null) {
        summaries.add(snapshot.toSummary());
      }
    }

    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<ProjectSummary>.unmodifiable(summaries);
  }

  Future<ProjectSnapshot> _read(File source) async {
    final raw = jsonDecode(await source.readAsString());
    return codec.decode(_documentFromJson(raw));
  }

  ProjectDocument _documentFromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('ElecX project root must be a JSON object.');
    }
    final normalized = raw.map((key, value) => MapEntry(key.toString(), value));
    final schemaVersion = normalized['schemaVersion'];
    final payload = normalized['payload'];
    if (schemaVersion is! int) {
      throw const FormatException('schemaVersion must be an integer.');
    }
    if (payload is! Map) {
      throw const FormatException('payload must be an object.');
    }
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: payload.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  File _target(ProjectId projectId) {
    final encoded = base64Url
        .encode(utf8.encode(projectId.value))
        .replaceAll('=', '');
    return File(path.join(rootDirectory.path, '$encoded.elecx.project.json'));
  }
}
