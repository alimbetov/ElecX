import 'dart:math' as math;

import '../domain/component_catalog_v2.dart';
import '../domain/electrical_placement.dart';
import '../domain/electrical_routing.dart';
import '../domain/engineering_topology.dart';
import '../domain/geometry.dart';
import '../domain/project_model.dart';
import '../domain/surfaces.dart';
import 'auto_route_graph_builder.dart';
import 'engineering_analysis_profile.dart';
import 'route_engine.dart';
import 'routing_constraints.dart';

typedef ComponentCatalogResolver = ComponentCatalogEntryV2? Function(
  String componentTypeId,
);

enum SimulationSeverity { info, warning, error }

enum DrawingDefectKind {
  unknownCatalogComponent,
  componentWrongRoom,
  componentSurfaceNotAllowed,
  componentOutsideGeometry,
  overlappingComponents,
  componentClearanceViolation,
  routeDisconnected,
  routeEmpty,
  routeKeepOutViolation,
  routeExcessiveTransitions,
  routeExcessiveBends,
  routeInefficient,
  routeNoFeasibleAlternative,
  topologyMissingNode,
  topologyNoPathToBoard,
  topologyWrongFlowDirection,
}

final class DrawingDefect {
  const DrawingDefect({
    required this.kind,
    required this.severity,
    required this.objectId,
    required this.message,
    this.relatedObjectIds = const [],
  });

  final DrawingDefectKind kind;
  final SimulationSeverity severity;
  final String objectId;
  final String message;
  final List<String> relatedObjectIds;
}

final class RouteOptimizationCandidate {
  const RouteOptimizationCandidate({
    required this.routeId,
    required this.preference,
    required this.currentLengthMm,
    required this.optimizedLengthMm,
    required this.optimizedSegments,
    required this.currentTransitionCount,
    required this.optimizedTransitionCount,
  });

  final String routeId;
  final RoutePreference preference;
  final double currentLengthMm;
  final double optimizedLengthMm;
  final List<ElectricalRouteSegment> optimizedSegments;
  final int currentTransitionCount;
  final int optimizedTransitionCount;

  double get savingMm => math.max(0, currentLengthMm - optimizedLengthMm);

  double get savingPercent =>
      currentLengthMm <= 0 ? 0 : savingMm / currentLengthMm * 100;
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
    this.profile = EngineeringAnalysisProfile.standard,
    this.keepOutZones = const [],
    this.catalogResolver,
  });

  final EngineeringSpace space;
  final List<ElectricalComponentPlacement> components;
  final List<ElectricalCableRoute> routes;
  final EngineeringTopology? topology;
  final String? boardNodeId;
  final RoutePreference routePreference;
  final int roomHeightMm;
  final EngineeringAnalysisProfile profile;
  final List<SurfaceKeepOutZone> keepOutZones;

  /// Runtime catalog lookup. Falls back to built-in catalog only when omitted.
  final ComponentCatalogResolver? catalogResolver;

  ComponentCatalogEntryV2? resolveCatalog(String id) =>
      catalogResolver?.call(id) ?? ComponentCatalogV2.byId(id);
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

  int count(SimulationSeverity severity) =>
      defects.where((item) => item.severity == severity).length;
}

