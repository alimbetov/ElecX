import 'package:flutter/foundation.dart';

import '../../domain/building_composition.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/site_orientation.dart';
import '../../domain/residential_tower_builder.dart';
import '../../domain/site_outdoor_model.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';

enum EditorWorkspaceContext { buildingLevel, siteOutdoor }

final class EditorBuildingWorkspace extends ChangeNotifier {
  EditorBuildingWorkspace({
    required this.editor,
    required this.building,
    required this.site,
    int initialLevelNumber = 1,
    Map<int, List<ArchitecturalOpening>> initialOpeningsByLevel = const {},
  }) : _activeLevelNumber = initialLevelNumber,
       _openingsByLevel = {
         for (final entry in initialOpeningsByLevel.entries)
           entry.key: List<ArchitecturalOpening>.of(entry.value),
       } {
    final initial =
        building.levelByNumber(initialLevelNumber) ??
        building.orderedLevels.first;
    _activeLevelNumber = initial.levelNumber;
    _activateLevel(initial);
  }

  factory EditorBuildingWorkspace.blank(
    EditorController editor, {
    required String projectId,
    required String projectName,
  }) {
    final level = ComposedBuildingLevel(
      level: editor.level,
      levelNumber: 1,
      kind: BuildingLevelKind.residential,
      zones: const [],
    );
    final buildingGeometry = Building(
      id: 'building-$projectId',
      name: projectName,
      levels: [level.level],
    );
    final building = ComposedBuilding(
      building: buildingGeometry,
      levels: [level],
    );
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'site-$projectId',
        name: projectName,
        buildings: [buildingGeometry],
      ),
      outdoorZones: const [],
      connections: const [],
    );
    return EditorBuildingWorkspace(
      editor: editor,
      building: building,
      site: site,
      initialLevelNumber: 1,
    );
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
  ComposedBuilding building;
  ComposedProjectSite site;
  final Map<int, List<ArchitecturalOpening>> _openingsByLevel;

  EditorWorkspaceContext _context = EditorWorkspaceContext.buildingLevel;
  late int _activeLevelNumber;
  String? _selectedZoneId;
  String? _activeOutdoorZoneId;

  EditorWorkspaceContext get context => _context;
  int get activeLevelNumber => _activeLevelNumber;
  String? get selectedZoneId => _selectedZoneId;
  String? get activeOutdoorZoneId => _activeOutdoorZoneId;
  Map<int, List<ArchitecturalOpening>> get openingsByLevel =>
      Map<int, List<ArchitecturalOpening>>.unmodifiable({
        for (final entry in _openingsByLevel.entries)
          entry.key: List<ArchitecturalOpening>.unmodifiable(entry.value),
      });

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

  void updateProjectNorth(ProjectNorth value) {
    if (site.site.projectNorth.northAzimuthDegrees ==
        value.northAzimuthDegrees) {
      return;
    }
    site = site.copyWith(site: site.site.copyWith(projectNorth: value));
    notifyListeners();
  }

  void selectLevel(int levelNumber) {
    if (_context == EditorWorkspaceContext.buildingLevel) {
      synchronizeActiveEditorState();
    }
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
      throw ArgumentError.value(
        zoneId,
        'zoneId',
        'Unknown zone on active level.',
      );
    }
    _selectedZoneId = zone.id;
    final firstSpaceId = zone.spaceIds.first;
    editor.selectSpace(firstSpaceId);
    notifyListeners();
  }

  void selectOutdoorZone(String zoneId) {
    if (_context == EditorWorkspaceContext.buildingLevel) {
      synchronizeActiveEditorState();
    }
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
          referenceFrame: RoomReferenceFrame(
            origin: zone.boundary.bounds.center,
          ),
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
    final index = levels.indexWhere(
      (level) => level.levelNumber == _activeLevelNumber,
    );
    if (index >= 0 && index + 1 < levels.length) {
      selectLevel(levels[index + 1].levelNumber);
    }
  }

  void previousLevel() {
    if (_context != EditorWorkspaceContext.buildingLevel) return;
    final levels = building.orderedLevels;
    final index = levels.indexWhere(
      (level) => level.levelNumber == _activeLevelNumber,
    );
    if (index > 0) {
      selectLevel(levels[index - 1].levelNumber);
    }
  }

  void synchronizeActiveEditorState() {
    if (_context != EditorWorkspaceContext.buildingLevel) return;
    final current = building.levelByNumber(_activeLevelNumber);
    if (current == null) return;

    _openingsByLevel[_activeLevelNumber] = List<ArchitecturalOpening>.of(
      editor.openings,
    );
    final updatedLevel = ComposedBuildingLevel(
      level: editor.level,
      levelNumber: current.levelNumber,
      kind: current.kind,
      floorToFloorHeightMm: current.floorToFloorHeightMm,
      zones: current.zones,
    );
    final levels = [
      for (final level in building.levels)
        if (level.levelNumber == _activeLevelNumber) updatedLevel else level,
    ];
    final geometry = Building(
      id: building.building.id,
      name: building.building.name,
      levels: [for (final level in levels) level.level],
    );
    building = ComposedBuilding(
      building: geometry,
      levels: levels,
      verticalCores: building.verticalCores,
    );
    site = site.copyWith(
      site: site.site.copyWith(
        buildings: [
          for (final candidate in site.site.buildings)
            if (candidate.id == geometry.id) geometry else candidate,
        ],
      ),
    );
  }

  void restoreNavigationState({
    required EditorWorkspaceContext context,
    String? selectedZoneId,
    String? activeOutdoorZoneId,
  }) {
    if (context == EditorWorkspaceContext.siteOutdoor) {
      if (activeOutdoorZoneId == null) {
        throw ArgumentError('Outdoor context requires an active zone.');
      }
      selectOutdoorZone(activeOutdoorZoneId);
      return;
    }
    _context = EditorWorkspaceContext.buildingLevel;
    _activeOutdoorZoneId = null;
    if (selectedZoneId != null &&
        !(activeLevel?.zones.any((zone) => zone.id == selectedZoneId) ??
            false)) {
      throw ArgumentError('Restored building zone does not exist.');
    }
    _selectedZoneId = selectedZoneId;
    notifyListeners();
  }

  void _activateLevel(ComposedBuildingLevel level) {
    editor.level = level.level;
    _resetEditorForLevel(
      level.level,
      openings: _openingsByLevel[level.levelNumber] ?? const [],
    );
  }

  void _resetEditorForLevel(
    BuildingLevel level, {
    List<ArchitecturalOpening> openings = const [],
  }) {
    editor.openings = List<ArchitecturalOpening>.of(openings);
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
