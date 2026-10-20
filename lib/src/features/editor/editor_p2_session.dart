import 'package:flutter/foundation.dart';

import '../../domain/cable_identity.dart';
import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/auto_route_graph_builder.dart';
import '../../engine/command_history.dart';
import '../../engine/direct_manipulation.dart';
import '../../engine/editor_layers.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/route_engine.dart';
import '../../engine/selection_engine.dart';
import '../../engine/snap_engine.dart';
import 'cable_route_constraints.dart';
import 'editor_controller.dart';

final class EditorP2State {
  const EditorP2State({
    this.components = const [],
    this.routes = const [],
    this.selection = const SelectionState(),
    this.routeConstraints = const {},
    this.circuitBundles = const [],
  });

  final List<ElectricalComponentPlacement> components;
  final List<ElectricalCableRoute> routes;
  final SelectionState selection;
  final Map<String, CableRouteConstraints> routeConstraints;
  final List<CircuitCableBundle> circuitBundles;

  EditorP2State copyWith({
    List<ElectricalComponentPlacement>? components,
    List<ElectricalCableRoute>? routes,
    SelectionState? selection,
    Map<String, CableRouteConstraints>? routeConstraints,
    List<CircuitCableBundle>? circuitBundles,
  }) =>
      EditorP2State(
        components: components ?? this.components,
        routes: routes ?? this.routes,
        selection: selection ?? this.selection,
        routeConstraints: routeConstraints ?? this.routeConstraints,
        circuitBundles: circuitBundles ?? this.circuitBundles,
      );
}

final class EditorP2Session extends ChangeNotifier {
  EditorP2Session({
    EditorP2State initialState = const EditorP2State(),
    RouteNormativeContext? Function(RoomSurfaceRef surface)?
        routeContextResolver,
  })  : _routeContextResolver = routeContextResolver,
        _componentSequence = _nextSequence(
          prefix: 'component-',
          ids: initialState.components.map((item) => item.id),
        ),
        _routeSequence = _nextSequence(
          prefix: 'route-',
          ids: initialState.routes.map((item) => item.id),
        ),
        history = CommandHistory<EditorP2State>(initialState) {
    _validateUniqueIds(initialState);
  }

  final CommandHistory<EditorP2State> history;
  final RouteNormativeContext? Function(RoomSurfaceRef surface)?
      _routeContextResolver;
  final EditorLayerRegistry layers = EditorLayerRegistry();
  SnapCandidate? activeSnap;
  ElectricalComponentType? placementType;
  RoutePreference routePreference = RoutePreference.shortest;
  EditorP2State? _moveOriginState;
  String? _moveComponentId;
  bool _movePreviewValid = false;
  int _componentSequence;
  int _routeSequence;

  EditorP2State get state => history.state;
  List<ElectricalComponentPlacement> get components => state.components;
  List<ElectricalCableRoute> get routes => state.routes;
  SelectionState get selection => state.selection;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  bool get isManipulating => _moveOriginState != null;
  bool get movePreviewValid => _movePreviewValid;

  ElectricalComponentPlacement? get selectedComponent {
    final id = selection.primaryId;
    if (id == null) return null;
    for (final component in components) {
      if (component.id == id) return component;
    }
    return null;
  }

  List<ElectricalComponentPlacement> get selectedComponents => components
      .where((component) => selection.ids.contains(component.id))
      .toList(growable: false);

  CableRouteConstraints routeConstraintsFor(String routeId) =>
      state.routeConstraints[routeId] ?? CableRouteConstraints.empty;

  CircuitCableBundle? circuitBundleForRoute(String routeId) {
    for (final bundle in state.circuitBundles) {
      if (bundle.cable.routeId == routeId) return bundle;
    }
    return null;
  }

  CircuitCableBundle? circuitBundleForLoad(String componentId) {
    for (final bundle in state.circuitBundles) {
      if (bundle.cable.endB.componentId == componentId) return bundle;
    }
    return null;
  }

  void setPlacementType(ElectricalComponentType? type) {
    placementType = type;
    notifyListeners();
  }

  void setRoutePreference(RoutePreference value) {
    routePreference = value;
    notifyListeners();
  }

  void setLayerVisible(EditorLayerId id, bool visible) {
    layers.setVisible(id, visible);
    notifyListeners();
  }

