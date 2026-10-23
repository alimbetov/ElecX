import '../../domain/boundary_penetration.dart';
import '../../domain/cable_penetration_authoring.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/port_snap_resolver.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'multi_level_route_normative_context.dart';
import 'physical_cable_route_committer.dart';
import 'route_selection_session.dart';
import 'surface_transition_navigator.dart';

final class _PhysicalManualEndpoint {
  const _PhysicalManualEndpoint(this.component, this.port);

  final ElectricalComponentPlacement component;
  final ElectricalPortDefinition port;
}

final class _PhysicalRouteContinuationIntent {
  const _PhysicalRouteContinuationIntent({
    required this.route,
    required this.p2MutationRevision,
    required this.canonicalSessionIdentity,
    required this.canonicalProjectVersion,
  });

  final ElectricalCableRoute route;
  final int p2MutationRevision;
  final Object? canonicalSessionIdentity;
  final int? canonicalProjectVersion;
}

final Expando<_PhysicalRouteContinuationIntent> _continuationIntents =
    Expando<_PhysicalRouteContinuationIntent>(
        'ElecX physical route continuation');

extension PhysicalManualCableDraftPersistence on EditorController {
  bool get hasPhysicalRouteContinuation => _continuationIntents[this] != null;

  String? get physicalRouteContinuationId =>
      _continuationIntents[this]?.route.id;

  /// Starts an edit draft at the current target of an already committed route.
  ///
  /// The committed aggregate is not changed here. The exact P2 revision and,
  /// when present, exact canonical authoring session/version are captured and
  /// must still match on finish. A stale continuation therefore cannot publish
  /// into a replacement document session.
  bool beginPhysicalRouteContinuation(String routeId) {
    final normalizedId = routeId.trim();
    if (normalizedId.isEmpty ||
        routeSegments.isNotEmpty ||
        hasPhysicalRouteContinuation ||
        p2.isManipulating ||
        !p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        p2.layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }

    ElectricalCableRoute? route;
    for (final candidate in p2.routes) {
      if (candidate.id == normalizedId) {
        route = candidate;
        break;
      }
    }
    if (route == null ||
        route.segments.isEmpty ||
        route.segments.last.points.isEmpty ||
        !ElectricalConnectivityValidator.routeIsConnected(
          route: route,
          components: p2.components,
        ) ||
        !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
          route: route,
          components: p2.components,
        )) {
      return false;
    }

    final lastSegment = route.segments.last;
    final continuationPoint = lastSegment.points.last;
    if (!SurfaceTransitionNavigator.navigate(this, lastSegment.surface)) {
      return false;
    }
    final draftSurface = activeSurface;
    if (draftSurface == null) return false;

