import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/physical_cable_route_committer.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A controlled physical route continuation', () {
    test('extends C-103 with same id and one undo transaction', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final original = fixture.route;
      final revisionBeforeBegin =
          fixture.controller.p2.history.mutationRevision;

      expect(
        fixture.controller.beginPhysicalRouteContinuation(original.id),
        isTrue,
      );
      expect(fixture.controller.physicalRouteContinuationId, original.id);
      expect(
        fixture.controller.p2.history.mutationRevision,
        revisionBeforeBegin,
      );
      expect(fixture.controller.p2.routes.single, same(original));

      fixture.controller.surfaceTap(const SurfacePointMm(1200, 1000));
      fixture.controller.surfaceTap(const SurfacePointMm(1500, 1000));

      expect(
        fixture.controller.finishPhysicalRouteContinuation(
          resolveTransition: (_, __, ___, ____) => null,
        ),
        isTrue,
      );
      expect(fixture.controller.p2.routes, hasLength(1));
      expect(fixture.controller.p2.routes.single.id, 'C-103');
      expect(
        fixture.controller.p2.routes.single.target.componentId,
        'target-b',
      );
      expect(
        fixture.controller.p2.history.mutationRevision,
        revisionBeforeBegin + 1,
      );
      expect(fixture.controller.hasPhysicalRouteContinuation, isFalse);
      expect(fixture.controller.routeSegments, isEmpty);

      fixture.controller.p2.undo();
      expect(fixture.controller.p2.routes.single, same(original));
      expect(
        fixture.controller.p2.routes.single.target.componentId,
        'target-a',
      );

      fixture.controller.p2.redo();
      expect(fixture.controller.p2.routes.single.id, 'C-103');
      expect(
        fixture.controller.p2.routes.single.target.componentId,
        'target-b',
      );
    });

    test('cancel clears only draft and intent without P2 mutation', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final original = fixture.route;
      final revision = fixture.controller.p2.history.mutationRevision;

      expect(
        fixture.controller.beginPhysicalRouteContinuation(original.id),
        isTrue,
      );
      fixture.controller.surfaceTap(const SurfacePointMm(1200, 1000));
      fixture.controller.cancelManualCableDraft();

      expect(fixture.controller.hasPhysicalRouteContinuation, isFalse);
      expect(fixture.controller.routeSegments, isEmpty);
      expect(fixture.controller.p2.history.mutationRevision, revision);
      expect(fixture.controller.p2.routes.single, same(original));
    });

    test('stale P2 revision blocks continuation commit', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final original = fixture.route;

      expect(
        fixture.controller.beginPhysicalRouteContinuation(original.id),
        isTrue,
      );
      fixture.controller.surfaceTap(const SurfacePointMm(1200, 1000));
      fixture.controller.surfaceTap(const SurfacePointMm(1500, 1000));

      // Any committed electrical change invalidates the continuation baseline.
      final added = fixture.controller.p2.placeComponent(
        type: ElectricalComponentType.junctionBox,
        surface: fixture.surface,
        position: const SurfacePointMm(2000, 1200),
      );
      expect(added.type, ElectricalComponentType.junctionBox);
      final revisionAfterExternalMutation =
          fixture.controller.p2.history.mutationRevision;

      expect(
        fixture.controller.finishPhysicalRouteContinuation(
          resolveTransition: (_, __, ___, ____) => null,
        ),
        isFalse,
      );
      expect(
        fixture.controller.p2.history.mutationRevision,
        revisionAfterExternalMutation,
      );
      expect(fixture.controller.p2.routes.single, same(original));
      expect(fixture.controller.hasPhysicalRouteContinuation, isTrue);
      expect(fixture.controller.routeSegments, isNotEmpty);
    });
  });
}

final class _Fixture {
  _Fixture() {
    final boundary = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final space = EngineeringSpace(
      id: 'room-a',
      name: 'Room A',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );
    surface = RoomSurfaceRef.wall(space.id, 0);
    controller = EditorController.restored(
      level: BuildingLevel(
        id: 'level-1',
        name: 'Level 1',
        elevationMm: 0,
        spaces: [space],
      ),
      openings: const [],
    )..selectSpace(space.id);
    controller.showWall(0);

    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(100, 1000),
      label: 'Source',
      ports: const [
        ElectricalPortDefinition(
          id: 'out',
          kind: ElectricalPortKind.powerOut,
        ),
      ],
    );
    final targetA = ElectricalComponentPlacement(
      id: 'target-a',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(900, 1000),
      label: 'Target A',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final targetB = ElectricalComponentPlacement(
      id: 'target-b',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1500, 1000),
      label: 'Target B',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    controller.p2.history.replaceState(
      EditorP2State(components: [source, targetA, targetB]),
      clearHistory: true,
    );
    route = ElectricalCableRoute(
      id: 'C-103',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target-a',
        portId: 'in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(100, 1000),
            SurfacePointMm(900, 1000),
          ],
        ),
      ],
    );
    if (!controller.p2.commitPhysicalCableRoute(route)) {
      throw StateError('Fixture route must commit.');
    }
  }

  late final EditorController controller;
  late final RoomSurfaceRef surface;
  late final ElectricalCableRoute route;

  void dispose() => controller.dispose();
}
