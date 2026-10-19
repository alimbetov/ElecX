import 'package:flutter/foundation.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/auto_route_graph_builder.dart';
import '../../engine/command_history.dart';
import '../../engine/direct_manipulation.dart';
import '../../engine/editor_layers.dart';
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
  });

  final List<ElectricalComponentPlacement> components;
  final List<ElectricalCableRoute> routes;
  final SelectionState selection;
  final Map<String, CableRouteConstraints> routeConstraints;

  EditorP2State copyWith({
    List<ElectricalComponentPlacement>? components,
    List<ElectricalCableRoute>? routes,
    SelectionState? selection,
    Map<String, CableRouteConstraints>? routeConstraints,
  }) =>
      EditorP2State(
        components: components ?? this.components,
        routes: routes ?? this.routes,
        selection: selection ?? this.selection,
        routeConstraints: routeConstraints ?? this.routeConstraints,
      );
}

final class EditorP2Session extends ChangeNotifier {
  EditorP2Session({EditorP2State initialState = const EditorP2State()})
      : history = CommandHistory<EditorP2State>(initialState);

  final CommandHistory<EditorP2State> history;
  final EditorLayerRegistry layers = EditorLayerRegistry();
  SnapCandidate? activeSnap;
  ElectricalComponentType? placementType;
  RoutePreference routePreference = RoutePreference.shortest;
  ElectricalComponentPlacement? _moveOrigin;
  int _componentSequence = 1;
  int _routeSequence = 1;

  EditorP2State get state => history.state;
  List<ElectricalComponentPlacement> get components => state.components;
  List<ElectricalCableRoute> get routes => state.routes;
  SelectionState get selection => state.selection;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  bool get isManipulating => _moveOrigin != null;

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
    final component = ElectricalComponentPlacement(
      id: 'component-$sequence',
      type: type,
      surface: surface,
      position: position,
      label: '${ElectricalComponentDefaults.defaultLabel(type)} $sequence',
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
    if (component == null || layers.isLocked(EditorLayerId.electrical)) {
      return false;
    }
    _moveOrigin = component;
    return true;
  }

  bool previewMoveSelectedComponent(SurfacePointMm point) {
    final origin = _moveOrigin;
    final current = selectedComponent;
    if (origin == null || current == null || current.id != origin.id) {
      return false;
    }
    _replaceState(_replaceComponent(state, current.copyWith(position: point)));
    return true;
  }

  bool commitMoveSelectedComponent() {
    final origin = _moveOrigin;
    final current = selectedComponent;
    _moveOrigin = null;
    if (origin == null || current == null || current.id != origin.id) {
      return false;
    }
    if (origin.position.xMm == current.position.xMm &&
        origin.position.yMm == current.position.yMm) {
      return false;
    }
    history.execute(_ReplaceComponentCommand(before: origin, after: current));
    notifyListeners();
    return true;
  }

  void cancelMoveSelectedComponent() {
    final origin = _moveOrigin;
    _moveOrigin = null;
    if (origin == null) return;
    _replaceState(_replaceComponent(state, origin));
  }

