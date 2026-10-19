import '../../domain/adjacent_room.dart';
import 'editor_controller.dart';

abstract final class AdjacentRoomCommand {
  static bool execute(
    EditorController controller, {
    required int wallIndex,
    required int depthMm,
    required int offsetFromWallStartMm,
    required int sharedLengthMm,
  }) {
    final host = controller.selectedSpace;
    if (host == null ||
        wallIndex < 0 ||
        wallIndex >= controller.selectedWalls.length) {
      return false;
    }

    try {
      final room = AdjacentRoomBuilder.build(
        hostRoom: host,
        hostWall: controller.selectedWalls[wallIndex],
        id: 'room-${controller.roomSequence}',
        name: 'Комната ${controller.roomSequence}',
        depthMm: depthMm,
        offsetFromWallStartMm: offsetFromWallStartMm,
        sharedLengthMm: sharedLengthMm,
      );
      controller.roomSequence += 1;
      controller.level = controller.level.copyWith(
        spaces: [...controller.level.spaces, room],
      );
      controller.selectSpace(room.id);
      return true;
    } on ArgumentError {
      return false;
    }
  }
}
