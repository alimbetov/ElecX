import '../../domain/cable_identity.dart';
import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../engine/command_history.dart';
import '../../engine/editor_layers.dart';
import 'cable_route_constraints.dart';
import 'editor_p2_session.dart';

typedef PhysicalRouteGeometryValidator = bool Function(
  ElectricalCableRoute route,
);

extension PhysicalCableRouteCommitter on EditorP2Session {
  /// Commits a fully materialized physical route as one undo/redo transaction.
  ///
  /// The route already owns its BoundaryPenetration records, therefore history
  /// cannot leave a cable without its holes or leave orphan holes after undo.
  bool commitPhysicalCableRoute(ElectricalCableRoute route) {
    if (!layers.isVisible(EditorLayerId.cableRoutes) ||
        layers.isLocked(EditorLayerId.cableRoutes) ||
        routes.any((existing) => existing.id == route.id)) {
      return false;
    }
    if (!ElectricalConnectivityValidator.routeIsConnected(
          route: route,
          components: components,
        ) ||
        !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
          route: route,
          components: components,
        )) {
      return false;
    }

    history.execute(_AddPhysicalCableRouteCommand(route));
    // This extension is part of the EditorP2Session mutation surface. The
    // command has already committed synchronously; notify the same listeners as
    // native session mutation methods so canvas/panels cannot observe stale UI.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
    return true;
  }

  /// Atomically replaces one already committed physical route while preserving
  /// its engineering identity.
  ///
  /// When [geometryValidator] is omitted, the regular EditorP2Session route
  /// replacement remains authoritative. Canonical continuation supplies an
  /// explicit validator because durable BoundaryEdgeId surfaces must be checked
  /// through the current legacy geometry projection rather than rejected merely
  /// because the transitional canvas still addresses that wall by ordinal.
  ///
  /// The explicit-validator path preserves the same engineering invariants as
  /// the regular replacement transaction: exact current-route affinity,
  /// connectivity, physical endpoint anchoring, locked segments, mandatory
  /// waypoints, circuit/cable identity and sizing-evidence invalidation. The
  /// entire replacement is one history command.
  bool replacePhysicalCableRoute({
    required ElectricalCableRoute before,
    required ElectricalCableRoute after,
    PhysicalRouteGeometryValidator? geometryValidator,
  }) {
    if (before.id != after.id ||
        !layers.isVisible(EditorLayerId.cableRoutes) ||
        layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    if (geometryValidator == null) {
      return replaceCableRoute(before, after);
    }

    final current = _routeById(routes, before.id);
    if (current == null || !_sameRoute(current, before)) return false;
    if (!ElectricalConnectivityValidator.routeIsConnected(
          route: after,
          components: components,
        ) ||
        !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
          route: after,
          components: components,
        ) ||
        !geometryValidator(after)) {
      return false;
    }

    final beforeConstraints = routeConstraintsFor(before.id);
    if (!_constraintsAllowReplacement(
      before: current,
      after: after,
      constraints: beforeConstraints,
    )) {
      return false;
    }
    final afterConstraints = beforeConstraints.reconcile([
      for (final segment in after.segments) segment.points,
    ]);

    final assignedBundle = circuitBundleForRoute(after.id);
    CircuitCableBundle? reboundBundle;
    if (assignedBundle != null) {
      if (assignedBundle.protectiveDevice != null &&
          after.source.componentId != before.source.componentId) {
        return false;
      }
      final targetComponent = _componentById(
        components,
        after.target.componentId,
      );
      final reboundCircuit = CircuitRef(
        id: assignedBundle.circuit.id,
        name: targetComponent == null
            ? assignedBundle.circuit.name
            : 'Группа · ${targetComponent.label}',
        boardId: assignedBundle.circuit.boardId == before.source.componentId
            ? after.source.componentId
            : assignedBundle.circuit.boardId,
        protectiveDeviceId: assignedBundle.circuit.protectiveDeviceId,
      );
      final reboundCable = CableIdentity(
        id: assignedBundle.cable.id,
        routeId: assignedBundle.cable.routeId,
        circuitId: assignedBundle.cable.circuitId,
        designation: assignedBundle.cable.designation,
        cableSpecId: assignedBundle.cable.cableSpecId,
        endA: CableTerminationRef(
          componentId: after.source.componentId,
          portId: after.source.portId,
        ),
        endB: CableTerminationRef(
          componentId: after.target.componentId,
          portId: after.target.portId,
        ),
      );
      reboundBundle = CircuitCableBundle(
        circuit: reboundCircuit,
        cable: reboundCable,
        protectiveDevice: assignedBundle.protectiveDevice,
      );
      try {
        final registry = CircuitCableRegistry()
          ..registerBundle(
            route: after,
            circuit: reboundCircuit,
            cable: reboundCable,
            protectiveDevice: assignedBundle.protectiveDevice,
          );
        if (registry.bundleByRouteId(after.id) == null) return false;
      } on ArgumentError {
        return false;
      } on StateError {
        return false;
      }
    }

    final nextConstraints = Map<String, CableRouteConstraints>.of(
      state.routeConstraints,
    );
    if (afterConstraints.isEmpty) {
      nextConstraints.remove(after.id);
    } else {
      nextConstraints[after.id] = afterConstraints;
    }
    final nextEvidence = Map.of(state.sizingEvidenceByRoute)..remove(after.id);
    final nextState = state.copyWith(
      routes: List.unmodifiable([
        for (final route in routes)
          if (route.id == after.id) after else route,
      ]),
      routeConstraints: Map.unmodifiable(nextConstraints),
      circuitBundles: reboundBundle == null
          ? state.circuitBundles
          : List.unmodifiable([
              for (final bundle in state.circuitBundles)
                if (bundle.cable.routeId == after.id) reboundBundle else bundle,
            ]),
      sizingEvidenceByRoute: Map.unmodifiable(nextEvidence),
    );

    history.execute(
      _ReplacePhysicalRouteStateCommand(
        before: state,
        after: nextState,
      ),
    );
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
    return true;
  }
}

