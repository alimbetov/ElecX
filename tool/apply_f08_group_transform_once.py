from pathlib import Path

p = Path('lib/src/features/editor/editor_p2_session.dart')
text = p.read_text()

text = text.replace(
    "  String? _moveComponentId;\n  bool _movePreviewValid = false;",
    "  String? _moveComponentId;\n  Set<String> _moveComponentIds = const <String>{};\n  bool _movePreviewValid = false;",
    1,
)

old_begin = '''  bool beginMoveSelectedComponent() {
    final component = selectedComponent;
    if (component == null ||
        layers.isLocked(EditorLayerId.electrical) ||
        (layers.isLocked(EditorLayerId.cableRoutes) &&
            _componentHasConnectedRoutes(component.id)) ||
        _moveOriginState != null) {
      return false;
    }
    _moveOriginState = state;
    _moveComponentId = component.id;
    _movePreviewValid = true;
    return true;
  }
'''
new_begin = '''  bool beginMoveSelectedComponent() {
    final component = selectedComponent;
    final selected = selectedComponents;
    if (component == null ||
        selected.isEmpty ||
        selected.any((item) => item.surface != component.surface) ||
        layers.isLocked(EditorLayerId.electrical) ||
        (layers.isLocked(EditorLayerId.cableRoutes) &&
            selected.any((item) => _componentHasConnectedRoutes(item.id))) ||
        _moveOriginState != null) {
      return false;
    }
    _moveOriginState = state;
    _moveComponentId = component.id;
    _moveComponentIds = Set.unmodifiable(selected.map((item) => item.id));
    _movePreviewValid = true;
    return true;
  }
'''
if old_begin not in text:
    raise SystemExit('beginMoveSelectedComponent anchor not found')
text = text.replace(old_begin, new_begin, 1)

start = text.index('  bool previewMoveSelectedComponent(SurfacePointMm point) {')
end = text.index('  bool commitMoveSelectedComponent() {', start)
new_preview = '''  bool previewMoveSelectedComponent(SurfacePointMm point) {
    final originState = _moveOriginState;
    final primaryId = _moveComponentId;
    final selectedIds = _moveComponentIds;
    if (originState == null || primaryId == null || selectedIds.isEmpty) {
      return false;
    }

    final originPrimary = _componentForId(originState, primaryId);
    if (originPrimary == null) return false;
    final dxMm = point.xMm - originPrimary.position.xMm;
    final dyMm = point.yMm - originPrimary.position.yMm;

    var preview = originState;
    final movedById = <String, ElectricalComponentPlacement>{};
    for (final component in originState.components) {
      if (!selectedIds.contains(component.id)) continue;
      final moved = component.copyWith(
        position: SurfacePointMm(
          component.position.xMm + dxMm,
          component.position.yMm + dyMm,
        ),
      );
      movedById[component.id] = moved;
      preview = _replaceComponent(preview, moved);
    }
    if (movedById.length != selectedIds.length) {
      _movePreviewValid = false;
      return false;
    }

    final nextRoutes = <ElectricalCableRoute>[];
    final nextConstraints = Map<String, CableRouteConstraints>.of(
      originState.routeConstraints,
    );

    for (final route in originState.routes) {
      final sourceSelected = selectedIds.contains(route.source.componentId);
      final targetSelected = selectedIds.contains(route.target.componentId);
      if (!sourceSelected && !targetSelected) {
        nextRoutes.add(route);
        continue;
      }

      final constraints = originState.routeConstraints[route.id] ??
          CableRouteConstraints.empty;
      ElectricalCableRoute? transformed;
      if (sourceSelected && targetSelected) {
        // Internal group wiring belongs to the transform. Explicitly locked
        // geometry/waypoints are absolute authoring constraints, so the whole
        // transaction must fail rather than silently breaking them.
        if (!constraints.isEmpty) {
          _movePreviewValid = false;
          return false;
        }
        transformed = _translateRoute(route, dxMm: dxMm, dyMm: dyMm);
        if (!_routeGeometryIsValid(transformed)) {
          _movePreviewValid = false;
          return false;
        }
      } else {
        final movedComponent = movedById[
          sourceSelected ? route.source.componentId : route.target.componentId
        ];
        if (movedComponent == null) {
          _movePreviewValid = false;
          return false;
        }
        transformed = _rerouteForMovedComponent(
          route: route,
          movedComponent: movedComponent,
          isSource: sourceSelected,
          constraints: constraints,
        );
        if (transformed == null) {
          _movePreviewValid = false;
          return false;
        }
        final reconciled = constraints.reconcile([
          for (final segment in transformed.segments) segment.points,
        ]);
        if (reconciled.isEmpty) {
          nextConstraints.remove(route.id);
        } else {
          nextConstraints[route.id] = reconciled;
        }
      }
      nextRoutes.add(transformed);
    }

    preview = preview.copyWith(
      routes: List.unmodifiable(nextRoutes),
      routeConstraints: Map.unmodifiable(nextConstraints),
    );
    final valid = _movePreviewValidState(preview, selectedIds);
    if (!valid) {
      _movePreviewValid = false;
      return false;
    }
    _replaceState(preview);
    _movePreviewValid = true;
    return true;
  }

'''
text = text[:start] + new_preview + text[end:]

