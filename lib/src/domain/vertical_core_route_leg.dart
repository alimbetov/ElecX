import 'project_identity.dart';

/// Hidden physical cable run inside one stable riser/shaft between two
/// consecutive slab penetrations.
///
/// Slab thickness is deliberately excluded because it is already owned by the
/// physical penetration entities. This leg contributes only the vertical run
/// between those physical slab boundaries.
final class VerticalCoreRouteLeg {
  VerticalCoreRouteLeg({
    required this.verticalCoreId,
    required this.fromSlabId,
    required this.toSlabId,
    required this.lengthMm,
  }) {
    if (fromSlabId == toSlabId) {
      throw ArgumentError(
        'VerticalCore route leg must connect two different SlabId values.',
      );
    }
    if (lengthMm < 0) {
      throw ArgumentError.value(
        lengthMm,
        'lengthMm',
        'VerticalCore route leg length must be non-negative.',
      );
    }
  }

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
