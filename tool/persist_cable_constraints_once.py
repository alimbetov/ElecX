from pathlib import Path

p2_path = Path('lib/src/features/editor/editor_p2_session.dart')
p2 = p2_path.read_text()

def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    return text.replace(old, new, 1)

p2 = replace_once(
    p2,
    "import 'editor_controller.dart';\n",
    "import 'cable_route_constraints.dart';\nimport 'editor_controller.dart';\n",
    'p2 import',
)

p2 = replace_once(
    p2,
    """  const EditorP2State({
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
""",
    """  const EditorP2State({
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
""",
    'EditorP2State',
)

p2 = replace_once(
    p2,
    """final class EditorP2Session extends ChangeNotifier {
  EditorP2Session()
      : history = CommandHistory<EditorP2State>(const EditorP2State());
""",
    """final class EditorP2Session extends ChangeNotifier {
  EditorP2Session({EditorP2State initialState = const EditorP2State()})
      : history = CommandHistory<EditorP2State>(initialState);
""",
    'EditorP2Session constructor',
)

p2 = replace_once(
    p2,
    """  List<ElectricalComponentPlacement> get selectedComponents => components
      .where((component) => selection.ids.contains(component.id))
      .toList(growable: false);

  void setPlacementType(ElectricalComponentType? type) {
""",
    """  List<ElectricalComponentPlacement> get selectedComponents => components
      .where((component) => selection.ids.contains(component.id))
      .toList(growable: false);

  CableRouteConstraints routeConstraintsFor(String routeId) =>
      state.routeConstraints[routeId] ?? CableRouteConstraints.empty;

  void setPlacementType(ElectricalComponentType? type) {
""",
    'constraints getter',
)

p2 = replace_once(
    p2,
    """  bool moveSelectedComponent(SurfacePointMm point) {
""",
    """  bool toggleRouteSegmentLock(String routeId, int segmentIndex) {
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
""",
    'constraint mutation methods',
)

p2 = replace_once(
    p2,
    """  static bool _sameSnap(SnapCandidate? a, SnapCandidate? b) =>
""",
    """  ElectricalCableRoute? _routeForId(String routeId) {
    for (final route in routes) {
      if (route.id == routeId) return route;
    }
    return null;
  }

  static bool _sameSnap(SnapCandidate? a, SnapCandidate? b) =>
""",
    'route lookup',
)

p2 = replace_once(
    p2,
    """final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {
""",
    """final class _ReplaceRouteConstraintsCommand
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
""",
    'constraint command',
)

p2_path.write_text(p2)

ui_path = Path('lib/src/features/editor/cable_editor_ui_session.dart')
ui_path.write_text("""import 'package:flutter/foundation.dart';

import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'cable_route_constraints.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

/// Transient interaction focus/mode for cable editing.
///
/// Persistent lock and mandatory-waypoint state lives in EditorP2State. This
/// session deliberately owns only interaction state that may disappear when a
/// widget/controller is recreated.
final class CableEditorUiSession extends ChangeNotifier {
  CableEditorUiSession(this._controller);

  final EditorController _controller;
  CableRoutingMode _mode = CableRoutingMode.auto;
  String? _activeRouteId;
  int? _activeSegmentIndex;
  int? _activePointIndex;

  CableRoutingMode get mode => _mode;
  String? get activeRouteId => _activeRouteId;
  int? get activeSegmentIndex => _activeSegmentIndex;
  int? get activePointIndex => _activePointIndex;

  void setMode(CableRoutingMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void focusGeometry({
    required String routeId,
    int? segmentIndex,
    int? pointIndex,
  }) {
    if (_activeRouteId == routeId &&
        _activeSegmentIndex == segmentIndex &&
        _activePointIndex == pointIndex) {
      return;
    }
    _activeRouteId = routeId;
    _activeSegmentIndex = segmentIndex;
    _activePointIndex = pointIndex;
    notifyListeners();
  }

  void clearFocus() {
    if (_activeRouteId == null &&
        _activeSegmentIndex == null &&
        _activePointIndex == null) {
      return;
    }
    _activeRouteId = null;
    _activeSegmentIndex = null;
    _activePointIndex = null;
    notifyListeners();
  }

  CableRouteConstraints _constraints(String routeId) =>
      _controller.p2.routeConstraintsFor(routeId);

  bool isSegmentLocked(String routeId, int segmentIndex) =>
      _constraints(routeId).isSegmentLocked(segmentIndex);

  bool get activeSegmentLocked {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    return routeId != null &&
        segmentIndex != null &&
        isSegmentLocked(routeId, segmentIndex);
  }

  void toggleActiveSegmentLock() {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    if (routeId == null || segmentIndex == null) return;
    if (_controller.p2.toggleRouteSegmentLock(routeId, segmentIndex)) {
      notifyListeners();
    }
  }

  bool routeHasLockedSegments(String routeId) =>
      _constraints(routeId).lockedSegments.isNotEmpty;

  bool segmentHasWaypoints(String routeId, int segmentIndex) =>
      _constraints(routeId).segmentHasWaypoints(segmentIndex);

  List<CableMandatoryWaypoint> waypointsFor(String routeId) =>
      _constraints(routeId).mandatoryWaypoints;

  bool isWaypoint(String routeId, int segmentIndex, int pointIndex) =>
      _constraints(routeId).isWaypoint(segmentIndex, pointIndex);

  bool get activePointIsWaypoint {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    final pointIndex = _activePointIndex;
    if (routeId == null || segmentIndex == null || pointIndex == null) {
      return false;
    }
    return isWaypoint(routeId, segmentIndex, pointIndex);
  }

  void toggleWaypoint({required SurfacePointMm point}) {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    final pointIndex = _activePointIndex;
    if (routeId == null || segmentIndex == null || pointIndex == null) return;
    if (_controller.p2.toggleRouteWaypoint(
      routeId: routeId,
      segmentIndex: segmentIndex,
      pointIndex: pointIndex,
      point: point,
    )) {
      notifyListeners();
    }
  }
}

final Expando<CableEditorUiSession> _cableUiSessions =
    Expando<CableEditorUiSession>('ElecX cable editor UI session');

extension CableEditorUiSessionAccess on EditorController {
  CableEditorUiSession get cableUi =>
      _cableUiSessions[this] ??= CableEditorUiSession(this);
}
""")

