import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../domain/wall_profile.dart';

abstract final class WallProfileCommand {
  static BuildingLevel addTopBeamNotch({
    required BuildingLevel level,
    required String spaceId,
    required int wallIndex,
    required int startMm,
    required int widthMm,
    required int depthMm,
  }) {
    return _replaceSpace(level, spaceId, (space) {
      final wall = RoomSurfaceResolver.wall(space, wallIndex);
      final profile = wall.profile.withTopNotch(
        startMm: startMm,
        widthMm: widthMm,
        depthMm: depthMm,
      );
      return space.withWallProfile(wallIndex, profile);
    });
  }

  static BuildingLevel setTopPolyline({
    required BuildingLevel level,
    required String spaceId,
    required int wallIndex,
    required List<WallProfilePoint> topPoints,
  }) {
    return _replaceSpace(level, spaceId, (space) {
      final wall = RoomSurfaceResolver.wall(space, wallIndex);
      final profile = wall.profile.withTopPolyline(topPoints);
      return space.withWallProfile(wallIndex, profile);
    });
  }

  static BuildingLevel resetWallProfile({
    required BuildingLevel level,
    required String spaceId,
    required int wallIndex,
  }) {
    return _replaceSpace(
      level,
      spaceId,
      (space) => space.withoutWallProfile(wallIndex),
    );
  }

  static BuildingLevel _replaceSpace(
    BuildingLevel level,
    String spaceId,
    EngineeringSpace Function(EngineeringSpace space) transform,
  ) {
    var found = false;
    final spaces = [
      for (final space in level.spaces)
        if (space.id == spaceId)
          (() {
            found = true;
            return transform(space);
          })()
        else
          space,
    ];
    if (!found) {
      throw ArgumentError.value(spaceId, 'spaceId', 'Space not found.');
    }
    return level.copyWith(spaces: spaces);
  }
}
