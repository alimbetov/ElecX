import 'dart:math' as math;

import '../domain/electrical_placement.dart';
import '../domain/geometry.dart';
import '../domain/project_model.dart';
import '../domain/surfaces.dart';
import 'route_engine.dart';

abstract final class AutoRouteGraphBuilder {
  static RoutingGraph build({
    required EngineeringSpace space,
    required ElectricalComponentPlacement source,
    required ElectricalComponentPlacement target,
    int roomHeightMm = 3000,
  }) {
    if (source.surface.spaceId != space.id ||
        target.surface.spaceId != space.id) {
      throw ArgumentError('Components must belong to the supplied room.');
    }
    final builder = _GraphBuilder();
    builder.addNode('source', source.surface, source.position);
    builder.addNode('target', target.surface, target.position);

    if (source.surface == target.surface) {
      builder.connectOrthogonal('source', 'target');
      return builder.build();
    }

    _addComponentTransitions(
      builder: builder,
      space: space,
      componentId: 'source',
      component: source,
      roomHeightMm: roomHeightMm,
    );
    _addComponentTransitions(
      builder: builder,
      space: space,
      componentId: 'target',
      component: target,
      roomHeightMm: roomHeightMm,
    );

    _connectHorizontalTransitionNodes(builder, SurfacePlaneType.floor);
    _connectHorizontalTransitionNodes(builder, SurfacePlaneType.ceiling);

    if ({
          source.surface.type,
          target.surface.type,
        }.contains(SurfacePlaneType.floor) &&
        {
          source.surface.type,
          target.surface.type,
        }.contains(SurfacePlaneType.ceiling)) {
      _addFloorCeilingBridges(
        builder: builder,
        space: space,
        roomHeightMm: roomHeightMm,
      );
      _connectHorizontalTransitionNodes(builder, SurfacePlaneType.floor);
      _connectHorizontalTransitionNodes(builder, SurfacePlaneType.ceiling);
    }

    return builder.build();
  }

  static void _addComponentTransitions({
    required _GraphBuilder builder,
    required EngineeringSpace space,
    required String componentId,
    required ElectricalComponentPlacement component,
    required int roomHeightMm,
  }) {
    switch (component.surface.type) {
      case SurfacePlaneType.wall:
        final wall = RoomSurfaceResolver.wall(
          space,
          component.surface.wallIndex!,
        );
        final x = component.position.xMm.clamp(0, wall.lengthMm.round());
        final bottomId = '$componentId:wall-bottom';
        builder.addNode(bottomId, component.surface, SurfacePointMm(x, 0));
        builder.connectOrthogonal(componentId, bottomId);
        final floorPoint = _wallXToHorizontal(space, wall, x);
        final floorId = '$componentId:floor-transition';
        builder.addNode(floorId, RoomSurfaceRef.floor(space.id), floorPoint);
        builder.connectTransition(bottomId, floorId);

        if (wall.profile.containsPoint(x, roomHeightMm)) {
          final topId = '$componentId:wall-top';
          builder.addNode(
            topId,
            component.surface,
            SurfacePointMm(x, roomHeightMm),
          );
          builder.connectOrthogonal(componentId, topId);
          final ceilingId = '$componentId:ceiling-transition';
          builder.addNode(
            ceilingId,
            RoomSurfaceRef.ceiling(space.id),
            floorPoint,
          );
          builder.connectTransition(topId, ceilingId);
        }
      case SurfacePlaneType.floor:
        _addHorizontalToWallTransitions(
          builder: builder,
          space: space,
          componentId: componentId,
          component: component,
          horizontalType: SurfacePlaneType.floor,
          roomHeightMm: roomHeightMm,
        );
      case SurfacePlaneType.ceiling:
        _addHorizontalToWallTransitions(
          builder: builder,
          space: space,
          componentId: componentId,
          component: component,
          horizontalType: SurfacePlaneType.ceiling,
          roomHeightMm: roomHeightMm,
        );
    }
  }

  static void _addHorizontalToWallTransitions({
    required _GraphBuilder builder,
    required EngineeringSpace space,
    required String componentId,
    required ElectricalComponentPlacement component,
    required SurfacePlaneType horizontalType,
    required int roomHeightMm,
  }) {
    final plan = _horizontalToPlan(space, component.position);
    for (var i = 0; i < space.boundary.vertices.length; i++) {
      final wall = RoomSurfaceResolver.wall(space, i);
      final xMm = _projectXOnWall(wall, plan);
      final horizontalPoint = _wallXToHorizontal(space, wall, xMm);
      final horizontalId = '$componentId:${horizontalType.name}:w$i';
      builder.addNode(horizontalId, component.surface, horizontalPoint);
      builder.connectOrthogonal(componentId, horizontalId);

      final y = horizontalType == SurfacePlaneType.ceiling ? roomHeightMm : 0;
      if (horizontalType == SurfacePlaneType.ceiling &&
          !wall.profile.containsPoint(xMm, roomHeightMm)) {
        continue;
      }
      final wallId = '$componentId:wall:$i:${horizontalType.name}';
      builder.addNode(
        wallId,
        RoomSurfaceRef.wall(space.id, i),
        SurfacePointMm(xMm, y),
      );
      builder.connectTransition(horizontalId, wallId);
    }
  }

