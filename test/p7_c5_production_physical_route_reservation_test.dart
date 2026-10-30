import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surface_routing.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7 C5 production physical-route reservation', () {
    test('penetration identity is reserved before candidate materialization',
        () {
      final editor = _editorWithAdjacentRooms();
      final factory = _GuardedEntityIdFactory();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      _prepareCrossRoomDraft(editor);

      final committed = editor.finishPhysicalManualCableDraft(
        routeId: 'route-reserved',
        identityFactory: factory,
        resolveTransition: (fromSurface, fromPoint, toSurface, toPoint) {
          factory.closeAllocations();
          return _wallTransition(
            fromSurface,
            fromPoint,
            toSurface,
            toPoint,
          );
        },
      );

      expect(committed, isTrue);
      expect(factory.penetrationAllocations, 1);
      expect(editor.p2.routes, hasLength(1));
      final penetration = editor.p2.routes.single.penetrations.single;
      expect(
        penetration.id,
        BoundaryPenetrationId('reserved-penetration-1'),
      );
      expect(penetration.id.value, isNot('route-reserved:penetration:0'));
    });

    test('reentrant P2 mutation makes frozen route candidate stale', () {
      final editor = _editorWithAdjacentRooms();
      final factory = _GuardedEntityIdFactory();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      _prepareCrossRoomDraft(editor);

      final committed = editor.finishPhysicalManualCableDraft(
        routeId: 'route-stale',
        identityFactory: factory,
        resolveTransition: (fromSurface, fromPoint, toSurface, toPoint) {
          editor.p2.placeComponent(
            type: ElectricalComponentType.socketOutlet,
            surface: RoomSurfaceRef.wall('room-a', 0),
            position: const SurfacePointMm(300, 900),
          );
          return _wallTransition(
            fromSurface,
            fromPoint,
            toSurface,
            toPoint,
          );
        },
      );

      expect(committed, isFalse);
      expect(editor.p2.routes, isEmpty);
      expect(editor.routeSegments, hasLength(2));
      expect(editor.tool, EditorTool.cableRoute);
    });
  });
}

SurfaceTransitionCandidate _wallTransition(
  RoomSurfaceRef fromSurface,
  SurfacePointMm fromPoint,
  RoomSurfaceRef toSurface,
  SurfacePointMm toPoint,
) =>
    SurfaceTransitionCandidate(
      id: 'shared-wall',
      kind: SurfaceTransitionKind.roomPenetration,
      fromSurface: fromSurface,
      fromPoint: fromPoint,
      toSurface: toSurface,
      toPoint: toPoint,
      penetrationRequirement: const BoundaryPenetrationRequirement(
        hostKind: BoundaryPenetrationHostKind.wall,
        hostThicknessMm: 180,
        materialId: 'brick',
      ),
    );

void _prepareCrossRoomDraft(EditorController editor) {
  final wallA = RoomSurfaceRef.wall('room-a', 1);
  final wallB = RoomSurfaceRef.wall('room-b', 3);
  editor.p2.placeComponent(
    type: ElectricalComponentType.powerSource,
    surface: wallA,
    position: const SurfacePointMm(100, 1200),
  );
  editor.p2.placeComponent(
    type: ElectricalComponentType.socketOutlet,
    surface: wallB,
    position: const SurfacePointMm(900, 1200),
  );
  editor.setTool(EditorTool.cableRoute);
  editor.routeSegments.addAll([
    SurfaceRouteSegmentDraft(
      surface: wallA,
      points: const [
        SurfacePointMm(100, 1200),
        SurfacePointMm(1500, 1200),
      ],
    ),
    SurfaceRouteSegmentDraft(
      surface: wallB,
      points: const [
        SurfacePointMm(1500, 1200),
        SurfacePointMm(900, 1200),
      ],
    ),
  ]);
}

EditorController _editorWithAdjacentRooms() {
  final editor = EditorController.blank();
  final roomA = EngineeringSpace(
    id: 'room-a',
    name: 'A',
    type: SpaceType.room,
    boundary: MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    ),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
  );
  final roomB = EngineeringSpace(
    id: 'room-b',
    name: 'B',
    type: SpaceType.room,
    boundary: MmPolygon.rectangle(
      const MmPoint(4000, 0),
      const MmPoint(8000, 3000),
    ),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(6000, 1500)),
  );
  editor.level = BuildingLevel(
    id: 'level-1',
    name: 'L1',
    elevationMm: 0,
    spaces: [roomA, roomB],
  );
  editor.selectedSpaceId = roomA.id;
  return editor;
}

final class _GuardedEntityIdFactory implements EntityIdFactory {
  final SecureRandomEntityIdFactory _delegate = SecureRandomEntityIdFactory();
  bool _allocationsClosed = false;
  int penetrationAllocations = 0;
  int routeAnchorAllocations = 0;

  void closeAllocations() {
    _allocationsClosed = true;
  }

  void _requireOpen() {
    if (_allocationsClosed) {
      throw StateError('Identity allocation occurred after candidate build.');
    }
  }

  @override
  BoundaryPenetrationId newBoundaryPenetrationId() {
    _requireOpen();
    penetrationAllocations++;
    return BoundaryPenetrationId(
      'reserved-penetration-$penetrationAllocations',
    );
  }

  @override
  RouteAnchorId newRouteAnchorId() {
    _requireOpen();
    routeAnchorAllocations++;
    return RouteAnchorId('reserved-anchor-$routeAnchorAllocations');
  }

  @override
  BoundaryEdgeId newBoundaryEdgeId() => _delegate.newBoundaryEdgeId();

  @override
  BuildingId newBuildingId() => _delegate.newBuildingId();

  @override
  CircuitId newCircuitId() => _delegate.newCircuitId();

  @override
  ComponentId newComponentId() => _delegate.newComponentId();

  @override
  EngineeringConnectionId newEngineeringConnectionId() =>
      _delegate.newEngineeringConnectionId();

  @override
  EngineeringGroupId newEngineeringGroupId() =>
      _delegate.newEngineeringGroupId();

  @override
  EngineeringSupplySourceId newEngineeringSupplySourceId() =>
      _delegate.newEngineeringSupplySourceId();

  @override
  GenerationId newGenerationId() => _delegate.newGenerationId();

  @override
  LevelId newLevelId() => _delegate.newLevelId();

  @override
  LoopId newLoopId() => _delegate.newLoopId();

  @override
  OpeningId newOpeningId() => _delegate.newOpeningId();

  @override
  OverlayClassificationId newOverlayClassificationId() =>
      _delegate.newOverlayClassificationId();

  @override
  PortId newPortId() => _delegate.newPortId();

  @override
  ProjectId newProjectId() => _delegate.newProjectId();

  @override
  RouteId newRouteId() => _delegate.newRouteId();

  @override
  ServiceEntryId newServiceEntryId() => _delegate.newServiceEntryId();

  @override
  SiteId newSiteId() => _delegate.newSiteId();

  @override
  SlabId newSlabId() => _delegate.newSlabId();

  @override
  SpaceAdjacencyId newSpaceAdjacencyId() => _delegate.newSpaceAdjacencyId();

  @override
  SpaceId newSpaceId() => _delegate.newSpaceId();

  @override
  TemplateId newTemplateId() => _delegate.newTemplateId();

  @override
  TypicalFloorDefinitionId newTypicalFloorDefinitionId() =>
      _delegate.newTypicalFloorDefinitionId();

  @override
  VerticalCoreId newVerticalCoreId() => _delegate.newVerticalCoreId();

  @override
  ZoneId newZoneId() => _delegate.newZoneId();
}