    final canonicalSession =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(this)?.session;
    setTool(EditorTool.cableRoute);
    _continuationIntents[this] = _PhysicalRouteContinuationIntent(
      route: route,
      p2MutationRevision: p2.history.mutationRevision,
      canonicalSessionIdentity: canonicalSession,
      canonicalProjectVersion: canonicalSession?.project.version.value,
    );
    routeSegments.add(
      SurfaceRouteSegmentDraft(
        surface: draftSurface,
        points: [continuationPoint],
      ),
    );
    routeSelection.select(route.id);
    // The draft list belongs to EditorController and is intentionally outside
    // P2 history. Notify presentation listeners without manufacturing a P2
    // mutation; Cancel must therefore remain revision-neutral.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
    return true;
  }

  /// Clears only the continuation intent. The caller owns draft/tool cleanup.
  void clearPhysicalRouteContinuationIntent() {
    _continuationIntents[this] = null;
  }

  /// Commits a continuation by replacing the original aggregate with the same
  /// route id in one P2 history command.
  ///
  /// The extension preserves the original route's surface-identity regime. A
  /// legacy route remains legacy. A canonical route converts transient canvas
  /// ordinals back to canonical SpaceId/BoundaryEdgeId immediately before the
  /// durable aggregate is constructed.
  bool finishPhysicalRouteContinuation({
    required RouteTransitionResolver resolveTransition,
    int endpointSnapRadiusMm = 180,
  }) {
    final intent = _continuationIntents[this];
    if (intent == null ||
        tool != EditorTool.cableRoute ||
        routeSegments.isEmpty ||
        endpointSnapRadiusMm <= 0 ||
        p2.history.mutationRevision != intent.p2MutationRevision ||
        !p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        p2.layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }

    final canonicalSession =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(this)?.session;
    if (!identical(canonicalSession, intent.canonicalSessionIdentity) ||
        canonicalSession?.project.version.value !=
            intent.canonicalProjectVersion) {
      return false;
    }

    ElectricalCableRoute? current;
    for (final candidate in p2.routes) {
      if (candidate.id == intent.route.id) {
        current = candidate;
        break;
      }
    }
    if (!identical(current, intent.route)) return false;

    final before = intent.route;
    final firstDraft = routeSegments.first;
    final lastDraft = routeSegments.last;
    final beforeLast = before.segments.last;
    final routingContext =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(this);
    final canonicalIdentity =
        _usesCanonicalSurfaceIdentity(beforeLast.surface, routingContext);
    final firstRouteSurface = _surfaceForRouteIdentity(
      firstDraft.surface,
      routingContext,
      canonicalIdentity: canonicalIdentity,
    );
    if (firstRouteSurface == null ||
        firstRouteSurface != beforeLast.surface ||
        firstDraft.points.isEmpty ||
        firstDraft.points.first != beforeLast.points.last) {
      return false;
    }

    final sourcePort = ElectricalPortCompatibility.portForEndpoint(
      endpoint: before.source,
      components: p2.components,
    );
    if (sourcePort == null) return false;
    final target = _nearestPhysicalEndpoint(
      components: p2.components,
      surface: lastDraft.surface,
      point: lastDraft.points.last,
      role: CableEndpointRole.target,
      radiusMm: endpointSnapRadiusMm,
      excludeComponentId: before.source.componentId,
      counterpartKind: sourcePort.kind,
      routingContext: routingContext,
      canonicalIdentity: canonicalIdentity,
    );
    if (target == null ||
        (target.component.id == before.target.componentId &&
            target.port.id == before.target.portId)) {
      return false;
    }

    final extensionSegments = <ElectricalRouteSegment>[];
    for (var index = 0; index < routeSegments.length; index++) {
      final draft = routeSegments[index];
      if (draft.points.isEmpty) return false;
      // The first draft point is the already committed route endpoint. A
      // one-point first segment carries no visible extension and is omitted so
      // we do not manufacture a zero-length durable segment.
      if (index == 0 && draft.points.length == 1) continue;
      if (draft.points.length < 2) return false;
      final routeSurface = _surfaceForRouteIdentity(
        draft.surface,
        routingContext,
        canonicalIdentity: canonicalIdentity,
      );
      if (routeSurface == null) return false;
      extensionSegments.add(
        ElectricalRouteSegment(
          surface: routeSurface,
          points: List.unmodifiable(draft.points),
          anchorIds: canonicalSession == null
              ? const []
              : List.unmodifiable([
                  for (final _ in draft.points)
                    canonicalSession.allocateRouteAnchorId(),
                ]),
        ),
      );
    }
    if (extensionSegments.isEmpty) return false;

    final segments = <ElectricalRouteSegment>[
      ...before.segments,
      ...extensionSegments,
    ];
    final penetrations = <BoundaryPenetration>[...before.penetrations];
    final penetrationIds = penetrations.map((item) => item.id).toSet();
    var penetrationSequence = penetrations.length;
    final firstNewTransitionIndex = before.segments.length - 1;
    try {
      for (var index = firstNewTransitionIndex;
          index + 1 < segments.length;
          index++) {
        final from = segments[index];
        final to = segments[index + 1];
        if (from.points.isEmpty || to.points.isEmpty) return false;
        if (from.surface == to.surface) {
          if (from.points.last != to.points.first) return false;
          continue;
        }
        final transition = resolveTransition(
          from.surface,
          from.points.last,
          to.surface,
          to.points.first,
        );
        if (transition == null ||
            transition.fromSurface != from.surface ||
            transition.fromPoint != from.points.last ||
            transition.toSurface != to.surface ||
            transition.toPoint != to.points.first) {
          return false;
        }
        if (!transition.requiresPenetration) continue;

        String penetrationId;
        do {
          penetrationId = '${before.id}:penetration:$penetrationSequence';
          penetrationSequence++;
        } while (penetrationIds.contains(penetrationId));
        penetrationIds.add(penetrationId);
        penetrations.add(
          transition.createPenetration(
            penetrationId: penetrationId,
            routeId: before.id,
          ),
        );
      }
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }

    ElectricalCableRoute after;
    try {
      after = before.copyWith(
        target: ElectricalEndpointRef(
          componentId: target.component.id,
          portId: target.port.id,
        ),
        segments: List.unmodifiable(segments),
        penetrations: List.unmodifiable(penetrations),
      );
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }

    if (!p2.replacePhysicalCableRoute(
      before: before,
      after: after,
      geometryValidator: (route) => _routeGeometryIsValidForContinuation(
        this,
        route,
        routingContext,
      ),
    )) {
      return false;
    }
    _continuationIntents[this] = null;
    clearRouteDraft();
    setTool(EditorTool.select);
    return true;
  }

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

    final canonicalSession =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(this)?.session;
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
          anchorIds: canonicalSession == null
              ? const []
              : List.unmodifiable([
                  for (final _ in points)
                    canonicalSession.allocateRouteAnchorId(),
                ]),
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
          portId: source.portId,
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