start = text.index('  bool commitMoveSelectedComponent() {')
end = text.index('  void cancelMoveSelectedComponent() {', start)
new_commit = '''  bool commitMoveSelectedComponent() {
    final origin = _moveOriginState;
    final componentIds = _moveComponentIds;
    final after = state;
    final previewValid = _movePreviewValid &&
        componentIds.isNotEmpty &&
        _movePreviewValidState(after, componentIds);
    _clearMoveTransaction();
    if (origin == null || componentIds.isEmpty || !previewValid) {
      if (origin != null) _replaceState(origin);
      return false;
    }

    final dirty = componentIds.any((componentId) {
      final beforeComponent = _componentForId(origin, componentId);
      final afterComponent = _componentForId(after, componentId);
      return beforeComponent == null ||
          afterComponent == null ||
          beforeComponent.position != afterComponent.position;
    });
    if (!dirty) {
      _replaceState(origin);
      return false;
    }

    history.execute(
      _ReplaceEditorStateCommand(
        before: origin,
        after: after,
        label: componentIds.length == 1
            ? 'Move component with connected routes'
            : 'Move component group with connected routes',
      ),
    );
    notifyListeners();
    return true;
  }

'''
text = text[:start] + new_commit + text[end:]

marker = '''  static ElectricalCableRoute _routeWithSegment(
'''
helper = '''  static ElectricalCableRoute _translateRoute(
    ElectricalCableRoute route, {
    required int dxMm,
    required int dyMm,
  }) =>
      ElectricalCableRoute(
        id: route.id,
        source: route.source,
        target: route.target,
        segments: [
          for (final segment in route.segments)
            ElectricalRouteSegment(
              surface: segment.surface,
              points: List.unmodifiable([
                for (final point in segment.points)
                  SurfacePointMm(point.xMm + dxMm, point.yMm + dyMm),
              ]),
            ),
        ],
        cableType: route.cableType,
        medium: route.medium,
        reservePercent: route.reservePercent,
      );

'''
if marker not in text:
    raise SystemExit('route helper insertion anchor not found')
text = text.replace(marker, helper + marker, 1)

old_valid = '''  bool _movePreviewValidState(EditorP2State preview, String componentId) {
    for (final route in preview.routes) {
      if (route.source.componentId != componentId &&
          route.target.componentId != componentId) {
        continue;
      }
      if (!ElectricalConnectivityValidator.routeIsConnected(
            route: route,
            components: preview.components,
          ) ||
          !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
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
new_valid = '''  bool _movePreviewValidState(
    EditorP2State preview,
    Set<String> componentIds,
  ) {
    for (final route in preview.routes) {
      if (!componentIds.contains(route.source.componentId) &&
          !componentIds.contains(route.target.componentId)) {
        continue;
      }
      if (!ElectricalConnectivityValidator.routeIsConnected(
            route: route,
            components: preview.components,
          ) ||
          !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
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
    _moveComponentIds = const <String>{};
    _movePreviewValid = false;
  }
'''
if old_valid not in text:
    raise SystemExit('move validation anchor not found')
text = text.replace(old_valid, new_valid, 1)
p.write_text(text)

Path('test/f08_group_transform_test.dart').write_text('''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-f08', 0);
  final context = RouteNormativeContext(
    surface: surface,
    widthMm: 6000,
    heightMm: 3000,
    edgeClearanceMm: 0,
  );

  test('F08 group transform moves components and internal route atomically', () {
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
    final before = p2.state;
    final routeBefore = before.routes.single;
    final depthBefore = p2.history.undoDepth;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(2800, 1700)),
      isTrue,
    );
    expect(
      p2.components.firstWhere((item) => item.id == source.id).position,
      const SurfacePointMm(800, 700),
    );
    expect(
      p2.components.firstWhere((item) => item.id == target.id).position,
      const SurfacePointMm(2800, 1700),
    );
    final routePreview = p2.routes.single;
    for (var s = 0; s < routeBefore.segments.length; s++) {
      for (var i = 0; i < routeBefore.segments[s].points.length; i++) {
        final oldPoint = routeBefore.segments[s].points[i];
        expect(
          routePreview.segments[s].points[i],
          SurfacePointMm(oldPoint.xMm + 300, oldPoint.yMm + 200),
        );
      }
    }
    expect(p2.history.undoDepth, depthBefore);

    expect(p2.commitMoveSelectedComponent(), isTrue);
    expect(p2.history.undoDepth, depthBefore + 1);
    p2.undo();
    expect(
      p2.components.firstWhere((item) => item.id == source.id).position,
      source.position,
    );
    expect(
      p2.components.firstWhere((item) => item.id == target.id).position,
      target.position,
    );
    expect(
      p2.routes.single.segments.single.points,
      routeBefore.segments.single.points,
    );
  });

  test('F08 group cancel restores all components and routes exactly', () {
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(700, 600),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2700, 1400),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final before = p2.state;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1600)),
      isTrue,
    );
    p2.cancelMoveSelectedComponent();

    expect(
      p2.components.map((item) => item.position).toList(),
      before.components.map((item) => item.position).toList(),
    );
    expect(
      p2.routes.single.segments.single.points,
      before.routes.single.segments.single.points,
    );
  });

  test('F08 cross-surface group transform fails closed', () {
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final a = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(700, 600),
    );
    final b = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall('room-f08', 1),
      position: const SurfacePointMm(900, 600),
    );
    p2.select(a.id, mode: SelectionMode.replace);
    p2.select(b.id, mode: SelectionMode.add);

    expect(p2.beginMoveSelectedComponent(), isFalse);
    expect(p2.isManipulating, isFalse);
  });
}
''')
