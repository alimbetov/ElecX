import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/hosted_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/circuit_sizing_evidence.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('physical cable penetration integration', () {
    test('cross-space route fails closed without a wall penetration', () {
      final segments = _wallSegments();

      expect(
        () => ElectricalCableRoute(
          id: 'route-physical',
          source: const ElectricalEndpointRef(
            componentId: 'source',
            portId: 'out',
          ),
          target: const ElectricalEndpointRef(
            componentId: 'target',
            portId: 'in',
          ),
          segments: segments,
        ),
        throwsArgumentError,
      );
    });

    test('floor-to-ceiling route fails closed without a slab penetration', () {
      expect(
        () => ElectricalCableRoute(
          id: 'route-level',
          source: const ElectricalEndpointRef(
            componentId: 'source',
            portId: 'out',
          ),
          target: const ElectricalEndpointRef(
            componentId: 'target',
            portId: 'in',
          ),
          segments: [
            ElectricalRouteSegment(
              surface: RoomSurfaceRef.ceiling('space-l1'),
              points: const [
                SurfacePointMm(100, 100),
                SurfacePointMm(500, 500),
              ],
            ),
            ElectricalRouteSegment(
              surface: RoomSurfaceRef.floor('space-l2'),
              points: const [
                SurfacePointMm(500, 500),
                SurfacePointMm(900, 900),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('hidden penetration length contributes to installed cable length', () {
      final segments = _wallSegments();
      final penetration = _wallPenetration(segments);
      final route = _route(segments: segments, penetration: penetration);

      expect(route.visibleLengthMm, 1100);
      expect(route.hiddenPenetrationLengthMm, 180);
      expect(route.geometricLengthMm, 1280);
      expect(route.installationLengthMm, 1344);
    });

    test('one physical transition rejects two different penetrations', () {
      final segments = _wallSegments();
      final first = _wallPenetration(segments);
      final second = BoundaryPenetration.normal(
        id: 'penetration-2',
        hostKind: BoundaryPenetrationHostKind.wall,
        entrySurface: segments.first.surface,
        entryPoint: segments.first.points.last,
        exitSurface: segments.last.surface,
        exitPoint: segments.last.points.first,
        hostThicknessMm: 180,
        routeId: 'route-physical',
        materialId: 'brick',
      );

      expect(
        () => ElectricalCableRoute(
          id: 'route-physical',
          source: const ElectricalEndpointRef(
            componentId: 'source',
            portId: 'out',
          ),
          target: const ElectricalEndpointRef(
            componentId: 'target',
            portId: 'in',
          ),
          segments: segments,
          penetrations: [first, second],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains(
              'must have exactly one penetration or one proven VerticalCore leg; '
              'found 2 penetration(s) and 0 VerticalCore leg(s)',
            ),
          ),
        ),
      );
    });

    test('hosted adapter exposes penetration identity as explicit transition',
        () {
      final segments = _wallSegments();
      final penetration = _wallPenetration(segments);
      final route = _route(segments: segments, penetration: penetration);

      final hosted = HostedRouteAdapter.fromIndoor(route);

      expect(hosted.routeId, route.id);
      expect(hosted.transitions, hasLength(1));
      final transition = hosted.transitions.single;
      expect(transition.id, penetration.id);
      expect(transition.kind, RouteHostTransitionKind.roomPenetration);
      expect(transition.slabId, isNull);
      expect(transition.requiresPenetration, isTrue);
      expect(transition.fromHost.surface, penetration.entryAnchor.surface);
      expect(transition.toHost.surface, penetration.exitAnchor.surface);
      expect(transition.fromPoint.x, penetration.entryAnchor.point.xMm);
      expect(transition.fromPoint.y, penetration.entryAnchor.point.yMm);
      expect(transition.toPoint.x, penetration.exitAnchor.point.xMm);
      expect(transition.toPoint.y, penetration.exitAnchor.point.yMm);
    });

    test('hosted adapter exposes slab continuation as stable level transition',
        () {
      final segments = _slabSegments();
      final penetration = _slabPenetration(segments);
      final route = ElectricalCableRoute(
        id: 'route-level',
        source: const ElectricalEndpointRef(
          componentId: 'source',
          portId: 'out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'target',
          portId: 'in',
        ),
        segments: segments,
        penetrations: [penetration],
      );

      final hosted = HostedRouteAdapter.fromIndoor(route);
      final transition = hosted.transitions.single;

      expect(transition.id, penetration.id);
      expect(transition.kind, RouteHostTransitionKind.levelPenetration);
      expect(transition.slabId, SlabId('slab-01-02'));
      expect(transition.requiresPenetration, isTrue);
      expect(transition.fromHost.surface, RoomSurfaceRef.ceiling('space-l1'));
      expect(transition.toHost.surface, RoomSurfaceRef.floor('space-l2'));
    });

    test('penetration geometry change invalidates cable sizing signature', () {
      final segments = _wallSegments();
      final originalPenetration = _wallPenetration(segments);
      final original = _route(
        segments: segments,
        penetration: originalPenetration,
      );
      final longerPenetration = BoundaryPenetration(
        id: originalPenetration.id,
        hostKind: originalPenetration.hostKind,
        entryAnchor: originalPenetration.entryAnchor,
        exitAnchor: originalPenetration.exitAnchor,
        hostThicknessMm: originalPenetration.hostThicknessMm,
        pathLengthMm: 240,
        materialId: originalPenetration.materialId,
      );
      final changed = _route(
        segments: segments,
        penetration: longerPenetration,
      );

      expect(
        CircuitSizingEvidence.geometrySignature(changed),
        isNot(CircuitSizingEvidence.geometrySignature(original)),
      );
      expect(changed.geometricLengthMm, original.geometricLengthMm + 60);
    });

    test('canonical wall and penetration survive project JSON round-trip', () {
      final editor = EditorController.demo();
      final workspace = EditorBuildingWorkspace.demo(editor);
      addTearDown(() {
        editor.disposeP2State();
        workspace.dispose();
        editor.dispose();
      });

      final base = EditorProjectDocument.capture(workspace);
      final segments = _wallSegments();
      final penetration = _wallPenetration(segments);
      final route = _route(segments: segments, penetration: penetration);
      final document = EditorProjectDocument(
        schemaVersion: base.schemaVersion,
        metadata: base.metadata,
        building: base.building,
        site: base.site,
        workspaceContext: base.workspaceContext,
        activeLevelNumber: base.activeLevelNumber,
        selectedZoneId: base.selectedZoneId,
        activeOutdoorZoneId: base.activeOutdoorZoneId,
        openingsByLevel: base.openingsByLevel,
        resume: base.resume,
        p2State: EditorP2State(routes: [route]),
      );

      final json = document.toJson();
      expect(json['schemaVersion'], 8);
      final routeJson = ((json['p2']! as Map)['routes']! as List).single as Map;
      final firstSurface =
          ((routeJson['segments']! as List).first as Map)['surface'] as Map;
      expect(firstSurface['wallIndex'], isNull);
      expect(firstSurface['boundaryEdgeId'], 'edge-a');

      final restored = EditorProjectDocument.fromJson(json);
      final restoredRoute = restored.p2State.routes.single;
      expect(
        restoredRoute.segments.first.surface.boundaryEdgeId?.value,
        'edge-a',
      );
      expect(
        restoredRoute.segments.last.surface.boundaryEdgeId?.value,
        'edge-b',
      );
      expect(restoredRoute.penetrations, hasLength(1));
      expect(restoredRoute.penetrations.single.id, 'penetration-1');
      expect(restoredRoute.penetrations.single.routeId, 'route-physical');
      expect(restoredRoute.penetrations.single.hostThicknessMm, 180);
      expect(restoredRoute.geometricLengthMm, 1280);
      expect(
        restoredRoute.penetrations.single.exitAnchor.isContinuationStart,
        isTrue,
      );
    });

    test('copyWith preserves penetration aggregate by default', () {
      final segments = _wallSegments();
      final penetration = _wallPenetration(segments);
      final route = _route(segments: segments, penetration: penetration);

      final changed = route.copyWith(cableType: 'NYM-J 3x2.5');

      expect(changed.penetrations, same(route.penetrations));
      expect(changed.geometricLengthMm, route.geometricLengthMm);
    });
  });
}

List<ElectricalRouteSegment> _wallSegments() {
  final entrySurface = RoomSurfaceRef.wallByBoundaryEdge(
    'space-a',
    BoundaryEdgeId('edge-a'),
  );
  final exitSurface = RoomSurfaceRef.wallByBoundaryEdge(
    'space-b',
    BoundaryEdgeId('edge-b'),
  );
  return [
    ElectricalRouteSegment(
      surface: entrySurface,
      points: const [
        SurfacePointMm(0, 1000),
        SurfacePointMm(500, 1000),
      ],
    ),
    ElectricalRouteSegment(
      surface: exitSurface,
      points: const [
        SurfacePointMm(200, 1000),
        SurfacePointMm(800, 1000),
      ],
    ),
  ];
}

List<ElectricalRouteSegment> _slabSegments() => [
      ElectricalRouteSegment(
        surface: RoomSurfaceRef.ceiling('space-l1'),
        points: const [
          SurfacePointMm(100, 500),
          SurfacePointMm(500, 500),
        ],
      ),
      ElectricalRouteSegment(
        surface: RoomSurfaceRef.floor('space-l2'),
        points: const [
          SurfacePointMm(500, 500),
          SurfacePointMm(900, 500),
        ],
      ),
    ];

BoundaryPenetration _wallPenetration(List<ElectricalRouteSegment> segments) =>
    BoundaryPenetration.normal(
      id: 'penetration-1',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: segments.first.surface,
      entryPoint: segments.first.points.last,
      exitSurface: segments.last.surface,
      exitPoint: segments.last.points.first,
      hostThicknessMm: 180,
      routeId: 'route-physical',
      materialId: 'brick',
    );

BoundaryPenetration _slabPenetration(List<ElectricalRouteSegment> segments) =>
    BoundaryPenetration.normal(
      id: 'penetration-level',
      hostKind: BoundaryPenetrationHostKind.slab,
      entrySurface: segments.first.surface,
      entryPoint: segments.first.points.last,
      exitSurface: segments.last.surface,
      exitPoint: segments.last.points.first,
      hostThicknessMm: 200,
      routeId: 'route-level',
      materialId: 'reinforced-concrete',
      slabId: SlabId('slab-01-02'),
    );

ElectricalCableRoute _route({
  required List<ElectricalRouteSegment> segments,
  required BoundaryPenetration penetration,
}) =>
    ElectricalCableRoute(
      id: 'route-physical',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target',
        portId: 'in',
      ),
      segments: segments,
      penetrations: [penetration],
    );
