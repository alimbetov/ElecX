import 'electrical_routing.dart';
import 'project_identity.dart';
import 'route_medium.dart';
import 'surfaces.dart';
import 'vertical_core_route_authoring.dart';

/// Exact editor-surface materialization for one planned VerticalCore slab
/// crossing. [slabId] is repeated intentionally so stale/reordered UI state is
/// rejected instead of being matched by list position alone.
final class VerticalCoreRouteCrossingMaterialization {
  const VerticalCoreRouteCrossingMaterialization({
    required this.slabId,
    required this.penetrationId,
    required this.entrySurface,
    required this.entryPoint,
    required this.exitSurface,
    required this.exitPoint,
  });

  final SlabId slabId;
  final String penetrationId;
  final RoomSurfaceRef entrySurface;
  final SurfacePointMm entryPoint;
  final RoomSurfaceRef exitSurface;
  final SurfacePointMm exitPoint;
}

/// Materializes one already-proven multi-level riser plan into the canonical
/// physical cable-route aggregate.
///
/// This intentionally does not infer rooms or surfaces from the core footprint.
/// Every crossing must be supplied by the editor after canonical navigation has
/// resolved the exact source/target SpaceId surfaces for that level pair.
abstract final class VerticalCoreCableRouteAuthoring {
  static ElectricalCableRoute build({
    required VerticalCoreRouteAuthoringPlan plan,
    required String routeId,
    required ElectricalEndpointRef source,
    required ElectricalEndpointRef target,
    required List<ElectricalRouteSegment> segments,
    required List<VerticalCoreRouteCrossingMaterialization> crossings,
    String? cableType,
    RouteMediumProfile medium = RouteMediumProfile.generic,
    int reservePercent = 5,
  }) {
    if (crossings.length != plan.crossings.length) {
      throw StateError(
        'VerticalCore route requires ${plan.crossings.length} slab '
        'materializations; received ${crossings.length}.',
      );
    }

    final penetrationIds = <String>{};
    final penetrations = <dynamic>[];
    for (var index = 0; index < plan.crossings.length; index++) {
      final planned = plan.crossings[index];
      final materialized = crossings[index];
      if (planned.verticalCoreId != plan.verticalCoreId ||
          materialized.slabId != planned.slabId) {
        throw StateError(
          'VerticalCore crossing $index does not match the planned SlabId '
          '${planned.slabId}.',
        );
      }
      final penetrationId = materialized.penetrationId.trim();
      if (penetrationId.isEmpty || !penetrationIds.add(penetrationId)) {
        throw StateError(
          'VerticalCore crossing penetration identities must be non-empty and '
          'unique.',
        );
      }
      penetrations.add(
        planned.createPenetration(
          penetrationId: penetrationId,
          routeId: routeId,
          entrySurface: materialized.entrySurface,
          entryPoint: materialized.entryPoint,
          exitSurface: materialized.exitSurface,
          exitPoint: materialized.exitPoint,
        ),
      );
    }

    return ElectricalCableRoute(
      id: routeId,
      source: source,
      target: target,
      segments: List.unmodifiable(segments),
      penetrations: List.unmodifiable(penetrations.cast()),
      verticalCoreLegs: plan.verticalLegs,
      cableType: cableType,
      medium: medium,
      reservePercent: reservePercent,
    );
  }
}
