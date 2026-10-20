import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-f08', 0);
  final context = RouteNormativeContext(
    surface: surface,
    widthMm: 6000,
    heightMm: 3000,
    edgeClearanceMm: 0,
  );

  test('F08 group transform moves components and internal route atomically',
      () {
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2500, 1500),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final before = p2.state;
    final routeBefore = before.routes.single;
    final depthBefore = p2.history.undoDepth;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(2800, 1700)),
      isTrue,
    );
    expect(
      p2.components.firstWhere((item) => item.id == source.id).position,
      const SurfacePointMm(800, 700),
    );
    expect(
      p2.components.firstWhere((item) => item.id == target.id).position,
      const SurfacePointMm(2800, 1700),
    );
    final routePreview = p2.routes.single;
    for (var s = 0; s < routeBefore.segments.length; s++) {
      for (var i = 0; i < routeBefore.segments[s].points.length; i++) {
        final oldPoint = routeBefore.segments[s].points[i];
        expect(
          routePreview.segments[s].points[i],
          SurfacePointMm(oldPoint.xMm + 300, oldPoint.yMm + 200),
        );
      }
    }
    expect(p2.history.undoDepth, depthBefore);

    expect(p2.commitMoveSelectedComponent(), isTrue);
    expect(p2.history.undoDepth, depthBefore + 1);
    p2.undo();
    expect(
      p2.components.firstWhere((item) => item.id == source.id).position,
      source.position,
    );
    expect(
      p2.components.firstWhere((item) => item.id == target.id).position,
      target.position,
    );
    expect(
      p2.routes.single.segments.single.points,
      routeBefore.segments.single.points,
    );
  });

  test('F08 group cancel restores all components and routes exactly', () {
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final source = p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(700, 600),
    );
    final target = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2700, 1400),
    );
    p2.select(source.id, mode: SelectionMode.replace);
    p2.select(target.id, mode: SelectionMode.add);
    expect(p2.autoRouteSelectedPair(), isTrue);
    final before = p2.state;

    expect(p2.beginMoveSelectedComponent(), isTrue);
    expect(
      p2.previewMoveSelectedComponent(const SurfacePointMm(3000, 1600)),
      isTrue,
    );
    p2.cancelMoveSelectedComponent();

    expect(
      p2.components.map((item) => item.position).toList(),
      before.components.map((item) => item.position).toList(),
    );
    expect(
      p2.routes.single.segments.single.points,
      before.routes.single.segments.single.points,
    );
  });

  test('F08 cross-surface group transform fails closed', () {
    final p2 = EditorP2Session(routeContextResolver: (_) => context);
    addTearDown(p2.dispose);
    final a = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(700, 600),
    );
    final b = p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall('room-f08', 1),
      position: const SurfacePointMm(900, 600),
    );
    p2.select(a.id, mode: SelectionMode.replace);
    p2.select(b.id, mode: SelectionMode.add);

    expect(p2.beginMoveSelectedComponent(), isFalse);
    expect(p2.isManipulating, isFalse);
  });
}
