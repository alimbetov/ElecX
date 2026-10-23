import 'boundary_penetration.dart';
import 'electrical_routing.dart';
import 'project_identity.dart';
import 'route_medium.dart';
import 'surface_transition_graph.dart';
import 'surfaces.dart';

typedef RouteTransitionResolver = SurfaceTransitionCandidate? Function(
  RoomSurfaceRef fromSurface,
  SurfacePointMm fromPoint,
  RoomSurfaceRef toSurface,
  SurfacePointMm toPoint,
);

typedef PenetrationIdFactory = BoundaryPenetrationId Function(
  int transitionIndex,
  SurfaceTransitionCandidate transition,
);

/// Builds one physical route aggregate from visible surface segments.
///
/// Every change of surface must be resolved explicitly. Cross-space/slab
/// transitions that require a physical opening are materialized into
/// [BoundaryPenetration] before the route is constructed. Missing transition
/// evidence or missing construction thickness rejects the whole operation.
abstract final class CablePenetrationAuthoring {
  static ElectricalCableRoute build({
    required String routeId,
    required ElectricalEndpointRef source,
    required ElectricalEndpointRef target,
    required List<ElectricalRouteSegment> segments,
    required RouteTransitionResolver resolveTransition,
    required PenetrationIdFactory penetrationIdFactory,
    String? cableType,
    RouteMediumProfile medium = RouteMediumProfile.generic,
    int reservePercent = 5,
  }) {
    if (routeId.trim().isEmpty) {
      throw ArgumentError('routeId must be non-empty.');
    }
    if (segments.isEmpty) {
      throw ArgumentError('A physical route requires at least one segment.');
    }
    if (segments.any((segment) => segment.points.length < 2)) {
      throw ArgumentError('Every route segment requires at least two points.');
    }

    final penetrations = <BoundaryPenetration>[];
    final penetrationIds = <BoundaryPenetrationId>{};
    for (var index = 0; index + 1 < segments.length; index++) {
      final before = segments[index];
      final after = segments[index + 1];
      if (before.surface == after.surface) {
        if (before.points.last != after.points.first) {
          throw StateError(
            'Adjacent segments on ${before.surface.id} are not contiguous.',
          );
        }
        continue;
      }

      final transition = resolveTransition(
        before.surface,
        before.points.last,
        after.surface,
        after.points.first,
      );
      if (transition == null) {
        throw StateError(
          'No physical transition evidence for ${before.surface.id} -> '
          '${after.surface.id}.',
        );
      }
      _requireExactTransition(transition, before, after);
      if (!transition.requiresPenetration) continue;

      final penetrationId = penetrationIdFactory(index, transition);
      if (penetrationId.trim().isEmpty) {
        throw StateError('Penetration id factory returned an empty id.');
      }
      if (!penetrationIds.add(penetrationId)) {
        throw StateError('Duplicate penetration id $penetrationId.');
      }
      penetrations.add(
        transition.createPenetration(
          penetrationId: penetrationId,
          routeId: routeId,
        ),
      );
    }

    return ElectricalCableRoute(
      id: routeId,
      source: source,
      target: target,
      segments: List.unmodifiable(segments),
      penetrations: List.unmodifiable(penetrations),
      cableType: cableType,
      medium: medium,
      reservePercent: reservePercent,
    );
  }

  static void _requireExactTransition(
    SurfaceTransitionCandidate transition,
    ElectricalRouteSegment before,
    ElectricalRouteSegment after,
  ) {
    if (transition.fromSurface != before.surface ||
        transition.fromPoint != before.points.last ||
        transition.toSurface != after.surface ||
        transition.toPoint != after.points.first) {
      throw StateError(
        'Transition ${transition.id} does not match the adjacent route '
        'segment endpoints exactly.',
      );
    }
  }
}