  void setLayerLocked(EditorLayerId id, bool locked) {
    layers.setLocked(id, locked);
    notifyListeners();
  }

  void updateSnap(SnapCandidate? candidate) {
    if (_sameSnap(activeSnap, candidate)) return;
    activeSnap = candidate;
    notifyListeners();
  }

  void select(String id, {SelectionMode mode = SelectionMode.replace}) {
    _replaceState(
      state.copyWith(selection: SelectionEngine.apply(selection, id, mode)),
    );
  }

  void clearSelection() {
    if (selection.ids.isEmpty) return;
    _replaceState(state.copyWith(selection: const SelectionState()));
  }

  ElectricalComponentPlacement placeComponent({
    required ElectricalComponentType type,
    required RoomSurfaceRef surface,
    required SurfacePointMm position,
  }) {
    if (layers.isLocked(EditorLayerId.electrical)) {
      throw StateError('Electrical layer is locked.');
    }
    final sequence = _componentSequence++;
    final componentId = _nextAvailableId(
      prefix: 'component-',
      initialSequence: sequence,
      existingIds: components.map((item) => item.id).toSet(),
    );
    _componentSequence = componentId.$2;
    final component = ElectricalComponentPlacement(
      id: componentId.$1,
      type: type,
      surface: surface,
      position: position,
      label:
          '${ElectricalComponentDefaults.defaultLabel(type)} ${componentId.$2 - 1}',
      ports: ElectricalComponentDefaults.portsFor(type),
    );
    history.execute(_AddComponentCommand(component));
    _replaceState(
      history.state.copyWith(
        selection: SelectionState(ids: {component.id}, primaryId: component.id),
      ),
      notify: false,
    );
    placementType = null;
    notifyListeners();
    return component;
  }

  bool beginMoveSelectedComponent() {
    final component = selectedComponent;
    if (component == null ||
        layers.isLocked(EditorLayerId.electrical) ||
        _moveOriginState != null) {
      return false;
    }
    _moveOriginState = state;
    _moveComponentId = component.id;
    _movePreviewValid = true;
    return true;
  }

  bool previewMoveSelectedComponent(SurfacePointMm point) {
    final originState = _moveOriginState;
    final componentId = _moveComponentId;
    if (originState == null || componentId == null) return false;

    ElectricalComponentPlacement? originComponent;
    for (final component in originState.components) {
      if (component.id == componentId) {
        originComponent = component;
        break;
      }
    }
    if (originComponent == null) return false;

    final moved = originComponent.copyWith(position: point);
    var preview = _replaceComponent(originState, moved);
    final nextRoutes = <ElectricalCableRoute>[];
    final nextConstraints = Map<String, CableRouteConstraints>.of(
      originState.routeConstraints,
    );

    for (final route in originState.routes) {
      final isSource = route.source.componentId == componentId;
      final isTarget = route.target.componentId == componentId;
      if (!isSource && !isTarget) {
        nextRoutes.add(route);
        continue;
      }
      if (isSource && isTarget) {
        _movePreviewValid = false;
        return false;
      }
      final rerouted = _rerouteForMovedComponent(
        route: route,
        movedComponent: moved,
        isSource: isSource,
        constraints: originState.routeConstraints[route.id] ??
            CableRouteConstraints.empty,
      );
      if (rerouted == null) {
        _movePreviewValid = false;
        return false;
      }
      nextRoutes.add(rerouted);
      final reconciled = (originState.routeConstraints[route.id] ??
              CableRouteConstraints.empty)
          .reconcile([
        for (final segment in rerouted.segments) segment.points,
      ]);
      if (reconciled.isEmpty) {
        nextConstraints.remove(route.id);
      } else {
        nextConstraints[route.id] = reconciled;
      }
    }

    preview = preview.copyWith(
      routes: List.unmodifiable(nextRoutes),
      routeConstraints: Map.unmodifiable(nextConstraints),
    );
    _replaceState(preview);
    _movePreviewValid = true;
    return true;
  }

