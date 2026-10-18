import 'package:elecx/src/domain/adjacent_room.dart';
import 'package:elecx/src/features/editor/adjacent_room_command.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adjacent room shares requested host-wall segment', () {
    final controller = EditorController.demo();
    final host = controller.selectedSpace!;
    final wall = controller.selectedWalls.first;

    final room = AdjacentRoomBuilder.build(
      hostRoom: host,
      hostWall: wall,
      id: 'room-new',
      name: 'Room New',
      depthMm: 3000,
      offsetFromWallStartMm: 500,
      sharedLengthMm: 2000,
    );

    expect(room.boundary.vertices.first.x, 1500);
    expect(room.boundary.vertices.first.y, 1200);
    expect(room.boundary.vertices[1].x, 3500);
    expect(room.boundary.vertices[1].y, 1200);
    expect(room.boundary.bounds.height, 3000);
  });

  test('adjacent room command appends and selects created room', () {
    final controller = EditorController.demo();
    final before = controller.level.spaces.length;

    final created = AdjacentRoomCommand.execute(
      controller,
      wallIndex: 0,
      depthMm: 2500,
      offsetFromWallStartMm: 0,
      sharedLengthMm: 1800,
    );

    expect(created, isTrue);
    expect(controller.level.spaces, hasLength(before + 1));
    expect(controller.selectedSpace?.name, 'Комната 102');
  });

  test('adjacent room command rejects segment beyond wall', () {
    final controller = EditorController.demo();

    final created = AdjacentRoomCommand.execute(
      controller,
      wallIndex: 0,
      depthMm: 2500,
      offsetFromWallStartMm: 3500,
      sharedLengthMm: 1200,
    );

    expect(created, isFalse);
    expect(controller.level.spaces, hasLength(2));
  });
}
