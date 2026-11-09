import 'building_composition.dart';
import 'electrical_routing.dart';
import 'geometry.dart';
import 'project_identity.dart';
import 'slab_topology.dart';
import 'surfaces.dart';
import 'vertical_core_route_leg_authoring.dart';

enum EngineeringRouteQualificationStatus {
  valid,
  stale,
  blocked,
  requiresReview,
}

final class EngineeringRouteQualificationResult {
  const EngineeringRouteQualificationResult({
    required this.routeId,
    required this.status,
    required this.reason,
  });

  final String routeId;
  final EngineeringRouteQualificationStatus status;
  final String reason;
}

/// Independent, non-mutating check of persisted multi-level riser legs.
///
/// The project document currently persists building levels and VerticalCore
/// owners, but not the canonical ProjectSlab registry. Callers MUST supply the
/// current slab evidence; missing evidence never qualifies a route as valid.
/// Other types of route (wall-only / single slab) require separate validators.
abstract final class EngineeringRouteQualificationService {
  static EngineeringRouteQualificationResult qualifyVerticalCoreRoute({
    required ElectricalCableRoute route,
    required ComposedBuilding building,
    required Map<SlabId, ProjectSlab> canonicalSlabs,
    required Map<String, int> roomHeightsByLevelId,
  }) {
    EngineeringRouteQualificationResult result(
      EngineeringRouteQualificationStatus status,
      String reason,
    ) =>
        EngineeringRouteQualificationResult(
          routeId: route.id,
          status: status,
          reason: reason,
        );

    if (route.verticalCoreLegs.isEmpty) {
      return result(
        EngineeringRouteQualificationStatus.requiresReview,
        'No vertical riser leg: other route validators are required.',
      );
    }
    for (final leg in route.verticalCoreLegs) {
      final lowerSlab = canonicalSlabs[leg.fromSlabId];
      final upperSlab = canonicalSlabs[leg.toSlabId];
      if (lowerSlab == null || upperSlab == null) {
        return result(
          EngineeringRouteQualificationStatus.requiresReview,
          'Canonical ProjectSlab evidence is missing.',
        );
      }

      final matches = building.verticalCores
          .where((candidate) => candidate.id == leg.verticalCoreId.value)
          .toList(growable: false);
      if (matches.length != 1) {
        return result(
          EngineeringRouteQualificationStatus.blocked,
          'VerticalCore ownership is missing or ambiguous.',
        );
      }
      final intermediate = building.levels
          .where((item) => item.level.id == lowerSlab.aboveLevelId?.value)
          .toList(growable: false);
      final lower = building.levels
          .where((item) => item.level.id == lowerSlab.belowLevelId?.value)
          .toList(growable: false);
      final upper = building.levels
          .where((item) => item.level.id == upperSlab.aboveLevelId?.value)
          .toList(growable: false);
      if (intermediate.length != 1 || lower.length != 1 || upper.length != 1) {
        return result(
          EngineeringRouteQualificationStatus.stale,
          'Referenced canonical levels no longer exist.',
        );
      }
      final lowerHeight = roomHeightsByLevelId[lower.single.level.id];
      final middleHeight = roomHeightsByLevelId[intermediate.single.level.id];
      if (lowerHeight == null || middleHeight == null) {
        return result(
          EngineeringRouteQualificationStatus.requiresReview,
          'Room height evidence is missing.',
        );
      }

      final firstPassage = route.penetrations.where(
        (p) =>
            p.slabId == lowerSlab.id && p.verticalCoreId == leg.verticalCoreId,
      );
      final secondPassage = route.penetrations.where(
        (p) =>
            p.slabId == upperSlab.id && p.verticalCoreId == leg.verticalCoreId,
      );
      if (firstPassage.length != 1 || secondPassage.length != 1) {
        return result(
          EngineeringRouteQualificationStatus.blocked,
          'Exactly two core-owned slab passages are required.',
        );
      }
      final lowerPassage = firstPassage.single;
      final upperPassage = secondPassage.single;
      if (lowerPassage.hostThicknessMm != lowerSlab.thicknessMm ||
          lowerPassage.materialId != lowerSlab.materialId ||
          upperPassage.hostThicknessMm != upperSlab.thicknessMm ||
          upperPassage.materialId != upperSlab.materialId ||
          lowerPassage.entryAnchor.surface.type != SurfacePlaneType.ceiling ||
          lowerPassage.exitAnchor.surface.type != SurfacePlaneType.floor ||
          upperPassage.entryAnchor.surface.type != SurfacePlaneType.ceiling ||
          upperPassage.exitAnchor.surface.type != SurfacePlaneType.floor ||
          !lower.single.level.spaces.any(
            (space) => space.id == lowerPassage.entryAnchor.surface.spaceId,
          ) ||
          !intermediate.single.level.spaces.any(
            (space) =>
                space.id == lowerPassage.exitAnchor.surface.spaceId &&
                space.id == upperPassage.entryAnchor.surface.spaceId,
          ) ||
          !upper.single.level.spaces.any(
            (space) => space.id == upperPassage.exitAnchor.surface.spaceId,
          )) {
        return result(
          EngineeringRouteQualificationStatus.stale,
          'Slab passage construction or floor/ceiling owner has changed.',
        );
      }
      MmPoint? globalPlanPoint(
        ComposedBuildingLevel level,
        String spaceId,
        SurfacePointMm local,
      ) {
        for (final space in level.level.spaces) {
          if (space.id == spaceId) {
            final bounds = space.boundary.bounds;
            return MmPoint(
              bounds.left + local.xMm,
              bounds.bottom + local.yMm,
            );
          }
        }
        return null;
      }

      final planPoints = [
        globalPlanPoint(
          lower.single,
          lowerPassage.entryAnchor.surface.spaceId,
          lowerPassage.entryAnchor.point,
        ),
        globalPlanPoint(
          intermediate.single,
          lowerPassage.exitAnchor.surface.spaceId,
          lowerPassage.exitAnchor.point,
        ),
        globalPlanPoint(
          intermediate.single,
          upperPassage.entryAnchor.surface.spaceId,
          upperPassage.entryAnchor.point,
        ),
        globalPlanPoint(
          upper.single,
          upperPassage.exitAnchor.surface.spaceId,
          upperPassage.exitAnchor.point,
        ),
      ];
      if (planPoints.any((point) => point == null) ||
          planPoints.any((point) => point != planPoints.first)) {
        return result(
          EngineeringRouteQualificationStatus.stale,
          'Slab penetrations are no longer co-linear in global building XY.',
        );
      }
      final firstPoint = firstPassage.single.exitAnchor.point;
      final secondPoint = secondPassage.single.entryAnchor.point;
      if (firstPoint != secondPoint) {
        return result(
          EngineeringRouteQualificationStatus.blocked,
          'VerticalCore slab penetration anchors are not co-linear.',
        );
      }
      final middleSpaceId = firstPassage.single.exitAnchor.surface.spaceId;
      final intermediateSpace = intermediate.single.level.spaces
          .where((space) => space.id == middleSpaceId)
          .toList(growable: false);
      if (intermediateSpace.length != 1) {
        return result(
          EngineeringRouteQualificationStatus.stale,
          'Intermediate route space is not in the current building.',
        );
      }
      final bounds = intermediateSpace.single.boundary.bounds;
      final point = MmPoint(
        bounds.left + firstPoint.xMm,
        bounds.bottom + firstPoint.yMm,
      );
      try {
        VerticalCoreRouteLegAuthoring.validatePersisted(
          leg: leg,
          core: matches.single,
          penetrationPlanPoint: point,
          lowerSlab: lowerSlab,
          upperSlab: upperSlab,
          lowerLevel: lower.single.level,
          intermediateLevel: intermediate.single.level,
          upperLevel: upper.single.level,
          lowerRoomHeightMm: lowerHeight,
          lowerLevelNumber: lower.single.levelNumber,
          intermediateLevelNumber: intermediate.single.levelNumber,
          upperLevelNumber: upper.single.levelNumber,
          intermediateRoomHeightMm: middleHeight,
        );
      } on ArgumentError {
        return result(
          EngineeringRouteQualificationStatus.stale,
          'Route no longer matches canonical building geometry.',
        );
      } on StateError {
        return result(
          EngineeringRouteQualificationStatus.stale,
          'Stored core length or identity differs from canonical evidence.',
        );
      }
    }
    return result(
      EngineeringRouteQualificationStatus.valid,
      'All vertical riser legs match canonical slab and core evidence.',
    );
  }
}
