import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_navigation_state.dart';

enum ProjectNavigatorNodeKind {
  site,
  building,
  level,
  structuralZone,
  space,
}

/// Immutable canonical node projected for Project Navigator presentation.
///
/// [id] is always a stable domain identity. The navigator may derive synthetic
/// widget keys from this value, but it must never replace it with display
/// numbers, labels or tree indices.
final class ProjectNavigatorNode {
  ProjectNavigatorNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.parentId,
    required Iterable<EntityId> childIds,
  }) : childIds = List.unmodifiable(childIds);

  final EntityId id;
  final ProjectNavigatorNodeKind kind;
  final String label;
  final EntityId? parentId;
  final List<EntityId> childIds;
}

final class ProjectBreadcrumbItem {
  const ProjectBreadcrumbItem({
    required this.id,
    required this.kind,
    required this.label,
  });

  final EntityId id;
  final ProjectNavigatorNodeKind kind;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ProjectBreadcrumbItem &&
      other.id == id &&
      other.kind == kind &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, kind, label);
}

/// Read-only, ID-indexed projection of the canonical project hierarchy.
///
/// Building and Level ordering use explicit domain ordering with stable ID
/// tie-breakers. Structural zones and spaces currently have no domain
/// display-order field, so their presentation order is deterministic by label
/// and stable ID. A zoned Space is projected exactly once under its structural
/// Zone; an unzoned Space is projected directly under its Level.
final class ProjectNavigatorProjection {
  ProjectNavigatorProjection._({
    required this.rootSiteId,
    required Map<EntityId, ProjectNavigatorNode> nodesById,
    required Map<EntityId, EntityId?> parentById,
  })  : nodesById = Map.unmodifiable(nodesById),
        parentById = Map.unmodifiable(parentById);

  factory ProjectNavigatorProjection.build(ProjectAggregateRoot project) {
    final childIdsByParent = <EntityId, List<EntityId>>{};
    final parentById = <EntityId, EntityId?>{};
    final nodeSeeds = <EntityId, _NavigatorNodeSeed>{};

    void register({
      required EntityId id,
      required ProjectNavigatorNodeKind kind,
      required String label,
      required EntityId? parentId,
    }) {
      nodeSeeds[id] = _NavigatorNodeSeed(
        id: id,
        kind: kind,
        label: label,
        parentId: parentId,
      );
      parentById[id] = parentId;
      if (parentId != null) {
        childIdsByParent.putIfAbsent(parentId, () => <EntityId>[]).add(id);
      }
    }

    final site = project.index.site(project.siteId)!;
    register(
      id: site.id,
      kind: ProjectNavigatorNodeKind.site,
      label: site.name,
      parentId: null,
    );

    final buildings = project.index.buildings.values.toList()
      ..sort(_compareBuildings);
    for (final building in buildings) {
      register(
        id: building.id,
        kind: ProjectNavigatorNodeKind.building,
        label: building.name,
        parentId: site.id,
      );

      final levels = project.index.levels.values
          .where((level) => level.buildingId == building.id)
          .toList()
        ..sort(_compareLevels);
      for (final level in levels) {
        register(
          id: level.id,
          kind: ProjectNavigatorNodeKind.level,
          label: level.name,
          parentId: building.id,
        );

        final zones = level.zoneIds
            .map(project.index.zone)
            .whereType<ProjectStructuralZoneEntity>()
            .toList()
          ..sort(_compareZones);
        for (final zone in zones) {
          register(
            id: zone.id,
            kind: ProjectNavigatorNodeKind.structuralZone,
            label: zone.name,
            parentId: level.id,
          );

          final zonedSpaces = zone.spaceIds
              .map(project.index.space)
              .whereType<ProjectSpaceEntity>()
              .toList()
            ..sort(_compareSpaces);
          for (final space in zonedSpaces) {
            register(
              id: space.id,
              kind: ProjectNavigatorNodeKind.space,
              label: space.name,
              parentId: zone.id,
            );
          }
        }

        final unzonedSpaces = level.spaceIds
            .where(
              (spaceId) =>
                  project.index.structuralZoneBySpace[spaceId] == null,
            )
            .map(project.index.space)
            .whereType<ProjectSpaceEntity>()
            .toList()
          ..sort(_compareSpaces);
        for (final space in unzonedSpaces) {
          register(
            id: space.id,
            kind: ProjectNavigatorNodeKind.space,
            label: space.name,
            parentId: level.id,
          );
        }
      }
    }

    final nodesById = <EntityId, ProjectNavigatorNode>{};
    for (final seed in nodeSeeds.values) {
      nodesById[seed.id] = ProjectNavigatorNode(
        id: seed.id,
        kind: seed.kind,
        label: seed.label,
        parentId: seed.parentId,
        childIds: childIdsByParent[seed.id] ?? const <EntityId>[],
      );
    }

    return ProjectNavigatorProjection._(
      rootSiteId: project.siteId,
      nodesById: nodesById,
      parentById: parentById,
    );
  }

