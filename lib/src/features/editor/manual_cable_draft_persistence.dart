import '../../domain/boundary_construction_transition_resolver.dart';
import '../../domain/cable_penetration_authoring.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/project_model.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surface_transition_graph.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'physical_manual_cable_draft_persistence.dart';
import 'port_driven_cable_authoring.dart';

extension ManualCableDraftPersistence on EditorController {
  /// Production manual-route commit boundary.
  ///
  /// The public API remains stable for SurfaceCanvas, but route construction is
  /// now delegated to the physical authoring flow. Every surface change must be
  /// proven by SurfaceTransitionGraph; canonical runtime additionally resolves
  /// wall thickness/material from BoundaryConstructionRegistry. A missing or
  /// conflicting physical construction therefore preserves the draft and
  /// rejects commit instead of creating a teleporting cable.
  bool finishManualCableDraft({int endpointSnapRadiusMm = 180}) {
    final routingContext =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(this);
    SurfaceTransitionCandidate? resolve(
      RoomSurfaceRef fromSurface,
      SurfacePointMm fromPoint,
      RoomSurfaceRef toSurface,
      SurfacePointMm toPoint,
    ) {
      final fromSpace = routingContext == null
          ? _spaceById(level, fromSurface.spaceId)
          : _spaceForRoutingSurface(level, fromSurface, routingContext);
      if (fromSpace == null) return null;

      if (routingContext != null) {
        return BoundaryConstructionTransitionResolver.resolve(
          level: level,
          fromSpace: fromSpace,
          fromSurface: fromSurface,
          fromPoint: fromPoint,
          toSurface: toSurface,
          toPoint: toPoint,
          constructions: routingContext.constructions,
          edgeOrderResolver: routingContext.edgeOrderForLegacySpace,
          canonicalSpaceIdResolver:
              routingContext.canonicalSpaceIdForSurfaceSpaceId,
        );
      }

      // Transitional/offline editor sessions have no canonical construction
      // registry. Ordinary same-room surface adjacency remains available,
      // while a physical wall crossing has no thickness evidence and is
      // consequently rejected by CablePenetrationAuthoring.
      for (final candidate in SurfaceTransitionGraph.candidates(
        level: level,
        fromSpace: fromSpace,
        fromSurface: fromSurface,
        point: fromPoint,
      )) {
        if (candidate.toSurface == toSurface &&
            candidate.toPoint == toPoint &&
            !candidate.requiresPenetration) {
          return candidate;
        }
      }
      return null;
    }

    if (hasPhysicalRouteContinuation) {
      return finishPhysicalRouteContinuation(
        endpointSnapRadiusMm: endpointSnapRadiusMm,
        resolveTransition: resolve,
      );
    }

    final binding = portDrivenCableStartBinding;
    if (binding != null) {
      return _finishPortDrivenCableDraft(
        controller: this,
        binding: binding,
        endpointSnapRadiusMm: endpointSnapRadiusMm,
        resolveTransition: resolve,
      );
    }

    return finishPhysicalManualCableDraft(
      endpointSnapRadiusMm: endpointSnapRadiusMm,
      resolveTransition: resolve,
    );
  }

  void cancelManualCableDraft({bool exitTool = false}) {
    clearPhysicalRouteContinuationIntent();
    clearPortDrivenCableStartBinding();
    if (routeSegments.isNotEmpty) clearRouteDraft();
    if (exitTool && tool == EditorTool.cableRoute) {
      setTool(EditorTool.select);
    }
  }
}

