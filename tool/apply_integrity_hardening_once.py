from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, got {count}')
    return text.replace(old, new, 1)

# 1/2. Semantic port compatibility is a domain invariant, not a UI heuristic.
p = 'lib/src/domain/electrical_routing.dart'
text = read(p)
start = text.index('abstract final class ElectricalConnectivityValidator')
new_tail = r'''abstract final class ElectricalPortCompatibility {
  static bool areCompatible(
    ElectricalPortKind source,
    ElectricalPortKind target,
  ) =>
      switch (source) {
        ElectricalPortKind.powerOut => target == ElectricalPortKind.powerIn,
        ElectricalPortKind.controlOut => target == ElectricalPortKind.controlIn,
        _ => false,
      };

  static ElectricalPortDefinition? portForEndpoint({
    required ElectricalEndpointRef endpoint,
    required Iterable<ElectricalComponentPlacement> components,
  }) {
    for (final component in components) {
      if (component.id != endpoint.componentId) continue;
      for (final port in component.ports) {
        if (port.id == endpoint.portId) return port;
      }
      return null;
    }
    return null;
  }
}

abstract final class ElectricalConnectivityValidator {
  static bool endpointExists({
    required ElectricalEndpointRef endpoint,
    required Iterable<ElectricalComponentPlacement> components,
  }) =>
      ElectricalPortCompatibility.portForEndpoint(
        endpoint: endpoint,
        components: components,
      ) !=
      null;

  static bool routeIsConnected({
    required ElectricalCableRoute route,
    required Iterable<ElectricalComponentPlacement> components,
  }) {
    if (route.segments.isEmpty) return false;
    final source = ElectricalPortCompatibility.portForEndpoint(
      endpoint: route.source,
      components: components,
    );
    final target = ElectricalPortCompatibility.portForEndpoint(
      endpoint: route.target,
      components: components,
    );
    return source != null &&
        target != null &&
        ElectricalPortCompatibility.areCompatible(source.kind, target.kind);
  }
}
'''
write(p, text[:start] + new_tail)

p = 'lib/src/engine/port_snap_resolver.dart'
text = read(p)
text = replace_once(
    text,
    "import '../domain/electrical_placement.dart';\n",
    "import '../domain/electrical_placement.dart';\nimport '../domain/electrical_routing.dart';\n",
    'port resolver import',
)
text = replace_once(
    text,
    '''    required CableEndpointRole role,\n    String? excludeComponentId,\n  }) {''',
    '''    required CableEndpointRole role,\n    String? excludeComponentId,\n    ElectricalPortKind? counterpartKind,\n  }) {''',
    'port resolver signature',
)
text = replace_once(
    text,
    '''      for (final port in component.ports) {\n        if (!_compatible(port.kind, role)) continue;\n        anchors.add(''',
    '''      for (final port in component.ports) {\n        if (!_compatible(port.kind, role)) continue;\n        if (counterpartKind != null) {\n          final pairCompatible = role == CableEndpointRole.source\n              ? ElectricalPortCompatibility.areCompatible(\n                  port.kind,\n                  counterpartKind,\n                )\n              : ElectricalPortCompatibility.areCompatible(\n                  counterpartKind,\n                  port.kind,\n                );\n          if (!pairCompatible) continue;\n        }\n        anchors.add(''',
    'port resolver pair filter',
)
write(p, text)

p = 'lib/src/features/editor/cable_endpoint_transform_session.dart'
text = read(p)
text = replace_once(
    text,
    '''    final fixedComponentId = role == CableEndpointRole.target\n        ? origin.source.componentId\n        : origin.target.componentId;\n    final anchors = PortSnapResolver.anchorsFor(''',
    '''    final fixedEndpoint = role == CableEndpointRole.target\n        ? origin.source\n        : origin.target;\n    final fixedComponentId = fixedEndpoint.componentId;\n    final counterpartKind = _portKindForEndpoint(fixedEndpoint);\n    if (counterpartKind == null) {\n      _invalidate();\n      return false;\n    }\n    final anchors = PortSnapResolver.anchorsFor(''',
    'endpoint fixed port kind',
)
text = replace_once(
    text,
    '''      role: role,\n      excludeComponentId: fixedComponentId,\n    );''',
    '''      role: role,\n      excludeComponentId: fixedComponentId,\n      counterpartKind: counterpartKind,\n    );''',
    'endpoint resolver counterpart',
)
insert = '''\n  ElectricalPortKind? _portKindForEndpoint(ElectricalEndpointRef endpoint) {\n    return ElectricalPortCompatibility.portForEndpoint(\n      endpoint: endpoint,\n      components: _components,\n    )?.kind;\n  }\n'''
text = replace_once(
    text,
    '''  ElectricalEndpointRef? _endpointForSourceId(String sourceId) {''',
    insert + '''\n  ElectricalEndpointRef? _endpointForSourceId(String sourceId) {''',
    'endpoint port kind helper',
)
write(p, text)