  bool replaceCableRoute(
    ElectricalCableRoute before,
    ElectricalCableRoute after,
  ) {
    if (before.id != after.id || layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    if (!routes.any((route) => route.id == before.id)) return false;
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: after,
      components: components,
    )) {
      return false;
    }
    history.execute(_ReplaceCableRouteCommand(before: before, after: after));
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
    history.execute(_DeleteComponentsCommand(deleted));
    _replaceState(
      history.state.copyWith(selection: const SelectionState()),
      notify: false,
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
    final route = ElectricalCableRoute(
      id: 'route-${_routeSequence++}',
      source: source,
      target: target,
      segments: RouteEngine.toSegments(graph, solution),
      cableType: cableType,
    );
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: route,
      components: components,
    )) {
      return false;
    }
    history.execute(_AddRouteCommand(route));
    notifyListeners();
    return true;
  }

  bool autoRouteSelectedPair({EngineeringSpace? space, String? cableType}) {
    final pair = selectedComponents;
    if (pair.length != 2) return false;
    final sourceComponent = _preferredSource(pair[0], pair[1]);
    final targetComponent =
        identical(sourceComponent, pair[0]) ? pair[1] : pair[0];
    final sourcePort = _portForSource(sourceComponent);
    final targetPort = _portForTarget(targetComponent);
    if (sourcePort == null || targetPort == null) return false;

    late final RoutingGraph graph;
    late final String startNodeId;
    late final String endNodeId;
    if (sourceComponent.surface == targetComponent.surface) {
      final surface = sourceComponent.surface;
      final a = sourceComponent.position;
      final d = targetComponent.position;
      final elbowX = SurfacePointMm(d.xMm, a.yMm);
      final elbowY = SurfacePointMm(a.xMm, d.yMm);
      graph = RoutingGraph(
        nodes: {
          'a': RouteNode(id: 'a', surface: surface, point: a),
          'bx': RouteNode(id: 'bx', surface: surface, point: elbowX),
          'by': RouteNode(id: 'by', surface: surface, point: elbowY),
          'd': RouteNode(id: 'd', surface: surface, point: d),
        },
        edges: [
          RouteEdge(from: 'a', to: 'bx', cost: _axisDistance(a, elbowX)),
          RouteEdge(from: 'bx', to: 'd', cost: _axisDistance(elbowX, d)),
          RouteEdge(from: 'a', to: 'by', cost: _axisDistance(a, elbowY)),
          RouteEdge(from: 'by', to: 'd', cost: _axisDistance(elbowY, d)),
        ],
      );
      startNodeId = 'a';
      endNodeId = 'd';
    } else {
      if (space == null) return false;
      graph = AutoRouteGraphBuilder.build(
        space: space,
        source: sourceComponent,
        target: targetComponent,
      );
      startNodeId = 'source';
      endNodeId = 'target';
    }

    return addAutoRoute(
      graph: graph,
      startNodeId: startNodeId,
      endNodeId: endNodeId,
      source: ElectricalEndpointRef(
        componentId: sourceComponent.id,
        portId: sourcePort.id,
      ),
      target: ElectricalEndpointRef(
        componentId: targetComponent.id,
        portId: targetPort.id,
      ),
      cableType: cableType,
    );
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

  static ElectricalComponentPlacement _preferredSource(
    ElectricalComponentPlacement first,
    ElectricalComponentPlacement second,
  ) {
    bool hasPowerOut(ElectricalComponentPlacement component) =>
        component.ports.any((port) => port.kind == ElectricalPortKind.powerOut);
    if (hasPowerOut(first) && !hasPowerOut(second)) return first;
    if (hasPowerOut(second) && !hasPowerOut(first)) return second;
    return first;
  }

  static ElectricalPortDefinition? _portForSource(
    ElectricalComponentPlacement component,
  ) {
    for (final port in component.ports) {
      if (port.kind == ElectricalPortKind.powerOut ||
          port.kind == ElectricalPortKind.controlOut) {
        return port;
      }
    }
    return component.ports.isEmpty ? null : component.ports.first;
  }

  static ElectricalPortDefinition? _portForTarget(
    ElectricalComponentPlacement component,
  ) {
    for (final port in component.ports) {
      if (port.kind == ElectricalPortKind.powerIn ||
          port.kind == ElectricalPortKind.controlIn) {
        return port;
      }
    }
    return component.ports.isEmpty ? null : component.ports.first;
  }

  static double _axisDistance(SurfacePointMm a, SurfacePointMm b) =>
      (a.xMm - b.xMm).abs().toDouble() + (a.yMm - b.yMm).abs().toDouble();
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
  const _ReplaceCableRouteCommand({required this.before, required this.after});

  final ElectricalCableRoute before;
  final ElectricalCableRoute after;

  @override
  String get label => 'Edit cable route';

  @override
  EditorP2State execute(EditorP2State state) =>
      _replace(state, before.id, after);

  @override
  EditorP2State undo(EditorP2State state) => _replace(state, after.id, before);

  static EditorP2State _replace(
    EditorP2State state,
    String routeId,
    ElectricalCableRoute replacement,
  ) =>
      state.copyWith(
        routes: [
          for (final route in state.routes)
            if (route.id == routeId) replacement else route,
        ],
      );
}

final Expando<EditorP2Session> _p2Sessions = Expando<EditorP2Session>(
  'ElecX P2 editor session',
);

extension EditorP2SessionAccess on EditorController {
  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session();
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

final class _DeleteComponentsCommand implements EditorCommand<EditorP2State> {
  const _DeleteComponentsCommand(this.deleted);
  final List<ElectricalComponentPlacement> deleted;

  @override
  String get label => 'Delete components';

  @override
  EditorP2State execute(EditorP2State state) {
    final ids = deleted.map((component) => component.id).toSet();
    return state.copyWith(
      components: state.components
          .where((component) => !ids.contains(component.id))
          .toList(growable: false),
    );
  }

  @override
  EditorP2State undo(EditorP2State state) =>
      state.copyWith(components: [...state.components, ...deleted]);
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
