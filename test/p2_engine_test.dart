import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/command_history.dart';
import 'package:elecx/src/engine/constraint_engine.dart';
import 'package:elecx/src/engine/direct_manipulation.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/engine/electrical_symbol_catalog.dart';
import 'package:elecx/src/engine/route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/engine/snap_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P2 SnapEngine', () {
    test('endpoint wins over grid and midpoint', () {
      final result = SnapEngine.resolve(
        SnapRequest(
          rawPoint: const MmPoint(1010, 995),
          acquisitionRadiusMm: 100,
          gridStepMm: 100,
          segments: const [
            SnapSegment(
              id: 'wall-1',
              a: MmPoint(1000, 1000),
              b: MmPoint(3000, 1000),
            ),
          ],
        ),
      );

      expect(result, isNotNull);
      expect(result!.kind, SnapKind.endpoint);
      expect(result.point.x, 1000);
      expect(result.point.y, 1000);
    });

    test('intersection is resolved before grid', () {
      final result = SnapEngine.resolve(
        SnapRequest(
          rawPoint: const MmPoint(1005, 1007),
          acquisitionRadiusMm: 50,
          gridStepMm: 100,
          segments: const [
            SnapSegment(
              id: 'horizontal',
              a: MmPoint(0, 1000),
              b: MmPoint(2000, 1000),
            ),
            SnapSegment(
              id: 'vertical',
              a: MmPoint(1000, 0),
              b: MmPoint(1000, 2000),
            ),
          ],
        ),
      );

      expect(result!.kind, SnapKind.intersection);
      expect(result.point.x, 1000);
      expect(result.point.y, 1000);
    });
  });

  test('SelectionEngine supports additive and box selection', () {
    var selection = SelectionEngine.apply(
      const SelectionState(),
      'room-a',
      SelectionMode.replace,
    );
    selection = SelectionEngine.apply(selection, 'room-b', SelectionMode.add);
    expect(selection.ids, containsAll(['room-a', 'room-b']));

    final boxed = SelectionEngine.boxSelect(
      objects: const [
        SelectableBounds(
          id: 'room-a',
          kind: SelectionKind.room,
          bounds: MmBounds(left: 0, top: 100, right: 100, bottom: 0),
        ),
        SelectableBounds(
          id: 'room-b',
          kind: SelectionKind.room,
          bounds: MmBounds(left: 500, top: 600, right: 600, bottom: 500),
        ),
      ],
      box: const MmBounds(left: -10, top: 150, right: 150, bottom: -10),
    );
    expect(boxed.ids, {'room-a'});
  });

  test('CommandHistory executes undo and redo deterministically', () {
    final history = CommandHistory<int>(10);
    history.execute(const _AddCommand(5));
    history.execute(const _AddCommand(3));
    expect(history.state, 18);
    expect(history.undo(), 15);
    expect(history.redo(), 18);
  });

  test('ConstraintEngine keeps horizontal and exact distance constraints', () {
    final horizontal = ConstraintEngine.horizontal(
      const MmPoint(0, 100),
      const MmPoint(900, 450),
    );
    expect(horizontal.b.y, 100);

    final distance = ConstraintEngine.distance(
      const MmPoint(0, 0),
      const MmPoint(800, 600),
      2000,
    );
    expect(distance.b.distanceTo(const MmPoint(0, 0)).round(), 2000);
  });

  test('Direct manipulation hit test picks nearest handle', () {
    final hit = DirectManipulationEngine.hitTest(
      handles: const [
        ManipulationHandle(
          id: 'a',
          ownerId: 'window-1',
          kind: ManipulationHandleKind.resizeStart,
          worldPoint: MmPoint(100, 100),
        ),
        ManipulationHandle(
          id: 'b',
          ownerId: 'window-1',
          kind: ManipulationHandleKind.resizeEnd,
          worldPoint: MmPoint(200, 100),
        ),
      ],
      point: const MmPoint(190, 100),
      radiusMm: 30,
    );
    expect(hit?.id, 'b');
  });

  test('layers preserve stable visibility and locking state', () {
    final layers = EditorLayerRegistry();
    layers.setVisible(EditorLayerId.guides, false);
    layers.setLocked(EditorLayerId.architecture, true);
    expect(layers.isVisible(EditorLayerId.guides), isFalse);
    expect(layers.isLocked(EditorLayerId.architecture), isTrue);
  });

  test('electrical SVG catalog covers every component type', () {
    for (final type in ElectricalComponentType.values) {
      final symbol = ElectricalSymbolCatalog.forType(type);
      expect(symbol.svg, contains('<svg'));
      expect(symbol.svg, contains('</svg>'));
    }
  });

  test('RouteEngine chooses lower-cost path and emits surface segments', () {
    final wall = RoomSurfaceRef.wall('room-1', 0);
    final ceiling = RoomSurfaceRef.ceiling('room-1');
    final graph = RoutingGraph(
      nodes: {
        'a': RouteNode(
          id: 'a',
          surface: wall,
          point: const SurfacePointMm(0, 300),
        ),
        'b': RouteNode(
          id: 'b',
          surface: wall,
          point: const SurfacePointMm(1000, 300),
        ),
        'c': RouteNode(
          id: 'c',
          surface: ceiling,
          point: const SurfacePointMm(1000, 0),
        ),
        'd': RouteNode(
          id: 'd',
          surface: ceiling,
          point: const SurfacePointMm(2000, 0),
        ),
      },
      edges: const [
        RouteEdge(from: 'a', to: 'b', cost: 1000),
        RouteEdge(from: 'b', to: 'c', cost: 300, transition: true),
        RouteEdge(from: 'c', to: 'd', cost: 1000),
        RouteEdge(from: 'a', to: 'd', cost: 5000),
      ],
    );

    final solution = RouteEngine.solve(
      graph: graph,
      startNodeId: 'a',
      endNodeId: 'd',
    );
    expect(solution!.nodeIds, ['a', 'b', 'c', 'd']);
    final segments = RouteEngine.toSegments(graph, solution);
    expect(segments.length, 2);
    expect(segments.first.surface, wall);
    expect(segments.last.surface, ceiling);
  });
}

final class _AddCommand implements EditorCommand<int> {
  const _AddCommand(this.value);

  final int value;

  @override
  String get label => 'add $value';

  @override
  int execute(int state) => state + value;

  @override
  int undo(int state) => state - value;
}