# 1. Central route context resolver on controller, reusable by preview and writes.
p = 'lib/src/features/editor/editor_controller.dart'
text = read(p)
text = replace_once(
    text,
    "import '../../engine/snap_engine.dart';\n",
    "import '../../engine/normative_route_engine.dart';\nimport '../../engine/snap_engine.dart';\n",
    'controller normative import',
)
anchor = '''  List<ArchitecturalOpening> get activeWallOpenings {\n    final surface = activeSurface;\n    if (surface == null) return const [];\n    return openings\n        .where((opening) => opening.hostWall == surface)\n        .toList(growable: false);\n  }\n'''
method = anchor + r'''

  RouteNormativeContext? routeNormativeContextFor(RoomSurfaceRef surface) {
    EngineeringSpace? space;
    for (final candidate in level.spaces) {
      if (candidate.id == surface.spaceId) {
        space = candidate;
        break;
      }
    }
    if (space == null) return null;

    if (surface.type == SurfacePlaneType.wall) {
      final wallIndex = surface.wallIndex;
      if (wallIndex == null) return null;
      final wall = RoomSurfaceResolver.wall(space, wallIndex);
      return RouteNormativeContext(
        surface: surface,
        widthMm: wall.lengthMm.round(),
        heightMm: wall.heightMm,
        edgeClearanceMm: 0,
        boundary: [
          for (final point in wall.profile.vertices)
            SurfacePointMm(point.xMm, point.yMm),
        ],
        obstacles: [
          for (final opening in openings)
            if (opening.hostWall == surface)
              RouteObstacleMm(
                id: opening.id,
                leftMm: opening.offsetFromStartMm,
                topMm: opening.sillHeightMm,
                rightMm: opening.endOffsetMm,
                bottomMm: opening.topMm,
              ),
        ],
      );
    }

    final bounds = space.boundary.bounds;
    return RouteNormativeContext(
      surface: surface,
      widthMm: bounds.width,
      heightMm: bounds.height,
      edgeClearanceMm: 0,
      boundary: [
        for (final point in space.boundary.vertices)
          SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom),
      ],
    );
  }
'''
text = replace_once(text, anchor, method, 'controller route context')
write(p, text)

# 1/3/5. Session initialization, unique IDs and write-boundary invariants.
p = 'lib/src/features/editor/editor_p2_session.dart'
text = read(p)
text = replace_once(
    text,
    "import '../../engine/editor_layers.dart';\n",
    "import '../../engine/editor_layers.dart';\nimport '../../engine/normative_route_engine.dart';\n",
    'p2 normative import',
)
text = replace_once(
    text,
    '''final class EditorP2Session extends ChangeNotifier {\n  EditorP2Session({EditorP2State initialState = const EditorP2State()})\n      : history = CommandHistory<EditorP2State>(initialState);\n\n  final CommandHistory<EditorP2State> history;''',
    '''final class EditorP2Session extends ChangeNotifier {\n  EditorP2Session({\n    EditorP2State initialState = const EditorP2State(),\n    RouteNormativeContext? Function(RoomSurfaceRef surface)? routeContextResolver,\n  })  : _routeContextResolver = routeContextResolver,\n        _componentSequence = _nextSequence(\n          prefix: 'component-',\n          ids: initialState.components.map((item) => item.id),\n        ),\n        _routeSequence = _nextSequence(\n          prefix: 'route-',\n          ids: initialState.routes.map((item) => item.id),\n        ),\n        history = CommandHistory<EditorP2State>(initialState) {\n    _validateUniqueIds(initialState);\n  }\n\n  final CommandHistory<EditorP2State> history;\n  final RouteNormativeContext? Function(RoomSurfaceRef surface)?\n      _routeContextResolver;''',
    'p2 constructor',
)
text = replace_once(
    text,
    '''  ElectricalComponentPlacement? _moveOrigin;\n  int _componentSequence = 1;\n  int _routeSequence = 1;''',
    '''  ElectricalComponentPlacement? _moveOrigin;\n  int _componentSequence;\n  int _routeSequence;''',
    'p2 sequences',
)
text = replace_once(
    text,
    '''    final sequence = _componentSequence++;\n    final component = ElectricalComponentPlacement(\n      id: 'component-$sequence',''',
    '''    final sequence = _componentSequence++;\n    final componentId = _nextAvailableId(\n      prefix: 'component-',\n      initialSequence: sequence,\n      existingIds: components.map((item) => item.id).toSet(),\n    );\n    _componentSequence = componentId.$2;\n    final component = ElectricalComponentPlacement(\n      id: componentId.$1,''',
    'component id allocation',
)
text = replace_once(
    text,
    '''      label: '${ElectricalComponentDefaults.defaultLabel(type)} $sequence',''',
    '''      label: '${ElectricalComponentDefaults.defaultLabel(type)} ${componentId.$2 - 1}',''',
    'component label sequence',
)