final class _AddPhysicalCableRouteCommand
    implements EditorCommand<EditorP2State> {
  const _AddPhysicalCableRouteCommand(this.route);

  final ElectricalCableRoute route;

  @override
  String get label => 'Create physical cable route with penetrations';

  @override
  EditorP2State execute(EditorP2State state) {
    if (state.routes.any((existing) => existing.id == route.id)) {
      throw StateError('Route ${route.id} already exists.');
    }
    return state.copyWith(
      routes: List.unmodifiable([...state.routes, route]),
    );
  }

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
        routes: List.unmodifiable([
          for (final existing in state.routes)
            if (existing.id != route.id) existing,
        ]),
      );
}

final class _ReplacePhysicalRouteStateCommand
    implements EditorCommand<EditorP2State> {
  const _ReplacePhysicalRouteStateCommand({
    required this.before,
    required this.after,
  });

  final EditorP2State before;
  final EditorP2State after;

  @override
  String get label => 'Continue physical cable route';

  @override
  EditorP2State execute(EditorP2State state) => after;

  @override
  EditorP2State undo(EditorP2State state) => before;
}

ElectricalCableRoute? _routeById(
  Iterable<ElectricalCableRoute> routes,
  String routeId,
) {
  for (final route in routes) {
    if (route.id == routeId) return route;
  }
  return null;
}

ElectricalComponentPlacement? _componentById(
  Iterable<ElectricalComponentPlacement> components,
  String componentId,
) {
  for (final component in components) {
    if (component.id == componentId) return component;
  }
  return null;
}

bool _constraintsAllowReplacement({
  required ElectricalCableRoute before,
  required ElectricalCableRoute after,
  required CableRouteConstraints constraints,
}) {
  for (final segmentIndex in constraints.lockedSegments) {
    if (segmentIndex >= before.segments.length ||
        segmentIndex >= after.segments.length ||
        !_sameSegment(
          before.segments[segmentIndex],
          after.segments[segmentIndex],
        )) {
      return false;
    }
  }
  for (final waypoint in constraints.mandatoryWaypoints) {
    if (waypoint.segmentIndex >= after.segments.length ||
        !after.segments[waypoint.segmentIndex].points.contains(waypoint.point)) {
      return false;
    }
  }
  return true;
}

bool _sameRoute(ElectricalCableRoute a, ElectricalCableRoute b) {
  if (a.id != b.id ||
      a.source.componentId != b.source.componentId ||
      a.source.portId != b.source.portId ||
      a.target.componentId != b.target.componentId ||
      a.target.portId != b.target.portId ||
      a.segments.length != b.segments.length ||
      a.penetrations.length != b.penetrations.length) {
    return false;
  }
  for (var index = 0; index < a.segments.length; index++) {
    if (!_sameSegment(a.segments[index], b.segments[index])) return false;
  }
  for (var index = 0; index < a.penetrations.length; index++) {
    if (!_samePenetration(a.penetrations[index], b.penetrations[index])) {
      return false;
    }
  }
  return true;
}

bool _sameSegment(ElectricalRouteSegment a, ElectricalRouteSegment b) {
  if (a.surface != b.surface ||
      a.points.length != b.points.length ||
      a.anchorIds.length != b.anchorIds.length) {
    return false;
  }
  for (var index = 0; index < a.points.length; index++) {
    if (a.points[index] != b.points[index]) return false;
  }
  for (var index = 0; index < a.anchorIds.length; index++) {
    if (a.anchorIds[index] != b.anchorIds[index]) return false;
  }
  return true;
}

bool _samePenetration(dynamic a, dynamic b) =>
    a.id == b.id &&
    a.hostKind == b.hostKind &&
    a.hostThicknessMm == b.hostThicknessMm &&
    a.pathLengthMm == b.pathLengthMm &&
    a.materialId == b.materialId &&
    a.entryAnchor.id == b.entryAnchor.id &&
    a.entryAnchor.penetrationId == b.entryAnchor.penetrationId &&
    a.entryAnchor.side == b.entryAnchor.side &&
    a.entryAnchor.surface == b.entryAnchor.surface &&
    a.entryAnchor.point == b.entryAnchor.point &&
    a.entryAnchor.routeId == b.entryAnchor.routeId &&
    a.exitAnchor.id == b.exitAnchor.id &&
    a.exitAnchor.penetrationId == b.exitAnchor.penetrationId &&
    a.exitAnchor.side == b.exitAnchor.side &&
    a.exitAnchor.surface == b.exitAnchor.surface &&
    a.exitAnchor.point == b.exitAnchor.point &&
    a.exitAnchor.routeId == b.exitAnchor.routeId;
