import 'building_composition.dart';
import 'project_identity.dart';
import 'project_model.dart';
import 'slab_topology.dart';
import 'vertical_core_route_leg.dart';

/// Creates the hidden cable span *between* two consecutive slab crossings.
///
/// The cable length inside each slab is accounted for by the corresponding
/// BoundaryPenetration. The vertical core leg accounts only for the free
/// intermediate vertical run, without double-counting slab thickness.
abstract final class VerticalCoreRouteLegAuthoring {
  static VerticalCoreRouteLeg betweenAdjacentSlabs({
    required VerticalCore core,
    required ProjectSlab lowerSlab,
    required ProjectSlab upperSlab,
    required BuildingLevel lowerLevel,
    required BuildingLevel intermediateLevel,
    required BuildingLevel upperLevel,
    required int lowerRoomHeightMm,
    required int lowerLevelNumber,
    required int intermediateLevelNumber,
    required int upperLevelNumber,
    required int intermediateRoomHeightMm,
  }) {
    if (core.kind != VerticalCoreKind.electricalRiser &&
        core.kind != VerticalCoreKind.cableRiser &&
        core.kind != VerticalCoreKind.serviceShaft) {
      throw ArgumentError('VerticalCore must be a cable-capable riser or shaft.');
    }
    if (lowerRoomHeightMm <= 0 || intermediateRoomHeightMm <= 0) {
      throw ArgumentError('Room heights must be positive.');
    }
    if (lowerLevelNumber + 1 != intermediateLevelNumber ||
        intermediateLevelNumber + 1 != upperLevelNumber ||
        !core.servedLevelNumbers.contains(lowerLevelNumber) ||
        !core.servedLevelNumbers.contains(intermediateLevelNumber) ||
        !core.servedLevelNumbers.contains(upperLevelNumber)) {
      throw ArgumentError('Riser must serve three consecutive level numbers.');
    }
    if (lowerSlab.kind != SlabKind.interLevel ||
        upperSlab.kind != SlabKind.interLevel ||
        lowerSlab.id == upperSlab.id ||
        lowerSlab.buildingId != upperSlab.buildingId ||
        lowerSlab.aboveLevelId?.value != intermediateLevel.id ||
        upperSlab.belowLevelId?.value != intermediateLevel.id ||
        lowerSlab.belowLevelId?.value != lowerLevel.id ||
        upperSlab.aboveLevelId?.value != upperLevel.id) {
      throw ArgumentError('Slabs must enclose the same intermediate level.');
    }
    if (lowerSlab.bottomElevationMm !=
            lowerLevel.elevationMm + lowerRoomHeightMm ||
        lowerSlab.topElevationMm != intermediateLevel.elevationMm ||
        upperSlab.bottomElevationMm !=
            intermediateLevel.elevationMm + intermediateRoomHeightMm ||
        upperSlab.topElevationMm != upperLevel.elevationMm) {
      throw ArgumentError('Slab elevations do not match intermediate room Z.');
    }
    final lengthMm =
        upperSlab.bottomElevationMm - lowerSlab.topElevationMm;
    if (lengthMm <= 0) {
      throw ArgumentError('Vertical run between slabs must be positive.');
    }
    return VerticalCoreRouteLeg(
      verticalCoreId: VerticalCoreId(core.id),
      fromSlabId: lowerSlab.id,
      toSlabId: upperSlab.id,
      lengthMm: lengthMm,
    );
  }
}