pattern = re.compile(r"  bool replaceCableRoute\(\n    ElectricalCableRoute before,\n    ElectricalCableRoute after,\n  \) \{.*?\n  \}\n\n  bool toggleRouteSegmentLock", re.S)
replacement = r'''  bool replaceCableRoute(
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

  bool toggleRouteSegmentLock'''
text, n = pattern.subn(replacement, text)
if n != 1:
    raise RuntimeError(f'replaceCableRoute: expected one match, got {n}')

text = replace_once(
    text,
    '''    final route = ElectricalCableRoute(\n      id: 'route-${_routeSequence++}',''',
    '''    final routeId = _nextAvailableId(\n      prefix: 'route-',\n      initialSequence: _routeSequence,\n      existingIds: routes.map((item) => item.id).toSet(),\n    );\n    _routeSequence = routeId.$2;\n    final route = ElectricalCableRoute(\n      id: routeId.$1,''',
    'route id allocation',
)
text = replace_once(
    text,
    '''    if (!ElectricalConnectivityValidator.routeIsConnected(\n      route: route,\n      components: components,\n    )) {\n      return false;\n    }\n    history.execute(_AddRouteCommand(route));''',
    '''    if (!ElectricalConnectivityValidator.routeIsConnected(\n      route: route,\n      components: components,\n    ) ||\n        !_routeGeometryIsValid(route)) {\n      return false;\n    }\n    history.execute(_AddRouteCommand(route));''',
    'add route write validation',
)
text = replace_once(
    text,
    '''    final sourceComponent = _preferredSource(pair[0], pair[1]);\n    final targetComponent =\n        identical(sourceComponent, pair[0]) ? pair[1] : pair[0];\n    final sourcePort = _portForSource(sourceComponent);\n    final targetPort = _portForTarget(targetComponent);\n    if (sourcePort == null || targetPort == null) return false;''',
    '''    final forward = _resolvePortPair(pair[0], pair[1]);\n    final reverse = forward == null ? _resolvePortPair(pair[1], pair[0]) : null;\n    final portPair = forward ?? reverse;\n    if (portPair == null) return false;\n    final sourceComponent = portPair.sourceComponent;\n    final targetComponent = portPair.targetComponent;\n    final sourcePort = portPair.sourcePort;\n    final targetPort = portPair.targetPort;''',
    'auto route compatible pair',
)

pattern = re.compile(r"  static ElectricalComponentPlacement _preferredSource\(.*?\n  static double _axisDistance", re.S)
replacement = r'''  static _ResolvedPortPair? _resolvePortPair(
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
          !after.segments[waypoint.segmentIndex].points.contains(waypoint.point)) {
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
      if (!_sameSegment(a.segments[i], b.segments[i])) return false;
    }
    return true;
  }

  static bool _sameSegment(ElectricalRouteSegment a, ElectricalRouteSegment b) {
    if (a.surface != b.surface || a.points.length != b.points.length) return false;
    for (var i = 0; i < a.points.length; i++) {
      if (a.points[i] != b.points[i]) return false;
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
      if (parsed != null && parsed >= next) next = parsed + 1;
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

  static double _axisDistance'''
text, n = pattern.subn(replacement, text)
if n != 1:
    raise RuntimeError(f'p2 helper replacement: expected one match, got {n}')

