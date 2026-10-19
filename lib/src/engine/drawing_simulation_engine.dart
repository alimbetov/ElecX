import 'dart:math' as math;

import '../domain/component_catalog_v2.dart';
import '../domain/electrical_placement.dart';
import '../domain/electrical_routing.dart';
import '../domain/engineering_topology.dart';
import '../domain/geometry.dart';
import '../domain/project_model.dart';
import '../domain/surfaces.dart';
import 'auto_route_graph_builder.dart';
import 'route_engine.dart';

enum SimulationSeverity { info, warning, error }

enum DrawingDefectKind {
  unknownCatalogComponent,
  componentWrongRoom,
  componentSurfaceNotAllowed,
  componentOutsideGeometry,
  overlappingComponents,
  routeDisconnected,
  routeEmpty,
  routeExcessiveTransitions,
  routeExcessiveBends,
  routeInefficient,
  topologyMissingNode,
  topologyNoPathToBoard,
}

final class DrawingDefect {
  const DrawingDefect({
    required this.kind,
    required this.severity,
    required this.objectId,
    required this.message,
  });

  final DrawingDefectKind kind;
  final SimulationSeverity severity;
  final String objectId;
  final String message;
}

final class RouteOptimizationCandidate {
  const RouteOptimizationCandidate({
    required this.routeId,
    required this.preference,
    required this.currentLengthMm,
    required this.optimizedLengthMm,
    required this.optimizedSegments,
  });

  final String routeId;
  final RoutePreference preference;
  final double currentLengthMm;
  final double optimizedLengthMm;
  final List<ElectricalRouteSegment> optimizedSegments;

  double get savingMm => math.max(0, currentLengthMm - optimizedLengthMm);

  double get savingPercent => currentLengthMm <= 0
      ? 0
      : savingMm / currentLengthMm * 100;
}

final class DrawingSimulationRequest {
  const DrawingSimulationRequest({
    required this.space,
    required this.components,
    required this.routes,
    this.topology,
    this.boardNodeId,
    this.routePreference = RoutePreference.orthogonal,
    this.roomHeightMm = 3000,
    this.routeImprovementThreshold = 0.10,
    this.maxTransitions = 3,
    this.maxBends = 6,
  });

  final EngineeringSpace space;
  final List<ElectricalComponentPlacement> components;
  final List<ElectricalCableRoute> routes;
  final EngineeringTopology? topology;
  final String? boardNodeId;
  final RoutePreference routePreference;
  final int roomHeightMm;
  final double routeImprovementThreshold;
  final int maxTransitions;
  final int maxBends;
}

final class DrawingSimulationResult {
  const DrawingSimulationResult({
    required this.defects,
    required this.routeCandidates,
    required this.score,
  });

  final List<DrawingDefect> defects;
  final List<RouteOptimizationCandidate> routeCandidates;
  final int score;

  bool get hasErrors =>
      defects.any((item) => item.severity == SimulationSeverity.error);
}

abstract final class DrawingSimulationEngine {
  static DrawingSimulationResult run(DrawingSimulationRequest request) {
    if (request.routeImprovementThreshold < 0) {
      throw ArgumentError.value(
        request.routeImprovementThreshold,
        'routeImprovementThreshold',
      );
    }

    final defects = <DrawingDefect>[];
    final candidates = <RouteOptimizationCandidate>[];
    final byId = <String, ElectricalComponentPlacement>{
      for (final component in request.components) component.id: component,
    };

    for (final component in request.components) {
      _auditComponent(request, component, defects);
    }
    _auditOverlaps(request.components, defects);

    for (final route in request.routes) {
      _auditRoute(request, route, byId, defects, candidates);
    }

    _auditTopology(request, defects);

    return DrawingSimulationResult(
      defects: List.unmodifiable(defects),
      routeCandidates: List.unmodifiable(candidates),
      score: _score(defects),
    );
  }

