import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation_reservation.dart';

enum WizardDiffKind { add, update, remove }

enum WizardDiffEntityCategory { site, building, level, other }

final class WizardFieldChange {
  const WizardFieldChange({
    required this.field,
    this.beforeValue,
    this.afterValue,
  });

  final String field;
  final String? beforeValue;
  final String? afterValue;
}

final class WizardDiffEntry {
  WizardDiffEntry({
    required this.kind,
    required this.category,
    required this.title,
    required this.semanticKey,
    required String sortKey,
    this.entityId,
    this.context,
    Iterable<WizardFieldChange> fields = const [],
  })  : _sortKey = sortKey,
        fields = List.unmodifiable(fields);

  final WizardDiffKind kind;
  final WizardDiffEntityCategory category;
  final EntityId? entityId;
  final String title;
  final String? context;
  final List<WizardFieldChange> fields;
  final String semanticKey;
  final String _sortKey;

  bool matches(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = <String>[
      title,
      context ?? '',
      semanticKey,
      entityId?.value ?? '',
      for (final field in fields) ...[
        field.field,
        field.beforeValue ?? '',
        field.afterValue ?? '',
      ],
    ].join('\n').toLowerCase();
    return searchable.contains(query);
  }
}

final class WizardDiffModel {
  WizardDiffModel(Iterable<WizardDiffEntry> entries)
      : entries = List.unmodifiable(
          List<WizardDiffEntry>.of(entries)
            ..sort((left, right) {
              final primary = left._sortKey.compareTo(right._sortKey);
              if (primary != 0) return primary;
              return left.semanticKey.compareTo(right.semanticKey);
            }),
        );

  final List<WizardDiffEntry> entries;

  bool get isEmpty => entries.isEmpty;
  int count(WizardDiffKind kind) =>
      entries.where((entry) => entry.kind == kind).length;

  List<WizardDiffEntry> filtered({
    Set<WizardDiffKind>? kinds,
    Set<WizardDiffEntityCategory>? categories,
    String query = '',
  }) =>
      List.unmodifiable(
        entries.where(
          (entry) =>
              (kinds == null || kinds.contains(entry.kind)) &&
              (categories == null || categories.contains(entry.category)) &&
              entry.matches(query),
        ),
      );
}

/// Converts canonical typed semantic operations into a stable, human-facing
/// Wizard diff. It never parses SVG or provider-specific payloads: field values
/// are read from the canonical before/candidate aggregates.
final class WizardDiffProjector {
  const WizardDiffProjector();

  WizardDiffModel project({
    required ProjectAggregateRoot before,
    required ReservedProjectMutationPreview preview,
  }) {
    final candidate = preview.candidate;
    return WizardDiffModel([
      for (final operation in preview.semanticChangeSet.operations)
        _entry(operation, before: before, candidate: candidate),
    ]);
  }

  WizardDiffEntry _entry(
    ProjectSemanticOperation operation, {
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
  }) {
    if (operation is CreateEntityOperation) {
      return _entityEntry(
        kind: WizardDiffKind.add,
        id: operation.entityId,
        before: before,
        candidate: candidate,
        semanticKey: operation.semanticKey,
      );
    }
    if (operation is UpdateEntityOperation) {
      return _entityEntry(
        kind: WizardDiffKind.update,
        id: operation.entityId,
        before: before,
        candidate: candidate,
        semanticKey: operation.semanticKey,
      );
    }
    if (operation is RemoveEntityOperation) {
      return _entityEntry(
        kind: WizardDiffKind.remove,
        id: operation.entityId,
        before: before,
        candidate: candidate,
        semanticKey: operation.semanticKey,
      );
    }
    return WizardDiffEntry(
      kind: WizardDiffKind.update,
      category: WizardDiffEntityCategory.other,
      title: _semanticTitle(operation),
      semanticKey: operation.semanticKey,
      sortKey: '9|${operation.semanticKey}',
    );
  }

  WizardDiffEntry _entityEntry({
    required WizardDiffKind kind,
    required EntityId id,
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required String semanticKey,
  }) {
    final beforeEntity = _entity(before, id);
    final candidateEntity = _entity(candidate, id);
    final displayEntity = candidateEntity ?? beforeEntity;
    final category = _category(id);
    final fields = switch (kind) {
      WizardDiffKind.add => _fieldChanges(null, candidateEntity),
      WizardDiffKind.update => _fieldChanges(beforeEntity, candidateEntity),
      WizardDiffKind.remove => _fieldChanges(beforeEntity, null),
    };
    return WizardDiffEntry(
      kind: kind,
      category: category,
      entityId: id,
      title: _title(id, displayEntity),
      context: _context(id, displayEntity, before, candidate),
      fields: fields,
      semanticKey: semanticKey,
      sortKey: _sortKey(id, displayEntity, before, candidate),
    );
  }