# Add private resolved pair class before commands.
text = replace_once(
    text,
    '''final class _ReplaceRouteConstraintsCommand''',
    '''final class _ResolvedPortPair {\n  const _ResolvedPortPair({\n    required this.sourceComponent,\n    required this.targetComponent,\n    required this.sourcePort,\n    required this.targetPort,\n  });\n\n  final ElectricalComponentPlacement sourceComponent;\n  final ElectricalComponentPlacement targetComponent;\n  final ElectricalPortDefinition sourcePort;\n  final ElectricalPortDefinition targetPort;\n}\n\nfinal class _ReplaceRouteConstraintsCommand''',
    'resolved port pair class',
)
text = replace_once(
    text,
    '''extension EditorP2SessionAccess on EditorController {\n  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session();\n}''',
    '''extension EditorP2SessionAccess on EditorController {\n  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session(\n        routeContextResolver: routeNormativeContextFor,\n      );\n}''',
    'p2 production resolver',
)
write(p, text)

# 1/6. Stronger normative geometry: real boundary + obstacle detours.
p = 'lib/src/engine/normative_route_engine.dart'
write(p, r'''import '../domain/surfaces.dart';

enum CableRoutingMode { auto, assisted, manualGuardrails }

enum RouteConstraintSeverity { info, warning, error }

final class RouteConstraintIssue {
  const RouteConstraintIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final RouteConstraintSeverity severity;
}

final class RouteConstraintResult {
  const RouteConstraintResult(this.issues);

  final List<RouteConstraintIssue> issues;

  bool get isValid =>
      !issues.any((issue) => issue.severity == RouteConstraintSeverity.error);

  bool get hasWarnings =>
      issues.any((issue) => issue.severity == RouteConstraintSeverity.warning);
}

final class RouteObstacleMm {
  const RouteObstacleMm({
    required this.id,
    required this.leftMm,
    required this.topMm,
    required this.rightMm,
    required this.bottomMm,
  })  : assert(rightMm >= leftMm),
        assert(bottomMm >= topMm);

  final String id;
  final int leftMm;
  final int topMm;
  final int rightMm;
  final int bottomMm;

  bool contains(SurfacePointMm point) =>
      point.xMm >= leftMm &&
      point.xMm <= rightMm &&
      point.yMm >= topMm &&
      point.yMm <= bottomMm;
}

final class RouteNormativeContext {
  const RouteNormativeContext({
    required this.surface,
    required this.widthMm,
    required this.heightMm,
    this.edgeClearanceMm = 100,
    this.detourClearanceMm = 50,
    this.obstacles = const [],
    this.boundary = const [],
  })  : assert(widthMm > 0),
        assert(heightMm > 0),
        assert(edgeClearanceMm >= 0),
        assert(detourClearanceMm > 0);

  final RoomSurfaceRef surface;
  final int widthMm;
  final int heightMm;
  final int edgeClearanceMm;
  final int detourClearanceMm;
  final List<RouteObstacleMm> obstacles;

  /// Usable surface polygon in surface-local millimetres. Empty preserves the
  /// rectangular width/height fallback used by low-level tests.
  final List<SurfacePointMm> boundary;
}

final class RouteCandidate {
  const RouteCandidate({
    required this.points,
    required this.validation,
    required this.score,
  });

  final List<SurfacePointMm> points;
  final RouteConstraintResult validation;
  final double score;
}

/// Deterministic geometric guardrail router.
///
/// This remains deliberately separate from the future normative registry. It
/// enforces orthogonality, the real usable surface polygon and declared
/// architectural obstacles, and produces simple obstacle-detour alternatives.
abstract final class NormativeRouteEngine {
  static List<RouteCandidate> buildCandidates({
    required SurfacePointMm source,
    required SurfacePointMm target,
    required RouteNormativeContext context,
  }) {
    final paths = <List<SurfacePointMm>>[
      [source, SurfacePointMm(target.xMm, source.yMm), target],
      [source, SurfacePointMm(source.xMm, target.yMm), target],
    ];

    final clearance = context.detourClearanceMm > context.edgeClearanceMm
        ? context.detourClearanceMm
        : context.edgeClearanceMm + 1;
    for (final obstacle in context.obstacles) {
      final above = obstacle.topMm - clearance;
      final below = obstacle.bottomMm + clearance;
      final left = obstacle.leftMm - clearance;
      final right = obstacle.rightMm + clearance;
      if (above >= 0) {
        paths.add([
          source,
          SurfacePointMm(source.xMm, above),
          SurfacePointMm(target.xMm, above),
          target,
        ]);
      }
      if (below <= context.heightMm) {
        paths.add([
          source,
          SurfacePointMm(source.xMm, below),
          SurfacePointMm(target.xMm, below),
          target,
        ]);
      }
      if (left >= 0) {
        paths.add([
          source,
          SurfacePointMm(left, source.yMm),
          SurfacePointMm(left, target.yMm),
          target,
        ]);
      }
      if (right <= context.widthMm) {
        paths.add([
          source,
          SurfacePointMm(right, source.yMm),
          SurfacePointMm(right, target.yMm),
          target,
        ]);
      }
    }

    final seen = <String>{};
    final candidates = <RouteCandidate>[];
    for (final path in paths) {
      final compact = _compact(path);
      final key = compact.map((p) => '${p.xMm},${p.yMm}').join(';');
      if (!seen.add(key)) continue;
      candidates.add(_candidate(compact, context));
    }
    candidates.sort((a, b) {
      if (a.validation.isValid != b.validation.isValid) {
        return a.validation.isValid ? -1 : 1;
      }
      return a.score.compareTo(b.score);
    });
    return List.unmodifiable(candidates);
  }

  static RouteConstraintResult validate({
    required List<SurfacePointMm> points,
    required RouteNormativeContext context,
  }) {
    final issues = <RouteConstraintIssue>[];
    if (points.length < 2) {
      return const RouteConstraintResult([
        RouteConstraintIssue(
          code: 'route.too-short',
          message: 'Маршрут должен содержать минимум две точки.',
          severity: RouteConstraintSeverity.error,
        ),
      ]);
    }

    for (final point in points) {
      if (point.xMm < context.edgeClearanceMm ||
          point.xMm > context.widthMm - context.edgeClearanceMm ||
          point.yMm < context.edgeClearanceMm ||
          point.yMm > context.heightMm - context.edgeClearanceMm) {
        issues.add(
          const RouteConstraintIssue(
            code: 'route.edge-clearance',
            message: 'Трасса выходит за допустимую зону поверхности.',
            severity: RouteConstraintSeverity.error,
          ),
        );
        break;
      }
    }

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a.xMm != b.xMm && a.yMm != b.yMm) {
        issues.add(
          const RouteConstraintIssue(
            code: 'route.non-orthogonal',
            message:
                'Автоматическая трасса должна идти по ортогональным направлениям.',
            severity: RouteConstraintSeverity.error,
          ),
        );
        break;
      }
      if (context.boundary.length >= 3 &&
          !_segmentInsideBoundary(a, b, context.boundary)) {
        issues.add(
          const RouteConstraintIssue(
            code: 'route.outside-surface-boundary',
            message: 'Трасса выходит за фактический контур поверхности.',
            severity: RouteConstraintSeverity.error,
          ),
        );
        break;
      }
      for (final obstacle in context.obstacles) {
        if (_segmentIntersectsObstacle(a, b, obstacle)) {
          issues.add(
            RouteConstraintIssue(
              code: 'route.obstacle.${obstacle.id}',
              message:
                  'Трасса пересекает архитектурное препятствие ${obstacle.id}.',
              severity: RouteConstraintSeverity.error,
            ),
          );
          break;
        }
      }
    }

    if (points.length > 4) {
      issues.add(
        const RouteConstraintIssue(
          code: 'route.excessive-bends',
          message: 'Маршрут содержит лишние повороты.',
          severity: RouteConstraintSeverity.warning,
        ),
      );
    }

    return RouteConstraintResult(List.unmodifiable(issues));
  }

  static RouteCandidate _candidate(
    List<SurfacePointMm> points,
    RouteNormativeContext context,
  ) {
    final validation = validate(points: points, context: context);
    final length = _length(points);
    final bends = points.length <= 2 ? 0 : points.length - 2;
    final warningPenalty = validation.issues
            .where((issue) => issue.severity == RouteConstraintSeverity.warning)
            .length *
        1000;
    final errorPenalty = validation.isValid ? 0 : 1000000;
    return RouteCandidate(
      points: List.unmodifiable(points),
      validation: validation,
      score: length + bends * 250 + warningPenalty + errorPenalty,
    );
  }

  static List<SurfacePointMm> _compact(List<SurfacePointMm> points) {
    final result = <SurfacePointMm>[];
    for (final point in points) {
      if (result.isNotEmpty && result.last == point) continue;
      result.add(point);
    }
    return result;
  }

  static double _length(List<SurfacePointMm> points) {
    var value = 0.0;
    for (var i = 1; i < points.length; i++) {
      value += (points[i].xMm - points[i - 1].xMm).abs();
      value += (points[i].yMm - points[i - 1].yMm).abs();
    }
    return value;
  }

  static bool _segmentInsideBoundary(
    SurfacePointMm a,
    SurfacePointMm b,
    List<SurfacePointMm> boundary,
  ) {
    if (!_insideOrBoundary(a, boundary) || !_insideOrBoundary(b, boundary)) {
      return false;
    }
    for (var i = 0; i < boundary.length; i++) {
      final c = boundary[i];
      final d = boundary[(i + 1) % boundary.length];
      if (_properlyIntersects(a, b, c, d)) return false;
    }
    return true;
  }

  static bool _insideOrBoundary(
    SurfacePointMm point,
    List<SurfacePointMm> polygon,
  ) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if (_onSegment(a, point, b)) return true;
      final crosses = (a.yMm > point.yMm) != (b.yMm > point.yMm);
      if (!crosses) continue;
      final crossingX = (b.xMm - a.xMm) *
              (point.yMm - a.yMm) /
              (b.yMm - a.yMm) +
          a.xMm;
      if (point.xMm < crossingX) inside = !inside;
    }
    return inside;
  }

  static bool _properlyIntersects(
    SurfacePointMm a,
    SurfacePointMm b,
    SurfacePointMm c,
    SurfacePointMm d,
  ) {
    final abC = _cross(a, b, c);
    final abD = _cross(a, b, d);
    final cdA = _cross(c, d, a);
    final cdB = _cross(c, d, b);
    return ((abC > 0 && abD < 0) || (abC < 0 && abD > 0)) &&
        ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0));
  }

  static int _cross(SurfacePointMm a, SurfacePointMm b, SurfacePointMm p) =>
      (b.xMm - a.xMm) * (p.yMm - a.yMm) -
      (b.yMm - a.yMm) * (p.xMm - a.xMm);

  static bool _onSegment(
    SurfacePointMm a,
    SurfacePointMm p,
    SurfacePointMm b,
  ) {
    if (_cross(a, b, p) != 0) return false;
    final minX = a.xMm < b.xMm ? a.xMm : b.xMm;
    final maxX = a.xMm > b.xMm ? a.xMm : b.xMm;
    final minY = a.yMm < b.yMm ? a.yMm : b.yMm;
    final maxY = a.yMm > b.yMm ? a.yMm : b.yMm;
    return p.xMm >= minX &&
        p.xMm <= maxX &&
        p.yMm >= minY &&
        p.yMm <= maxY;
  }

  static bool _segmentIntersectsObstacle(
    SurfacePointMm a,
    SurfacePointMm b,
    RouteObstacleMm obstacle,
  ) {
    if (a.xMm == b.xMm) {
      if (a.xMm < obstacle.leftMm || a.xMm > obstacle.rightMm) return false;
      final minY = a.yMm < b.yMm ? a.yMm : b.yMm;
      final maxY = a.yMm > b.yMm ? a.yMm : b.yMm;
      return maxY >= obstacle.topMm && minY <= obstacle.bottomMm;
    }
    if (a.yMm == b.yMm) {
      if (a.yMm < obstacle.topMm || a.yMm > obstacle.bottomMm) return false;
      final minX = a.xMm < b.xMm ? a.xMm : b.xMm;
      final maxX = a.xMm > b.xMm ? a.xMm : b.xMm;
      return maxX >= obstacle.leftMm && minX <= obstacle.rightMm;
    }
    return true;
  }
}
''')

