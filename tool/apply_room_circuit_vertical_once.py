from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1))


# Editor state + atomic board/load connection.
path = 'lib/src/features/editor/editor_p2_session.dart'
replace_once(path,
"import '../../domain/electrical_placement.dart';\n",
"import '../../domain/cable_identity.dart';\nimport '../../domain/circuit_cable_registry.dart';\nimport '../../domain/electrical_placement.dart';\n")
replace_once(path,
"    this.routeConstraints = const {},\n  });\n\n  final List<ElectricalComponentPlacement> components;\n  final List<ElectricalCableRoute> routes;\n  final SelectionState selection;\n  final Map<String, CableRouteConstraints> routeConstraints;\n",
"    this.routeConstraints = const {},\n    this.circuitBundles = const [],\n  });\n\n  final List<ElectricalComponentPlacement> components;\n  final List<ElectricalCableRoute> routes;\n  final SelectionState selection;\n  final Map<String, CableRouteConstraints> routeConstraints;\n  final List<CircuitCableBundle> circuitBundles;\n")
replace_once(path,
"    Map<String, CableRouteConstraints>? routeConstraints,\n  }) =>\n      EditorP2State(\n        components: components ?? this.components,\n        routes: routes ?? this.routes,\n        selection: selection ?? this.selection,\n        routeConstraints: routeConstraints ?? this.routeConstraints,\n      );\n",
"    Map<String, CableRouteConstraints>? routeConstraints,\n    List<CircuitCableBundle>? circuitBundles,\n  }) =>\n      EditorP2State(\n        components: components ?? this.components,\n        routes: routes ?? this.routes,\n        selection: selection ?? this.selection,\n        routeConstraints: routeConstraints ?? this.routeConstraints,\n        circuitBundles: circuitBundles ?? this.circuitBundles,\n      );\n")
replace_once(path,
"  CableRouteConstraints routeConstraintsFor(String routeId) =>\n      state.routeConstraints[routeId] ?? CableRouteConstraints.empty;\n",
"  CableRouteConstraints routeConstraintsFor(String routeId) =>\n      state.routeConstraints[routeId] ?? CableRouteConstraints.empty;\n\n  CircuitCableBundle? circuitBundleForRoute(String routeId) {\n    for (final bundle in state.circuitBundles) {\n      if (bundle.cable.routeId == routeId) return bundle;\n    }\n    return null;\n  }\n\n  CircuitCableBundle? circuitBundleForLoad(String componentId) {\n    for (final bundle in state.circuitBundles) {\n      if (bundle.cable.endB.componentId == componentId) return bundle;\n    }\n    return null;\n  }\n")
old_delete = """  bool deleteSelection() {
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
"""
new_delete = """  bool deleteSelection() {
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
"""
replace_once(path, old_delete, new_delete)
anchor = """  bool autoRouteSelectedPair({EngineeringSpace? space, String? cableType}) {
"""
method = """  CircuitCableBundle? connectLoadToBoard({
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

"""
replace_once(path, anchor, method + anchor)
# Replace auto-route method with shared segment builder use.
start = Path(path).read_text().index("  bool autoRouteSelectedPair({EngineeringSpace? space, String? cableType}) {")
end = Path(path).read_text().index("\n  bool _addRouteSegments({", start)
text = Path(path).read_text()
old = text[start:end]
new = """  bool autoRouteSelectedPair({EngineeringSpace? space, String? cableType}) {
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
              ElectricalRouteSegment(surface: surface, points: candidate.points),
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
"""
Path(path).write_text(text[:start] + new + text[end:])

