import 'geometry.dart';
import 'project_identity.dart';
import 'site_orientation.dart';
import 'wall_profile.dart';

enum SpaceType {
  room,
  corridor,
  hall,
  technicalRoom,
  stair,
  shaft,
  outdoorArea,
}

final class GridDefinition {
  const GridDefinition({this.minorStepMm = 100, this.majorEvery = 10})
      : assert(minorStepMm > 0),
        assert(majorEvery > 0);

  final int minorStepMm;
  final int majorEvery;
  int get majorStepMm => minorStepMm * majorEvery;

  GridDefinition copyWith({int? minorStepMm, int? majorEvery}) =>
      GridDefinition(
        minorStepMm: minorStepMm ?? this.minorStepMm,
        majorEvery: majorEvery ?? this.majorEvery,
      );
}

final class RoomReferenceFrame {
  const RoomReferenceFrame({required this.origin, this.rotationRadians = 0});

  final MmPoint origin;
  final double rotationRadians;
}

final class EngineeringSpace {
  const EngineeringSpace({
    required this.id,
    required this.name,
    required this.type,
    required this.boundary,
    required this.referenceFrame,
    this.grid = const GridDefinition(),
    this.wallProfiles = const {},
    this.boundaryEdgeWallProfiles = const {},
  });

  final String id;
  final String name;
  final SpaceType type;
  final MmPolygon boundary;
  final RoomReferenceFrame referenceFrame;
  final GridDefinition grid;

  /// Transitional legacy wall-elevation overrides by boundary ordinal.
  /// Canonical P7A-5 code must use [boundaryEdgeWallProfiles].
  final Map<int, WallProfile> wallProfiles;

  /// Durable wall-elevation overrides keyed by stable boundary identity.
  final Map<BoundaryEdgeId, WallProfile> boundaryEdgeWallProfiles;

  EngineeringSpace copyWith({
    GridDefinition? grid,
    MmPolygon? boundary,
    RoomReferenceFrame? referenceFrame,
    Map<int, WallProfile>? wallProfiles,
    Map<BoundaryEdgeId, WallProfile>? boundaryEdgeWallProfiles,
  }) =>
      EngineeringSpace(
        id: id,
        name: name,
        type: type,
        boundary: boundary ?? this.boundary,
        referenceFrame: referenceFrame ?? this.referenceFrame,
        grid: grid ?? this.grid,
        wallProfiles: wallProfiles ?? this.wallProfiles,
        boundaryEdgeWallProfiles:
            boundaryEdgeWallProfiles ?? this.boundaryEdgeWallProfiles,
      );

  /// Transitional legacy mutation by wall ordinal.
  EngineeringSpace withWallProfile(int wallIndex, WallProfile profile) {
    if (wallIndex < 0 || wallIndex >= boundary.vertices.length) {
      throw RangeError.index(wallIndex, boundary.vertices, 'wallIndex');
    }
    return copyWith(wallProfiles: {...wallProfiles, wallIndex: profile});
  }

  EngineeringSpace withoutWallProfile(int wallIndex) {
    if (!wallProfiles.containsKey(wallIndex)) return this;
    final updated = Map<int, WallProfile>.from(wallProfiles)..remove(wallIndex);
    return copyWith(wallProfiles: updated);
  }

  EngineeringSpace withBoundaryEdgeWallProfile(
    BoundaryEdgeId edgeId,
    WallProfile profile,
  ) =>
      copyWith(
        boundaryEdgeWallProfiles: {
          ...boundaryEdgeWallProfiles,
          edgeId: profile,
        },
      );

  EngineeringSpace withoutBoundaryEdgeWallProfile(BoundaryEdgeId edgeId) {
    if (!boundaryEdgeWallProfiles.containsKey(edgeId)) return this;
    final updated = Map<BoundaryEdgeId, WallProfile>.from(
      boundaryEdgeWallProfiles,
    )..remove(edgeId);
    return copyWith(boundaryEdgeWallProfiles: updated);
  }
}

final class BuildingLevel {
  const BuildingLevel({
    required this.id,
    required this.name,
    required this.elevationMm,
    required this.spaces,
  });

  final String id;
  final String name;
  final int elevationMm;
  final List<EngineeringSpace> spaces;

  BuildingLevel copyWith({List<EngineeringSpace>? spaces}) => BuildingLevel(
        id: id,
        name: name,
        elevationMm: elevationMm,
        spaces: spaces ?? this.spaces,
      );
}

final class Building {
  const Building({required this.id, required this.name, required this.levels});

  final String id;
  final String name;
  final List<BuildingLevel> levels;
}

final class ProjectSite {
  const ProjectSite({
    required this.id,
    required this.name,
    required this.buildings,
    this.projectNorth = const ProjectNorth(),
    this.solarContext,
  });

  final String id;
  final String name;
  final List<Building> buildings;

  /// True-north orientation relative to the project/plan coordinate system.
  /// All facade/window azimuths are derived from this single source of truth.
  final ProjectNorth projectNorth;

  /// Optional physical site data for future solar/daylight calculations.
  /// Keeping it nullable allows offline CAD work without geolocation.
  final SolarSiteContext? solarContext;

  ProjectSite copyWith({
    List<Building>? buildings,
    ProjectNorth? projectNorth,
    SolarSiteContext? solarContext,
    bool clearSolarContext = false,
  }) =>
      ProjectSite(
        id: id,
        name: name,
        buildings: buildings ?? this.buildings,
        projectNorth: projectNorth ?? this.projectNorth,
        solarContext:
            clearSolarContext ? null : solarContext ?? this.solarContext,
      );
}

final class EngineeringProject {
  const EngineeringProject({
    required this.id,
    required this.name,
    required this.site,
  });

  final String id;
  final String name;
  final ProjectSite site;
}
