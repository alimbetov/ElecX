import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/wall_construction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rectangle boundary is counter-clockwise', () {
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    expect(WallPlanGeometry.isCounterClockwise(room), isTrue);
  });

  test('bottom external wall projects thickness outside room', () {
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final body = WallPlanGeometry.externalWallBody(
      spaceId: 'room-1',
      roomBoundary: room,
      wallIndex: 0,
      thicknessMm: 200,
    );

    expect(body.interiorStart, const MmPoint(0, 0));
    expect(body.interiorEnd, const MmPoint(4000, 0));
    expect(body.exteriorStart, const MmPoint(0, -200));
    expect(body.exteriorEnd, const MmPoint(4000, -200));
    expect(body.thicknessMm, 200);
  });

  test('right external wall projects thickness to the right', () {
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final body = WallPlanGeometry.externalWallBody(
      spaceId: 'room-1',
      roomBoundary: room,
      wallIndex: 1,
      thicknessMm: 250,
    );

    expect(body.exteriorStart, const MmPoint(4250, 0));
    expect(body.exteriorEnd, const MmPoint(4250, 3000));
  });

  test('wall thickness must be positive', () {
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    expect(
      () => WallPlanGeometry.externalWallBody(
        spaceId: 'room-1',
        roomBoundary: room,
        wallIndex: 0,
        thicknessMm: 0,
      ),
      throwsArgumentError,
    );
  });
}
