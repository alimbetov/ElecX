from pathlib import Path
import re


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, got {count}')
    p.write_text(text.replace(old, new, 1))

p = 'lib/src/features/editor/editor_p2_session.dart'
text = Path(p).read_text()
text = text.replace(
    '  ElectricalComponentPlacement? _moveOrigin;\n',
    '  EditorP2State? _moveOriginState;\n  String? _moveComponentId;\n  bool _movePreviewValid = false;\n',
    1,
)
text = text.replace(
    '  bool get isManipulating => _moveOrigin != null;\n',
    '  bool get isManipulating => _moveOriginState != null;\n  bool get movePreviewValid => _movePreviewValid;\n',
    1,
)
pattern = re.compile(
    r"  bool beginMoveSelectedComponent\(\) \{.*?\n  \}\n\n  bool replaceCableRoute",
    re.S,
)
replacement = r'''  bool beginMoveSelectedComponent() {
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
        role: isSource ? CableEndpointRole.source : CableEndpointRole.target,
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
    _clearMoveTransaction();
    if (origin == null || componentId == null || !_movePreviewValidState(after)) {
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

  bool replaceCableRoute'''
text, count = pattern.subn(replacement, text)
if count != 1:
    raise RuntimeError(f'move lifecycle replacement expected 1, got {count}')

helper_anchor = '  static _ResolvedPortPair? _resolvePortPair(\n'
if text.count(helper_anchor) != 1:
    raise RuntimeError('helper anchor mismatch')
helpers = r'''  ElectricalCableRoute? _rerouteForMovedComponent({
    required ElectricalCableRoute route,
    required ElectricalComponentPlacement movedComponent,
    required CableEndpointRole role,
    required CableRouteConstraints constraints,
  }) {
    if (route.segments.isEmpty) return null;
    final segmentIndex =
        role == CableEndpointRole.source ? 0 : route.segments.length - 1;
    if (constraints.isSegmentLocked(segmentIndex)) return null;
    final segment = route.segments[segmentIndex];
    if (segment.surface != movedComponent.surface || segment.points.length < 2) {
      return null;
    }
    final context = _routeContextResolver?.call(segment.surface);
    if (context == null) {
      // Context-free unit sessions preserve the old component-only behavior.
      final points = segment.points.toList();
      if (role == CableEndpointRole.source) {
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
    if (role == CableEndpointRole.source) {
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

  bool _movePreviewValidState(EditorP2State preview) {
    if (!_movePreviewValid) return false;
    for (final route in preview.routes) {
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

'''
text = text.replace(helper_anchor, helpers + helper_anchor, 1)

# Snapshot history command.
command_anchor = 'final class _ResolvedPortPair {'
if text.count(command_anchor) != 1:
    raise RuntimeError('command anchor mismatch')
command = r'''final class _ReplaceEditorStateCommand implements EditorCommand<EditorP2State> {
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

'''
text = text.replace(command_anchor, command + command_anchor, 1)
Path(p).write_text(text)

# Transform session must combine placement validity with route-group validity.
p = 'lib/src/features/editor/component_transform_session.dart'
text = Path(p).read_text()
old = '''    _preview = ComponentTransformPreview(\n      componentId: current.componentId,\n      surface: current.surface,\n      originalPosition: current.originalPosition,\n      position: position,\n      isValid: isValid,\n    );\n    _phase = isValid\n        ? EditorEditSessionPhase.previewing\n        : EditorEditSessionPhase.invalid;\n    if (isValid) {\n      controller.p2.previewMoveSelectedComponent(position);\n    }\n    notifyListeners();\n    return isValid;'''
new = '''    final routesValid =\n        isValid && controller.p2.previewMoveSelectedComponent(position);\n    final previewValid = isValid && routesValid && controller.p2.movePreviewValid;\n    _preview = ComponentTransformPreview(\n      componentId: current.componentId,\n      surface: current.surface,\n      originalPosition: current.originalPosition,\n      position: position,\n      isValid: previewValid,\n    );\n    _phase = previewValid\n        ? EditorEditSessionPhase.previewing\n        : EditorEditSessionPhase.invalid;\n    notifyListeners();\n    return previewValid;'''
if text.count(old) != 1:
    raise RuntimeError('component transform preview anchor mismatch')
