import 'geometry.dart';

enum SpaceType { room, corridor, hall, technicalRoom, stair, shaft, outdoorArea }

final class GridDefinition {
  const GridDefinition({this.minorStepMm = 100, this.majorEvery = 10})
      : assert(minorStepMm > 0),
        assert(majorEvery > 0);

  final int minorStepMm;
  final int majorEvery;
  int get majorStepMm => minorStepMm * majorEvery;

  GridDefinition copyWith({int? minorStepMm, int? majorEvery}) => GridDefinition(
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
  });

  final String id;
  final String name;
  final SpaceType type;
  final MmPolygon boundary;
  final RoomReferenceFrame referenceFrame;
  final GridDefinition grid;

  EngineeringSpace copyWith({GridDefinition? grid}) => EngineeringSpace(
        id: id,
        name: name,
        type: type,
        boundary: boundary,
        referenceFrame: referenceFrame,
        grid: grid ?? this.grid,
      );
}

final class BuildingLevel {
  const BuildingLevel({required this.id, required this.name, required this.elevationMm, required this.spaces});

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
  const ProjectSite({required this.id, required this.name, required this.buildings});

  final String id;
  final String name;
  final List<Building> buildings;
}

final class EngineeringProject {
  const EngineeringProject({required this.id, required this.name, required this.site});

  final String id;
  final String name;
  final ProjectSite site;
}