# 4. Canvas teardown always rolls back active preview transactions.
p = 'lib/src/features/editor/surface_canvas.dart'
text = read(p)
text = replace_once(
    text,
    '''      oldWidget.controller.cableUi.removeListener(_onInteractionChanged);\n      _lastViewportRevision = controller.viewportCommandRevision;''',
    '''      oldWidget.controller.cableUi.removeListener(_onInteractionChanged);\n      _cancelActiveInteractions(oldWidget.controller);\n      _lastViewportRevision = controller.viewportCommandRevision;''',
    'canvas controller switch cancel',
)
text = replace_once(
    text,
    '''    controller.cableUi.removeListener(_onInteractionChanged);\n    _routeFlow.dispose();''',
    '''    controller.cableUi.removeListener(_onInteractionChanged);\n    _cancelActiveInteractions(controller);\n    _routeFlow.dispose();''',
    'canvas dispose cancel',
)
helper = r'''
  void _cancelActiveInteractions(EditorController target) {
    if (target.componentTransform.active) target.componentTransform.cancel();
    if (target.cableEndpointTransform.active) {
      target.cableEndpointTransform.cancel();
    }
    if (target.cableRouteEdit.active) target.cableRouteEdit.cancel();
    if (target.p2.isManipulating) target.p2.cancelMoveSelectedComponent();
    _dragComponentId = null;
    _dragStartPosition = null;
    _cableDragHit = null;
    _activePointers.clear();
  }

'''
text = replace_once(
    text,
    '''  void _syncRouteFlowAnimation() {''',
    helper + '''  void _syncRouteFlowAnimation() {''',
    'canvas cancel helper',
)
# Route context now comes from the controller's project geometry.
pattern = re.compile(r"  RouteNormativeContext _routeContext\(_SurfaceProjection projection\) \{.*?\n  \}\n\n  CableCanvasHit\? _cableHitAt", re.S)
replacement = r'''  RouteNormativeContext _routeContext(_SurfaceProjection projection) {
    final surface = controller.activeSurface!;
    final context = controller.routeNormativeContextFor(surface);
    if (context == null) {
      throw StateError('No normative route context for ${surface.id}.');
    }
    return context;
  }

  CableCanvasHit? _cableHitAt'''
