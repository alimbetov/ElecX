import 'dart:io';

import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/cable_penetration_authoring.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/plan_cable_route_projector.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
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

  test('R3.4 saves, loads and reopens one three-room electrical project',
      () async {
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
    final editor = EditorController.restored(level: level, openings: const []);
    final workspace = EditorBuildingWorkspace.blank(
      editor,
      projectId: 'r3-three-room',
      projectName: 'Three-room electrical acceptance',
    );
    final panel = ElectricalComponentPlacement(
      id: 'board',
      type: ElectricalComponentType.distributionBoard,
      surface: wallA,
      position: segments.first.points.first,
      label: 'Main distribution board',
      ports: const [
        ElectricalPortDefinition(id: 'out', kind: ElectricalPortKind.powerOut),
      ],
    );
    final socket = ElectricalComponentPlacement(
      id: 'socket',
      type: ElectricalComponentType.socketOutlet,
      surface: wallC,
      position: segments.last.points.last,
      label: 'Room C socket',
      ports: const [
        ElectricalPortDefinition(id: 'in', kind: ElectricalPortKind.powerIn),
      ],
    );
    final physical = route(passages);
    editor.restoreP2State(EditorP2State(
      components: [panel, socket],
      routes: [physical],
    ));
    final directory = await Directory.systemTemp.createTemp('elecx-r3-');
    addTearDown(() async {
      workspace.dispose();
      editor.dispose();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    expect(editor.level.spaces, hasLength(3));
    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: physical,
        components: editor.p2.components,
      ),
      isTrue,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: physical,
        components: editor.p2.components,
      ),
      isTrue,
    );

    final document = EditorProjectDocument.capture(workspace);
    final store = JsonFileEditorProjectStore(directory);
    await store.save(document);
    final reloaded = await store.load(document.projectId);
    expect(reloaded, isNotNull);
    final reopened = reloaded!.restore();
    addTearDown(() {
      reopened.workspace.dispose();
      reopened.editor.dispose();
    });

    expect(reopened.editor.level.spaces.map((s) => s.id).toList(),
        ['room-a', 'room-b', 'room-c']);
    expect(reopened.editor.p2.components, hasLength(2));
    final restoredPanel = reopened.editor.p2.components
        .singleWhere((component) => component.id == 'board');
    final restoredSocket = reopened.editor.p2.components
        .singleWhere((component) => component.id == 'socket');
    expect(restoredPanel.type, ElectricalComponentType.distributionBoard);
    expect(restoredPanel.ports.single.kind, ElectricalPortKind.powerOut);
    expect(restoredSocket.type, ElectricalComponentType.socketOutlet);
    expect(restoredSocket.ports.single.kind, ElectricalPortKind.powerIn);

    final restored = reopened.editor.p2.routes.single;
    expect(restored.id, physical.id);
    expect(restored.source.componentId, restoredPanel.id);
    expect(restored.target.componentId, restoredSocket.id);
    expect(restored.segments, hasLength(5));
    for (var index = 0; index < physical.segments.length; index++) {
      expect(
          restored.segments[index].surface, physical.segments[index].surface);
      expect(restored.segments[index].points, physical.segments[index].points);
    }
    expect(restored.penetrations.map((p) => p.id.value).toList(),
        ['wall-ab', 'wall-bc']);
    expect(restored.penetrations.first.hostThicknessMm, 180);
    expect(restored.penetrations.last.hostThicknessMm, 200);
    expect(restored.penetrations.first.materialId, 'brick');
    expect(restored.penetrations.last.materialId, 'concrete');
    expect(restored.visibleLengthMm, 2800);
    expect(restored.hiddenPenetrationLengthMm, 380);
    expect(restored.geometricLengthMm, 3180);
    expect(restored.installationLengthMm, 3339);
    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: restored,
        components: reopened.editor.p2.components,
      ),
      isTrue,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: restored,
        components: reopened.editor.p2.components,
      ),
      isTrue,
    );
  });

  test('R3.4 authored route persists with real rooms and ports', () async {
    EngineeringSpace room(String id, int left, int right) {
      final polygon = MmPolygon.rectangle(
        MmPoint(left, 0),
        MmPoint(right, 3000),
      );
      return EngineeringSpace(
        id: id,
        name: id,
        type: SpaceType.room,
        boundary: polygon,
        referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
      );
    }

    final a = room('room-a', 0, 4000);
    final b = room('room-b', 4000, 8000);
    final c = room('room-c', 8000, 12000);
    final level = BuildingLevel(
      id: 'level-1',
      name: 'Level 1',
      elevationMm: 0,
      spaces: [a, b, c],
    );
    final routedSegments = <ElectricalRouteSegment>[
      ElectricalRouteSegment(
        surface: wallA,
        points: const [
          SurfacePointMm(900, 1200),
          SurfacePointMm(1500, 1200),
        ],
      ),
      ElectricalRouteSegment(
        surface: wallBEntry,
        points: const [
          SurfacePointMm(1500, 1200),
          SurfacePointMm(1500, 3000),
        ],
      ),
      ElectricalRouteSegment(
        surface: ceilingB,
        points: const [
          SurfacePointMm(0, 1500),
          SurfacePointMm(4000, 1500),
        ],
      ),
      ElectricalRouteSegment(
        surface: wallBExit,
        points: const [
          SurfacePointMm(1500, 3000),
          SurfacePointMm(1500, 1200),
        ],
      ),
      ElectricalRouteSegment(
        surface: wallC,
        points: const [
          SurfacePointMm(1500, 1200),
          SurfacePointMm(2200, 1200),
        ],
      ),
    ];

    SurfaceTransitionCandidate? resolve(
      RoomSurfaceRef from,
      SurfacePointMm fromPoint,
      RoomSurfaceRef to,
      SurfacePointMm toPoint,
    ) {
      final space = switch (from.spaceId) {
        'room-a' => a,
        'room-b' => b,
        'room-c' => c,
        _ => throw StateError('Unknown space'),
      };
      final candidates = SurfaceTransitionGraph.candidates(
        level: level,
        fromSpace: space,
        fromSurface: from,
        point: fromPoint,
        thicknessResolver: (entry, exit) =>
            entry.spaceId == 'room-a' ? 180 : 200,
        materialResolver: (entry, exit) =>
            entry.spaceId == 'room-a' ? 'brick' : 'concrete',
      );
      for (final candidate in candidates) {
        if (candidate.toSurface == to && candidate.toPoint == toPoint) {
          return candidate;
        }
      }
      return null;
    }

    ElectricalCableRoute author(List<ElectricalRouteSegment> spans) =>
        CablePenetrationAuthoring.build(
          routeId: 'topology-backed-route',
          source: const ElectricalEndpointRef(
            componentId: 'board',
            portId: 'out',
          ),
          target: const ElectricalEndpointRef(
            componentId: 'socket',
            portId: 'in',
          ),
          segments: spans,
          resolveTransition: resolve,
          penetrationIdFactory: (index, _) =>
              BoundaryPenetrationId('actual-passage-$index'),
        );

    final physical = author(routedSegments);
    expect(physical.segments, hasLength(5));
    expect(physical.penetrations, hasLength(2));
    expect(physical.penetrations.first.hostThicknessMm, 180);
    expect(physical.penetrations.last.hostThicknessMm, 200);
    expect(physical.visibleLengthMm, 8900);
    expect(physical.hiddenPenetrationLengthMm, 380);
    expect(physical.geometricLengthMm, 9280);
    expect(physical.installationLengthMm, 9744);

    final editor = EditorController.restored(level: level, openings: const []);
    final workspace = EditorBuildingWorkspace.blank(
      editor,
      projectId: 'topology-backed-project',
      projectName: 'Topology-backed three-room project',
    );
    editor.restoreP2State(EditorP2State(
      components: [
        ElectricalComponentPlacement(
          id: 'board',
          type: ElectricalComponentType.distributionBoard,
          surface: wallA,
          position: routedSegments.first.points.first,
          label: 'Distribution board',
          ports: const [
            ElectricalPortDefinition(
              id: 'out',
              kind: ElectricalPortKind.powerOut,
            ),
          ],
        ),
        ElectricalComponentPlacement(
          id: 'socket',
          type: ElectricalComponentType.socketOutlet,
          surface: wallC,
          position: routedSegments.last.points.last,
          label: 'Room C socket',
          ports: const [
            ElectricalPortDefinition(
              id: 'in',
              kind: ElectricalPortKind.powerIn,
            ),
          ],
        ),
      ],
      routes: [physical],
    ));
    final directory =
        await Directory.systemTemp.createTemp('elecx-r3-authored-');
    addTearDown(() async {
      workspace.dispose();
      editor.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final document = EditorProjectDocument.capture(workspace);
    final store = JsonFileEditorProjectStore(directory);
    await store.save(document);
    final loaded = await store.load(document.projectId);
    expect(loaded, isNotNull);
    final reopened = loaded!.restore();
    addTearDown(() {
      reopened.workspace.dispose();
      reopened.editor.dispose();
    });
    expect(reopened.editor.level.spaces, hasLength(3));
    expect(reopened.editor.p2.components, hasLength(2));
    final persisted = reopened.editor.p2.routes.single;
    expect(persisted.id, physical.id);
    expect(persisted.penetrations, hasLength(2));
    expect(persisted.geometricLengthMm, 9280);
    expect(persisted.installationLengthMm, 9744);
    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: persisted,
        components: reopened.editor.p2.components,
      ),
      isTrue,
    );
    expect(
      ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: persisted,
        components: reopened.editor.p2.components,
      ),
      isTrue,
    );

    final invalid = [
      routedSegments.first,
      routedSegments[1],
      ElectricalRouteSegment(
        surface: ceilingB,
        points: const [
          SurfacePointMm(100, 1500),
          SurfacePointMm(4000, 1500),
        ],
      ),
      routedSegments[3],
      routedSegments.last,
    ];
    expect(() => author(invalid), throwsStateError);
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
