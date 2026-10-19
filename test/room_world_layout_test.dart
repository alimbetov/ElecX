import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/room_world_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundary = MmPolygon.rectangle(
    const MmPoint(1000, 2000),
    const MmPoint(5000, 5000),
  );
  final room = EngineeringSpace(
    id: 'room-a',
    name: 'Room A',
    type: SpaceType.room,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );

  test('ceiling is always above walls and floor is always below', () {
    final layout = RoomWorldLayout.build(room);
    final ceiling = layout.singleWhere(
      (tile) => tile.surface.type == SurfacePlaneType.ceiling,
    );
    final floor = layout.singleWhere(
      (tile) => tile.surface.type == SurfacePlaneType.floor,
    );
    final walls = layout
        .where((tile) => tile.surface.type == SurfacePlaneType.wall)
        .toList();

    expect(ceiling.row, 0);
    expect(walls, hasLength(4));
    expect(walls.every((tile) => tile.row == 1), isTrue);
    expect(floor.row, 2);
  });

  test('wall order follows physical room boundary order', () {
    final walls = RoomWorldLayout.build(room)
        .where((tile) => tile.surface.type == SurfacePlaneType.wall)
        .toList();

    for (var index = 0; index < walls.length; index++) {
      expect(walls[index].surface, RoomSurfaceRef.wall(room.id, index));
      expect(walls[index].column, index);
    }
  });

  test('all room world tiles preserve selected room identity', () {
    final layout = RoomWorldLayout.build(room);
    expect(layout.every((tile) => tile.surface.spaceId == room.id), isTrue);
  });
}
