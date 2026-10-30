import '../../../domain/composition_generation_provenance.dart';
import '../../../domain/boundary_topology.dart';
import '../../../domain/boundary_host_migration.dart';
import '../../../domain/project_service_anchor.dart';
import '../../../domain/project_site_layout.dart';
import '../../../domain/slab_topology.dart';
import '../../../domain/vertical_core.dart';
import '../../../domain/typical_floor.dart';
import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/project_space_semantics.dart';
import '../project_mutation_reservation.dart';

enum WizardDiffKind { add, update, remove }

enum WizardDiffEntityCategory {
  site,
  building,
  level,
  structuralZone,
  space,
  opening,
  adjacency,
  boundaryTopology,
  provenance,
  slab,
  verticalCore,
  serviceAnchor,
  other,
}

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
    this.groupKey,
    Iterable<WizardFieldChange> fields = const [],
  })  : _sortKey = sortKey,
        fields = List.unmodifiable(fields);

  final WizardDiffKind kind;
  final WizardDiffEntityCategory category;
  final EntityId? entityId;
  final String title;
  final String? context;
  final String? groupKey;
  final List<WizardFieldChange> fields;
  final String semanticKey;
  final String _sortKey;

  bool matches(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = <String>[
      title,
      context ?? '',
      groupKey ?? '',
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

final class WizardDiffGroup {
  WizardDiffGroup(
      {required this.key, required Iterable<WizardDiffEntry> entries})
      : entries = List.unmodifiable(entries);

  final String key;
  final List<WizardDiffEntry> entries;
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

  List<WizardDiffGroup> grouped() {
    final groups = <String, List<WizardDiffEntry>>{};
    for (final entry in entries) {
      final key = entry.groupKey ?? 'entry:${entry.semanticKey}';
      (groups[key] ??= <WizardDiffEntry>[]).add(entry);
    }
    return List.unmodifiable([
      for (final entry in groups.entries)
        WizardDiffGroup(key: entry.key, entries: entry.value),
    ]);
  }
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
      title: _title(id, displayEntity, before, candidate),
      context: _context(id, displayEntity, before, candidate),
      groupKey: _groupKey(id, displayEntity),
      fields: [
        ...fields,
        if (id is BuildingId)
          ..._fieldChanges(before.engineeringMetadata.siteLayout.placements[id],
              candidate.engineeringMetadata.siteLayout.placements[id]),
        if (id is ServiceEntryId)
          ..._fieldChanges(
              before.engineeringMetadata.boundaryHostedObjectRegistry
                  .serviceEntryHost(id),
              candidate.engineeringMetadata.boundaryHostedObjectRegistry
                  .serviceEntryHost(id)),
      ],
      semanticKey: semanticKey,
      sortKey: _sortKey(id, displayEntity, before, candidate),
    );
  }

  Object? _entity(ProjectAggregateRoot project, EntityId id) {
    if (id is SiteId) return project.stores.sites[id];
    if (id is BuildingId) return project.stores.buildings[id];
    if (id is LevelId) return project.stores.levels[id];
    if (id is ZoneId) return project.stores.zones[id];
    if (id is SpaceId) return project.stores.spaces[id];
    if (id is OpeningId) return project.stores.openings[id];
    if (id is SpaceAdjacencyId) return project.stores.adjacencies[id];
    if (id is BoundaryEdgeId) return project.index.boundaryEdges[id];
    if (id is SlabId) return project.stores.slabs[id];
    if (id is VerticalCoreId) return project.stores.verticalCores[id];
    if (id is ServiceEntryId) {
      return project.engineeringMetadata.siteLayout.serviceAnchors[id] ??
          project.engineeringMetadata.siteLayout.sharedAnchors[id];
    }
    if (id is GenerationId) {
      return project
          .engineeringMetadata.generationProvenanceRegistry.compositions[id];
    }
    if (id is TypicalFloorDefinitionId) {
      return project.engineeringMetadata.generationProvenanceRegistry
          .typicalFloorDefinitions[id];
    }
    return null;
  }

  WizardDiffEntityCategory _category(EntityId id) {
    if (id is GenerationId) return WizardDiffEntityCategory.provenance;
    if (id is SiteId) return WizardDiffEntityCategory.site;
    if (id is BuildingId) return WizardDiffEntityCategory.building;
    if (id is LevelId) return WizardDiffEntityCategory.level;
    if (id is ZoneId) return WizardDiffEntityCategory.structuralZone;
    if (id is SpaceId) return WizardDiffEntityCategory.space;
    if (id is OpeningId) return WizardDiffEntityCategory.opening;
    if (id is SpaceAdjacencyId) return WizardDiffEntityCategory.adjacency;
    if (id is BoundaryEdgeId) return WizardDiffEntityCategory.boundaryTopology;
    if (id is SlabId) return WizardDiffEntityCategory.slab;
    if (id is VerticalCoreId) return WizardDiffEntityCategory.verticalCore;
    if (id is ServiceEntryId) return WizardDiffEntityCategory.serviceAnchor;
    if (id is TypicalFloorDefinitionId) {
      return WizardDiffEntityCategory.provenance;
    }
    return WizardDiffEntityCategory.other;
  }

  String _title(
    EntityId id,
    Object? entity,
    ProjectAggregateRoot before,
    ProjectAggregateRoot candidate,
  ) {
    if (entity is CompositionGenerationManifest) return 'Composition origin';
    if (entity is ProjectSiteEntity) return 'Site “${entity.name}”';
    if (entity is ProjectBuildingEntity) return 'Building “${entity.name}”';
    if (entity is ProjectLevelEntity) {
      return 'Level ${entity.levelNumber} — ${entity.name}';
    }
    if (entity is ProjectStructuralZoneEntity) {
      return entity.kind == ProjectStructuralZoneKind.apartment
          ? 'Apartment “${entity.name}”'
          : 'Structural zone “${entity.name}”';
    }
    if (entity is ProjectSpaceEntity) return 'Space “${entity.name}”';
    if (entity is ProjectSlab) return 'Slab';
    if (entity is ProjectVerticalCore) {
      return 'Vertical core “${entity.name ?? entity.usage.name}”';
    }
    if (entity is ProjectServiceAnchor) {
      return 'Service anchor “${entity.name}”';
    }
    if (entity is ProjectSharedSiteAnchor) {
      return 'Shared anchor “${entity.name}”';
    }
    if (entity is TypicalFloorDefinition) {
      return 'Typical floor “${entity.definitionKey}”';
    }
    if (entity is ProjectOpeningEntity) {
      final names = entity.connectedSpaceIds
          .map((spaceId) => _spaceName(candidate, before, spaceId))
          .toList()
        ..sort();
      return entity.connectedSpaceIds.length == 1
          ? 'Entrance to ${names.single}'
          : '${_openingLabel(entity.kind)}: ${names.join(' ↔ ')}';
    }
    if (entity is ProjectSpaceAdjacencyEntity) {
      final left = _spaceName(candidate, before, entity.spaceAId);
      final right = _spaceName(candidate, before, entity.spaceBId);
      return '${_adjacencyLabel(entity.kind)}: $left ↔ $right';
    }
    if (entity is ProjectBoundaryEdge) {
      final spaceName = _spaceName(candidate, before, entity.spaceId);
      return 'Boundary — $spaceName';
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
    if (entity is ProjectStructuralZoneEntity) {
      return _levelContext(candidate, before, entity.levelId);
    }
    if (entity is ProjectSpaceEntity) {
      final zone = candidate.stores.zones.values
          .where((zone) => zone.spaceIds.contains(entity.id))
          .cast<ProjectStructuralZoneEntity?>()
          .firstWhere((zone) => zone != null, orElse: () => null);
      return zone == null
          ? _levelContext(candidate, before, entity.levelId)
          : '${zone.name} · ${_levelContext(candidate, before, entity.levelId)}';
    }
    if (entity is ProjectOpeningEntity) {
      return _levelContext(candidate, before, entity.levelId);
    }
    if (entity is ProjectSpaceAdjacencyEntity) {
      return 'Spaces on the same canonical apartment graph';
    }
    if (entity is ProjectBoundaryEdge) {
      return 'Space “${_spaceName(candidate, before, entity.spaceId)}”';
    }
    return null;
  }

  String? _groupKey(EntityId id, Object? entity) {
    if (entity is ProjectBoundaryEdge) return 'space:${entity.spaceId.value}';
    if (id is SpaceId) return 'space:${id.value}';
    if (id is OpeningId || id is SpaceAdjacencyId) return 'relations';
    if (id is ZoneId) return 'zones';
    if (id is LevelId) return 'level:${id.value}';
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
    if (entity is ProjectBuildingSitePlacement) {
      return {
        for (final e in entity.toCanonicalJson().entries)
          e.key: e.value.toString()
      };
    }
    if (entity is ProjectServiceAnchor) {
      return {
        for (final e in entity.toCanonicalJson().entries)
          e.key: e.value.toString()
      };
    }
    if (entity is ProjectSharedSiteAnchor) {
      return {
        for (final e in entity.toCanonicalJson().entries)
          e.key: e.value.toString()
      };
    }
    if (entity is BoundaryHostedReference) {
      return {
        'Wall space': entity.host.spaceId.value,
        'Boundary edge': entity.host.edgeId.value,
        'Offset': '${entity.startOffsetMm} mm'
      };
    }
    if (entity is ProjectVerticalCore) {
      return {
        'Name': entity.name ?? '',
        'Usage': entity.usage.name,
        'Levels': entity.levelIds.length.toString(),
        'Hosts': entity.hostSpaceIdsByLevel.length.toString()
      };
    }
    if (entity is ProjectSlab) {
      return {
        'Kind': entity.kind.name,
        'Elevation': '${entity.bottomElevationMm} mm',
        'Thickness': '${entity.thicknessMm} mm'
      };
    }
    if (entity is TypicalFloorDefinition) {
      return {
        'Definition': entity.definitionKey,
        'Template': entity.templateId.value,
        'Version': entity.templateVersion.toString()
      };
    }
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
        'Structural zones': entity.zoneIds.length.toString(),
        'Spaces': entity.spaceIds.length.toString(),
      };
    }
    if (entity is ProjectStructuralZoneEntity) {
      return {
        'Name': entity.name,
        'Kind': entity.kind.name,
        'Spaces': entity.spaceIds.length.toString(),
      };
    }
    if (entity is ProjectSpaceEntity) {
      return {
        'Name': entity.name,
        'Type': entity.type.name,
        'Usage': entity.usage.name,
      };
    }
    if (entity is ProjectOpeningEntity) {
      return {
        'Kind': entity.kind.name,
        'Width': '${entity.widthMm} mm',
        'Height': '${entity.heightMm} mm',
        'Base elevation': '${entity.baseElevationMm} mm',
        'Connected spaces': entity.connectedSpaceIds.length.toString(),
      };
    }
    if (entity is ProjectSpaceAdjacencyEntity) {
      return {
        'Kind': entity.kind.name,
        'Opening': entity.openingId == null ? 'No' : 'Yes',
      };
    }
    if (entity is ProjectBoundaryEdge) {
      return {
        'Start': '${entity.start.xMm}, ${entity.start.yMm} mm',
        'End': '${entity.end.xMm}, ${entity.end.yMm} mm',
        'Length': '${_edgeLength(entity)} mm',
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
    if (entity is ProjectStructuralZoneEntity) {
      return '3|${entity.name}|${id.value}';
    }
    if (entity is ProjectSpaceEntity) {
      return '4|${entity.usage.name}|${entity.name}|${id.value}';
    }
    if (entity is ProjectOpeningEntity) {
      final names = entity.connectedSpaceIds
          .map((spaceId) => _spaceName(candidate, before, spaceId))
          .toList()
        ..sort();
      return '5|${names.join('|')}|${entity.kind.name}|${id.value}';
    }
    if (entity is ProjectSpaceAdjacencyEntity) {
      final left = _spaceName(candidate, before, entity.spaceAId);
      final right = _spaceName(candidate, before, entity.spaceBId);
      return '6|$left|$right|${entity.kind.name}|${id.value}';
    }
    if (entity is ProjectBoundaryEdge) {
      final space = _spaceName(candidate, before, entity.spaceId);
      return '7|$space|${entity.start.xMm}|${entity.start.yMm}|${id.value}';
    }
    return '9|${id.runtimeType}|${id.value}';
  }

  String _spaceName(
    ProjectAggregateRoot candidate,
    ProjectAggregateRoot before,
    SpaceId id,
  ) =>
      candidate.stores.spaces[id]?.name ??
      before.stores.spaces[id]?.name ??
      'Space';

  String _levelContext(
    ProjectAggregateRoot candidate,
    ProjectAggregateRoot before,
    LevelId levelId,
  ) {
    final level =
        candidate.stores.levels[levelId] ?? before.stores.levels[levelId];
    return level == null
        ? 'Level'
        : 'Level ${level.levelNumber} — ${level.name}';
  }

  int _edgeLength(ProjectBoundaryEdge edge) =>
      (edge.end.xMm - edge.start.xMm).abs() +
      (edge.end.yMm - edge.start.yMm).abs();

  String _openingLabel(OpeningKind kind) => switch (kind) {
        OpeningKind.door => 'Door',
        OpeningKind.openPassage => 'Open passage',
        OpeningKind.window => 'Window',
        OpeningKind.hatch => 'Hatch',
        OpeningKind.serviceOpening => 'Service opening',
        OpeningKind.other => 'Opening',
      };

  String _adjacencyLabel(SpaceAdjacencyKind kind) => switch (kind) {
        SpaceAdjacencyKind.sharedBoundary => 'Shared boundary',
        SpaceAdjacencyKind.opening => 'Door connection',
        SpaceAdjacencyKind.openPassage => 'Open connection',
        SpaceAdjacencyKind.vertical => 'Vertical connection',
      };

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
