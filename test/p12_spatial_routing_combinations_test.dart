import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/cable_penetration_authoring.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final room = EngineeringSpace(
    id: 'room-1',
    name: 'Room 1',
    type: SpaceType.room,
    boundary: MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    ),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
  );
  final level = BuildingLevel(
    id: 'level-1',
    name: 'Level 1',
    elevationMm: 0,
    spaces: [room],
  );

  ElectricalRouteSegment segment(
    RoomSurfaceRef surface,
    SurfacePointMm start,
    SurfacePointMm end,
  ) =>
      ElectricalRouteSegment(surface: surface, points: [start, end]);

  ElectricalCableRoute author(
    String id,
    List<ElectricalRouteSegment> segments,
    SurfaceTransitionCandidate? Function(
      RoomSurfaceRef,
      SurfacePointMm,
      RoomSurfaceRef,
      SurfacePointMm,
    ) resolver,
  ) =>
      CablePenetrationAuthoring.build(
        routeId: id,
        source: const ElectricalEndpointRef(
          componentId: 'board',
          portId: 'out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'socket',
          portId: 'in',
        ),
        segments: segments,
        resolveTransition: resolver,
        penetrationIdFactory: (index, _) =>
            BoundaryPenetrationId('$id-passage-$index'),
      );

  SurfaceTransitionCandidate? sameRoom(
    RoomSurfaceRef from,
    SurfacePointMm fromPoint,
    RoomSurfaceRef to,
    SurfacePointMm toPoint,
  ) {
    final candidates = SurfaceTransitionGraph.candidates(
      level: level,
      fromSpace: room,
      fromSurface: from,
      point: fromPoint,
    );
    for (final candidate in candidates) {
      if (candidate.toSurface == to && candidate.toPoint == toPoint) {
        return candidate;
      }
    }
    return null;
  }

  test('wall to ceiling and ceiling to wall are continuous', () {
    final wall = RoomSurfaceRef.wall(room.id, 0);
    final ceiling = RoomSurfaceRef.ceiling(room.id);
    final forward = author(
        'wall-ceiling',
        [
          segment(wall, const SurfacePointMm(1000, 1200),
              const SurfacePointMm(1000, 3000)),
          segment(ceiling, const SurfacePointMm(1000, 0),
              const SurfacePointMm(2000, 0)),
        ],
        sameRoom);
    final backward = author(
        'ceiling-wall',
        [
          segment(ceiling, const SurfacePointMm(2000, 0),
              const SurfacePointMm(1000, 0)),
          segment(wall, const SurfacePointMm(1000, 3000),
              const SurfacePointMm(1000, 1200)),
        ],
        sameRoom);

    expect(forward.penetrations, isEmpty);
    expect(backward.penetrations, isEmpty);
    expect(forward.segments, hasLength(2));
    expect(backward.segments, hasLength(2));
  });

  test('wall to floor and floor to wall are continuous', () {
    final wall = RoomSurfaceRef.wall(room.id, 0);
    final floor = RoomSurfaceRef.floor(room.id);
    final forward = author(
        'wall-floor',
        [
          segment(wall, const SurfacePointMm(1000, 1200),
              const SurfacePointMm(1000, 0)),
          segment(floor, const SurfacePointMm(1000, 0),
              const SurfacePointMm(2000, 0)),
        ],
        sameRoom);
    final backward = author(
        'floor-wall',
        [
          segment(floor, const SurfacePointMm(2000, 0),
              const SurfacePointMm(1000, 0)),
          segment(wall, const SurfacePointMm(1000, 0),
              const SurfacePointMm(1000, 1200)),
        ],
        sameRoom);

    expect(forward.penetrations, isEmpty);
    expect(backward.penetrations, isEmpty);
  });

  test('adjacent walls connect only through their common corner', () {
    final wall0 = RoomSurfaceRef.wall(room.id, 0);
    final wall1 = RoomSurfaceRef.wall(room.id, 1);
    final physical = author(
        'wall-corner',
        [
          segment(wall0, const SurfacePointMm(3000, 1200),
              const SurfacePointMm(4000, 1200)),
          segment(wall1, const SurfacePointMm(0, 1200),
              const SurfacePointMm(0, 1800)),
        ],
        sameRoom);
    expect(physical.penetrations, isEmpty);

    expect(
      () => author(
          'wall-teleport',
          [
            segment(wall0, const SurfacePointMm(1000, 1200),
                const SurfacePointMm(2000, 1200)),
            segment(wall1, const SurfacePointMm(0, 1200),
                const SurfacePointMm(0, 1800)),
          ],
          sameRoom),
      throwsStateError,
    );
  });

  test('floor and ceiling cannot connect without physical structure', () {
    final floor = RoomSurfaceRef.floor(room.id);
    final ceiling = RoomSurfaceRef.ceiling(room.id);
    expect(
      () => author(
          'floor-ceiling-teleport',
          [
            segment(floor, const SurfacePointMm(500, 500),
                const SurfacePointMm(1000, 500)),
            segment(ceiling, const SurfacePointMm(1000, 500),
                const SurfacePointMm(1500, 500)),
          ],
          sameRoom),
      throwsStateError,
    );
    expect(
      () => author(
          'ceiling-floor-teleport',
          [
            segment(ceiling, const SurfacePointMm(500, 500),
                const SurfacePointMm(1000, 500)),
            segment(floor, const SurfacePointMm(1000, 500),
                const SurfacePointMm(1500, 500)),
          ],
          sameRoom),
      throwsStateError,
    );
  });

  test('inter-level up and down require the exact canonical slab', () {
    final upperRoom = EngineeringSpace(
      id: 'room-2',
      name: 'Room 2',
      type: SpaceType.room,
      boundary: room.boundary,
      referenceFrame: room.referenceFrame,
    );
    final upperLevel = BuildingLevel(
      id: 'level-2',
      name: 'Level 2',
      elevationMm: 3220,
      spaces: [upperRoom],
    );
    final slab = ProjectSlab(
      id: SlabId('slab-1-2'),
      buildingId: BuildingId('building-1'),
      kind: SlabKind.interLevel,
      belowLevelId: LevelId(level.id),
      aboveLevelId: LevelId(upperLevel.id),
      bottomElevationMm: 3000,
      thicknessMm: 220,
      materialId: 'reinforced-concrete',
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ],
    );

    SurfaceTransitionCandidate? transition(
      RoomSurfaceRef from,
      SurfacePointMm fromPoint,
      RoomSurfaceRef to,
      SurfacePointMm toPoint, {
      ProjectSlab? structure,
    }) {
      final upward = from.spaceId == room.id;
      final candidate = SurfaceTransitionGraph.levelPenetration(
        buildingLevels: [level, upperLevel],
        fromLevel: upward ? level : upperLevel,
        fromSpace: upward ? room : upperRoom,
        fromSurface: from,
        point: fromPoint,
        fromRoomHeightMm: 3000,
        toLevel: upward ? upperLevel : level,
        toSpace: upward ? upperRoom : room,
        toRoomHeightMm: 3000,
        slabThicknessMm: 220,
        slab: structure,
        materialId: 'reinforced-concrete',
      );
      if (candidate?.toSurface != to || candidate?.toPoint != toPoint) {
        return null;
      }
      return candidate;
    }

    final ceiling = RoomSurfaceRef.ceiling(room.id);
    final upperFloor = RoomSurfaceRef.floor(upperRoom.id);
    final up = [
      segment(ceiling, const SurfacePointMm(1000, 1000),
          const SurfacePointMm(1500, 1000)),
      segment(upperFloor, const SurfacePointMm(1500, 1000),
          const SurfacePointMm(2000, 1000)),
    ];
    final down = [
      segment(upperFloor, const SurfacePointMm(2000, 1000),
          const SurfacePointMm(1500, 1000)),
      segment(ceiling, const SurfacePointMm(1500, 1000),
          const SurfacePointMm(1000, 1000)),
    ];
    SurfaceTransitionCandidate? verified(
      RoomSurfaceRef from,
      SurfacePointMm fromPoint,
      RoomSurfaceRef to,
      SurfacePointMm toPoint,
    ) =>
        transition(from, fromPoint, to, toPoint, structure: slab);

    for (final entry in [(id: 'up', spans: up), (id: 'down', spans: down)]) {
      final route = author(entry.id, entry.spans, verified);
      expect(route.penetrations, hasLength(1));
      expect(route.penetrations.single.slabId, slab.id);
      expect(route.hiddenPenetrationLengthMm, 220);
      expect(route.penetrations.single.materialId, 'reinforced-concrete');
    }

    expect(
      () =>
          author('no-slab', up, (from, p, to, q) => transition(from, p, to, q)),
      throwsStateError,
    );
    expect(
      () => author(
          'wrong-floor',
          [
            up.first,
            segment(
                RoomSurfaceRef.ceiling(upperRoom.id),
                const SurfacePointMm(1500, 1000),
                const SurfacePointMm(2000, 1000)),
          ],
          verified),
      throwsStateError,
    );
  });
}