bool _usesCanonicalSurfaceIdentity(
  RoomSurfaceRef surface,
  CanonicalPhysicalRoutingContext? context,
) {
  if (context == null) return false;
  final canonicalSpaceId =
      context.canonicalSpaceIdForSurfaceSpaceId(surface.spaceId);
  if (canonicalSpaceId == null || surface.spaceId != canonicalSpaceId.value) {
    return false;
  }
  return surface.type != SurfacePlaneType.wall ||
      surface.boundaryEdgeId != null;
}

RoomSurfaceRef? _surfaceForRouteIdentity(
  RoomSurfaceRef draftSurface,
  CanonicalPhysicalRoutingContext? context, {
  required bool canonicalIdentity,
}) {
  if (!canonicalIdentity) return draftSurface;
  if (context == null) return null;
  final canonicalSpaceId =
      context.canonicalSpaceIdForSurfaceSpaceId(draftSurface.spaceId);
  if (canonicalSpaceId == null) return null;

  switch (draftSurface.type) {
    case SurfacePlaneType.floor:
      return RoomSurfaceRef.floor(canonicalSpaceId.value);
    case SurfacePlaneType.ceiling:
      return RoomSurfaceRef.ceiling(canonicalSpaceId.value);
    case SurfacePlaneType.wall:
      final topology = context.project.index.boundary(canonicalSpaceId);
      if (topology == null) return null;
      final direct = draftSurface.boundaryEdgeId;
      if (direct != null) {
        if (!topology.orderedEdgeIds.contains(direct)) return null;
        return RoomSurfaceRef.wallByBoundaryEdge(
          canonicalSpaceId.value,
          direct,
        );
      }
      final ordinal = draftSurface.wallIndex;
      if (ordinal == null ||
          ordinal < 0 ||
          ordinal >= topology.orderedEdgeIds.length) {
        return null;
      }
      return RoomSurfaceRef.wallByBoundaryEdge(
        canonicalSpaceId.value,
        topology.orderedEdgeIds[ordinal],
      );
  }
}

bool _routeGeometryIsValidForContinuation(
  EditorController controller,
  ElectricalCableRoute route,
  CanonicalPhysicalRoutingContext? context,
) {
  for (final segment in route.segments) {
    final geometrySurface = _surfaceForLegacyGeometry(segment.surface, context);
    if (geometrySurface == null) return false;
    final normativeContext = MultiLevelRouteNormativeContext.resolve(
      controller,
      geometrySurface,
    );
    if (normativeContext == null ||
        !NormativeRouteEngine.validate(
          points: segment.points,
          context: normativeContext,
        ).isValid) {
      return false;
    }
  }
  return true;
}

RoomSurfaceRef? _surfaceForLegacyGeometry(
  RoomSurfaceRef surface,
  CanonicalPhysicalRoutingContext? context,
) {
  if (context == null) return surface;
  final canonicalSpaceId =
      context.canonicalSpaceIdForSurfaceSpaceId(surface.spaceId);
  if (canonicalSpaceId == null) return null;
  final legacySpaceId = context.legacySpaceIdForCanonical(canonicalSpaceId);
  if (legacySpaceId == null) return null;

  switch (surface.type) {
    case SurfacePlaneType.floor:
      return RoomSurfaceRef.floor(legacySpaceId);
    case SurfacePlaneType.ceiling:
      return RoomSurfaceRef.ceiling(legacySpaceId);
    case SurfacePlaneType.wall:
      final topology = context.project.index.boundary(canonicalSpaceId);
      if (topology == null) return null;
      final direct = surface.boundaryEdgeId;
      if (direct != null) {
        final ordinal = topology.orderedEdgeIds.indexOf(direct);
        if (ordinal < 0) return null;
        return RoomSurfaceRef.wall(legacySpaceId, ordinal);
      }
      final ordinal = surface.wallIndex;
      if (ordinal == null ||
          ordinal < 0 ||
          ordinal >= topology.orderedEdgeIds.length) {
        return null;
      }
      return RoomSurfaceRef.wall(legacySpaceId, ordinal);
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
  CanonicalPhysicalRoutingContext? routingContext,
  bool canonicalIdentity = false,
}) {
  final requestedSurface = _surfaceForRouteIdentity(
    surface,
    routingContext,
    canonicalIdentity: canonicalIdentity,
  );
  if (requestedSurface == null) return null;

  _PhysicalManualEndpoint? best;
  var bestDistanceSquared = radiusMm * radiusMm + 1;
  for (final component in components) {
    final componentSurface = _surfaceForRouteIdentity(
      component.surface,
      routingContext,
      canonicalIdentity: canonicalIdentity,
    );
    if (componentSurface != requestedSurface ||
        component.id == excludeComponentId) {
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
