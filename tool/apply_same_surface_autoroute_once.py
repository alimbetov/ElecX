from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, got {count}')
    p.write_text(text.replace(old, new, 1))

p = 'lib/src/features/editor/editor_p2_session.dart'
replace_once(
    p,
    '''    if (sourceComponent.surface == targetComponent.surface) {\n      final surface = sourceComponent.surface;\n      final a = sourceComponent.position;\n      final d = targetComponent.position;\n      final elbowX = SurfacePointMm(d.xMm, a.yMm);\n      final elbowY = SurfacePointMm(a.xMm, d.yMm);\n      graph = RoutingGraph(''',
    '''    if (sourceComponent.surface == targetComponent.surface) {\n      final surface = sourceComponent.surface;\n      final context = _routeContextResolver?.call(surface);\n      if (context != null) {\n        final candidates = NormativeRouteEngine.buildCandidates(\n          source: sourceComponent.position,\n          target: targetComponent.position,\n          context: context,\n        );\n        RouteCandidate? best;\n        for (final candidate in candidates) {\n          if (candidate.validation.isValid) {\n            best = candidate;\n            break;\n          }\n        }\n        if (best == null) return false;\n        return _addRouteSegments(\n          source: ElectricalEndpointRef(\n            componentId: sourceComponent.id,\n            portId: sourcePort.id,\n          ),\n          target: ElectricalEndpointRef(\n            componentId: targetComponent.id,\n            portId: targetPort.id,\n          ),\n          segments: [\n            ElectricalRouteSegment(surface: surface, points: best.points),\n          ],\n          cableType: cableType,\n        );\n      }\n\n      // Context-free sessions retain the deterministic two-elbow fallback used\n      // by low-level engine tests. Production EditorController sessions always\n      // provide routeContextResolver and therefore use the guarded router above.\n      final a = sourceComponent.position;\n      final d = targetComponent.position;\n      final elbowX = SurfacePointMm(d.xMm, a.yMm);\n      final elbowY = SurfacePointMm(a.xMm, d.yMm);\n      graph = RoutingGraph(''',
    'same-surface guarded routing',
)

replace_once(
    p,
    '''    final routeId = _nextAvailableId(\n      prefix: 'route-',\n      initialSequence: _routeSequence,\n      existingIds: routes.map((item) => item.id).toSet(),\n    );\n    _routeSequence = routeId.$2;\n    final route = ElectricalCableRoute(\n      id: routeId.$1,\n      source: source,\n      target: target,\n      segments: RouteEngine.toSegments(graph, solution),\n      cableType: cableType,\n    );\n    if (!ElectricalConnectivityValidator.routeIsConnected(\n          route: route,\n          components: components,\n        ) ||\n        !_routeGeometryIsValid(route)) {\n      return false;\n    }\n    history.execute(_AddRouteCommand(route));\n    notifyListeners();\n    return true;''',
    '''    return _addRouteSegments(\n      source: source,\n      target: target,\n      segments: RouteEngine.toSegments(graph, solution),\n      cableType: cableType,\n    );''',
    'centralize add auto route',
)

replace_once(
    p,
    '''  List<ManipulationHandle> handlesForSelection() {''',
    '''  bool _addRouteSegments({\n    required ElectricalEndpointRef source,\n    required ElectricalEndpointRef target,\n    required List<ElectricalRouteSegment> segments,\n    String? cableType,\n  }) {\n    if (layers.isLocked(EditorLayerId.cableRoutes)) return false;\n    final routeId = _nextAvailableId(\n      prefix: 'route-',\n      initialSequence: _routeSequence,\n      existingIds: routes.map((item) => item.id).toSet(),\n    );\n    final route = ElectricalCableRoute(\n      id: routeId.$1,\n      source: source,\n      target: target,\n      segments: segments,\n      cableType: cableType,\n    );\n    if (!ElectricalConnectivityValidator.routeIsConnected(\n          route: route,\n          components: components,\n        ) ||\n        !_routeGeometryIsValid(route)) {\n      return false;\n    }\n    _routeSequence = routeId.$2;\n    history.execute(_AddRouteCommand(route));\n    notifyListeners();\n    return true;\n  }\n\n  List<ManipulationHandle> handlesForSelection() {''',
    'add route segments helper',
)

p = 'test/editor_p2_session_test.dart'
text = Path(p).read_text()
import_anchor = "import 'package:elecx/src/engine/editor_layers.dart';\n"
if text.count(import_anchor) != 1:
    raise RuntimeError('editor session import anchor mismatch')
text = text.replace(
    import_anchor,
    import_anchor + "import 'package:elecx/src/engine/normative_route_engine.dart';\n",
    1,
)
insert_before = "  test('wall source can auto-route to ceiling load through topology', () {"
if text.count(insert_before) != 1:
    raise RuntimeError('editor session test anchor mismatch')
new_test = r'''  test('same-surface AUTO uses project context to detour around opening', () {
    late final RouteNormativeContext context;
    final session = EditorP2Session(
      routeContextResolver: (surface) {
        context = RouteNormativeContext(
          surface: surface,
          widthMm: 3500,
          heightMm: 2500,
          edgeClearanceMm: 0,
          obstacles: const [
            RouteObstacleMm(
              id: 'window',
              leftMm: 1400,
              topMm: 700,
              rightMm: 2100,
              bottomMm: 1300,
            ),
          ],
        );
        return context;
      },
    );
    addTearDown(session.dispose);

    final source = session.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(500, 1000),
    );
    final target = session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(3000, 1000),
    );
    session.select(source.id, mode: SelectionMode.replace);
    session.select(target.id, mode: SelectionMode.add);

    expect(session.autoRouteSelectedPair(), isTrue);
    final route = session.routes.single;
    final points = route.segments.single.points;
    expect(points.length, greaterThanOrEqualTo(4));
    expect(
      NormativeRouteEngine.validate(points: points, context: context).isValid,
      isTrue,
    );
    expect(points.any((point) => point.yMm != 1000), isTrue);
  });

'''
Path(p).write_text(text.replace(insert_before, new_test + insert_before, 1))