  final SiteId rootSiteId;
  final Map<EntityId, ProjectNavigatorNode> nodesById;
  final Map<EntityId, EntityId?> parentById;

  ProjectNavigatorNode get root => nodesById[rootSiteId]!;

  ProjectNavigatorNode? node(EntityId id) => nodesById[id];

  /// Returns the root-to-node path through indexed parent links.
  ///
  /// Missing IDs fail closed instead of being rebound by name, level number or
  /// presentation position.
  List<ProjectNavigatorNode> pathTo(EntityId id) {
    if (!nodesById.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'Navigator node does not exist.');
    }

    final reversed = <ProjectNavigatorNode>[];
    EntityId? cursor = id;
    while (cursor != null) {
      final current = nodesById[cursor];
      if (current == null) {
        throw StateError('Navigator parent index is inconsistent at $cursor.');
      }
      reversed.add(current);
      cursor = parentById[cursor];
    }
    return List.unmodifiable(reversed.reversed);
  }

  /// Resolves the one canonical leaf represented by [navigation].
  EntityId currentLeafId(ProjectNavigationState navigation) {
    return navigation.selectedSpaceId ??
        navigation.selectedZoneId ??
        navigation.activeLevelId ??
        navigation.activeBuildingId ??
        navigation.siteId;
  }

  /// Breadcrumb and tree-current path are derived from the same source.
  List<ProjectBreadcrumbItem> breadcrumb(
    ProjectNavigationState navigation,
  ) {
    return List.unmodifiable(
      pathTo(currentLeafId(navigation)).map(
        (node) => ProjectBreadcrumbItem(
          id: node.id,
          kind: node.kind,
          label: node.label,
        ),
      ),
    );
  }

  /// Ancestors that must be expanded to reveal the active/selected leaf.
  ///
  /// The leaf itself is excluded because expansion is a container concern.
  Set<EntityId> requiredExpandedAncestorIds(
    ProjectNavigationState navigation,
  ) {
    final path = pathTo(currentLeafId(navigation));
    if (path.length <= 1) return const <EntityId>{};
    return Set.unmodifiable(path.take(path.length - 1).map((node) => node.id));
  }

  bool isActiveBuilding(
    ProjectNavigatorNode node,
    ProjectNavigationState navigation,
  ) =>
      node.id == navigation.activeBuildingId;

  bool isActiveLevel(
    ProjectNavigatorNode node,
    ProjectNavigationState navigation,
  ) =>
      node.id == navigation.activeLevelId;

  bool isSelected(
    ProjectNavigatorNode node,
    ProjectNavigationState navigation,
  ) =>
      node.id == navigation.selectedZoneId ||
      node.id == navigation.selectedSpaceId;
}

final class _NavigatorNodeSeed {
  const _NavigatorNodeSeed({
    required this.id,
    required this.kind,
    required this.label,
    required this.parentId,
  });

  final EntityId id;
  final ProjectNavigatorNodeKind kind;
  final String label;
  final EntityId? parentId;
}

int _compareBuildings(
  ProjectBuildingEntity left,
  ProjectBuildingEntity right,
) {
  final byOrder = left.displayOrder.compareTo(right.displayOrder);
  if (byOrder != 0) return byOrder;
  return left.id.value.compareTo(right.id.value);
}

int _compareLevels(ProjectLevelEntity left, ProjectLevelEntity right) {
  final byOrder = left.displayOrder.compareTo(right.displayOrder);
  if (byOrder != 0) return byOrder;
  final byNumber = left.levelNumber.compareTo(right.levelNumber);
  if (byNumber != 0) return byNumber;
  return left.id.value.compareTo(right.id.value);
}

int _compareZones(
  ProjectStructuralZoneEntity left,
  ProjectStructuralZoneEntity right,
) {
  final byLabel = left.name.compareTo(right.name);
  if (byLabel != 0) return byLabel;
  return left.id.value.compareTo(right.id.value);
}

int _compareSpaces(ProjectSpaceEntity left, ProjectSpaceEntity right) {
  final byLabel = left.name.compareTo(right.name);
  if (byLabel != 0) return byLabel;
  return left.id.value.compareTo(right.id.value);
}