canvas_path = Path('lib/src/features/editor/surface_canvas.dart')
canvas = canvas_path.read_text()
old_reconcile = """        } else {
          final route = controller.routeSelection.selectedRoute;
          if (route != null) {
            controller.cableUi.reconcileRoutePoints(
              route.id,
              [for (final segment in route.segments) segment.points],
            );
          }
        }
"""
new_reconcile = """        }
"""
canvas = replace_once(canvas, old_reconcile, new_reconcile, 'remove transient reconcile')

old_begin = """                    _dragComponentId = component.id;
                    _dragStartPosition = component.position;
                    controller.componentTransform.begin();
"""
new_begin = """                    if (!controller.componentTransform.begin()) return;
                    _dragComponentId = component.id;
                    _dragStartPosition = component.position;
"""
canvas = replace_once(canvas, old_begin, new_begin, 'component begin ordering')
canvas_path.write_text(canvas)

test_path = Path('test/cable_route_constraints_test.dart')
test_path.write_text("""import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);
  final route = ElectricalCableRoute(
    id: 'route-1',
    source: const ElectricalEndpointRef(
      componentId: 'source',
      portId: 'power-out',
    ),
    target: const ElectricalEndpointRef(
      componentId: 'target',
      portId: 'power-in',
    ),
    segments: [
      ElectricalRouteSegment(
        surface: surface,
        points: const [
          SurfacePointMm(100, 100),
          SurfacePointMm(1000, 100),
          SurfacePointMm(1000, 800),
        ],
      ),
    ],
  );

  test('constraint payload round-trips for project persistence', () {
    final constraints = CableRouteConstraints(
      lockedSegments: {0},
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 1,
          point: SurfacePointMm(1000, 100),
        ),
      ],
    );

    final restored = CableRouteConstraints.fromJson(constraints.toJson());

    expect(restored.isSegmentLocked(0), isTrue);
    expect(restored.isWaypoint(0, 1), isTrue);
    expect(restored.mandatoryWaypoints.single.point,
        const SurfacePointMm(1000, 100));
  });

  test('lock and waypoint mutations are undoable editor state', () {
    final session = EditorP2Session(
      initialState: EditorP2State(routes: [route]),
    );

    expect(session.toggleRouteSegmentLock(route.id, 0), isTrue);
    expect(
      session.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: 1,
        point: const SurfacePointMm(1000, 100),
      ),
      isTrue,
    );
    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isTrue);
    expect(session.routeConstraintsFor(route.id).isWaypoint(0, 1), isTrue);
    expect(session.history.undoDepth, 2);

    session.undo();
    expect(session.routeConstraintsFor(route.id).isWaypoint(0, 1), isFalse);
    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isTrue);
    session.redo();
    expect(session.routeConstraintsFor(route.id).isWaypoint(0, 1), isTrue);
  });

  test('constraint state survives session reopen from canonical snapshot', () {
    final session = EditorP2Session(
      initialState: EditorP2State(routes: [route]),
    );
    session.toggleRouteSegmentLock(route.id, 0);
    session.toggleRouteWaypoint(
      routeId: route.id,
      segmentIndex: 0,
      pointIndex: 1,
      point: const SurfacePointMm(1000, 100),
    );

    final reopened = EditorP2Session(initialState: session.state);
    final restored = reopened.routeConstraintsFor(route.id);

    expect(restored.isSegmentLocked(0), isTrue);
    expect(restored.isWaypoint(0, 1), isTrue);
    expect(reopened.history.undoDepth, 0);
  });

  test('constraint mutation rejects stale geometry references', () {
    final session = EditorP2Session(
      initialState: EditorP2State(routes: [route]),
    );

    expect(session.toggleRouteSegmentLock(route.id, 99), isFalse);
    expect(
      session.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: 1,
        point: const SurfacePointMm(999, 999),
      ),
      isFalse,
    );
    expect(session.history.undoDepth, 0);
  });
}
""")
