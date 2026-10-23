import 'project_identity.dart';

/// Minimal canonical placement needed to establish physical storey order.
///
/// Presentation metadata such as levelNumber/displayOrder is intentionally not
/// part of this contract. P7 vertical topology must follow physical evidence.
final class PhysicalLevelPlacement {
  const PhysicalLevelPlacement({
    required this.levelId,
    required this.buildingId,
    required this.elevationMm,
  });

  final LevelId levelId;
  final BuildingId buildingId;
  final int elevationMm;
}

/// Directed canonical physical adjacency, normally derived from an inter-level
/// slab: [belowLevelId] -> [aboveLevelId].
final class PhysicalLevelAdjacency {
  const PhysicalLevelAdjacency({
    required this.buildingId,
    required this.belowLevelId,
    required this.aboveLevelId,
  });

  final BuildingId buildingId;
  final LevelId belowLevelId;
  final LevelId aboveLevelId;
}

/// Resolves one unique physical level order and fails closed on ambiguity.
///
/// Strict elevation differences establish ordering directly. Canonical slab
/// adjacency is used to disambiguate otherwise equal-elevation placements and
/// is also checked for contradictions. Presentation/insertion order is never a
/// tie breaker.
abstract final class PhysicalLevelOrder {
  static List<PhysicalLevelPlacement>? tryResolve(
    Iterable<PhysicalLevelPlacement> placements, {
    Iterable<PhysicalLevelAdjacency> adjacencies = const [],
  }) {
    final nodes = List<PhysicalLevelPlacement>.of(placements);
    if (nodes.isEmpty) return const [];

    final byId = <LevelId, PhysicalLevelPlacement>{};
    for (final placement in nodes) {
      if (byId.putIfAbsent(placement.levelId, () => placement) != placement) {
        return null;
      }
    }

    final outgoing = <LevelId, Set<LevelId>>{
      for (final placement in nodes) placement.levelId: <LevelId>{},
    };
    final indegree = <LevelId, int>{
      for (final placement in nodes) placement.levelId: 0,
    };

    void addEdge(LevelId from, LevelId to) {
      if (from == to) return;
      if (outgoing[from]!.add(to)) {
        indegree[to] = indegree[to]! + 1;
      }
    }

    // Elevation is canonical physical evidence whenever it is strict.
    for (var leftIndex = 0; leftIndex < nodes.length; leftIndex++) {
      final left = nodes[leftIndex];
      for (var rightIndex = leftIndex + 1;
          rightIndex < nodes.length;
          rightIndex++) {
        final right = nodes[rightIndex];
        if (left.buildingId != right.buildingId) return null;
        if (left.elevationMm < right.elevationMm) {
          addEdge(left.levelId, right.levelId);
        } else if (right.elevationMm < left.elevationMm) {
          addEdge(right.levelId, left.levelId);
        }
      }
    }

    // Slab topology may resolve an elevation tie, but may never contradict a
    // strict elevation relation or cross a building boundary.
    for (final adjacency in adjacencies) {
      final below = byId[adjacency.belowLevelId];
      final above = byId[adjacency.aboveLevelId];
      if (below == null || above == null) continue;
      if (adjacency.buildingId != below.buildingId ||
          adjacency.buildingId != above.buildingId ||
          below.elevationMm > above.elevationMm) {
        return null;
      }
      addEdge(adjacency.belowLevelId, adjacency.aboveLevelId);
    }

    final remaining = Set<LevelId>.of(byId.keys);
    final ordered = <PhysicalLevelPlacement>[];
    while (remaining.isNotEmpty) {
      final available = remaining.where((id) => indegree[id] == 0).toList();
      // More than one valid next node means physical order is still ambiguous.
      if (available.length != 1) return null;

      final next = available.single;
      remaining.remove(next);
      ordered.add(byId[next]!);
      for (final target in outgoing[next]!) {
        indegree[target] = indegree[target]! - 1;
      }
    }

    return List.unmodifiable(ordered);
  }

  /// Whether [selectedLevelIds] forms one uninterrupted physical range.
  ///
  /// Every selected level must exist in [orderedLevels]. All physical levels
  /// between the lowest and highest selected levels must also be selected.
  static bool isContiguousSelection({
    required List<PhysicalLevelPlacement> orderedLevels,
    required Set<LevelId> selectedLevelIds,
  }) {
    if (selectedLevelIds.isEmpty) return false;

    final indexes = <int>[];
    for (final levelId in selectedLevelIds) {
      final index = orderedLevels.indexWhere(
        (placement) => placement.levelId == levelId,
      );
      if (index < 0) return false;
      indexes.add(index);
    }
    indexes.sort();

    final first = indexes.first;
    final last = indexes.last;
    if (last - first + 1 != selectedLevelIds.length) return false;

    for (var index = first; index <= last; index++) {
      if (!selectedLevelIds.contains(orderedLevels[index].levelId)) {
        return false;
      }
    }
    return true;
  }
}
