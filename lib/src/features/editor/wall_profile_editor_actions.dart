import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../domain/wall_profile.dart';
import 'editor_controller.dart';
import 'electrical_host_geometry_guard.dart';
import 'wall_profile_command.dart';

final class WallTopNotchState {
  const WallTopNotchState({
    required this.startMm,
    required this.widthMm,
    required this.depthMm,
  });

  final int startMm;
  final int widthMm;
  final int depthMm;

  int get endMm => startMm + widthMm;
}

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

    final candidateLevel = _candidateLevel(
      spaceId: space.id,
      wallIndex: wallIndex,
      startMm: startMm,
      widthMm: widthMm,
      depthMm: depthMm,
    );
    if (candidateLevel == null) {
      return false;
    }

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
    if (invalidatesOpening ||
        !ElectricalHostGeometryGuard.wallProfileCandidateAllowed(
          this,
          candidateSpace,
          wallIndex,
        )) {
      return false;
    }

    level = candidateLevel;
    selectSpace(space.id);
    showWall(wallIndex);
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

  WallTopNotchState? get activeWallTopNotch {
    final space = selectedSpace;
    final wallIndex = activeSurface?.wallIndex;
    if (space == null || wallIndex == null) {
      return null;
    }
    final profile = space.wallProfiles[wallIndex];
    if (profile == null) {
      return null;
    }
    return _topNotchFromProfile(profile);
  }

  bool nudgeActiveWallTopNotchX(int deltaMm) {
    final notch = activeWallTopNotch;
    if (notch == null || deltaMm == 0) {
      return false;
    }
    return addActiveWallTopNotch(
      startMm: notch.startMm + deltaMm,
      widthMm: notch.widthMm,
      depthMm: notch.depthMm,
    );
  }

  bool nudgeActiveWallTopNotchDepth(int deltaMm) {
    final notch = activeWallTopNotch;
    if (notch == null || deltaMm == 0) {
      return false;
    }
    return addActiveWallTopNotch(
      startMm: notch.startMm,
      widthMm: notch.widthMm,
      depthMm: notch.depthMm + deltaMm,
    );
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
    selectSpace(space.id);
    showWall(wallIndex);
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

WallTopNotchState? _topNotchFromProfile(WallProfile profile) {
  final v = profile.vertices;
  if (v.length != 8) {
    return null;
  }
  final top = profile.maxY;
  final width = profile.maxX;
  final looksLikeTopNotch = v[0].xMm == 0 &&
      v[0].yMm == 0 &&
      v[1].xMm == width &&
      v[1].yMm == 0 &&
      v[2].xMm == width &&
      v[2].yMm == top &&
      v[3].yMm == top &&
      v[4].xMm == v[3].xMm &&
      v[5].yMm == v[4].yMm &&
      v[6].xMm == v[5].xMm &&
      v[6].yMm == top &&
      v[7].xMm == 0 &&
      v[7].yMm == top;
  if (!looksLikeTopNotch) {
    return null;
  }
  final start = v[5].xMm;
  final end = v[4].xMm;
  final depth = top - v[4].yMm;
  if (start < 0 || end <= start || depth <= 0) {
    return null;
  }
  return WallTopNotchState(
    startMm: start,
    widthMm: end - start,
    depthMm: depth,
  );
}