abstract final class DrawingSimulationEngine {
  static DrawingSimulationResult run(DrawingSimulationRequest request) {
    final defects = <DrawingDefect>[];
    final candidates = <RouteOptimizationCandidate>[];
    final byId = <String, ElectricalComponentPlacement>{
      for (final component in request.components) component.id: component,
    };

    for (final component in request.components) {
      _auditComponent(request, component, defects);
    }
    _auditComponentClearances(request, defects);

    for (final route in request.routes) {
      _auditRoute(request, route, byId, defects, candidates);
    }

    _auditTopology(request, defects);

    return DrawingSimulationResult(
      defects: List.unmodifiable(defects),
      routeCandidates: List.unmodifiable(candidates),
      score: _score(defects, request.profile),
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

    final entry = request.resolveCatalog(component.componentTypeId);
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
          message:
              '${entry.name} is not allowed on ${component.surface.type.name}.',
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

  static void _auditComponentClearances(
    DrawingSimulationRequest request,
    List<DrawingDefect> defects,
  ) {
    final minimum = request.profile.componentClearanceMm.toDouble();
    for (var i = 0; i < request.components.length; i++) {
      for (var j = i + 1; j < request.components.length; j++) {
        final a = request.components[i];
        final b = request.components[j];
        if (a.surface != b.surface) continue;
        final dx = (a.position.xMm - b.position.xMm).toDouble();
        final dy = (a.position.yMm - b.position.yMm).toDouble();
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance == 0) {
          defects.add(
            DrawingDefect(
              kind: DrawingDefectKind.overlappingComponents,
              severity: SimulationSeverity.warning,
              objectId: a.id,
              relatedObjectIds: [b.id],
              message: 'Two components occupy the same surface coordinate.',
            ),
          );
        } else if (minimum > 0 && distance < minimum) {
          defects.add(
            DrawingDefect(
              kind: DrawingDefectKind.componentClearanceViolation,
              severity: SimulationSeverity.warning,
              objectId: a.id,
              relatedObjectIds: [b.id],
              message:
                  'Component clearance is ${distance.round()} mm; profile requires at least ${minimum.round()} mm.',
            ),
          );
        }
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

    final currentTransitions = math.max(0, route.segments.length - 1);
    if (currentTransitions > request.profile.maxSurfaceTransitions) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeExcessiveTransitions,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message:
              'Route uses $currentTransitions surface transitions; profile allows ${request.profile.maxSurfaceTransitions}.',
        ),
      );
    }

    final bends = route.segments.fold<int>(
      0,
      (sum, item) => sum + _bendCount(item),
    );
    if (bends > request.profile.maxRouteBends) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeExcessiveBends,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message:
              'Route uses $bends bends; profile allows ${request.profile.maxRouteBends}.',
        ),
      );
    }

    for (final segment in route.segments) {
      final violations = RoutingConstraintEngine.routeViolations(
        surface: segment.surface,
        points: segment.points,
        zones: request.keepOutZones,
      );
      for (final zone in violations) {
        defects.add(
          DrawingDefect(
            kind: DrawingDefectKind.routeKeepOutViolation,
            severity: SimulationSeverity.error,
            objectId: route.id,
            relatedObjectIds: [zone.id],
            message:
                'Route crosses keep-out zone ${zone.id}${zone.reason == null ? '' : ': ${zone.reason}'}.',
          ),
        );
      }
    }

    final source = byId[route.source.componentId];
    final target = byId[route.target.componentId];
    if (source == null || target == null) return;
    if (source.surface.spaceId != request.space.id ||
        target.surface.spaceId != request.space.id) {
      return;
    }

    var graph = AutoRouteGraphBuilder.build(
      space: request.space,
      source: source,
      target: target,
      roomHeightMm: request.roomHeightMm,
    );
    graph = RoutingConstraintEngine.constrain(
      graph: graph,
      zones: request.keepOutZones,
    );
    final solution = RouteEngine.solve(
      graph: graph,
      startNodeId: 'source',
      endNodeId: 'target',
      preference: request.routePreference,
    );
    if (solution == null) {
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeNoFeasibleAlternative,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message:
              'No feasible auto-route satisfies the current geometric constraints.',
        ),
      );
      return;
    }

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
      currentTransitionCount: currentTransitions,
      optimizedTransitionCount: math.max(0, optimizedSegments.length - 1),
    );
    final minimumSaving =
        route.geometricLengthMm * request.profile.routeImprovementThreshold;
    if (candidate.savingMm > minimumSaving) {
      candidates.add(candidate);
      defects.add(
        DrawingDefect(
          kind: DrawingDefectKind.routeInefficient,
          severity: SimulationSeverity.warning,
          objectId: route.id,
          message:
              'A shorter route can save ${candidate.savingMm.round()} mm (${candidate.savingPercent.toStringAsFixed(1)}%).',
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
          message:
              'Configured distribution board node is missing from topology.',
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
            message:
                'No physical engineering path exists from component to distribution board.',
          ),
        );
        continue;
      }
      if (!topology.hasDirectedPath(boardNodeId, component.id)) {
        defects.add(
          DrawingDefect(
            kind: DrawingDefectKind.topologyWrongFlowDirection,
            severity: SimulationSeverity.error,
            objectId: component.id,
            message:
                'Topology is connected, but no directed supply path exists from distribution board to component.',
          ),
        );
      }
    }
  }

  static int _score(
    List<DrawingDefect> defects,
    EngineeringAnalysisProfile profile,
  ) {
    var score = 100;
    for (final defect in defects) {
      score -= switch (defect.severity) {
        SimulationSeverity.error => profile.penaltyFor(
            AnalysisSeverityWeight.error,
          ),
        SimulationSeverity.warning => profile.penaltyFor(
            AnalysisSeverityWeight.warning,
          ),
        SimulationSeverity.info => profile.penaltyFor(
            AnalysisSeverityWeight.info,
          ),
      };
    }
    return score.clamp(0, 100);
  }
}
