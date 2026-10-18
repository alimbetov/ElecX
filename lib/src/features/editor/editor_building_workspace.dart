import 'package:flutter/foundation.dart';

import '../../domain/building_composition.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/residential_tower_builder.dart';
import '../../domain/site_outdoor_model.dart';
import 'editor_controller.dart';

enum EditorWorkspaceContext { buildingLevel, siteOutdoor }

final class EditorBuildingWorkspace extends ChangeNotifier {
  EditorBuildingWorkspace({
    required this.editor,
    required this.building,
    required this.site,
    int initialLevelNumber = 1,
  }) : _activeLevelNumber = initialLevelNumber {
    final initial = building.levelByNumber(initialLevelNumber) ??
        building.orderedLevels.first;
    _activeLevelNumber = initial.levelNumber;
    _activateLevel(initial);
  }

  factory EditorBuildingWorkspace.demo(EditorController editor) {
    final residential = _residentialTemplate();
    final basement = _basementTemplate();
    final building = ResidentialTowerBuilder.build(
      buildingId: 'building-a',
      buildingName: 'Building A',
      residentialTemplate: residential,
      basementTemplate: basement,
    );
    final projectSite = ProjectSite(
      id: 'site-1',
      name: 'Площадка',
      buildings: [building.building],
    );
    final yard = OutdoorZone(
      id: 'yard-main',
      name: 'Дворовая зона',
      kind: OutdoorZoneKind.yard,
      boundary: MmPolygon.rectangle(
        const MmPoint(-15000, -12000),
        const MmPoint(50000, 36000),
      ),
    );
    final site = ComposedProjectSite(
      site: projectSite,
      outdoorZones: [yard],
      connections: [
        SiteBuildingConnection(
          id: 'service-entry-main',
          kind: SiteConnectionKind.electricalServiceEntry,
          outdoorZoneId: yard.id,
          buildingId: building.building.id,
          levelNumber: -1,
          sitePoint: const MmPoint(12000, 4000),
          levelPoint: const MmPoint(1000, 1000),
          targetSpaceId: 'L-1:electrical-room',
        ),
      ],
    );
    return EditorBuildingWorkspace(
      editor: editor,
      building: building,
      site: site,
    );
  }

  final EditorController editor;
  final ComposedBuilding building;
  final ComposedProjectSite site;

  EditorWorkspaceContext _context = EditorWorkspaceContext.buildingLevel;
  late int _activeLevelNumber;
  String? _selectedZoneId;
  String? _activeOutdoorZoneId;

  EditorWorkspaceContext get context => _context;
  int get activeLevelNumber => _activeLevelNumber;
  String? get selectedZoneId => _selectedZoneId;
  String? get activeOutdoorZoneId => _activeOutdoorZoneId;

  ComposedBuildingLevel? get activeLevel =>
      building.levelByNumber(_activeLevelNumber);