# Persistence schema v3 and bundle codec.
path = 'lib/src/features/editor/project_schema_migrator.dart'
replace_once(path, '  static const int currentSchemaVersion = 2;\n', '  static const int currentSchemaVersion = 3;\n')
replace_once(path,
"        1 => _v1ToV2(result, legacyTimestamp: legacyTimestamp),\n",
"        1 => _v1ToV2(result, legacyTimestamp: legacyTimestamp),\n        2 => _v2ToV3(result),\n")
replace_once(path,
"  static Map<String, Object?> _v1ToV2(\n",
"  static Map<String, Object?> _v2ToV3(Map<String, Object?> source) {\n    final p2Raw = source['p2'];\n    if (p2Raw is! Map) {\n      throw const FormatException('p2 must be an object for schema v2.');\n    }\n    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));\n    return <String, Object?>{\n      ...source,\n      'schemaVersion': 3,\n      'p2': <String, Object?>{...p2, 'circuitBundles': const <Object?>[]},\n    };\n  }\n\n  static Map<String, Object?> _v1ToV2(\n")

path = 'lib/src/features/editor/editor_project_document.dart'
replace_once(path,
"import '../../domain/building_composition.dart';\n",
"import '../../domain/building_composition.dart';\nimport '../../domain/cable_identity.dart';\nimport '../../domain/circuit_cable_registry.dart';\n")
replace_once(path,
"      'routeConstraints': {\n        for (final entry in value.routeConstraints.entries)\n          entry.key: entry.value.toJson(),\n      },\n    };\n",
"      'routeConstraints': {\n        for (final entry in value.routeConstraints.entries)\n          entry.key: entry.value.toJson(),\n      },\n      'circuitBundles': [\n        for (final bundle in value.circuitBundles) _circuitBundleToJson(bundle),\n      ],\n    };\n")
replace_once(path,
"    routeConstraints: Map.unmodifiable({\n      for (final entry in constraints.entries)\n        entry.key: CableRouteConstraints.fromJson(\n          _map(entry.value, 'routeConstraints.${entry.key}'),\n        ),\n    }),\n  );\n}\n",
"    routeConstraints: Map.unmodifiable({\n      for (final entry in constraints.entries)\n        entry.key: CableRouteConstraints.fromJson(\n          _map(entry.value, 'routeConstraints.${entry.key}'),\n        ),\n    }),\n    circuitBundles: [\n      for (final item in _list(json['circuitBundles'], 'p2.circuitBundles'))\n        _circuitBundleFromJson(_map(item, 'circuitBundle')),\n    ],\n  );\n}\n\nMap<String, Object?> _circuitBundleToJson(CircuitCableBundle value) => {\n      'circuit': {\n        'id': value.circuit.id,\n        'name': value.circuit.name,\n        'boardId': value.circuit.boardId,\n        'protectiveDeviceId': value.circuit.protectiveDeviceId,\n      },\n      'cable': {\n        'id': value.cable.id,\n        'routeId': value.cable.routeId,\n        'circuitId': value.cable.circuitId,\n        'designation': value.cable.designation,\n        'cableSpecId': value.cable.cableSpecId,\n        'endA': _terminationToJson(value.cable.endA),\n        'endB': _terminationToJson(value.cable.endB),\n      },\n      'protectiveDevice': value.protectiveDevice == null\n          ? null\n          : {\n              'id': value.protectiveDevice!.id,\n              'boardId': value.protectiveDevice!.boardId,\n              'designation': value.protectiveDevice!.designation,\n              'poleCount': value.protectiveDevice!.poleCount,\n              'ratedCurrentA': value.protectiveDevice!.ratedCurrentA,\n            },\n    };\n\nCircuitCableBundle _circuitBundleFromJson(Map<String, Object?> json) {\n  final circuitJson = _map(json['circuit'], 'circuitBundle.circuit');\n  final cableJson = _map(json['cable'], 'circuitBundle.cable');\n  final deviceRaw = json['protectiveDevice'];\n  final circuit = CircuitRef(\n    id: _string(circuitJson['id'], 'circuit.id'),\n    name: _string(circuitJson['name'], 'circuit.name'),\n    boardId: _nullableString(circuitJson['boardId']),\n    protectiveDeviceId: _nullableString(circuitJson['protectiveDeviceId']),\n  );\n  final cable = CableIdentity(\n    id: _string(cableJson['id'], 'cable.id'),\n    routeId: _string(cableJson['routeId'], 'cable.routeId'),\n    circuitId: _string(cableJson['circuitId'], 'cable.circuitId'),\n    designation: _string(cableJson['designation'], 'cable.designation'),\n    cableSpecId: _nullableString(cableJson['cableSpecId']),\n    endA: _terminationFromJson(_map(cableJson['endA'], 'cable.endA')),\n    endB: _terminationFromJson(_map(cableJson['endB'], 'cable.endB')),\n  );\n  final protectiveDevice = deviceRaw == null\n      ? null\n      : () {\n          final device = _map(deviceRaw, 'circuitBundle.protectiveDevice');\n          return ProtectiveDeviceRef(\n            id: _string(device['id'], 'protectiveDevice.id'),\n            boardId: _string(device['boardId'], 'protectiveDevice.boardId'),\n            designation:\n                _string(device['designation'], 'protectiveDevice.designation'),\n            poleCount: device['poleCount'] == null\n                ? null\n                : _int(device['poleCount'], 'protectiveDevice.poleCount'),\n            ratedCurrentA: device['ratedCurrentA'] == null\n                ? null\n                : _double(\n                    device['ratedCurrentA'],\n                    'protectiveDevice.ratedCurrentA',\n                  ),\n          );\n        }();\n  return CircuitCableBundle(\n    circuit: circuit,\n    cable: cable,\n    protectiveDevice: protectiveDevice,\n  );\n}\n\nMap<String, Object?> _terminationToJson(CableTerminationRef value) => {\n      'componentId': value.componentId,\n      'portId': value.portId,\n      'terminalId': value.terminalId,\n    };\n\nCableTerminationRef _terminationFromJson(Map<String, Object?> json) =>\n    CableTerminationRef(\n      componentId: _string(json['componentId'], 'termination.componentId'),\n      portId: _string(json['portId'], 'termination.portId'),\n      terminalId: _nullableString(json['terminalId']),\n    );\n")

