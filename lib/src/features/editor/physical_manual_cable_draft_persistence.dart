import '../../domain/cable_penetration_authoring.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import '../../engine/port_snap_resolver.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'physical_cable_route_committer.dart';

final class _PhysicalManualEndpoint {
  const _PhysicalManualEndpoint(this.component, this.port);

  final ElectricalComponentPlacement component;
  final ElectricalPortDefinition port;
}

extension PhysicalManualCableDraftPersistence on EditorController {
  /// Commits the current manual cable draft as one physical route aggregate.
  ///
  /// Cross-surface transitions are never inferred from adjacency alone. The
  /// supplied resolver must prove each transition; wall/slab crossings must
  /// also provide construction thickness so CablePenetrationAuthoring can
  /// materialize BoundaryPenetration records before history commit.
  bool finishPhysicalManualCableDraft({
    required RouteTransitionResolver resolveTransition,
    String? routeId,
    int endpointSnapRadiusMm = 180,
  }) {
    if (tool != EditorTool.cableRoute ||
        routeSegments.isEmpty ||
        endpointSnapRadiusMm <= 0 ||
        !p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        p2.layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    if (routeSegments.any((segment) => segment.points.length < 2)) {
      return false;
    }

    final firstDraft = routeSegments.first;
    final lastDraft = routeSegments.last;
    final source = _nearestPhysicalEndpoint(
      components: p2.components,
      surface: firstDraft.surface,
      point: firstDraft.points.first,
      role: CableEndpointRole.source,
      radiusMm: endpointSnapRadiusMm,
    );
    if (source == null) return false;
    final target = _nearestPhysicalEndpoint(
      components: p2.components,
      surface: lastDraft.surface,
      point: lastDraft.points.last,
      role: CableEndpointRole.target,
      radiusMm: endpointSnapRadiusMm,
      excludeComponentId: source.component.id,
      counterpartKind: source.port.kind,
    );
    if (target == null) return false;

    final segments = <ElectricalRouteSegment>[];
    for (var index = 0; index < routeSegments.length; index++) {
      final draft = routeSegments[index];
      final points = List<SurfacePointMm>.of(draft.points);
      if (index == 0) points[0] = source.component.position;
      if (index == routeSegments.length - 1) {
        points[points.length - 1] = target.component.position;
      }
      segments.add(
        ElectricalRouteSegment(
          surface: draft.surface,
          points: List.unmodifiable(points),
        ),
      );
    }

    final resolvedRouteId = routeId?.trim().isNotEmpty == true
        ? routeId!.trim()
        : _nextPhysicalRouteId(p2.routes);
    ElectricalCableRoute route;
    try {
      route = CablePenetrationAuthoring.build(
        routeId: resolvedRouteId,
        source: ElectricalEndpointRef(
          componentId: source.component.id,
          portId: source.port.id,
        ),
        target: ElectricalEndpointRef(
          componentId: target.component.id,
          portId: target.port.id,
        ),
        segments: List.unmodifiable(segments),
        resolveTransition: resolveTransition,
        penetrationIdFactory: (transitionIndex, transition) =>
            '$resolvedRouteId:penetration:$transitionIndex',
      );
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }

    if (!p2.commitPhysicalCableRoute(route)) return false;
    clearRouteDraft();
    setTool(EditorTool.select);
    return true;
  }
}

String _nextPhysicalRouteId(Iterable<ElectricalCableRoute> routes) {
  final used = routes.map((route) => route.id).toSet();
  var sequence = 1;
  while (used.contains('route-$sequence')) {
    sequence++;
  }
  return 'route-$sequence';
}

_PhysicalManualEndpoint? _nearestPhysicalEndpoint({
  required Iterable<ElectricalComponentPlacement> components,
  required RoomSurfaceRef surface,
  required SurfacePointMm point,
  required CableEndpointRole role,
  required int radiusMm,
  String? excludeComponentId,
  ElectricalPortKind? counterpartKind,
}) {
  _PhysicalManualEndpoint? best;
  var bestDistanceSquared = radiusMm * radiusMm + 1;
  for (final component in components) {
    if (component.surface != surface || component.id == excludeComponentId) {
      continue;
    }
    final dx = component.position.xMm - point.xMm;
    final dy = component.position.yMm - point.yMm;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared > radiusMm * radiusMm ||
        distanceSquared >= bestDistanceSquared) {
      continue;
    }
    for (final port in component.ports) {
      final roleCompatible = switch (role) {
        CableEndpointRole.source => port.kind == ElectricalPortKind.powerOut ||
            port.kind == ElectricalPortKind.controlOut,
        CableEndpointRole.target => port.kind == ElectricalPortKind.powerIn ||
            port.kind == ElectricalPortKind.controlIn,
      };
      if (!roleCompatible) continue;
      if (counterpartKind != null) {
        final compatible = role == CableEndpointRole.source
            ? ElectricalPortCompatibility.areCompatible(
                port.kind,
                counterpartKind,
              )
            : ElectricalPortCompatibility.areCompatible(
                counterpartKind,
                port.kind,
              );
        if (!compatible) continue;
      }
      best = _PhysicalManualEndpoint(component, port);
      bestDistanceSquared = distanceSquared;
      break;
    }
  }
  return best;
}
