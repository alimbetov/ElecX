import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/plan_cable_route_projector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wallA = RoomSurfaceRef.wall('room-a', 1);
  final wallBEntry = RoomSurfaceRef.wall('room-b', 3);
  final ceilingB = RoomSurfaceRef.ceiling('room-b');
  final wallBExit = RoomSurfaceRef.wall('room-b', 1);
  final wallC = RoomSurfaceRef.wall('room-c', 3);

  final segments = <ElectricalRouteSegment>[
    ElectricalRouteSegment(
      surface: wallA,
      points: const [
        SurfacePointMm(100, 1000),
        SurfacePointMm(700, 1000),
      ],
    ),
    ElectricalRouteSegment(
      surface: wallBEntry,
      points: const [
        SurfacePointMm(200, 1000),
        SurfacePointMm(900, 1000),
      ],
    ),
    ElectricalRouteSegment(
      surface: ceilingB,
      points: const [
        SurfacePointMm(100, 100),
        SurfacePointMm(400, 100),
      ],
    ),
    ElectricalRouteSegment(
      surface: wallBExit,
      points: const [
        SurfacePointMm(300, 1000),
        SurfacePointMm(800, 1000),
      ],
    ),
    ElectricalRouteSegment(
      surface: wallC,
      points: const [
        SurfacePointMm(200, 1000),
        SurfacePointMm(900, 1000),
      ],
    ),
  ];

  final passages = <BoundaryPenetration>[
    BoundaryPenetration.normal(
      id: 'wall-ab',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: wallA,
      entryPoint: segments[0].points.last,
      exitSurface: wallBEntry,
      exitPoint: segments[1].points.first,
      hostThicknessMm: 180,
      routeId: 'three-room-route',
      materialId: 'brick',
    ),
    BoundaryPenetration.normal(
      id: 'wall-bc',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: wallBExit,
      entryPoint: segments[3].points.last,
      exitSurface: wallC,
      exitPoint: segments[4].points.first,
      hostThicknessMm: 200,
      routeId: 'three-room-route',
      materialId: 'concrete',
    ),
  ];

  ElectricalCableRoute route(List<BoundaryPenetration> penetrations) =>
      ElectricalCableRoute(
        id: 'three-room-route',
        source: const ElectricalEndpointRef(
          componentId: 'board',
          portId: 'out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'socket',
          portId: 'in',
        ),
        segments: segments,
        penetrations: penetrations,
      );

  test('two physical wall passages retain their hidden cable length', () {
    final physical = route(passages);

    expect(physical.penetrations, hasLength(2));
    expect(physical.visibleLengthMm, 2800);
    expect(physical.hiddenPenetrationLengthMm, 380);
    expect(physical.geometricLengthMm, 3180);
    expect(physical.installationLengthMm, 3339);
  });

  test('missing intermediate wall passage fails closed', () {
    expect(() => route([passages.first]), throwsArgumentError);
    expect(() => route([passages.last]), throwsArgumentError);
    expect(() => route([]), throwsArgumentError);
  });

  test('three-room projection keeps physical surface spans distinct', () {
    EngineeringSpace room(String id, int left, int right) {
      final boundary = MmPolygon.rectangle(
        MmPoint(left, 0),
        MmPoint(right, 3000),
      );
      return EngineeringSpace(
        id: id,
        name: id,
        type: SpaceType.room,
        boundary: boundary,
        referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
      );
    }

    final level = BuildingLevel(
      id: 'level-1',
      name: 'Level 1',
      elevationMm: 0,
      spaces: [
        room('room-a', 0, 4000),
        room('room-b', 4000, 8000),
        room('room-c', 8000, 12000),
      ],
    );

    final projected = PlanCableRouteProjector.project(
      level: level,
      routes: [route(passages)],
    );

    expect(projected.hasIncompleteProjection, isFalse);
    expect(projected.segments, hasLength(5));
    expect(
      projected.segments.map((segment) => segment.routeId).toSet(),
      {'three-room-route'},
    );
    expect(projected.segments[2].surfaceType, SurfacePlaneType.ceiling);
    expect(
      projected.segments[2].points,
      [const MmPoint(4100, 100), const MmPoint(4400, 100)],
    );
  });
}
