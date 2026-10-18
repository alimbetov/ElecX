import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'wall_profile_command.dart';

extension WallProfileEditorActions on EditorController {
  bool addActiveWallTopNotch({
    required int startMm,
    required int widthMm,
    required int depthMm,
  }) {
    final space = selectedSpace;
    final wallIndex = activeSurface?.wallIndex;
    if (space == null || wallIndex == null) {
      return false;
    }

    final candidateLevel = switch (_candidateLevel(
      spaceId: space.id,
      wallIndex: wallIndex,
      startMm: startMm,
      widthMm: widthMm,
      depthMm: depthMm,
    )) {
      final candidate? => candidate,
      null => return false,
    };

    final candidateSpace = candidateLevel.spaces.firstWhere(
      (candidate) => candidate.id == space.id,
    );
    final candidateWall = RoomSurfaceResolver.wall(candidateSpace, wallIndex);
    final invalidatesOpening = activeWallOpenings.any(
      (opening) => !RoomSurfaceResolver.openingFitsWall(
        opening: opening,
        wall: candidateWall,
      ),
    );
    if (invalidatesOpening) {
      return false;
    }

    level = candidateLevel;
    notifyListeners();
    return true;
  }

  BuildingLevel? _candidateLevel({
    required String spaceId,
    required int wallIndex,
    required int startMm,
    required int widthMm,
    required int depthMm,
  }) {
    try {
      return WallProfileCommand.addTopBeamNotch(
        level: level,
        spaceId: spaceId,
        wallIndex: wallIndex,
        startMm: startMm,
        widthMm: widthMm,
        depthMm: depthMm,
      );
    } on ArgumentError {
      return null;
    }
  }

  bool resetActiveWallProfile() {
    final space = selectedSpace;
    final wallIndex = activeSurface?.wallIndex;
    if (space == null || wallIndex == null) {
      return false;
    }
    level = WallProfileCommand.resetWallProfile(
      level: level,
      spaceId: space.id,
      wallIndex: wallIndex,
    );
    notifyListeners();
    return true;
  }

  bool get activeWallHasCustomProfile {
    final space = selectedSpace;
    final wallIndex = activeSurface?.wallIndex;
    return space != null &&
        wallIndex != null &&
        space.wallProfiles.containsKey(wallIndex);
  }
}