Path(p).write_text(text.replace(old, new, 1))

# Regression tests: reroute, atomic undo, exact cancel, locked route refusal.
p = 'test/component_transform_session_test.dart'
text = Path(p).read_text()
imports = "import 'package:elecx/src/features/editor/component_transform_session.dart';\n"
if imports not in text:
    raise RuntimeError('component transform test import anchor missing')
# Add routing imports if absent.
text = text.replace(
    "import 'package:elecx/src/domain/electrical_placement.dart';\n",
    "import 'package:elecx/src/domain/electrical_placement.dart';\nimport 'package:elecx/src/domain/electrical_routing.dart';\n",
    1,
)
text = text.replace(
    "import 'package:elecx/src/features/editor/component_transform_session.dart';\n",
    "import 'package:elecx/src/engine/normative_route_engine.dart';\nimport 'package:elecx/src/engine/selection_engine.dart';\nimport 'package:elecx/src/features/editor/component_transform_session.dart';\nimport 'package:elecx/src/features/editor/editor_p2_session.dart';\n",
    1,
)
insert = r'''
  test('connected route previews and commits atomically with component move', () {
    final surface = RoomSurfaceRef.wall('room-1', 0);
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 4000,
      heightMm: 2500,
      edgeClearanceMm: 0,
    );
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final routeBefore = p2.routes.single;
    p2.select(target.id, mode: SelectionMode.replace);
    final depthBefore = p2.history.undoDepth;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1900)),
      isTrue,
    );
    final previewRoute = p2.routes.single;
    expect(previewRoute.target, routeBefore.target);
    expect(previewRoute.segments.single.points.last,
        const SurfacePointMm(3000, 1900));
    expect(p2.history.undoDepth, depthBefore);

    expect(p2.commitMoveSelectedComponent(), isTrue);
    expect(p2.history.undoDepth, depthBefore + 1);
    expect(p2.selectedComponent!.position, const SurfacePointMm(3000, 1900));
    expect(p2.routes.single.segments.single.points.last,
        const SurfacePointMm(3000, 1900));

    p2.undo();
    expect(p2.selectedComponent!.position, target.position);
    expect(p2.routes.single.segments.single.points, routeBefore.segments.single.points);
  });

  test('cancel restores component routes and constraints exactly', () {
    final surface = RoomSurfaceRef.wall('room-1', 0);
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 4000,
      heightMm: 2500,
      edgeClearanceMm: 0,
    );
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final route = p2.routes.single;
    expect(
      p2.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: 1,
        point: route.segments.single.points[1],
      ),
      isTrue,
    );
    final before = p2.state;
    p2.select(target.id, mode: SelectionMode.replace);

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1900)),
      isTrue,
    );
    p2.cancelMoveSelectedComponent();

    expect(p2.selectedComponent!.position, target.position);
    expect(p2.routes.single.segments.single.points, before.routes.single.segments.single.points);
    expect(
      p2.routeConstraintsFor(route.id).mandatoryWaypoints.single.point,
      before.routeConstraints[route.id]!.mandatoryWaypoints.single.point,
    );
  });

  test('locked connected endpoint segment blocks component move commit', () {
    final surface = RoomSurfaceRef.wall('room-1', 0);
    final context = RouteNormativeContext(
      surface: surface,
      widthMm: 4000,
      heightMm: 2500,
      edgeClearanceMm: 0,
    );
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final route = p2.routes.single;
    expect(p2.toggleRouteSegmentLock(route.id, 0), isTrue);
    p2.select(target.id, mode: SelectionMode.replace);
    final before = p2.state;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1900)),
      isFalse,
    );
    expect(p2.movePreviewValid, isFalse);
    p2.cancelMoveSelectedComponent();
    expect(p2.selectedComponent!.position, target.position);
    expect(p2.routes.single.segments.single.points, before.routes.single.segments.single.points);
  });
'''
idx = text.rfind('\n}')
if idx < 0:
    raise RuntimeError('component transform test closing brace missing')
Path(p).write_text(text[:idx] + insert + text[idx:])