text, n = pattern.subn(replacement, text)
if n != 1:
    raise RuntimeError(f'canvas route context: expected one match, got {n}')
write(p, text)

# 7. Compass definition: true azimuth is plan direction relative to shown north.
p = 'lib/src/domain/site_orientation.dart'
text = read(p)
text = replace_once(
    text,
    '''  double toTrueAzimuth(double planAzimuthDegrees) =>\n      _normalize(planAzimuthDegrees + northAzimuthDegrees);''',
    '''  double toTrueAzimuth(double planAzimuthDegrees) =>\n      _normalize(planAzimuthDegrees - northAzimuthDegrees);''',
    'north azimuth conversion',
)
write(p, text)

p = 'test/daylight_assist_engine_test.dart'
text = read(p)
text = replace_once(
    text,
    '''    expect(north.toTrueAzimuth(0), 30);\n    expect(north.toTrueAzimuth(90), 120);\n    expect(north.toTrueAzimuth(350), 20);''',
    '''    expect(north.toTrueAzimuth(0), 330);\n    expect(north.toTrueAzimuth(90), 60);\n    expect(north.toTrueAzimuth(350), 320);\n    const eastNorth = ProjectNorth(northAzimuthDegrees: 90);\n    expect(eastNorth.toTrueAzimuth(90), 0);''',
    'daylight north expectations',
)
write(p, text)

