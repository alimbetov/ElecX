import 'dart:math' as math;

import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.8 performance and memory qualification', () {
    test('20k hosted references remap without cardinality explosion', () {
      final spaceId = SpaceId('perf-space');
      final topology = _fortyEdgeRectangle(spaceId);
      final lineage = BoundaryTopologyChangeSet([
        for (final edgeId in topology.orderedEdgeIds)
          BoundaryEdgeLineage.preserved(edgeId),
      ]);
      final references = <BoundaryHostedReference>[];
      for (var index = 0; index < 20000; index++) {
        final edgeId = topology.orderedEdgeIds[index % topology.orderedEdgeIds.length];
        final edge = topology.edges[edgeId]!;
        final length = math.sqrt(
          math.pow(edge.end.xMm - edge.start.xMm, 2) +
              math.pow(edge.end.yMm - edge.start.yMm, 2),
        );
        references.add(
          BoundaryHostedReference.point(
            objectKey: 'component:perf-$index',
            objectKind: BoundaryHostedObjectKind.component,
            host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId),
            offsetMm: math.min(index % 100, length.floor()),
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final remapped = BoundaryHostedObjectRemapper.remapAll(
        before: topology,
        after: topology,
        lineage: lineage,
        references: references,
      );
      stopwatch.stop();

      expect(remapped, hasLength(references.length));
      expect(
        remapped.map((item) => item.source.objectKey).toSet(),
        hasLength(references.length),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 15)));
    });

    test('unified document history remains bounded at 200 entries', () {
      final editor = EditorController.demo();
      final history = EditorDocumentHistory(editor);
      addTearDown(() {
        history.dispose();
        editor.disposeP2State();
        editor.dispose();
      });
      final wall = RoomSurfaceRef.wall(editor.selectedSpace!.id, 0);

      for (var index = 0; index < 250; index++) {
        editor.p2.placeComponent(
          type: ElectricalComponentType.junctionBox,
          surface: wall,
          position: SurfacePointMm(100 + index, 300),
        );
      }

      expect(history.undoDepth, 200);
      expect(history.redoDepth, 0);
      expect(history.canUndo, isTrue);
    });
  });
}

SpaceBoundaryTopology _fortyEdgeRectangle(SpaceId spaceId) {
  const segmentsPerSide = 10;
  const side = 10000;
  const step = side ~/ segmentsPerSide;
  final points = <BoundaryPointMm>[];
  for (var index = 0; index < segmentsPerSide; index++) {
    points.add(BoundaryPointMm(xMm: index * step, yMm: 0));
  }
  for (var index = 0; index < segmentsPerSide; index++) {
    points.add(BoundaryPointMm(xMm: side, yMm: index * step));
  }
  for (var index = 0; index < segmentsPerSide; index++) {
    points.add(BoundaryPointMm(xMm: side - index * step, yMm: side));
  }
  for (var index = 0; index < segmentsPerSide; index++) {
    points.add(BoundaryPointMm(xMm: 0, yMm: side - index * step));
  }
  final ids = [
    for (var index = 0; index < points.length; index++)
      BoundaryEdgeId('perf-edge-$index'),
  ];
  return SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: ids,
    edges: {
      for (var index = 0; index < points.length; index++)
        ids[index]: ProjectBoundaryEdge(
          id: ids[index],
          spaceId: spaceId,
          start: points[index],
          end: points[(index + 1) % points.length],
        ),
    },
  );
}
