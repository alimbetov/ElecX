import 'package:flutter_test/flutter_test.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/features/editor/wall_distance_guide_calculator.dart';

void main() {
  test('rectangular room: four first directional intersections', () {
    final room = MmPolygon.rectangle(
      const MmPoint(1000, 1000),
      const MmPoint(5000, 4000),
    );
    final guides = WallDistanceGuideCalculator.fromAnchor(
      room: room,
      anchor: const MmPoint(2000, 2200),
    );
    expect(guides.length, 4);
    expect(
      {for (final guide in guides) guide.direction: guide.distanceMm.round()},
      {
        WallGuideDirection.left: 1000,
        WallGuideDirection.right: 3000,
        WallGuideDirection.down: 1200,
        WallGuideDirection.up: 1800,
      },
    );
  });

  test('on wall: does not create meaningless zero dimension', () {
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final guides = WallDistanceGuideCalculator.fromAnchor(
      room: room,
      anchor: const MmPoint(0, 1500),
    );
    expect(guides.length, 3);
    expect(guides.any((g) => g.direction == WallGuideDirection.left), false);
    expect(guides.every((g) => g.distanceMm > 0), true);
  });

  test('concave room: nearest boundary wins over outer bounding box', () {
    final room = MmPolygon([
      const MmPoint(0, 0),
      const MmPoint(6000, 0),
      const MmPoint(6000, 1000),
      const MmPoint(2000, 1000),
      const MmPoint(2000, 5000),
      const MmPoint(0, 5000),
    ]);
    final guides = WallDistanceGuideCalculator.fromAnchor(
      room: room,
      anchor: const MmPoint(1000, 3000),
    );
    final right = guides.singleWhere(
      (g) => g.direction == WallGuideDirection.right,
    );
    expect(right.distanceMm, 1000);
  });

  test('outside room: no fabricated dimensions', () {
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    expect(
      WallDistanceGuideCalculator.fromAnchor(
        room: room,
        anchor: const MmPoint(7000, 1800),
      ),
      isEmpty,
    );
  });

  test('diagonal boundary: value measures the drawn ray', () {
    final room = MmPolygon([
      const MmPoint(0, 0),
      const MmPoint(3000, 0),
      const MmPoint(2000, 2000),
      const MmPoint(0, 2000),
    ]);
    final guides = WallDistanceGuideCalculator.fromAnchor(
      room: room,
      anchor: const MmPoint(1000, 1000),
    );
    final right = guides.singleWhere(
      (g) => g.direction == WallGuideDirection.right,
    );
    expect(right.distanceMm, 1500);
    expect(right.end, const MmPoint(2500, 1000));
  });
}
