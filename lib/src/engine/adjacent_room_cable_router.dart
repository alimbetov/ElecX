import '../domain/boundary_construction_registry.dart';
import '../domain/boundary_construction_transition_resolver.dart';
import '../domain/cable_penetration_authoring.dart';
import '../domain/electrical_placement.dart';
import '../domain/electrical_routing.dart';
import '../domain/project_identity.dart';
import '../domain/project_model.dart';
import '../domain/route_medium.dart';
import '../domain/surface_transition_graph.dart';
import '../domain/surfaces.dart';
import 'auto_route_graph_builder.dart';
import 'normative_route_engine.dart';
import 'route_engine.dart';

/// Physical proposal only. Electrical sizing/protection is never inferred.
/// The first supported apartment path crosses one proven shared wall; no
/// synthetic room, boundary, penetration thickness or material is introduced.
abstract final class AdjacentRoomCableRouter {
  static ElectricalCableRoute build({
    required BuildingLevel level,
    required ElectricalComponentPlacement source,
    required ElectricalComponentPlacement target,
    required String routeId,
    required Map<String, List<BoundaryEdgeId>> edgeOrderBySpace,
    required CanonicalSpaceIdResolver canonicalSpaceIdResolver,
    required BoundaryConstructionRegistry constructions,
    required EntityIdFactory identityFactory,
    List<ArchitecturalOpening> openings = const [],
    int roomHeightMm = 3000,
  }) {
    final spaces = {for (final space in level.spaces) space.id: space};
    final from = spaces[source.surface.spaceId];
    final to = spaces[target.surface.spaceId];
    if (from == null || to == null || from.id == to.id) {
      throw StateError(
          'Нужны два устройства в разных помещениях одного этажа.');
    }
    if (!source.ports.any((p) =>
            p.id == 'power-out' && p.kind == ElectricalPortKind.powerOut) ||
        !target.ports.any((p) =>
            p.id == 'power-in' && p.kind == ElectricalPortKind.powerIn)) {
      throw StateError('Нет совместимых питающих портов щита и нагрузки.');
    }
    final toEdges = edgeOrderBySpace[to.id];
    if (toEdges == null || edgeOrderBySpace[from.id] == null) {
      throw StateError('Не подтверждены канонические границы помещений.');
    }
    SurfaceTransitionCandidate? resolve(RoomSurfaceRef a, SurfacePointMm ap,
        RoomSurfaceRef b, SurfacePointMm bp) {
      final space = spaces[a.spaceId];
      if (space == null) return null;
      return BoundaryConstructionTransitionResolver.resolve(
        level: level,
        fromSpace: space,
        fromSurface: a,
        fromPoint: ap,
        toSurface: b,
        toPoint: bp,
        constructions: constructions,
        edgeOrderResolver: (id) => edgeOrderBySpace[id],
        canonicalSpaceIdResolver: canonicalSpaceIdResolver,
        roomHeightMm: roomHeightMm,
      );
    }

    final candidates = <ElectricalCableRoute>[];
    // Sample each target wall independently: a long corridor wall may overlap
    // several shorter room walls, so its own midpoint is insufficient.
    for (final wall in RoomSurfaceResolver.wallsByBoundaryEdges(to, toEdges,
        defaultHeightMm: roomHeightMm)) {
      final point = SurfacePointMm(wall.lengthMm ~/ 2, roomHeightMm - 300);
      for (final crossing in SurfaceTransitionGraph.candidates(
        level: level,
        fromSpace: to,
        fromSurface: wall.ref,
        point: point,
        roomHeightMm: roomHeightMm,
        boundaryEdgeOrderResolver: (id) => edgeOrderBySpace[id],
      )) {
        if (crossing.kind != SurfaceTransitionKind.roomPenetration ||
            crossing.toSurface.spaceId != from.id) {
          continue;
        }
        final proven = resolve(crossing.toSurface, crossing.toPoint,
            crossing.fromSurface, crossing.fromPoint);
        if (proven == null) continue;
        try {
          final segments = [
            ..._leg(
                from,
                source,
                source.copyWith(
                    surface: proven.fromSurface, position: proven.fromPoint),
                edgeOrderBySpace[from.id]!,
                roomHeightMm),
            ..._leg(
                to,
                target.copyWith(
                    surface: proven.toSurface, position: proven.toPoint),
                target,
                toEdges,
                roomHeightMm),
          ];
          var valid = true;
          for (final segment in segments) {
            final space = spaces[segment.surface.spaceId]!;
            final legacy =
                _legacySurface(segment.surface, edgeOrderBySpace[space.id]!);
            final context = _context(space, legacy, openings,
                edgeOrderBySpace[space.id]!, roomHeightMm);
            if (!NormativeRouteEngine.validate(
                    points: List.unmodifiable(segment.points), context: context)
                .isValid) {
              valid = false;
              break;
            }
          }
          if (!valid) continue;
          final route = CablePenetrationAuthoring.build(
            routeId: routeId,
            source: ElectricalEndpointRef(
                componentId: source.id, portId: 'power-out'),
            target: ElectricalEndpointRef(
                componentId: target.id, portId: 'power-in'),
            segments: [
              for (final segment in segments)
                ElectricalRouteSegment(
                    surface: segment.surface,
                    points: List.unmodifiable(segment.points),
                    anchorIds: List.unmodifiable([
                      for (final _ in segment.points)
                        identityFactory.newRouteAnchorId()
                    ]))
            ],
            resolveTransition: resolve,
            penetrationIdFactory: (_, __) =>
                identityFactory.newBoundaryPenetrationId(),
            medium: RouteMediumProfile.acPower,
          );
          if (ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
              route: route, components: [source, target])) {
            candidates.add(route);
          }
        } on ArgumentError {
          continue;
        } on StateError {
          continue;
        }
      }
    }
    if (candidates.isEmpty) {
      throw StateError('Нет допустимого пути через общую стену. '
          'Укажите одинаковую толщину и материал на обеих сторонах стены '
          'и проверьте проёмы. Прямое соединение через комнаты запрещено.');
    }
    candidates
        .sort((a, b) => a.geometricLengthMm.compareTo(b.geometricLengthMm));
    return candidates.first;
  }

  static RoomSurfaceRef _legacySurface(
      RoomSurfaceRef surface, List<BoundaryEdgeId> edges) {
    if (surface.boundaryEdgeId == null) return surface;
    final index = edges.indexOf(surface.boundaryEdgeId!);
    if (index < 0) throw StateError('Поверхность стены устарела.');
    return RoomSurfaceRef.wall(surface.spaceId, index);
  }

  static List<ElectricalRouteSegment> _leg(
      EngineeringSpace space,
      ElectricalComponentPlacement a,
      ElectricalComponentPlacement b,
      List<BoundaryEdgeId> edges,
      int height) {
    final graph = AutoRouteGraphBuilder.build(
        space: space,
        source: a.copyWith(surface: _legacySurface(a.surface, edges)),
        target: b.copyWith(surface: _legacySurface(b.surface, edges)),
        roomHeightMm: height);
    final path = RouteEngine.solve(
        graph: graph,
        startNodeId: 'source',
        endNodeId: 'target',
        preference: RoutePreference.preferCeiling);
    if (path == null) throw StateError('В помещении нет допустимого пути.');
    return [
      for (final segment in RouteEngine.toSegments(graph, path))
        ElectricalRouteSegment(
          surface: segment.surface.type == SurfacePlaneType.wall
              ? RoomSurfaceRef.wallByBoundaryEdge(
                  space.id, edges[segment.surface.wallIndex!])
              : segment.surface,
          points: segment.points.length == 1
              ? [segment.points.single, segment.points.single]
              : segment.points,
          anchorIds: const [],
        ),
    ];
  }

  static RouteNormativeContext _context(
      EngineeringSpace space,
      RoomSurfaceRef surface,
      List<ArchitecturalOpening> openings,
      List<BoundaryEdgeId> edges,
      int height) {
    final bounds = space.boundary.bounds;
    if (surface.type != SurfacePlaneType.wall) {
      return RouteNormativeContext(
          surface: surface,
          widthMm: bounds.width,
          heightMm: bounds.height,
          edgeClearanceMm: 0,
          boundary: [
            for (final p in space.boundary.vertices)
              SurfacePointMm(p.x - bounds.left, p.y - bounds.bottom)
          ]);
    }
    final wall = RoomSurfaceResolver.wall(space, surface.wallIndex!,
        defaultHeightMm: height);
    return RouteNormativeContext(
      surface: surface,
      widthMm: wall.lengthMm.round(),
      heightMm: wall.heightMm,
      edgeClearanceMm: 0,
      boundary: [
        for (final p in wall.profile.vertices) SurfacePointMm(p.xMm, p.yMm)
      ],
      obstacles: [
        for (final o in openings)
          if (o.hostWall.spaceId == space.id &&
              _legacySurface(o.hostWall, edges) == surface)
            RouteObstacleMm(
                id: o.id,
                leftMm: o.offsetFromStartMm,
                topMm: o.sillHeightMm,
                rightMm: o.endOffsetMm,
                bottomMm: o.topMm)
      ],
    );
  }
}