# Permanent diagnostic regressions for the seven reported integrity defects.
p = 'test/editor_integrity_hardening_test.dart'
write(p, r'''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wall = RoomSurfaceRef.wall('room', 0);

  ElectricalComponentPlacement component(
    String id,
    ElectricalComponentType type,
    SurfacePointMm point,
  ) =>
      ElectricalComponentPlacement(
        id: id,
        type: type,
        surface: wall,
        position: point,
        label: id,
        ports: ElectricalComponentDefaults.portsFor(type),
      );

  test('route connectivity rejects powerOut to controlIn', () {
    final source = component(
      'source',
      ElectricalComponentType.powerSource,
      const SurfacePointMm(100, 100),
    );
    final target = component(
      'target',
      ElectricalComponentType.lightingPoint,
      const SurfacePointMm(900, 900),
    );
    final route = ElectricalCableRoute(
      id: 'r',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target',
        portId: 'control-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [SurfacePointMm(100, 100), SurfacePointMm(900, 100)],
        ),
      ],
    );
    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: route,
        components: [source, target],
      ),
      isFalse,
    );
  });

  test('restored state advances generated component and route ids', () {
    final source = component(
      'component-7',
      ElectricalComponentType.powerSource,
      const SurfacePointMm(100, 100),
    );
    final target = component(
      'component-9',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(900, 100),
    );
    final route = ElectricalCableRoute(
      id: 'route-12',
      source: const ElectricalEndpointRef(
        componentId: 'component-7',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'component-9',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [SurfacePointMm(100, 100), SurfacePointMm(900, 100)],
        ),
      ],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(components: [source, target], routes: [route]),
    );
    addTearDown(session.dispose);
    final placed = session.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(1200, 100),
    );
    expect(placed.id, 'component-10');
  });

  test('restored state rejects duplicate ids immediately', () {
    final a = component(
      'component-1',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(100, 100),
    );
    final b = component(
      'component-1',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(200, 100),
    );
    expect(
      () => EditorP2Session(initialState: EditorP2State(components: [a, b])),
      throwsArgumentError,
    );
  });

  test('write API cannot mutate a locked segment or drop waypoint', () {
    final source = component(
      'source',
      ElectricalComponentType.powerSource,
      const SurfacePointMm(100, 100),
    );
    final target = component(
      'target',
      ElectricalComponentType.socketOutlet,
      const SurfacePointMm(900, 900),
    );
    final before = ElectricalCableRoute(
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
          surface: wall,
          points: const [
            SurfacePointMm(100, 100),
            SurfacePointMm(100, 500),
            SurfacePointMm(900, 500),
            SurfacePointMm(900, 900),
          ],
        ),
      ],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(
        components: [source, target],
        routes: [before],
        routeConstraints: {
          'route-1': CableRouteConstraints(
            lockedSegments: const {0},
            mandatoryWaypoints: const [
              CableMandatoryWaypoint(
                segmentIndex: 0,
                pointIndex: 1,
                point: SurfacePointMm(100, 500),
              ),
            ],
          ),
        },
      ),
    );
    addTearDown(session.dispose);
    final after = ElectricalCableRoute(
      id: before.id,
      source: before.source,
      target: before.target,
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [
            SurfacePointMm(100, 100),
            SurfacePointMm(500, 100),
            SurfacePointMm(500, 900),
            SurfacePointMm(900, 900),
          ],
        ),
      ],
    );
    expect(session.replaceCableRoute(before, after), isFalse);
    expect(session.routes.single.segments.single.points, before.segments.single.points);
  });

  test('concave surface boundary rejects route that exits and re-enters', () {
    final context = RouteNormativeContext(
      surface: RoomSurfaceRef.floor('room'),
      widthMm: 4000,
      heightMm: 4000,
      edgeClearanceMm: 0,
      boundary: const [
        SurfacePointMm(0, 0),
        SurfacePointMm(4000, 0),
        SurfacePointMm(4000, 1000),
        SurfacePointMm(1000, 1000),
        SurfacePointMm(1000, 4000),
        SurfacePointMm(0, 4000),
      ],
    );
    final result = NormativeRouteEngine.validate(
      points: const [
        SurfacePointMm(500, 3500),
        SurfacePointMm(3500, 3500),
        SurfacePointMm(3500, 500),
      ],
      context: context,
    );
    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.code == 'route.outside-surface-boundary'),
      isTrue,
    );
  });

  test('auto route finds an orthogonal detour around centered obstacle', () {
    final context = RouteNormativeContext(
      surface: wall,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
      obstacles: const [
        RouteObstacleMm(
          id: 'window',
          leftMm: 1200,
          topMm: 700,
          rightMm: 1800,
          bottomMm: 1300,
        ),
      ],
    );
    final candidates = NormativeRouteEngine.buildCandidates(
      source: const SurfacePointMm(500, 1000),
      target: const SurfacePointMm(2500, 1000),
      context: context,
    );
    expect(candidates.first.validation.isValid, isTrue);
    expect(candidates.first.points.length, greaterThanOrEqualTo(4));
  });
}
''')

p = 'test/surface_canvas_lifecycle_hardening_test.dart'
write(p, r'''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disposing canvas cancels active component preview exactly', (tester) async {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(1);
    final original = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 500),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SurfaceCanvas(controller: controller))),
    );
    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(2000, 500),
        isValid: true,
      ),
      isTrue,
    );
    expect(controller.p2.selectedComponent!.position.xMm, 2000);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(controller.componentTransform.active, isFalse);
    expect(controller.p2.isManipulating, isFalse);
    expect(controller.p2.selectedComponent!.position, original.position);
  });
}
''')
