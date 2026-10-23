import 'project_identity.dart';

/// Minimal canonical placement needed to establish physical storey order.
///
/// Presentation metadata such as levelNumber/displayOrder is intentionally not
/// part of this contract. P7 vertical topology must follow physical elevation.
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

/// Resolves deterministic physical level order and fails closed on ambiguity.
abstract final class PhysicalLevelOrder {
  static List<PhysicalLevelPlacement>? tryResolve(
    Iterable<PhysicalLevelPlacement> placements,
  ) {
    final ordered = List<PhysicalLevelPlacement>.of(placements)
      ..sort((a, b) => a.elevationMm.compareTo(b.elevationMm));

    for (var index = 1; index < ordered.length; index++) {
      if (ordered[index - 1].elevationMm == ordered[index].elevationMm) {
        return null;
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
