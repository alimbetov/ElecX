import '../../domain/boundary_penetration.dart';
import '../../domain/cable_penetration_authoring.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import '../../engine/port_snap_resolver.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
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
  });

  final ElectricalCableRoute route;
  final int p2MutationRevision;
}

final Expando<_PhysicalRouteContinuationIntent> _continuationIntents =
    Expando<_PhysicalRouteContinuationIntent>('ElecX physical route continuation');

extension PhysicalManualCableDraftPersistence on EditorController {
  bool get hasPhysicalRouteContinuation => _continuationIntents[this] != null;

  String? get physicalRouteContinuationId => _continuationIntents[this]?.route.id;

  /// Starts an edit draft at the current target of an already committed route.
  ///
  /// The committed aggregate is not changed here. The exact P2 mutation
  /// revision is captured and must still match on finish, so an unrelated
  /// electrical edit, wall projection or route replacement invalidates this
  /// draft instead of being overwritten by a stale continuation.
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
    setTool(EditorTool.cableRoute);
    _continuationIntents[this] = _PhysicalRouteContinuationIntent(
      route: route,
      p2MutationRevision: p2.history.mutationRevision,
    );
    routeSegments.add(
      SurfaceRouteSegmentDraft(
        surface: lastSegment.surface,
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
  /// Existing segments and penetrations are preserved verbatim. Only newly
  /// authored surface transitions are resolved and, when required, receive new
  /// penetration records. The final route then passes the same production
  /// connectivity/physical-anchor validators as ordinary route replacement.
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
    if (firstDraft.surface != beforeLast.surface ||
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
      extensionSegments.add(
        ElectricalRouteSegment(
          surface: draft.surface,
          points: List.unmodifiable(draft.points),
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

    if (!p2.replacePhysicalCableRoute(before: before, after: after)) {
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
