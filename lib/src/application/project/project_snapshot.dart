import '../../domain/boundary_geometry_integrity.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';

/// Persistence-facing immutable snapshot of one canonical ElecX project.
///
/// The aggregate owns engineering/structural state. Snapshot metadata is kept
/// outside UI/editor classes so repositories and codecs do not depend on
/// filesystem, Flutter widgets or the transitional editor workspace.
final class ProjectSnapshot {
  ProjectSnapshot({
    required this.aggregate,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : name = _normalizeName(name),
        createdAt = createdAt.toUtc(),
        updatedAt = updatedAt.toUtc() {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Must not be before createdAt.',
      );
    }

    aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry
        .requireCoversActiveBoundaries(aggregate.stores.boundaries);
    aggregate.engineeringMetadata.boundaryHostedObjectRegistry
        .validateAgainst(aggregate.stores.boundaries);
    for (final topology in aggregate.stores.boundaries.values) {
      BoundaryGeometryIntegrity.validateOrThrow(topology);
    }
  }

  final ProjectAggregateRoot aggregate;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectId get id => aggregate.id;
  SiteId get siteId => aggregate.siteId;
  LocalProjectVersion get localVersion => aggregate.version;

  ProjectSnapshot copyWith({
    ProjectAggregateRoot? aggregate,
    String? name,
    DateTime? updatedAt,
  }) =>
      ProjectSnapshot(
        aggregate: aggregate ?? this.aggregate,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  ProjectSummary toSummary() => ProjectSummary(
        id: id,
        name: name,
        createdAt: createdAt,
        updatedAt: updatedAt,
        localVersion: localVersion,
      );

  static String _normalizeName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'name', 'Must be non-empty.');
    }
    return normalized;
  }
}

/// Lightweight repository listing projection.
final class ProjectSummary {
  ProjectSummary({
    required this.id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.localVersion,
  })  : name = ProjectSnapshot._normalizeName(name),
        createdAt = createdAt.toUtc(),
        updatedAt = updatedAt.toUtc() {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Must not be before createdAt.',
      );
    }
  }

  final ProjectId id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalProjectVersion localVersion;
}