# Structured save validation for persisted circuit evidence.
path = 'lib/src/features/editor/project_save_diagnostics.dart'
replace_once(path,
"import '../../domain/electrical_placement.dart';\n",
"import '../../domain/circuit_cable_registry.dart';\nimport '../../domain/electrical_placement.dart';\n")
replace_once(path,
"  disconnectedRoute,\n}\n",
"  disconnectedRoute,\n  missingCircuitRoute,\n  invalidCircuitAssignment,\n}\n")
replace_once(path,
"    for (final route in editor.p2.routes) {\n",
"    final routes = {for (final route in editor.p2.routes) route.id: route};\n    for (final route in editor.p2.routes) {\n")
replace_once(path,
"    return List.unmodifiable(issues);\n  }\n",
"    final registry = CircuitCableRegistry();\n    for (final bundle in editor.p2.state.circuitBundles) {\n      final route = routes[bundle.cable.routeId];\n      if (route == null) {\n        issues.add(\n          EditorProjectSaveIssue(\n            code: EditorProjectSaveIssueCode.missingCircuitRoute,\n            title: 'Инженерная группа потеряла кабельную трассу',\n            detail:\n                'Группа ${bundle.circuit.id} ссылается на отсутствующую трассу ${bundle.cable.routeId}. Переподключите нагрузку к щиту.',\n            routeId: bundle.cable.routeId,\n          ),\n        );\n        continue;\n      }\n      try {\n        registry.registerBundle(\n          route: route,\n          circuit: bundle.circuit,\n          cable: bundle.cable,\n          protectiveDevice: bundle.protectiveDevice,\n        );\n      } catch (error) {\n        issues.add(\n          EditorProjectSaveIssue(\n            code: EditorProjectSaveIssueCode.invalidCircuitAssignment,\n            title: 'Нарушена целостность электрической группы',\n            detail:\n                'Группа ${bundle.circuit.id}: $error Исправьте подключение нагрузки к щиту перед сохранением.',\n            routeId: route.id,\n          ),\n        );\n      }\n    }\n    return List.unmodifiable(issues);\n  }\n")

