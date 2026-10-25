import 'surfaces.dart';

enum InstallationGuideKind {
  socketMountingLine,
  switchMountingLine,
  wallCableRouteZone,
  ceilingLightingAxis,
  ceilingLightingGrid,
}

enum InstallationGuideAuthority { normative, projectPreset, advisory }

/// Traceable source metadata for a normative/advisory installation statement.
///
/// [revision] is deliberately explicit: a compliance result without the exact
/// source edition cannot be reproduced safely after a ruleset update.
final class InstallationGuideSource {
  const InstallationGuideSource({
    required this.code,
    required this.title,
    this.clause,
    this.revision,
    this.effectiveFrom,
    this.sourceUri,
    this.authority = InstallationGuideAuthority.normative,
  });

  final String code;
  final String title;
  final String? clause;
  final String? revision;
  final String? effectiveFrom;
  final String? sourceUri;
  final InstallationGuideAuthority authority;

  bool get isRevisionPinned =>
      revision != null && revision!.trim().isNotEmpty;
}

/// A visual/semantic installation guide bound to one physical room surface.
///
/// Wall guide coordinates use millimetres above finished floor. Ceiling guides
/// use the room-local ceiling plane. A guide is not an electrical component and
/// does not become part of the bill of materials.
final class InstallationGuide {
  const InstallationGuide({
    required this.id,
    required this.surface,
    required this.kind,
    required this.authority,
    required this.label,
    this.offsetMm,
    this.source,
    this.visible = true,
  });

  final String id;
  final RoomSurfaceRef surface;
  final InstallationGuideKind kind;
  final InstallationGuideAuthority authority;
  final String label;

  /// For wall mounting lines this is height above finished floor.
  /// For ceiling axes/grids the geometry is generated from the room plane.
  final int? offsetMm;
  final InstallationGuideSource? source;
  final bool visible;
}

/// Project defaults are deliberately separated from normative constraints.
/// Values such as 300/900 mm are common design presets but are not presented as
/// universally mandatory Kazakhstan/GOST requirements.
final class InstallationGuideProfile {
  const InstallationGuideProfile({
    required this.id,
    required this.name,
    required this.socketHeightMm,
    required this.switchHeightMm,
    this.showCeilingCenterAxes = true,
    this.showCeilingGrid = false,
  });

  final String id;
  final String name;
  final int socketHeightMm;
  final int switchHeightMm;
  final bool showCeilingCenterAxes;
  final bool showCeilingGrid;

  static const residentialProjectDefault = InstallationGuideProfile(
    id: 'project-residential-default',
    name: 'Жилой проект — настраиваемый preset',
    socketHeightMm: 300,
    switchHeightMm: 900,
    showCeilingCenterAxes: true,
  );
}

abstract final class InstallationGuideFactory {
  static List<InstallationGuide> forRoom({
    required String roomId,
    required int wallCount,
    InstallationGuideProfile profile =
        InstallationGuideProfile.residentialProjectDefault,
  }) {
    final guides = <InstallationGuide>[];
    for (var wallIndex = 0; wallIndex < wallCount; wallIndex++) {
      final wall = RoomSurfaceRef.wall(roomId, wallIndex);
      guides.add(
        InstallationGuide(
          id: '$roomId:wall:$wallIndex:socket-line',
          surface: wall,
          kind: InstallationGuideKind.socketMountingLine,
          authority: InstallationGuideAuthority.projectPreset,
          label: 'Розетки ${profile.socketHeightMm} mm',
          offsetMm: profile.socketHeightMm,
        ),
      );
      guides.add(
        InstallationGuide(
          id: '$roomId:wall:$wallIndex:switch-line',
          surface: wall,
          kind: InstallationGuideKind.switchMountingLine,
          authority: InstallationGuideAuthority.projectPreset,
          label: 'Выключатели ${profile.switchHeightMm} mm',
          offsetMm: profile.switchHeightMm,
        ),
      );
    }

    if (profile.showCeilingCenterAxes) {
      guides.add(
        InstallationGuide(
          id: '$roomId:ceiling:center-axis',
          surface: RoomSurfaceRef.ceiling(roomId),
          kind: InstallationGuideKind.ceilingLightingAxis,
          authority: InstallationGuideAuthority.projectPreset,
          label: 'Оси освещения',
        ),
      );
    }
    if (profile.showCeilingGrid) {
      guides.add(
        InstallationGuide(
          id: '$roomId:ceiling:lighting-grid',
          surface: RoomSurfaceRef.ceiling(roomId),
          kind: InstallationGuideKind.ceilingLightingGrid,
          authority: InstallationGuideAuthority.projectPreset,
          label: 'Сетка освещения',
        ),
      );
    }
    return List.unmodifiable(guides);
  }
}