  Object? _entity(ProjectAggregateRoot project, EntityId id) {
    if (id is SiteId) return project.stores.sites[id];
    if (id is BuildingId) return project.stores.buildings[id];
    if (id is LevelId) return project.stores.levels[id];
    return null;
  }

  WizardDiffEntityCategory _category(EntityId id) {
    if (id is SiteId) return WizardDiffEntityCategory.site;
    if (id is BuildingId) return WizardDiffEntityCategory.building;
    if (id is LevelId) return WizardDiffEntityCategory.level;
    return WizardDiffEntityCategory.other;
  }

  String _title(EntityId id, Object? entity) {
    if (entity is ProjectSiteEntity) return 'Site “${entity.name}”';
    if (entity is ProjectBuildingEntity) return 'Building “${entity.name}”';
    if (entity is ProjectLevelEntity) {
      return 'Level ${entity.levelNumber} — ${entity.name}';
    }
    return '${id.runtimeType} ${id.value}';
  }

  String? _context(
    EntityId id,
    Object? entity,
    ProjectAggregateRoot before,
    ProjectAggregateRoot candidate,
  ) {
    if (entity is ProjectBuildingEntity) {
      final site = candidate.stores.sites[entity.siteId] ??
          before.stores.sites[entity.siteId];
      return site == null ? null : 'Site “${site.name}”';
    }
    if (entity is ProjectLevelEntity) {
      final building = candidate.stores.buildings[entity.buildingId] ??
          before.stores.buildings[entity.buildingId];
      return building == null ? null : 'Building “${building.name}”';
    }
    return null;
  }

  List<WizardFieldChange> _fieldChanges(Object? before, Object? after) {
    final beforeFields = _fields(before);
    final afterFields = _fields(after);
    final keys = <String>{...beforeFields.keys, ...afterFields.keys}.toList()
      ..sort();
    return [
      for (final key in keys)
        if (beforeFields[key] != afterFields[key])
          WizardFieldChange(
            field: key,
            beforeValue: beforeFields[key],
            afterValue: afterFields[key],
          ),
    ];
  }

  Map<String, String> _fields(Object? entity) {
    if (entity is ProjectSiteEntity) {
      return {
        'Name': entity.name,
        'Buildings': entity.buildingIds.length.toString(),
      };
    }
    if (entity is ProjectBuildingEntity) {
      return {
        'Name': entity.name,
        'Display order': entity.displayOrder.toString(),
        'Levels': entity.levelIds.length.toString(),
      };
    }
    if (entity is ProjectLevelEntity) {
      return {
        'Name': entity.name,
        'Number': entity.levelNumber.toString(),
        'Elevation': '${entity.elevationMm} mm',
        'Kind': entity.kind.name,
        'Floor-to-floor': '${entity.floorToFloorHeightMm} mm',
        'Display order': entity.displayOrder.toString(),
      };
    }
    return const {};
  }

  String _sortKey(
    EntityId id,
    Object? entity,
    ProjectAggregateRoot before,
    ProjectAggregateRoot candidate,
  ) {
    if (entity is ProjectSiteEntity) return '0|${id.value}';
    if (entity is ProjectBuildingEntity) {
      return '1|${entity.displayOrder.toString().padLeft(6, '0')}|${id.value}';
    }
    if (entity is ProjectLevelEntity) {
      final building = candidate.stores.buildings[entity.buildingId] ??
          before.stores.buildings[entity.buildingId];
      final buildingOrder = building?.displayOrder ?? 0;
      return '2|${buildingOrder.toString().padLeft(6, '0')}|'
          '${entity.displayOrder.toString().padLeft(6, '0')}|${id.value}';
    }
    return '8|${id.runtimeType}|${id.value}';
  }

  String _semanticTitle(ProjectSemanticOperation operation) {
    if (operation is CreatePenetrationOperation) return 'Create penetration';
    if (operation is AttachPenetrationToSlabOperation) {
      return 'Attach penetration to slab';
    }
    if (operation is BindPenetrationToVerticalCoreOperation) {
      return 'Bind penetration to vertical core';
    }
    if (operation is AddRouteAnchorOperation) return 'Add route anchor';
    if (operation is AddHiddenVerticalRouteLegOperation) {
      return 'Add hidden vertical route leg';
    }
    if (operation is UpdateEngineeringEvidenceOperation) {
      return 'Update engineering evidence';
    }
    if (operation is RemovePhysicalDependencyOperation) {
      return 'Remove physical dependency';
    }
    return operation.runtimeType.toString();
  }
}
