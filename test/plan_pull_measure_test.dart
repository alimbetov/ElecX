import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/engine/plan_pull_measure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('horizontal boundary measures to opposite horizontal wall', () {
    final space = _room(0, 0, 5000, 3200);
    final measure = PlanPullMeasureResolver.nearestParallelBoundary(
      space: space,
      edgeIndex: 0,
    );

    expect(measure, isNotNull);
    expect(measure!.distanceMm, 3200);
    expect(measure.sourceMidpoint, const MmPoint(2500, 0));
    expect(measure.targetPoint, const MmPoint(2500, 3200));
  });

  test('vertical boundary measures to opposite vertical wall', () {
    final space = _room(0, 0, 5000, 3200);
    final measure = PlanPullMeasureResolver.nearestParallelBoundary(
      space: space,
      edgeIndex: 1,
    );

    expect(measure, isNotNull);
    expect(measure!.distanceMm, 5000);
  });

  test('irregular room selects nearest parallel boundary', () {
    final boundary = MmPolygon([
      const MmPoint(0, 0),
      const MmPoint(6000, 0),
      const MmPoint(6000, 1500),
      const MmPoint(4000, 1500),
      const MmPoint(4000, 3500),
      const MmPoint(0, 3500),
    ]);
    final space = EngineeringSpace(
      id: 'room',
      name: 'Room',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );

    final measure = PlanPullMeasureResolver.nearestParallelBoundary(
      space: space,
      edgeIndex: 0,
    );

    expect(measure, isNotNull);
    expect(measure!.distanceMm, 1500);
  });
}

EngineeringSpace _room(int left, int bottom, int right, int top) {
  final boundary = MmPolygon.rectangle(
    MmPoint(left, bottom),
    MmPoint(right, top),
  );
  return EngineeringSpace(
    id: 'room',
    name: 'Room',
    type: SpaceType.room,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}
