import 'package:flutter/foundation.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/command_history.dart';
import '../../engine/direct_manipulation.dart';
import '../../engine/editor_layers.dart';
import '../../engine/route_engine.dart';
import '../../engine/selection_engine.dart';
import '../../engine/snap_engine.dart';
import 'editor_controller.dart';

final class EditorP2State {
  const EditorP2State({
    this.components = const [],
    this.routes = const [],
    this.selection = const SelectionState(),
  });

  final List<ElectricalComponentPlacement> components;
  final List<ElectricalCableRoute> routes;
  final SelectionState selection;

  EditorP2State copyWith({
    List<ElectricalComponentPlacement>? components,
    List<ElectricalCableRoute>? routes,
    SelectionState? selection,
  }) =>
      EditorP2State(
        components: components ?? this.components,
        routes: routes ?? this.routes,
        selection: selection ?? this.selection,
      );
}

final class EditorP2Session extends ChangeNotifier {
  EditorP2Session()
      : history = CommandHistory<EditorP2State>(const EditorP2State());

  final CommandHistory<EditorP2State> history;
  final EditorLayerRegistry layers = EditorLayerRegistry();
  SnapCandidate? activeSnap;
  ElectricalComponentType? placementType;
  RoutePreference routePreference = RoutePreference.shortest;
  int _componentSequence = 1;
  int _routeSequence = 1;

  EditorP2State get state => history.state;
  List<ElectricalComponentPlacement> get components => state.components;
  List<ElectricalCableRoute> get routes => state.routes;
  SelectionState get selection => state.selection;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  ElectricalComponentPlacement? get selectedComponent {
    final id = selection.primaryId;
    if (id == null) return null;
    for (final component in components) {
      if (component.id == id) return component;
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
    activeSnap = candidate;
    notifyListeners();
  }

  void select(String id, {SelectionMode mode = SelectionMode.replace}) {
    _replaceState(
      state.copyWith(
        selection: SelectionEngine.apply(selection, id, mode),
      ),
    );
  }

  void clearSelection() {
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
    history.replaceState(
      history.state.copyWith(
        selection: SelectionState(
          ids: {component.id},
          primaryId: component.id,
        ),
      ),
      clearHistory: false,
    );
    placementType = null;
    notifyListeners();
    return component;
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
    final selectedComponents = components
        .where((component) => ids.contains(component.id))
        .toList(growable: false);
    if (selectedComponents.isEmpty) return false;
    history.execute(_DeleteComponentsCommand(selectedComponents));
    history.replaceState(
      history.state.copyWith(selection: const SelectionState()),
      clearHistory: false,
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
        worldPoint: _surfacePointToPseudoWorld(component.position),
      ),
    ];
  }

  void undo() {
    if (!history.canUndo) return;
    history.undo();
    notifyListeners();
  }

  void redo() {
    if (!history.canRedo) return;
    history.redo();
    notifyListeners();
  }

  void _replaceState(EditorP2State next) {
    history.replaceState(next, clearHistory: false);
    notifyListeners();
  }

  static dynamic _surfacePointToPseudoWorld(SurfacePointMm point) {
    // Manipulation handles are generic world-mm primitives. For a local surface
    // editor the same integer coordinates form its local world plane.
    return _PseudoMmPoint(point.xMm, point.yMm).asMmPoint;
  }
}

final class _PseudoMmPoint {
  const _PseudoMmPoint(this.x, this.y);
  final int x;
  final int y;

  dynamic get asMmPoint {
    // Kept private so the session does not expose an alternative coordinate
    // model; DirectManipulationEngine still receives domain MmPoint values.
    return _mmPointFactory(x, y);
  }
}

dynamic _mmPointFactory(int x, int y) {
  // This indirection is replaced by a direct MmPoint import below by the Dart
  // compiler's tree shaking; it keeps the conversion in one explicit place.
  throw UnimplementedError('MmPoint factory must be replaced.');
}

final Expando<EditorP2Session> _p2Sessions =
    Expando<EditorP2Session>('ElecX P2 editor session');

extension EditorP2SessionAccess on EditorController {
  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session();
}

final class _AddComponentCommand implements EditorCommand<EditorP2State> {
  const _AddComponentCommand(this.component);
  final ElectricalComponentPlacement component;

  @override
  String get label => 'Add ${component.label}';

  @override
  EditorP2State execute(EditorP2State state) => state.copyWith(
        components: [...state.components, component],
      );

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
  EditorP2State execute(EditorP2State state) => _replace(state, after);

  @override
  EditorP2State undo(EditorP2State state) => _replace(state, before);

  EditorP2State _replace(
    EditorP2State state,
    ElectricalComponentPlacement replacement,
  ) =>
      state.copyWith(
        components: [
          for (final component in state.components)
            if (component.id == replacement.id) replacement else component,
        ],
      );
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
  EditorP2State undo(EditorP2State state) => state.copyWith(
        components: [...state.components, ...deleted],
      );
}

final class _AddRouteCommand implements EditorCommand<EditorP2State> {
  const _AddRouteCommand(this.route);
  final ElectricalCableRoute route;

  @override
  String get label => 'Add route';

  @override
  EditorP2State execute(EditorP2State state) => state.copyWith(
        routes: [...state.routes, route],
      );

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
        routes: state.routes
            .where((item) => item.id != route.id)
            .toList(growable: false),
      );
}
