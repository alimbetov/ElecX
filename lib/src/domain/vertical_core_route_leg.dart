import 'project_identity.dart';

/// Hidden physical cable run inside one stable riser/shaft between two
/// consecutive slab penetrations.
///
/// Slab thickness is deliberately excluded: it is already owned by the two
/// [BoundaryPenetration] entities. This leg contributes only the vertical run
/// between those physical slab boundaries.
final class VerticalCoreRouteLeg {
  const VerticalCoreRouteLeg({
    required this.verticalCoreId,
    required this.fromSlabId,
    required this.toSlabId,
    required this.lengthMm,
  }) : assert(lengthMm >= 0);

  final VerticalCoreId verticalCoreId;
  final SlabId fromSlabId;
  final SlabId toSlabId;
  final int lengthMm;

  @override
  bool operator ==(Object other) =>
      other is VerticalCoreRouteLeg &&
      other.verticalCoreId == verticalCoreId &&
      other.fromSlabId == fromSlabId &&
      other.toSlabId == toSlabId &&
      other.lengthMm == lengthMm;

  @override
  int get hashCode =>
      Object.hash(verticalCoreId, fromSlabId, toSlabId, lengthMm);
}
