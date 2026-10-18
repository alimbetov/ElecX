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
    try {
      level = WallProfileCommand.addTopBeamNotch(
        level: level,
        spaceId: space.id,
        wallIndex: wallIndex,
        startMm: startMm,
        widthMm: widthMm,
        depthMm: depthMm,
      );
    } on ArgumentError {
      return false;
    }
    notifyListeners();
    return true;
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