  bool commitMoveSelectedComponent() {
    final origin = _moveOriginState;
    final componentId = _moveComponentId;
    final after = state;
    final previewValid = _movePreviewValid &&
        componentId != null &&
        _movePreviewValidState(after, componentId);
    _clearMoveTransaction();
    if (origin == null || componentId == null || !previewValid) {
      if (origin != null) _replaceState(origin);
      return false;
    }

    final beforeComponent = _componentForId(origin, componentId);
    final afterComponent = _componentForId(after, componentId);
    if (beforeComponent == null || afterComponent == null) {
      _replaceState(origin);
      return false;
    }
    if (beforeComponent.position == afterComponent.position) {
      _replaceState(origin);
      return false;
    }

    history.execute(
      _ReplaceEditorStateCommand(
        before: origin,
        after: after,
        label: 'Move component with connected routes',
      ),
    );
    notifyListeners();
    return true;
  }

  void cancelMoveSelectedComponent() {
    final origin = _moveOriginState;
    _clearMoveTransaction();
    if (origin == null) return;
    _replaceState(origin);
  }

  bool replaceCableRoute(
    ElectricalCableRoute before,
    ElectricalCableRoute after,
  ) {
    if (before.id != after.id || layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    final current = _routeForId(before.id);
    if (current == null || !_sameRoute(current, before)) return false;
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: after,
      components: components,
    )) {
      return false;
    }
    if (!_routeGeometryIsValid(after)) return false;

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
    history.execute(
      _ReplaceCableRouteCommand(
        before: current,
        after: after,
        beforeConstraints: beforeConstraints,
        afterConstraints: afterConstraints,
      ),
    );
    notifyListeners();
    return true;
  }

  bool toggleRouteSegmentLock(String routeId, int segmentIndex) {
    final route = _routeForId(routeId);
    if (route == null ||
        segmentIndex < 0 ||
        segmentIndex >= route.segments.length) {
      return false;
    }
    final before = routeConstraintsFor(routeId);
    final after = before.toggleSegmentLock(segmentIndex);
    history.execute(
      _ReplaceRouteConstraintsCommand(
        routeId: routeId,
        before: before,
        after: after,
      ),
    );
    notifyListeners();
    return true;
  }

  bool toggleRouteWaypoint({
    required String routeId,
    required int segmentIndex,
    required int pointIndex,
    required SurfacePointMm point,
  }) {
    final route = _routeForId(routeId);
    if (route == null ||
        segmentIndex < 0 ||
        segmentIndex >= route.segments.length) {
      return false;
    }
    final points = route.segments[segmentIndex].points;
    if (pointIndex < 0 || pointIndex >= points.length) return false;
    final actual = points[pointIndex];
    if (actual.xMm != point.xMm || actual.yMm != point.yMm) return false;

    final before = routeConstraintsFor(routeId);
    final after = before.toggleWaypoint(
      segmentIndex: segmentIndex,
      pointIndex: pointIndex,
      point: point,
    );
    history.execute(
      _ReplaceRouteConstraintsCommand(
        routeId: routeId,
        before: before,
        after: after,
      ),
    );
    notifyListeners();
    return true;
  }

  bool moveSelectedComponent(SurfacePointMm point) {
    final component = selectedComponent;
    if (component == null || layers.isLocked(EditorLayerId.electrical)) {
      return false;
    }
    history.execute(
      _ReplaceComponentCommand(
        before: component,
        after: component.copyWith(position: point),
      ),
    );
    notifyListeners();
    return true;
  }

  bool deleteSelection() {
    final ids = selection.ids;
    if (ids.isEmpty || layers.isLocked(EditorLayerId.electrical)) return false;
    final deleted = components
        .where((component) => ids.contains(component.id))
        .toList(growable: false);
    if (deleted.isEmpty) return false;

    final removedRouteIds = <String>{
      for (final route in routes)
        if (ids.contains(route.source.componentId) ||
            ids.contains(route.target.componentId))
          route.id,
    };
    final nextConstraints = Map<String, CableRouteConstraints>.of(
      state.routeConstraints,
    )..removeWhere((routeId, _) => removedRouteIds.contains(routeId));
    final after = state.copyWith(
      components: [
        for (final component in components)
          if (!ids.contains(component.id)) component,
      ],
      routes: [
        for (final route in routes)
          if (!removedRouteIds.contains(route.id)) route,
      ],
      selection: const SelectionState(),
      routeConstraints: Map.unmodifiable(nextConstraints),
      circuitBundles: [
        for (final bundle in state.circuitBundles)
          if (!removedRouteIds.contains(bundle.cable.routeId)) bundle,
      ],
    );
    history.execute(
      _ReplaceEditorStateCommand(
        before: state,
        after: after,
        label: 'Delete components with connected engineering routes',
      ),
    );
    notifyListeners();
    return true;
  }

  bool addAutoRoute({
    required RoutingGraph graph,
    required String startNodeId,
    required String endNodeId,
    required ElectricalEndpointRef source,
    required ElectricalEndpointRef target,
    String? cableType,
  }) {
    if (layers.isLocked(EditorLayerId.cableRoutes)) return false;
    final solution = RouteEngine.solve(
      graph: graph,
      startNodeId: startNodeId,
      endNodeId: endNodeId,
      preference: routePreference,
    );
    if (solution == null) return false;
    return _addRouteSegments(
      source: source,
      target: target,
      segments: RouteEngine.toSegments(graph, solution),
      cableType: cableType,
    );
  }

  CircuitCableBundle? connectLoadToBoard({
    required String loadComponentId,
    required String boardComponentId,
    EngineeringSpace? space,
    String? cableType,
  }) {
    if (layers.isLocked(EditorLayerId.electrical) ||
        layers.isLocked(EditorLayerId.cableRoutes)) {
      return null;
    }
    if (circuitBundleForLoad(loadComponentId) != null) return null;

    final board = _componentForId(state, boardComponentId);
    final load = _componentForId(state, loadComponentId);
    if (board == null ||
        load == null ||
        board.id == load.id ||
        board.type != ElectricalComponentType.distributionBoard ||
        board.surface.spaceId != load.surface.spaceId) {
      return null;
    }
    final pair = _resolvePortPair(board, load);
    if (pair == null || pair.sourceComponent.id != board.id) return null;

    final segments = _buildSegmentsBetween(
      sourceComponent: board,
      targetComponent: load,
      space: space,
    );
    if (segments == null) return null;

    final routeId = _nextAvailableId(
      prefix: 'route-',
      initialSequence: _routeSequence,
      existingIds: routes.map((item) => item.id).toSet(),
    );
    final route = ElectricalCableRoute(
      id: routeId.$1,
      source: ElectricalEndpointRef(
        componentId: board.id,
        portId: pair.sourcePort.id,
      ),
      target: ElectricalEndpointRef(
        componentId: load.id,
        portId: pair.targetPort.id,
      ),
      segments: segments,
      cableType: cableType,
    );
    if (!ElectricalConnectivityValidator.routeIsConnected(
          route: route,
          components: components,
        ) ||
        !_routeGeometryIsValid(route)) {
      return null;
    }

    final suffix = route.id.startsWith('route-')
        ? route.id.substring('route-'.length)
        : route.id;
    final circuit = CircuitRef(
      id: 'circuit-$suffix',
      name: 'Группа · ${load.label}',
      boardId: board.id,
    );
    final cable = CableIdentity(
      id: 'cable-$suffix',
      routeId: route.id,
      circuitId: circuit.id,
      designation: 'CAB-$suffix',
      endA: CableTerminationRef(
        componentId: route.source.componentId,
        portId: route.source.portId,
      ),
      endB: CableTerminationRef(
        componentId: route.target.componentId,
        portId: route.target.portId,
      ),
      cableSpecId: cableType,
    );
    final bundle = CircuitCableBundle(circuit: circuit, cable: cable);
    final registry = CircuitCableRegistry()
      ..registerBundle(route: route, circuit: circuit, cable: cable);
    if (registry.bundleByRouteId(route.id) == null) return null;

    final after = state.copyWith(
      routes: List.unmodifiable([...routes, route]),
      circuitBundles: List.unmodifiable([...state.circuitBundles, bundle]),
      selection: SelectionState(ids: {load.id}, primaryId: load.id),
    );
    _routeSequence = routeId.$2;
    history.execute(
      _ReplaceEditorStateCommand(
        before: state,
        after: after,
        label: 'Connect load to distribution board',
      ),
    );
    notifyListeners();
    return bundle;
  }

  bool autoRouteSelectedPair({EngineeringSpace? space, String? cableType}) {
    final pair = selectedComponents;
    if (pair.length != 2) return false;
    final forward = _resolvePortPair(pair[0], pair[1]);
    final reverse = forward == null ? _resolvePortPair(pair[1], pair[0]) : null;
    final portPair = forward ?? reverse;
    if (portPair == null) return false;
    final segments = _buildSegmentsBetween(
      sourceComponent: portPair.sourceComponent,
      targetComponent: portPair.targetComponent,
      space: space,
    );
    if (segments == null) return false;
    return _addRouteSegments(
      source: ElectricalEndpointRef(
        componentId: portPair.sourceComponent.id,
        portId: portPair.sourcePort.id,
      ),
      target: ElectricalEndpointRef(
        componentId: portPair.targetComponent.id,
        portId: portPair.targetPort.id,
      ),
      segments: segments,
      cableType: cableType,
    );
  }

  List<ElectricalRouteSegment>? _buildSegmentsBetween({
    required ElectricalComponentPlacement sourceComponent,
    required ElectricalComponentPlacement targetComponent,
    EngineeringSpace? space,
  }) {
    if (sourceComponent.surface == targetComponent.surface) {
      final surface = sourceComponent.surface;
      final context = _routeContextResolver?.call(surface);
      if (context != null) {
        for (final candidate in NormativeRouteEngine.buildCandidates(
          source: sourceComponent.position,
          target: targetComponent.position,
          context: context,
        )) {
          if (candidate.validation.isValid) {
            return [
              ElectricalRouteSegment(
                  surface: surface, points: candidate.points),
            ];
          }
        }
        return null;
      }
      final a = sourceComponent.position;
      final d = targetComponent.position;
      final elbowX = SurfacePointMm(d.xMm, a.yMm);
      return [
        ElectricalRouteSegment(
          surface: surface,
          points: _compactOrthogonal([a, elbowX, d]),
        ),
      ];
    }
    if (space == null) return null;
    final graph = AutoRouteGraphBuilder.build(
      space: space,
      source: sourceComponent,
      target: targetComponent,
    );
    final solution = RouteEngine.solve(
      graph: graph,
      startNodeId: 'source',
      endNodeId: 'target',
      preference: routePreference,
    );
    return solution == null ? null : RouteEngine.toSegments(graph, solution);
  }

  static List<SurfacePointMm> _compactOrthogonal(
    List<SurfacePointMm> points,
  ) {
    final result = <SurfacePointMm>[];
    for (final point in points) {
      if (result.isEmpty || result.last != point) result.add(point);
    }
    return List.unmodifiable(result);
  }

  bool _addRouteSegments({
    required ElectricalEndpointRef source,
    required ElectricalEndpointRef target,
    required List<ElectricalRouteSegment> segments,
    String? cableType,
  }) {
    if (layers.isLocked(EditorLayerId.cableRoutes)) return false;
    final routeId = _nextAvailableId(
      prefix: 'route-',
      initialSequence: _routeSequence,
      existingIds: routes.map((item) => item.id).toSet(),
    );
    final route = ElectricalCableRoute(
      id: routeId.$1,
      source: source,
      target: target,
      segments: segments,
      cableType: cableType,
    );
    if (!ElectricalConnectivityValidator.routeIsConnected(
          route: route,
          components: components,
        ) ||
        !_routeGeometryIsValid(route)) {
      return false;
    }
    _routeSequence = routeId.$2;
    history.execute(_AddRouteCommand(route));
    notifyListeners();
    return true;
  }

  List<ManipulationHandle> handlesForSelection() {
    final component = selectedComponent;
    if (component == null) return const [];
    return [
      ManipulationHandle(
        id: '${component.id}:move',
        ownerId: component.id,
        kind: ManipulationHandleKind.move,
        worldPoint: MmPoint(component.position.xMm, component.position.yMm),
      ),
    ];
  }

  void undo() {
    if (!history.canUndo || isManipulating) return;
    history.undo();
    _normalizeSelection();
    notifyListeners();
  }

  void redo() {
    if (!history.canRedo || isManipulating) return;
    history.redo();
    _normalizeSelection();
    notifyListeners();
  }

  void _normalizeSelection() {
    final valid = components.map((component) => component.id).toSet();
    final ids = selection.ids.where(valid.contains).toSet();
    if (ids.length == selection.ids.length) return;
    _replaceState(
      state.copyWith(
        selection: SelectionState(
          ids: Set.unmodifiable(ids),
          primaryId: ids.contains(selection.primaryId)
              ? selection.primaryId
              : ids.isEmpty
                  ? null
                  : ids.first,
        ),
      ),
      notify: false,
    );
  }

  void _replaceState(EditorP2State next, {bool notify = true}) {
    history.replaceState(next, clearHistory: false);
    if (notify) notifyListeners();
  }

  ElectricalCableRoute? _routeForId(String routeId) {
    for (final route in routes) {
      if (route.id == routeId) return route;
    }
    return null;
  }

  static bool _sameSnap(SnapCandidate? a, SnapCandidate? b) =>
      a?.kind == b?.kind &&
      a?.point.x == b?.point.x &&
      a?.point.y == b?.point.y &&
      a?.sourceId == b?.sourceId;

  static EditorP2State _replaceComponent(
    EditorP2State state,
    ElectricalComponentPlacement replacement,
  ) =>
      state.copyWith(
        components: [
          for (final component in state.components)
            if (component.id == replacement.id) replacement else component,
        ],
      );

  ElectricalCableRoute? _rerouteForMovedComponent({
    required ElectricalCableRoute route,
    required ElectricalComponentPlacement movedComponent,
    required bool isSource,
    required CableRouteConstraints constraints,
  }) {
    if (route.segments.isEmpty) return null;
    final segmentIndex = isSource ? 0 : route.segments.length - 1;
    if (constraints.isSegmentLocked(segmentIndex)) return null;
    final segment = route.segments[segmentIndex];
    if (segment.surface != movedComponent.surface ||
        segment.points.length < 2) {
      return null;
    }
    final context = _routeContextResolver?.call(segment.surface);
    if (context == null) {
      // Context-free unit sessions preserve the old component-only behavior.
      final points = segment.points.toList();
      if (isSource) {
        points[0] = movedComponent.position;
      } else {
        points[points.length - 1] = movedComponent.position;
      }
      final replacement = _routeWithSegment(route, segmentIndex, points);
      return _routeGeometryIsValid(replacement) ? replacement : null;
    }

    final waypoints = constraints.mandatoryWaypoints
        .where((item) => item.segmentIndex == segmentIndex)
        .toList()
      ..sort((a, b) => a.pointIndex.compareTo(b.pointIndex));
    for (final waypoint in waypoints) {
      if (waypoint.pointIndex >= segment.points.length ||
          segment.points[waypoint.pointIndex] != waypoint.point) {
        return null;
      }
    }

    final anchors = <SurfacePointMm>[];
    if (isSource) {
      anchors.add(movedComponent.position);
      anchors.addAll(waypoints.map((item) => item.point));
      anchors.add(segment.points.last);
    } else {
      anchors.add(segment.points.first);
      anchors.addAll(waypoints.map((item) => item.point));
      anchors.add(movedComponent.position);
    }
    final points = _routeThroughAnchors(anchors, context);
    if (points == null) return null;
    final replacement = _routeWithSegment(route, segmentIndex, points);
    if (!_routeGeometryIsValid(replacement) ||
        !_constraintsAllowReplacement(
          before: route,
          after: replacement,
          constraints: constraints,
        )) {
      return null;
    }
    return replacement;
  }

  static List<SurfacePointMm>? _routeThroughAnchors(
    List<SurfacePointMm> anchors,
    RouteNormativeContext context,
  ) {
    if (anchors.length < 2) return null;
    final result = <SurfacePointMm>[];
    for (var i = 1; i < anchors.length; i++) {
      RouteCandidate? best;
      for (final candidate in NormativeRouteEngine.buildCandidates(
        source: anchors[i - 1],
        target: anchors[i],
        context: context,
      )) {
        if (candidate.validation.isValid) {
          best = candidate;
          break;
        }
      }
      if (best == null) return null;
      for (final point in best.points) {
        if (result.isEmpty || result.last != point) result.add(point);
      }
    }
    return List.unmodifiable(result);
  }

  static ElectricalCableRoute _routeWithSegment(
    ElectricalCableRoute route,
    int segmentIndex,
    List<SurfacePointMm> points,
  ) =>
      ElectricalCableRoute(
        id: route.id,
        source: route.source,
        target: route.target,
        segments: [
          for (var i = 0; i < route.segments.length; i++)
            if (i == segmentIndex)
              ElectricalRouteSegment(
                surface: route.segments[i].surface,
                points: List.unmodifiable(points),
              )
            else
              route.segments[i],
        ],
        cableType: route.cableType,
        medium: route.medium,
        reservePercent: route.reservePercent,
      );

  static ElectricalComponentPlacement? _componentForId(
    EditorP2State state,
    String componentId,
  ) {
    for (final component in state.components) {
      if (component.id == componentId) return component;
    }
    return null;
  }

  bool _movePreviewValidState(EditorP2State preview, String componentId) {
    for (final route in preview.routes) {
      if (route.source.componentId != componentId &&
          route.target.componentId != componentId) {
        continue;
      }
      if (!ElectricalConnectivityValidator.routeIsConnected(
            route: route,
            components: preview.components,
          ) ||
          !_routeGeometryIsValid(route)) {
        return false;
      }
    }
    return true;
  }

  void _clearMoveTransaction() {
    _moveOriginState = null;
    _moveComponentId = null;
    _movePreviewValid = false;
  }

  static _ResolvedPortPair? _resolvePortPair(
    ElectricalComponentPlacement source,
    ElectricalComponentPlacement target,
  ) {
    for (final sourcePort in source.ports) {
      for (final targetPort in target.ports) {
        if (ElectricalPortCompatibility.areCompatible(
          sourcePort.kind,
          targetPort.kind,
        )) {
          return _ResolvedPortPair(
            sourceComponent: source,
            targetComponent: target,
            sourcePort: sourcePort,
            targetPort: targetPort,
          );
        }
      }
    }
    return null;
  }

  bool _routeGeometryIsValid(ElectricalCableRoute route) {
    final resolver = _routeContextResolver;
    if (resolver == null) return true;
    for (final segment in route.segments) {
      final context = resolver(segment.surface);
      if (context == null ||
          !NormativeRouteEngine.validate(
            points: segment.points,
            context: context,
          ).isValid) {
        return false;
      }
    }
    return true;
  }

  static bool _constraintsAllowReplacement({
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
          !after.segments[waypoint.segmentIndex].points
              .contains(waypoint.point)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameRoute(ElectricalCableRoute a, ElectricalCableRoute b) {
    if (a.id != b.id ||
        a.source.componentId != b.source.componentId ||
        a.source.portId != b.source.portId ||
        a.target.componentId != b.target.componentId ||
        a.target.portId != b.target.portId ||
        a.segments.length != b.segments.length) {
      return false;
    }
    for (var i = 0; i < a.segments.length; i++) {
      if (!_sameSegment(a.segments[i], b.segments[i])) {
        return false;
      }
    }
    return true;
  }

  static bool _sameSegment(ElectricalRouteSegment a, ElectricalRouteSegment b) {
    if (a.surface != b.surface || a.points.length != b.points.length) {
      return false;
    }
    for (var i = 0; i < a.points.length; i++) {
      if (a.points[i] != b.points[i]) {
        return false;
      }
    }
    return true;
  }

  static int _nextSequence({
    required String prefix,
    required Iterable<String> ids,
  }) {
    var next = 1;
    for (final id in ids) {
      if (!id.startsWith(prefix)) continue;
      final parsed = int.tryParse(id.substring(prefix.length));
      if (parsed != null && parsed >= next) {
        next = parsed + 1;
      }
    }
    return next;
  }

  static (String, int) _nextAvailableId({
    required String prefix,
    required int initialSequence,
    required Set<String> existingIds,
  }) {
    var sequence = initialSequence;
    while (existingIds.contains('$prefix$sequence')) {
      sequence++;
    }
    return ('$prefix$sequence', sequence + 1);
  }

  static void _validateUniqueIds(EditorP2State state) {
    final componentIds = <String>{};
    for (final component in state.components) {
      if (!componentIds.add(component.id)) {
        throw ArgumentError('Duplicate component id: ${component.id}');
      }
    }
    final routeIds = <String>{};
    for (final route in state.routes) {
      if (!routeIds.add(route.id)) {
        throw ArgumentError('Duplicate route id: ${route.id}');
      }
    }
  }
}

final class _ReplaceEditorStateCommand implements EditorCommand<EditorP2State> {
  const _ReplaceEditorStateCommand({
    required this.before,
    required this.after,
    required this.label,
  });

  final EditorP2State before;
  final EditorP2State after;

  @override
  final String label;

  @override
  EditorP2State execute(EditorP2State state) => after;

  @override
  EditorP2State undo(EditorP2State state) => before;
}

final class _ResolvedPortPair {
  const _ResolvedPortPair({
    required this.sourceComponent,
    required this.targetComponent,
    required this.sourcePort,
    required this.targetPort,
  });

  final ElectricalComponentPlacement sourceComponent;
  final ElectricalComponentPlacement targetComponent;
  final ElectricalPortDefinition sourcePort;
  final ElectricalPortDefinition targetPort;
}

final class _ReplaceRouteConstraintsCommand
    implements EditorCommand<EditorP2State> {
  const _ReplaceRouteConstraintsCommand({
    required this.routeId,
    required this.before,
    required this.after,
  });

  final String routeId;
  final CableRouteConstraints before;
  final CableRouteConstraints after;

  @override
  String get label => 'Edit cable route constraints';

  @override
  EditorP2State execute(EditorP2State state) => _replace(state, after);

  @override
  EditorP2State undo(EditorP2State state) => _replace(state, before);

  EditorP2State _replace(
    EditorP2State state,
    CableRouteConstraints constraints,
  ) {
    final next = Map<String, CableRouteConstraints>.of(state.routeConstraints);
    if (constraints.isEmpty) {
      next.remove(routeId);
    } else {
      next[routeId] = constraints;
    }
    return state.copyWith(routeConstraints: Map.unmodifiable(next));
  }
}

final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {
  const _ReplaceCableRouteCommand({
    required this.before,
    required this.after,
    required this.beforeConstraints,
    required this.afterConstraints,
  });

  final ElectricalCableRoute before;
  final ElectricalCableRoute after;
  final CableRouteConstraints beforeConstraints;
  final CableRouteConstraints afterConstraints;

  @override
  String get label => 'Edit cable route';

  @override
  EditorP2State execute(EditorP2State state) => _replace(
        state,
        before.id,
        after,
        afterConstraints,
      );

  @override
  EditorP2State undo(EditorP2State state) => _replace(
        state,
        after.id,
        before,
        beforeConstraints,
      );

  static EditorP2State _replace(
    EditorP2State state,
    String routeId,
    ElectricalCableRoute replacement,
    CableRouteConstraints constraints,
  ) {
    final nextConstraints = Map<String, CableRouteConstraints>.of(
      state.routeConstraints,
    );
    if (constraints.isEmpty) {
      nextConstraints.remove(routeId);
    } else {
      nextConstraints[routeId] = constraints;
    }
    return state.copyWith(
      routes: [
        for (final route in state.routes)
          if (route.id == routeId) replacement else route,
      ],
      routeConstraints: Map.unmodifiable(nextConstraints),
    );
  }
}

final Expando<EditorP2Session> _p2Sessions = Expando<EditorP2Session>(
  'ElecX P2 editor session',
);

extension EditorP2SessionAccess on EditorController {
  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session(
        routeContextResolver: routeNormativeContextFor,
      );

  void restoreP2State(EditorP2State state) {
    final previous = _p2Sessions[this];
    previous?.dispose();
    _p2Sessions[this] = EditorP2Session(
      initialState: state,
      routeContextResolver: routeNormativeContextFor,
    );
  }

  void disposeP2State() {
    _p2Sessions[this]?.dispose();
    _p2Sessions[this] = null;
  }
}

final class _AddComponentCommand implements EditorCommand<EditorP2State> {
  const _AddComponentCommand(this.component);
  final ElectricalComponentPlacement component;

  @override
  String get label => 'Add ${component.label}';

  @override
  EditorP2State execute(EditorP2State state) =>
      state.copyWith(components: [...state.components, component]);

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
        components: state.components
            .where((item) => item.id != component.id)
            .toList(growable: false),
      );
}

final class _ReplaceComponentCommand implements EditorCommand<EditorP2State> {
  const _ReplaceComponentCommand({required this.before, required this.after});
  final ElectricalComponentPlacement before;
  final ElectricalComponentPlacement after;

  @override
  String get label => 'Move ${before.label}';

  @override
  EditorP2State execute(EditorP2State state) =>
      EditorP2Session._replaceComponent(state, after);

  @override
  EditorP2State undo(EditorP2State state) =>
      EditorP2Session._replaceComponent(state, before);
}

final class _AddRouteCommand implements EditorCommand<EditorP2State> {
  const _AddRouteCommand(this.route);
  final ElectricalCableRoute route;

  @override
  String get label => 'Add route';

  @override
  EditorP2State execute(EditorP2State state) =>
      state.copyWith(routes: [...state.routes, route]);

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
        routes: state.routes
            .where((item) => item.id != route.id)
            .toList(growable: false),
      );
}
