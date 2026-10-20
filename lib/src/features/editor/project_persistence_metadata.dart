import 'dart:math';

final class EditorProjectMetadata {
  const EditorProjectMetadata({
    required this.projectId,
    required this.projectName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String projectId;
  final String projectName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EditorProjectMetadata.create({
    required String projectName,
    String? projectId,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final normalizedName = projectName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(projectName, 'projectName', 'Must be non-empty.');
    }
    return EditorProjectMetadata(
      projectId: projectId ?? _ProjectIdGenerator.generate(timestamp),
      projectName: normalizedName,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  EditorProjectMetadata copyWith({
    String? projectName,
    DateTime? updatedAt,
  }) {
    final nextName = (projectName ?? this.projectName).trim();
    if (nextName.isEmpty) {
      throw ArgumentError.value(projectName, 'projectName', 'Must be non-empty.');
    }
    final nextUpdatedAt = (updatedAt ?? this.updatedAt).toUtc();
    if (nextUpdatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        nextUpdatedAt,
        'updatedAt',
        'Must not be before createdAt.',
      );
    }
    return EditorProjectMetadata(
      projectId: projectId,
      projectName: nextName,
      createdAt: createdAt.toUtc(),
      updatedAt: nextUpdatedAt,
    );
  }

  EditorProjectMetadata touch([DateTime? now]) => copyWith(
        updatedAt: (now ?? DateTime.now()).toUtc(),
      );
}

enum EditorProjectSaveStatus {
  saved,
  modified,
  saving,
  saveFailed,
}

extension EditorProjectSaveStatusText on EditorProjectSaveStatus {
  String get label => switch (this) {
        EditorProjectSaveStatus.saved => 'Saved',
        EditorProjectSaveStatus.modified => 'Modified',
        EditorProjectSaveStatus.saving => 'Saving…',
        EditorProjectSaveStatus.saveFailed => 'Save failed',
      };
}

abstract final class _ProjectIdGenerator {
  static final Random _random = Random.secure();

  static String generate(DateTime timestamp) {
    final time = timestamp.microsecondsSinceEpoch.toRadixString(36);
    final entropyA = _random.nextInt(1 << 30).toRadixString(36);
    final entropyB = _random.nextInt(1 << 30).toRadixString(36);
    return 'project-$time-$entropyA$entropyB';
  }
}