bool _finishPortDrivenCableDraft({
  required EditorController controller,
  required PortDrivenCableStartBinding binding,
  required int endpointSnapRadiusMm,
  required RouteTransitionResolver resolveTransition,
}) {
  if (endpointSnapRadiusMm <= 0 ||
      controller.p2.history.mutationRevision != binding.p2MutationRevision ||
      controller.routeSegments.isEmpty) {
    return false;
  }

  final component = _componentById(controller, binding.componentId);
  if (component == null) return false;
  final port = _portById(component, binding.portId);
  if (port == null || port.kind != binding.portKind) return false;

  final first = controller.routeSegments.first;
  if (first.points.isEmpty ||
      first.surface != component.surface ||
      first.points.first != component.position) {
    return false;
  }

  if (binding.role == PortDrivenCableEndpointRole.source) {
    final resolved = _nearestDraftEndpoint(
      components: controller.p2.components,
      surface: first.surface,
      point: first.points.first,
      role: PortDrivenCableEndpointRole.source,
      radiusMm: endpointSnapRadiusMm,
    );
    if (!_matchesBinding(resolved, binding)) return false;

    final committed = controller.finishPhysicalManualCableDraft(
      endpointSnapRadiusMm: endpointSnapRadiusMm,
      resolveTransition: resolveTransition,
    );
    if (committed) controller.clearPortDrivenCableStartBinding();
    return committed;
  }

  final last = controller.routeSegments.last;
  if (last.points.isEmpty) return false;
  final remoteSource = _nearestDraftEndpoint(
    components: controller.p2.components,
    surface: last.surface,
    point: last.points.last,
    role: PortDrivenCableEndpointRole.source,
    radiusMm: endpointSnapRadiusMm,
    excludeComponentId: component.id,
    counterpartKind: port.kind,
  );
  if (remoteSource == null) return false;

  final resolvedTarget = _nearestDraftEndpoint(
    components: controller.p2.components,
    surface: first.surface,
    point: first.points.first,
    role: PortDrivenCableEndpointRole.target,
    radiusMm: endpointSnapRadiusMm,
    counterpartKind: remoteSource.port.kind,
  );
  if (!_matchesBinding(resolvedTarget, binding)) return false;

  final drawingOrder = List<SurfaceRouteSegmentDraft>.of(
    controller.routeSegments,
  );
  controller.routeSegments
    ..clear()
    ..addAll([
      for (final segment in drawingOrder.reversed)
        SurfaceRouteSegmentDraft(
          surface: segment.surface,
          points: List.unmodifiable(segment.points.reversed),
        ),
    ]);

  final committed = controller.finishPhysicalManualCableDraft(
    endpointSnapRadiusMm: endpointSnapRadiusMm,
    resolveTransition: resolveTransition,
  );
  if (committed) {
    controller.clearPortDrivenCableStartBinding();
    return true;
  }

  controller.routeSegments
    ..clear()
    ..addAll(drawingOrder);
  // Restoring a failed target-first draft is presentation-only and must not
  // manufacture a P2 history mutation.
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  controller.notifyListeners();
  return false;
}

final class _DraftEndpoint {
  const _DraftEndpoint(this.component, this.port);

  final ElectricalComponentPlacement component;
  final ElectricalPortDefinition port;
}

_DraftEndpoint? _nearestDraftEndpoint({
  required Iterable<ElectricalComponentPlacement> components,
  required RoomSurfaceRef surface,
  required SurfacePointMm point,
  required PortDrivenCableEndpointRole role,
  required int radiusMm,
  String? excludeComponentId,
  ElectricalPortKind? counterpartKind,
}) {
  _DraftEndpoint? best;
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
        PortDrivenCableEndpointRole.source =>
          port.kind == ElectricalPortKind.powerOut ||
              port.kind == ElectricalPortKind.controlOut,
        PortDrivenCableEndpointRole.target =>
          port.kind == ElectricalPortKind.powerIn ||
              port.kind == ElectricalPortKind.controlIn,
      };
      if (!roleCompatible) continue;
      if (counterpartKind != null) {
        final compatible = role == PortDrivenCableEndpointRole.source
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
      best = _DraftEndpoint(component, port);
      bestDistanceSquared = distanceSquared;
      break;
    }
  }
  return best;
}

bool _matchesBinding(
  _DraftEndpoint? endpoint,
  PortDrivenCableStartBinding binding,
) =>
    endpoint != null &&
    endpoint.component.id == binding.componentId &&
    endpoint.port.id == binding.portId &&
    endpoint.port.kind == binding.portKind;

ElectricalComponentPlacement? _componentById(
  EditorController controller,
  String componentId,
) {
  for (final component in controller.p2.components) {
    if (component.id == componentId) return component;
  }
  return null;
}

ElectricalPortDefinition? _portById(
  ElectricalComponentPlacement component,
  String portId,
) {
  for (final port in component.ports) {
    if (port.id == portId) return port;
  }
  return null;
}

EngineeringSpace? _spaceForRoutingSurface(
  BuildingLevel level,
  RoomSurfaceRef surface,
  CanonicalPhysicalRoutingContext context,
) {
  final direct = _spaceById(level, surface.spaceId);
  if (direct != null) return direct;
  final canonicalSpaceId =
      context.canonicalSpaceIdForSurfaceSpaceId(surface.spaceId);
  if (canonicalSpaceId == null) return null;
  final legacySpaceId = context.legacySpaceIdForCanonical(canonicalSpaceId);
  return legacySpaceId == null ? null : _spaceById(level, legacySpaceId);
}

EngineeringSpace? _spaceById(BuildingLevel level, String spaceId) {
  for (final space in level.spaces) {
    if (space.id == spaceId) return space;
  }
  return null;
}
