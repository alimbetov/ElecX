import 'canonical_slab_route_handoff.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';

/// Proven vertical geometry for one canonical ceiling↔floor slab handoff.
///
/// The evidence deliberately keeps both room heights explicit. The current
/// legacy editor model does not own a durable room-height scalar, so production
/// cross-level authoring must supply measured/materialized heights instead of
/// silently assuming the historical 3000 mm default.
final class CanonicalSlabVerticalEvidence {
  const CanonicalSlabVerticalEvidence({
    required this.slabId,
    required this.fromLevelId,
    required this.toLevelId,
    required this.fromLevelElevationMm,
    required this.toLevelElevationMm,
    required this.fromRoomHeightMm,
    required this.toRoomHeightMm,
    required this.physicalGapMm,
    required this.slabThicknessMm,
  });

  final SlabId slabId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final int fromLevelElevationMm;
  final int toLevelElevationMm;
  final int fromRoomHeightMm;
  final int toRoomHeightMm;
  final int physicalGapMm;
  final int slabThicknessMm;
}

/// Validates the Z-axis evidence needed before an editor level switch can be
/// considered a physical ceiling↔floor continuation.
abstract final class CanonicalSlabVerticalEvidenceResolver {
  static CanonicalSlabVerticalEvidence? resolve({
    required ProjectAggregateRoot project,
    required CanonicalSlabRouteHandoffPlan plan,
    required int fromLevelElevationMm,
    required int toLevelElevationMm,
    required int fromRoomHeightMm,
    required int toRoomHeightMm,
    int verticalToleranceMm = 2,
  }) {
    if (fromRoomHeightMm <= 0 || toRoomHeightMm <= 0) return null;
    if (verticalToleranceMm < 0) {
      throw ArgumentError.value(
        verticalToleranceMm,
        'verticalToleranceMm',
        'Must be non-negative.',
      );
    }

    final slab = project.index.slab(plan.slabId);
    final fromLevel = project.index.level(plan.fromLevelId);
    final toLevel = project.index.level(plan.toLevelId);
    if (slab == null || fromLevel == null || toLevel == null) return null;
    if (slab.id != plan.slab.id ||
        slab.belowLevelId != plan.slab.belowLevelId ||
        slab.aboveLevelId != plan.slab.aboveLevelId) {
      return null;
    }

    if ((fromLevel.elevationMm - fromLevelElevationMm).abs() >
            verticalToleranceMm ||
        (toLevel.elevationMm - toLevelElevationMm).abs() >
            verticalToleranceMm) {
      return null;
    }

    final isUpward = plan.isUpward;
    final lowerLevelElevationMm =
        isUpward ? fromLevelElevationMm : toLevelElevationMm;
    final lowerRoomHeightMm = isUpward ? fromRoomHeightMm : toRoomHeightMm;
    final upperLevelElevationMm =
        isUpward ? toLevelElevationMm : fromLevelElevationMm;

    final lowerCeilingElevationMm = lowerLevelElevationMm + lowerRoomHeightMm;
    if ((lowerCeilingElevationMm - slab.bottomElevationMm).abs() >
        verticalToleranceMm) {
      return null;
    }
    if ((upperLevelElevationMm - slab.topElevationMm).abs() >
        verticalToleranceMm) {
      return null;
    }

    final physicalGapMm = upperLevelElevationMm - lowerCeilingElevationMm;
    if (physicalGapMm <= 0 ||
        (physicalGapMm - slab.thicknessMm).abs() > verticalToleranceMm) {
      return null;
    }

    return CanonicalSlabVerticalEvidence(
      slabId: slab.id,
      fromLevelId: plan.fromLevelId,
      toLevelId: plan.toLevelId,
      fromLevelElevationMm: fromLevelElevationMm,
      toLevelElevationMm: toLevelElevationMm,
      fromRoomHeightMm: fromRoomHeightMm,
      toRoomHeightMm: toRoomHeightMm,
      physicalGapMm: physicalGapMm,
      slabThicknessMm: slab.thicknessMm,
    );
  }
}
