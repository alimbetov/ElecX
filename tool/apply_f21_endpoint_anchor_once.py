from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:140]!r}')
    p.write_text(text.replace(old, new, 1))

# Domain invariant: semantic endpoints must also be physically anchored to the
# referenced component surface/position (current port anchor contract).
replace_once(
    'lib/src/domain/electrical_routing.dart',
    "  static bool routeIsConnected({\n    required ElectricalCableRoute route,\n    required Iterable<ElectricalComponentPlacement> components,\n  }) {\n",
    "  static bool routeIsPhysicallyAnchored({\n    required ElectricalCableRoute route,\n    required Iterable<ElectricalComponentPlacement> components,\n  }) {\n    if (route.segments.isEmpty ||\n        route.segments.first.points.isEmpty ||\n        route.segments.last.points.isEmpty) {\n      return false;\n    }\n    ElectricalComponentPlacement? sourceComponent;\n    ElectricalComponentPlacement? targetComponent;\n    for (final component in components) {\n      if (component.id == route.source.componentId) sourceComponent = component;\n      if (component.id == route.target.componentId) targetComponent = component;\n    }\n    if (sourceComponent == null || targetComponent == null) return false;\n    return route.segments.first.surface == sourceComponent.surface &&\n        route.segments.first.points.first == sourceComponent.position &&\n        route.segments.last.surface == targetComponent.surface &&\n        route.segments.last.points.last == targetComponent.position;\n  }\n\n  static bool routeIsConnected({\n    required ElectricalCableRoute route,\n    required Iterable<ElectricalComponentPlacement> components,\n  }) {\n",
)

# All route writes must satisfy both semantic and physical connectivity.
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "    if (!ElectricalConnectivityValidator.routeIsConnected(\n      route: after,\n      components: components,\n    )) {\n      return false;\n    }\n",
    "    if (!ElectricalConnectivityValidator.routeIsConnected(\n          route: after,\n          components: components,\n        ) ||\n        !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(\n          route: after,\n          components: components,\n        )) {\n      return false;\n    }\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "    if (!ElectricalConnectivityValidator.routeIsConnected(\n          route: route,\n          components: components,\n        ) ||\n        !_routeGeometryIsValid(route)) {\n",
    "    if (!ElectricalConnectivityValidator.routeIsConnected(\n          route: route,\n          components: components,\n        ) ||\n        !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(\n          route: route,\n          components: components,\n        ) ||\n        !_routeGeometryIsValid(route)) {\n",
)
# Legacy direct move is safe only for an unconnected component. Connected
# components must use ComponentTransformSession, which reroutes atomically.
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "    if (component == null ||\n        layers.isLocked(EditorLayerId.electrical) ||\n        (layers.isLocked(EditorLayerId.cableRoutes) &&\n            _componentHasConnectedRoutes(component.id))) {\n",
    "    if (component == null ||\n        layers.isLocked(EditorLayerId.electrical) ||\n        _componentHasConnectedRoutes(component.id)) {\n",
)
# Preview commit validation also requires physical anchors after reroute.
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "      if (!ElectricalConnectivityValidator.routeIsConnected(\n            route: route,\n            components: preview.components,\n          ) ||\n          !_routeGeometryIsValid(route)) {\n",
    "      if (!ElectricalConnectivityValidator.routeIsConnected(\n            route: route,\n            components: preview.components,\n          ) ||\n          !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(\n            route: route,\n            components: preview.components,\n          ) ||\n          !_routeGeometryIsValid(route)) {\n",
)

# Save/imported-state diagnostics fail closed on detached physical endpoints.
replace_once(
    'lib/src/features/editor/project_save_diagnostics.dart',
    "      if (route.segments.isEmpty) {\n        issues.add(\n          EditorProjectSaveIssue(\n            code: EditorProjectSaveIssueCode.disconnectedRoute,\n            title: 'У кабеля отсутствует геометрия трассы',\n            detail:\n                'Трасса ${route.id} подключена семантически, но не содержит ни одного физического сегмента. Постройте трассу заново.',\n            routeId: route.id,\n          ),\n        );\n      }\n",
    "      if (route.segments.isEmpty) {\n        issues.add(\n          EditorProjectSaveIssue(\n            code: EditorProjectSaveIssueCode.disconnectedRoute,\n            title: 'У кабеля отсутствует геометрия трассы',\n            detail:\n                'Трасса ${route.id} подключена семантически, но не содержит ни одного физического сегмента. Постройте трассу заново.',\n            routeId: route.id,\n          ),\n        );\n        continue;\n      }\n      if (!ElectricalConnectivityValidator.routeIsPhysicallyAnchored(\n        route: route,\n        components: editor.p2.components,\n      )) {\n        issues.add(\n          EditorProjectSaveIssue(\n            code: EditorProjectSaveIssueCode.disconnectedRoute,\n            title: 'Конец кабеля оторван от компонента',\n            detail:\n                'Трасса ${route.id}: физическая точка или поверхность конца не совпадает с подключённым компонентом. Переподключите кабель перед сохранением.',\n            routeId: route.id,\n          ),\n        );\n      }\n",
)

