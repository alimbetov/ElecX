import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/plan_cable_route_projector.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

ElectricalCableRoute route(List<ElectricalRouteSegment> segments) =>
    ElectricalCableRoute(
      id: 'route-test',
      source: const ElectricalEndpointRef(
        componentId: 'board',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'socket',
        portId: 'power-in',
      ),
      segments: segments,
    );

void main() {
  test('Wall vertical leg is a point and ceiling cable has plan geometry', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    final space = controller.level.spaces.first;
    final wall = RoomSurfaceResolver.wall(space, 0);
    final result = PlanCableRouteProjector.project(
      level: controller.level,
      routes: [
        route([
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.wall(space.id, 0),
            points: const [
              SurfacePointMm(900, 1500),
              SurfacePointMm(900, 3000),
            ],
          ),
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.ceiling(space.id),
            points: const [
              SurfacePointMm(900, 0),
              SurfacePointMm(1500, 0),
            ],
          ),
        ]),
      ],
    );
    expect(result.skippedSurfaceSegments, 0);
    expect(result.segments, hasLength(2));
    expect(result.segments.first.isVerticalPlanMarker, isTrue);
    final expectedWallPoint = RoomSurfaceResolver.wallLocalToPlan(wall, 900);
    expect(
        result.segments.first.points, [expectedWallPoint, expectedWallPoint]);
    expect(result.segments.last.surfaceType, SurfacePlaneType.ceiling);
    expect(
      result.segments.last.points,
      [
        MmPoint(space.boundary.bounds.left + 900, space.boundary.bounds.bottom),
        MmPoint(
            space.boundary.bounds.left + 1500, space.boundary.bounds.bottom),
      ],
    );
  });

  test('independent room spans are not joined by an invented wall passage', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    final living = controller.level.spaces.first;
    final corridor = controller.level.spaces.last;
    final result = PlanCableRouteProjector.project(
      level: controller.level,
      routes: [
        route([
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.floor(living.id),
            points: const [
              SurfacePointMm(100, 100),
              SurfacePointMm(400, 100),
            ],
          ),
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.floor(corridor.id),
            points: const [
              SurfacePointMm(100, 100),
              SurfacePointMm(400, 100),
            ],
          ),
        ]),
      ],
    );
    expect(result.segments, hasLength(2));
    expect(result.segments.first.points.last,
        isNot(result.segments.last.points.first));
  });

  test('unknown/canonical-unmapped wall host is skipped, never guessed', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    final result = PlanCableRouteProjector.project(
      level: controller.level,
      routes: [
        route([
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.wallByBoundaryEdge(
              controller.level.spaces.first.id,
              BoundaryEdgeId('edge-not-resolved'),
            ),
            points: const [
              SurfacePointMm(100, 1000),
              SurfacePointMm(200, 1000),
            ],
          ),
        ]),
      ],
    );
    expect(result.hasIncompleteProjection, isTrue);
    expect(result.skippedSurfaceSegments, 1);
    expect(result.segments, isEmpty);
  });
}