# User-facing circuit panel.
Path('lib/src/features/editor/room_circuit_panel.dart').write_text(r'''import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/project_model.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

class RoomCircuitPanel extends StatelessWidget {
  const RoomCircuitPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return AnimatedBuilder(
      animation: p2,
      builder: (context, _) {
        final selected = p2.selectedComponent;
        if (selected == null) {
          return const _CircuitCard(
            title: 'Электрическая группа',
            body: 'Выберите нагрузку, чтобы подключить её к щиту.',
          );
        }
        if (selected.type == ElectricalComponentType.distributionBoard) {
          return _CircuitCard(
            title: selected.label,
            body: 'Щит готов как источник групп. Выберите нагрузку в комнате.',
          );
        }
        final bundle = p2.circuitBundleForLoad(selected.id);
        if (bundle != null) {
          final board = p2.components
              .where((item) => item.id == bundle.circuit.boardId)
              .firstOrNull;
          return Card(
            key: const ValueKey('room-circuit-status'),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Электрическая группа',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Нагрузка: ${selected.label}'),
                  Text('Щит: ${board?.label ?? bundle.circuit.boardId ?? '—'}'),
                  Text('Группа: ${bundle.circuit.name}'),
                  Text('Кабель: ${bundle.cable.designation}'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bundle.protectiveDevice == null
                              ? 'Защита не назначена — требуется подбор автомата.'
                              : 'Защита: ${bundle.protectiveDevice!.designation}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final boards = p2.components
            .where(
              (item) =>
                  item.type == ElectricalComponentType.distributionBoard &&
                  item.surface.spaceId == selected.surface.spaceId,
            )
            .toList(growable: false);
        if (boards.isEmpty) {
          return const _CircuitCard(
            title: 'Электрическая группа',
            body: 'В этой комнате нет щита. Разместите щит из каталога.',
          );
        }
        final space = _spaceById(selected.surface.spaceId);
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Подключить к щиту',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(selected.label),
                const SizedBox(height: 8),
                for (final board in boards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FilledButton.tonalIcon(
                      key: ValueKey('connect-load-to-board-${board.id}'),
                      onPressed: space == null
                          ? null
                          : () {
                              final bundle = p2.connectLoadToBoard(
                                loadComponentId: selected.id,
                                boardComponentId: board.id,
                                space: space,
                              );
                              final messenger = ScaffoldMessenger.of(context);
                              messenger
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      bundle == null
                                          ? 'Не удалось построить допустимую трассу до щита.'
                                          : 'Нагрузка подключена к ${board.label}.',
                                    ),
                                  ),
                                );
                            },
                      icon: const Icon(Icons.electrical_services_outlined),
                      label: Text(board.label),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  EngineeringSpace? _spaceById(String spaceId) {
    for (final space in controller.level.spaces) {
      if (space.id == spaceId) return space;
    }
    return null;
  }
}

class _CircuitCard extends StatelessWidget {
  const _CircuitCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
''')

path = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
replace_once(path,
"import 'project_save_diagnostics.dart';\n",
"import 'project_save_diagnostics.dart';\nimport 'room_circuit_panel.dart';\n")
replace_once(path,
"                      child: SafeArea(\n                        child: DeviceCatalogPanel(controller: controller),\n                      ),\n",
"                      child: SafeArea(\n                        child: Column(\n                          children: [\n                            RoomCircuitPanel(controller: controller),\n                            const Divider(height: 1),\n                            Expanded(\n                              child: DeviceCatalogPanel(controller: controller),\n                            ),\n                          ],\n                        ),\n                      ),\n")
replace_once(path,
"          const Divider(height: 1),\n          Expanded(child: DeviceCatalogPanel(controller: controller)),\n",
"          const Divider(height: 1),\n          RoomCircuitPanel(controller: controller),\n          const Divider(height: 1),\n          Expanded(child: DeviceCatalogPanel(controller: controller)),\n")