  BuildingZone? get selectedZone {
    final id = _selectedZoneId;
    if (id == null) return null;
    for (final zone in activeLevel?.zones ?? const <BuildingZone>[]) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  List<ComposedBuildingLevel> get residentialLevels => building.orderedLevels
      .where((level) => level.levelNumber > 0)
      .toList(growable: false);

  List<ComposedBuildingLevel> get basementLevels => building.orderedLevels
      .where((level) => level.levelNumber < 0)
      .toList(growable: false);

  void selectLevel(int levelNumber) {
    final level = building.levelByNumber(levelNumber);
    if (level == null) {
      throw ArgumentError.value(levelNumber, 'levelNumber', 'Unknown level.');
    }
    _context = EditorWorkspaceContext.buildingLevel;
    _activeOutdoorZoneId = null;
    _activeLevelNumber = levelNumber;
    _selectedZoneId = null;
    _activateLevel(level);
    notifyListeners();
  }

  void selectZone(String? zoneId) {
    if (zoneId == null) {
      _selectedZoneId = null;
      notifyListeners();
      return;
    }
    BuildingZone? zone;
    for (final candidate in activeLevel?.zones ?? const <BuildingZone>[]) {
      if (candidate.id == zoneId) {
        zone = candidate;
        break;
      }
    }
    if (zone == null) {
      throw ArgumentError.value(zoneId, 'zoneId', 'Unknown zone on active level.');
    }
    _selectedZoneId = zone.id;
    final firstSpaceId = zone.spaceIds.first;
    editor.selectSpace(firstSpaceId);
    notifyListeners();
  }

  void selectOutdoorZone(String zoneId) {
    OutdoorZone? zone;
    for (final candidate in site.outdoorZones) {
      if (candidate.id == zoneId) {
        zone = candidate;
        break;
      }
    }
    if (zone == null) {
      throw ArgumentError.value(zoneId, 'zoneId', 'Unknown outdoor zone.');
    }
    _context = EditorWorkspaceContext.siteOutdoor;
    _activeOutdoorZoneId = zone.id;
    _selectedZoneId = null;
    editor.level = BuildingLevel(
      id: 'site:${zone.id}',
      name: zone.name,
      elevationMm: 0,
      spaces: [
        EngineeringSpace(
          id: 'site-space:${zone.id}',
          name: zone.name,
          type: SpaceType.outdoorArea,
          boundary: zone.boundary,
          referenceFrame: RoomReferenceFrame(origin: zone.boundary.bounds.center),
          grid: zone.grid,
        ),
      ],
    );
    _resetEditorForLevel(editor.level);
    notifyListeners();
  }

  void nextLevel() {
    if (_context != EditorWorkspaceContext.buildingLevel) return;
    final levels = building.orderedLevels;
    final index = levels.indexWhere((level) => level.levelNumber == _activeLevelNumber);
    if (index >= 0 && index + 1 < levels.length) {
      selectLevel(levels[index + 1].levelNumber);
    }
  }

  void previousLevel() {
    if (_context != EditorWorkspaceContext.buildingLevel) return;
    final levels = building.orderedLevels;
    final index = levels.indexWhere((level) => level.levelNumber == _activeLevelNumber);
    if (index > 0) {
      selectLevel(levels[index - 1].levelNumber);
    }
  }

  void _activateLevel(ComposedBuildingLevel level) {
    editor.level = level.level;
    _resetEditorForLevel(level.level);
  }

  void _resetEditorForLevel(BuildingLevel level) {
    editor.openings = [];
    editor.routeSegments.clear();
    editor.activeSurface = null;
    editor.selectedOpeningId = null;
    editor.draftStart = null;
    editor.viewMode = EditorViewMode.plan;
    editor.tool = EditorTool.select;
    editor.selectSpace(level.spaces.isEmpty ? null : level.spaces.first.id);
  }
}

EngineeringSpace _space(
  String id,
  String name,
  int left,
  int bottom,
  int right,
  int top, {
  SpaceType type = SpaceType.room,
}) {
  final boundary = MmPolygon.rectangle(
    MmPoint(left, bottom),
    MmPoint(right, top),
  );
  return EngineeringSpace(
    id: id,
    name: name,
    type: type,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}

ComposedBuildingLevel _residentialTemplate() {
  final spaces = [
    _space('apt01-hall', 'Прихожая 01', 0, 0, 1800, 2500),
    _space('apt01-living', 'Кухня-гостиная 01', 0, 2500, 5200, 7000),
    _space('apt01-bedroom', 'Спальня 01', 1800, 0, 5200, 2500),
    _space('apt02-hall', 'Прихожая 02', 7800, 0, 9600, 2500),
    _space('apt02-living', 'Кухня-гостиная 02', 6400, 2500, 11600, 7000),
    _space('apt02-bedroom', 'Спальня 02', 9600, 0, 11600, 2500),
    _space(
      'common-corridor',
      'Общий коридор',
      5200,
      0,
      6400,
      7000,
      type: SpaceType.corridor,
    ),
  ];
  final level = BuildingLevel(
    id: 'residential-template',
    name: 'Типовой жилой этаж',
    elevationMm: 0,
    spaces: spaces,
  );
  return ComposedBuildingLevel(
    level: level,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
    zones: [
      BuildingZone(
        id: 'apt-01',
        name: 'Квартира 01',
        kind: BuildingZoneKind.apartment,
        apartmentNumber: '01',
        spaceIds: const {'apt01-hall', 'apt01-living', 'apt01-bedroom'},
      ),
      BuildingZone(
        id: 'apt-02',
        name: 'Квартира 02',
        kind: BuildingZoneKind.apartment,
        apartmentNumber: '02',
        spaceIds: const {'apt02-hall', 'apt02-living', 'apt02-bedroom'},
      ),
      BuildingZone(
        id: 'common',
        name: 'МОП',
        kind: BuildingZoneKind.common,
        spaceIds: const {'common-corridor'},
      ),
    ],
  );
}

ComposedBuildingLevel _basementTemplate() {
  final spaces = [
    _space('parking', 'Паркинг', 0, 0, 12000, 7500, type: SpaceType.hall),
    _space(
      'service-corridor',
      'Технический коридор',
      12000,
      0,
      14000,
      7500,
      type: SpaceType.corridor,
    ),
    _space(
      'electrical-room',
      'Электрощитовая',
      14000,
      0,
      17500,
      3500,
      type: SpaceType.technicalRoom,
    ),
  ];
  final level = BuildingLevel(
    id: 'basement-template',
    name: 'Типовой подземный этаж',
    elevationMm: -3300,
    spaces: spaces,
  );
  return ComposedBuildingLevel(
    level: level,
    levelNumber: -1,
    kind: BuildingLevelKind.basement,
    floorToFloorHeightMm: 3300,
    zones: [
      BuildingZone(
        id: 'parking-zone',
        name: 'Паркинг',
        kind: BuildingZoneKind.parking,
        spaceIds: const {'parking'},
      ),
      BuildingZone(
        id: 'technical-zone',
        name: 'Техническая зона',
        kind: BuildingZoneKind.technical,
        spaceIds: const {'service-corridor', 'electrical-room'},
      ),
    ],
  );
}