  static void _auditComponent(
    DrawingSimulationRequest request,
    ElectricalComponentPlacement component,
    List<DrawingDefect> defects,
  ) {
    if (component.surface.spaceId != request.space.id) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.componentWrongRoom,
          severity: SimulationSeverity.error,
          objectId: component.id,
          message: 'Component belongs to another room surface.',
        ),
      );
      return;
    }

    final entry = ComponentCatalogV2.byId(component.componentTypeId);
    if (entry == null) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.unknownCatalogComponent,
          severity: SimulationSeverity.warning,
          objectId: component.id,
          message: 'Unknown componentTypeId ${component.componentTypeId}.',
        ),
      );
    } else if (!entry.canPlaceOn(component.surface)) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.componentSurfaceNotAllowed,
          severity: SimulationSeverity.error,
          objectId: component.id,
          message: '${entry.name} is not allowed on ${component.surface.type.name}.',
        ),
      );
    }

    if (!_pointInsideSpace(request.space, component, request.roomHeightMm)) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.componentOutsideGeometry,
          severity: SimulationSeverity.error,
          objectId: component.id,
          message: 'Component position is outside the host surface geometry.',
        ),
      );
    }
  }

  static bool _pointInsideSpace(
    EngineeringSpace space,
    ElectricalComponentPlacement component,
    int roomHeightMm,
  ) {
    final point = component.position;
    if (point.xMm < 0 || point.yMm < 0) return false;
    switch (component.surface.type) {
      case SurfacePlaneType.wall:
        final wallIndex = component.surface.wallIndex;
        if (wallIndex == null ||
            wallIndex < 0 ||
            wallIndex >= space.boundary.vertices.length) {
          return false;
        }
        final wall = RoomSurfaceResolver.wall(space, wallIndex);
        if (point.xMm > wall.lengthMm.round() || point.yMm > roomHeightMm) {
          return false;
        }
        return wall.profile.containsPoint(point.xMm, point.yMm);
      case SurfacePlaneType.floor:
      case SurfacePlaneType.ceiling:
        final bounds = space.boundary.bounds;
        if (point.xMm > bounds.width || point.yMm > bounds.height) return false;
        return space.boundary.contains(
          MmPoint(bounds.left + point.xMm, bounds.bottom + point.yMm),
        );
    }
  }

  static void _auditOverlaps(
    List<ElectricalComponentPlacement> components,
    List<DrawingDefect> defects,
  ) {
    for (var i = 0; i < components.length; i++) {
      for (var j = i + 1; j < components.length; j++) {
        final a = components[i];
        final b = components[j];
        if (a.surface != b.surface ||
            a.position.xMm != b.position.xMm ||
            a.position.yMm != b.position.yMm) {
          continue;
        }
        defects.add(
          DrawingDefect(
            kind: DrawingDefectKind.overlappingComponents,
            severity: SimulationSeverity.warning,
            objectId: '${a.id}|${b.id}',
            message: 'Two components occupy the same surface coordinate.',
          ),
        );
      }
    }
  }

  static void _auditRoute(
    DrawingSimulationRequest request,
    ElectricalCableRoute route,
    Map<String, ElectricalComponentPlacement> byId,
    List<DrawingDefect> defects,
    List<RouteOptimizationCandidate> candidates,
  ) {
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: route,
      components: request.components,
    )) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeDisconnected,
          severity: SimulationSeverity.error,
          objectId: route.id,
          message: 'Cable route has missing or invalid component endpoints.',
        ),
      );
    }

    if (route.segments.isEmpty || route.geometricLengthMm <= 0) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeEmpty,
          severity: SimulationSeverity.error,
          objectId: route.id,
          message: 'Cable route has no physical path.',
        ),
      );
      return;
    }

    final transitions = math.max(0, route.segments.length - 1);
    if (transitions > request.maxTransitions) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeExcessiveTransitions,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message: 'Route uses $transitions surface transitions; expected at most ${request.maxTransitions}.',
        ),
      );
    }

    final bends = route.segments.fold<int>(0, (sum, item) => sum + _bendCount(item));
    if (bends > request.maxBends) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeExcessiveBends,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message: 'Route uses $bends bends; expected at most ${request.maxBends}.',
        ),
      );
    }

    final source = byId[route.source.componentId];
    final target = byId[route.target.componentId];
    if (source == null || target == null) return;
    if (source.surface.spaceId != request.space.id ||
        target.surface.spaceId != request.space.id) {
      return;
    }

    final graph = AutoRouteGraphBuilder.build(
      space: request.space,
      source: source,
      target: target,
      roomHeightMm: request.roomHeightMm,
    );
    final solution = RouteEngine.solve(
      graph: graph,
      startNodeId: 'source',
      endNodeId: 'target',
      preference: request.routePreference,
    );
    if (solution == null) return;
    final optimizedSegments = RouteEngine.toSegments(graph, solution);
    final optimizedLength = optimizedSegments.fold<double>(
      0,
      (sum, segment) => sum + segment.lengthMm,
    );
    if (optimizedLength <= 0) return;

    final candidate = RouteOptimizationCandidate(
      routeId: route.id,
      preference: request.routePreference,
      currentLengthMm: route.geometricLengthMm,
      optimizedLengthMm: optimizedLength,
      optimizedSegments: optimizedSegments,
    );
    final minimumSaving = route.geometricLengthMm * request.routeImprovementThreshold;
    if (candidate.savingMm > minimumSaving) {
      candidates.add(candidate);
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeInefficient,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message: 'A shorter route can save ${candidate.savingMm.round()} mm (${candidate.savingPercent.toStringAsFixed(1)}%).',
        ),
      );
    }
  }

  static int _bendCount(ElectricalRouteSegment segment) {
    var count = 0;
    for (var i = 1; i + 1 < segment.points.length; i++) {
      final a = segment.points[i - 1];
      final b = segment.points[i];
      final c = segment.points[i + 1];
      final dx1 = b.xMm - a.xMm;
      final dy1 = b.yMm - a.yMm;
      final dx2 = c.xMm - b.xMm;
      final dy2 = c.yMm - b.yMm;
      if (dx1 * dy2 != dy1 * dx2) count++;
    }
    return count;
  }

  static void _auditTopology(
    DrawingSimulationRequest request,
    List<DrawingDefect> defects,
  ) {
    final topology = request.topology;
    final boardNodeId = request.boardNodeId;
    if (topology == null || boardNodeId == null) return;

    final nodeIds = topology.nodes.map((node) => node.id).toSet();
    if (!nodeIds.contains(boardNodeId)) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.topologyMissingNode,
          severity: SimulationSeverity.error,
          objectId: boardNodeId,
          message: 'Configured distribution board node is missing from topology.',
        ),
      );
      return;
    }

    for (final component in request.components) {
      if (component.id == boardNodeId) continue;
      if (!nodeIds.contains(component.id)) {
        defects.add(
          DrawingDefect(
            kind: DrawingDefectKind.topologyMissingNode,
            severity: SimulationSeverity.warning,
            objectId: component.id,
            message: 'Placed component has no engineering topology node.',
          ),
        );
        continue;
      }
      if (!topology.hasPath(component.id, boardNodeId)) {
        defects.add(
          DrawingDefect(
            kind: DrawingDefectKind.topologyNoPathToBoard,
            severity: SimulationSeverity.error,
            objectId: component.id,
            message: 'No engineering path exists from component to distribution board.',
          ),
        );
      }
    }
  }

  static int _score(List<DrawingDefect> defects) {
    var score = 100;
    for (final defect in defects) {
      score -= switch (defect.severity) {
        SimulationSeverity.error => 20,
        SimulationSeverity.warning => 7,
        SimulationSeverity.info => 2,
      };
    }
    return score.clamp(0, 100);
  }
}