  static void _addFloorCeilingBridges({
    required _GraphBuilder builder,
    required EngineeringSpace space,
    required int roomHeightMm,
  }) {
    for (var i = 0; i < space.boundary.vertices.length; i++) {
      final wall = RoomSurfaceResolver.wall(space, i);
      for (final x in <int>{0, wall.lengthMm.round()}) {
        if (!wall.profile.containsPoint(x, roomHeightMm)) continue;
        final horizontal = _wallXToHorizontal(space, wall, x);
        final floorId = 'bridge:$i:$x:floor';
        final wallBottomId = 'bridge:$i:$x:wall-bottom';
        final wallTopId = 'bridge:$i:$x:wall-top';
        final ceilingId = 'bridge:$i:$x:ceiling';
        builder.addNode(floorId, RoomSurfaceRef.floor(space.id), horizontal);
        builder.addNode(
          wallBottomId,
          RoomSurfaceRef.wall(space.id, i),
          SurfacePointMm(x, 0),
        );
        builder.addNode(
          wallTopId,
          RoomSurfaceRef.wall(space.id, i),
          SurfacePointMm(x, roomHeightMm),
        );
        builder.addNode(
          ceilingId,
          RoomSurfaceRef.ceiling(space.id),
          horizontal,
        );
        builder.connectTransition(floorId, wallBottomId);
        builder.connectDirect(wallBottomId, wallTopId);
        builder.connectTransition(wallTopId, ceilingId);
      }
    }
  }

  static void _connectHorizontalTransitionNodes(
    _GraphBuilder builder,
    SurfacePlaneType type,
  ) {
    final ids = builder.nodes.entries
        .where((entry) => entry.value.surface.type == type)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        builder.connectOrthogonal(ids[i], ids[j]);
      }
    }
  }

  static SurfacePointMm _wallXToHorizontal(
    EngineeringSpace space,
    RoomWallSurface wall,
    int xMm,
  ) {
    final plan = RoomSurfaceResolver.wallLocalToPlan(wall, xMm);
    final bounds = space.boundary.bounds;
    return SurfacePointMm(plan.x - bounds.left, plan.y - bounds.bottom);
  }

  static MmPoint _horizontalToPlan(
    EngineeringSpace space,
    SurfacePointMm point,
  ) {
    final bounds = space.boundary.bounds;
    return MmPoint(bounds.left + point.xMm, bounds.bottom + point.yMm);
  }

  static int _projectXOnWall(RoomWallSurface wall, MmPoint point) {
    final ax = wall.start.x.toDouble();
    final ay = wall.start.y.toDouble();
    final dx = (wall.end.x - wall.start.x).toDouble();
    final dy = (wall.end.y - wall.start.y).toDouble();
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return 0;
    final rawT = ((point.x - ax) * dx + (point.y - ay) * dy) / lengthSquared;
    final t = rawT.clamp(0.0, 1.0);
    return (math.sqrt(lengthSquared) * t).round();
  }
}

final class _GraphBuilder {
  final Map<String, RouteNode> nodes = {};
  final List<RouteEdge> edges = [];
  int _elbowSequence = 0;

  void addNode(String id, RoomSurfaceRef surface, SurfacePointMm point) {
    nodes.putIfAbsent(
      id,
      () => RouteNode(id: id, surface: surface, point: point),
    );
  }

  void connectTransition(String a, String b) {
    _connect(a, b, 1, transition: true);
  }

  void connectDirect(String a, String b) {
    final first = nodes[a]!;
    final second = nodes[b]!;
    _connect(a, b, _distance(first.point, second.point));
  }

  void connectOrthogonal(String a, String b) {
    final first = nodes[a]!;
    final second = nodes[b]!;
    if (first.surface != second.surface) return;
    if (first.point.xMm == second.point.xMm ||
        first.point.yMm == second.point.yMm) {
      connectDirect(a, b);
      return;
    }
    final prefix = 'elbow-${_elbowSequence++}';
    final xId = '$prefix:x';
    final yId = '$prefix:y';
    addNode(
      xId,
      first.surface,
      SurfacePointMm(second.point.xMm, first.point.yMm),
    );
    addNode(
      yId,
      first.surface,
      SurfacePointMm(first.point.xMm, second.point.yMm),
    );
    connectDirect(a, xId);
    connectDirect(xId, b);
    connectDirect(a, yId);
    connectDirect(yId, b);
  }

  void _connect(String a, String b, double cost, {bool transition = false}) {
    if (a == b) return;
    final normalized = math.max(cost, 0.001).toDouble();
    edges
      ..add(RouteEdge(from: a, to: b, cost: normalized, transition: transition))
      ..add(
        RouteEdge(from: b, to: a, cost: normalized, transition: transition),
      );
  }

  RoutingGraph build() => RoutingGraph(
    nodes: Map.unmodifiable(nodes),
    edges: List.unmodifiable(edges),
  );

  static double _distance(SurfacePointMm a, SurfacePointMm b) {
    final dx = (a.xMm - b.xMm).toDouble();
    final dy = (a.yMm - b.yMm).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}