Path('test/f21_endpoint_anchor_invariant_test.dart').write_text(r'''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/project_save_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

ElectricalCableRoute _route({
  required ElectricalComponentPlacement source,
  required ElectricalComponentPlacement target,
  SurfacePointMm? first,
  SurfacePointMm? last,
  RoomSurfaceRef? firstSurface,
  RoomSurfaceRef? lastSurface,
}) {
  return ElectricalCableRoute(
    id: 'route-anchor',
    source: ElectricalEndpointRef(
      componentId: source.id,
      portId: source.ports.firstWhere(
        (port) => port.kind == ElectricalPortKind.powerOut,
      ).id,
    ),
    target: ElectricalEndpointRef(
      componentId: target.id,
      portId: target.ports.firstWhere(
        (port) => port.kind == ElectricalPortKind.powerIn,
      ).id,
    ),
    segments: [
      ElectricalRouteSegment(
        surface: firstSurface ?? source.surface,
        points: [first ?? source.position, const SurfacePointMm(1500, 1000)],
      ),
      ElectricalRouteSegment(
        surface: lastSurface ?? target.surface,
        points: [const SurfacePointMm(1500, 1000), last ?? target.position],
      ),
    ],
  );
}

void main() {
  test('F21 physical anchor validator rejects detached point and wrong surface', () {
    final wall = RoomSurfaceRef.wall('room-1', 0);
    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(200, 1000),
      label: 'Source',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.powerSource,
      ),
    );
    final target = ElectricalComponentPlacement(
      id: 'target',
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(2800, 1000),
      label: 'Target',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    );
    final components = [source, target];

    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: _route(source: source, target: target),
        components: components,
      ),
      isTrue,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: _route(
          source: source,
          target: target,
          first: const SurfacePointMm(300, 1000),
        ),
        components: components,
      ),
      isFalse,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: _route(
          source: source,
          target: target,
          lastSurface: RoomSurfaceRef.wall('room-1', 1),
        ),
        components: components,
      ),
      isFalse,
    );
  });

  test('F21 replace rejects detached geometry before history mutation', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.p2.select(source.id);
    controller.p2.select(target.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final before = controller.p2.routes.single;
    final undoDepth = controller.p2.history.undoDepth;
    final segment = before.segments.single;
    final detached = ElectricalCableRoute(
      id: before.id,
      source: before.source,
      target: before.target,
      segments: [
        ElectricalRouteSegment(
          surface: segment.surface,
          points: [
            const SurfacePointMm(300, 1000),
            ...segment.points.skip(1),
          ],
        ),
      ],
      cableType: before.cableType,
      medium: before.medium,
      reservePercent: before.reservePercent,
    );

    expect(controller.p2.replaceCableRoute(before, detached), isFalse);
    expect(controller.p2.history.undoDepth, undoDepth);
    expect(controller.p2.routes.single.segments.first.points.first, source.position);
  });

  test('F21 legacy direct move rejects connected component', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.p2.select(source.id);
    controller.p2.select(target.id, mode: SelectionMode.add);
    expect(controller.p2.autoRouteSelectedPair(space: controller.selectedSpace), isTrue);
    controller.p2.select(source.id);

    expect(
      controller.p2.moveSelectedComponent(const SurfacePointMm(500, 1000)),
      isFalse,
    );
    expect(controller.p2.selectedComponent!.position, source.position);
    expect(controller.p2.routes.single.segments.first.points.first, source.position);
  });

  test('F21 save diagnostics reject imported detached endpoint geometry', () {
    final controller = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(controller);
    addTearDown(() {
      workspace.dispose();
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    final broken = _route(
      source: source,
      target: target,
      first: const SurfacePointMm(300, 1000),
    );
    controller.p2.history.replaceState(
      controller.p2.state.copyWith(routes: [broken]),
      clearHistory: false,
    );

    final issues = EditorProjectSaveDiagnostics.validate(workspace);
    expect(
      issues.any((issue) =>
          issue.code == EditorProjectSaveIssueCode.disconnectedRoute &&
          issue.routeId == broken.id),
      isTrue,
    );
  });
}
''')