# Persistence expectation now migrates all the way to v3.
path = 'test/editor_project_persistence_test.dart'
replace_once(path,
"  test('schema v1 migrates to v2 metadata without losing project identity', () {\n",
"  test('schema v1 migrates through v3 without losing project identity', () {\n")
replace_once(path,
"    expect(decoded.schemaVersion, 2);\n",
"    expect(decoded.schemaVersion, 3);\n")

# Functional vertical-slice regressions.
Path('test/room_circuit_workflow_test.dart').write_text(r'''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/room_circuit_panel.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected load connects to board as one engineering transaction', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    final depthBefore = editor.p2.history.undoDepth;

    final bundle = editor.p2.connectLoadToBoard(
      loadComponentId: load.id,
      boardComponentId: board.id,
      space: editor.selectedSpace,
    );

    expect(bundle, isNotNull);
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.state.circuitBundles, hasLength(1));
    expect(bundle!.circuit.boardId, board.id);
    expect(bundle.cable.endB.componentId, load.id);
    expect(bundle.protectiveDevice, isNull);
    expect(editor.p2.history.undoDepth, depthBefore + 1);

    editor.p2.undo();
    expect(editor.p2.routes, isEmpty);
    expect(editor.p2.state.circuitBundles, isEmpty);
    editor.p2.redo();
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.state.circuitBundles, hasLength(1));
  });

  test('circuit bundle survives canonical save and reopen', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.lightingPoint,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    expect(
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      ),
      isNotNull,
    );

    final encoded = EditorProjectDocument.capture(workspace).toJson();
    final decoded = EditorProjectDocument.fromJson(encoded);
    final restored = decoded.restore();
    addTearDown(() {
      restored.editor.disposeP2State();
      restored.workspace.dispose();
      restored.editor.dispose();
    });
    expect(restored.editor.p2.routes, hasLength(1));
    expect(restored.editor.p2.state.circuitBundles, hasLength(1));
    expect(restored.editor.p2.circuitBundleForLoad(load.id), isNotNull);
  });

  test('deleting a connected load removes route and circuit atomically', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    expect(
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      ),
      isNotNull,
    );
    editor.p2.select(load.id, mode: SelectionMode.replace);
    expect(editor.p2.deleteSelection(), isTrue);
    expect(editor.p2.routes, isEmpty);
    expect(editor.p2.state.circuitBundles, isEmpty);
    expect(editor.p2.components.any((item) => item.id == load.id), isFalse);

    editor.p2.undo();
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.state.circuitBundles, hasLength(1));
    expect(editor.p2.components.any((item) => item.id == load.id), isTrue);
  });

  test('schema v2 migrates with empty circuit bundle list', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final current = EditorProjectDocument.capture(workspace).toJson();
    final legacyP2 = Map<String, Object?>.from(current['p2']! as Map)
      ..remove('circuitBundles');
    final legacy = Map<String, Object?>.from(current)
      ..['schemaVersion'] = 2
      ..['p2'] = legacyP2;

    final decoded = EditorProjectDocument.fromJson(legacy);
    expect(decoded.schemaVersion, 3);
    expect(decoded.p2State.circuitBundles, isEmpty);
  });

  testWidgets('circuit panel connects selected load and exposes incomplete protection',
      (tester) async {
    final editor = EditorController.demo();
    addTearDown(() {
      editor.disposeP2State();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    editor.p2.select(load.id);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RoomCircuitPanel(controller: editor)),
      ),
    );
    await tester.pump();
    expect(find.byKey(ValueKey('connect-load-to-board-${board.id}')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('connect-load-to-board-${board.id}')));
    await tester.pump();
    expect(editor.p2.state.circuitBundles, hasLength(1));
    expect(find.textContaining('Защита не назначена'), findsOneWidget);
  });
}
''')
