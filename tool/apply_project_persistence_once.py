from pathlib import Path

BRANCH = 'feat/spatial-editor-interaction-hardening'


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    p.write_text(text.replace(old, new, 1))

# ---------------------------------------------------------------------------
# EditorController: explicit restore boundary for committed editor state.
# ---------------------------------------------------------------------------
p = 'lib/src/features/editor/editor_controller.dart'
replace_once(
    p,
    '''  static EngineeringSpace _room(\n''',
    '''  EditorController.restored({\n    required this.level,\n    required List<ArchitecturalOpening> openings,\n  }) {\n    this.openings = List<ArchitecturalOpening>.of(openings);\n  }\n\n  void restoreResumeState({\n    required String? selectedSpaceId,\n    required String? selectedOpeningId,\n    required RoomSurfaceRef? activeSurface,\n    required EditorViewMode viewMode,\n    required bool snapEnabled,\n    required bool dimensionsVisible,\n    required int floorGridMm,\n    required double zoom,\n    required int roomSequence,\n    required int openingSequence,\n  }) {\n    if (selectedSpaceId != null &&\n        !level.spaces.any((space) => space.id == selectedSpaceId)) {\n      throw ArgumentError('Restored selected space does not exist.');\n    }\n    if (selectedOpeningId != null &&\n        !openings.any((opening) => opening.id == selectedOpeningId)) {\n      throw ArgumentError('Restored selected opening does not exist.');\n    }\n    if (activeSurface != null &&\n        !level.spaces.any((space) => space.id == activeSurface.spaceId)) {\n      throw ArgumentError('Restored active surface references unknown space.');\n    }\n    if (floorGridMm <= 0 || roomSequence <= 0 || openingSequence <= 0) {\n      throw ArgumentError('Restored editor counters/grid are invalid.');\n    }\n    this.selectedSpaceId = selectedSpaceId;\n    this.selectedOpeningId = selectedOpeningId;\n    this.activeSurface = activeSurface;\n    this.viewMode = viewMode;\n    tool = EditorTool.select;\n    draftStart = null;\n    routeSegments.clear();\n    this.snapEnabled = snapEnabled;\n    this.dimensionsVisible = dimensionsVisible;\n    this.floorGridMm = floorGridMm;\n    this.zoom = zoom.clamp(0.35, 6.0).toDouble();\n    this.roomSequence = roomSequence;\n    this.openingSequence = openingSequence;\n  }\n\n  static EngineeringSpace _room(\n''',
    'add controller restore boundary',
)

# ---------------------------------------------------------------------------
# P2: allow a canonical persisted state to replace the lazy Expando session.
# ---------------------------------------------------------------------------
p = 'lib/src/features/editor/editor_p2_session.dart'
replace_once(
    p,
    '''extension EditorP2SessionAccess on EditorController {\n  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session(\n        routeContextResolver: routeNormativeContextFor,\n      );\n}\n''',
    '''extension EditorP2SessionAccess on EditorController {\n  EditorP2Session get p2 => _p2Sessions[this] ??= EditorP2Session(\n        routeContextResolver: routeNormativeContextFor,\n      );\n\n  void restoreP2State(EditorP2State state) {\n    final previous = _p2Sessions[this];\n    previous?.dispose();\n    _p2Sessions[this] = EditorP2Session(\n      initialState: state,\n      routeContextResolver: routeNormativeContextFor,\n    );\n  }\n\n  void disposeP2State() {\n    _p2Sessions[this]?.dispose();\n    _p2Sessions[this] = null;\n  }\n}\n''',
    'add P2 restore boundary',
)

# ---------------------------------------------------------------------------
# Workspace: keep edited level geometry/openings in the project-level model.
# ---------------------------------------------------------------------------
p = 'lib/src/features/editor/editor_building_workspace.dart'
text = Path(p).read_text()
text = text.replace(
    "import '../../domain/site_outdoor_model.dart';\n",
    "import '../../domain/site_outdoor_model.dart';\nimport '../../domain/surfaces.dart';\n",
    1,
)
text = text.replace(
    '''    required this.site,\n    int initialLevelNumber = 1,\n  }) : _activeLevelNumber = initialLevelNumber {''',
    '''    required this.site,\n    int initialLevelNumber = 1,\n    Map<int, List<ArchitecturalOpening>> initialOpeningsByLevel = const {},\n  })  : _activeLevelNumber = initialLevelNumber,\n        _openingsByLevel = {\n          for (final entry in initialOpeningsByLevel.entries)\n            entry.key: List<ArchitecturalOpening>.of(entry.value),\n        } {''',
    1,
)
text = text.replace(
    '  final ComposedBuilding building;\n  ComposedProjectSite site;\n',
    '  ComposedBuilding building;\n  ComposedProjectSite site;\n  final Map<int, List<ArchitecturalOpening>> _openingsByLevel;\n',
    1,
)
text = text.replace(
    '''  String? get activeOutdoorZoneId => _activeOutdoorZoneId;\n''',
    '''  String? get activeOutdoorZoneId => _activeOutdoorZoneId;\n  Map<int, List<ArchitecturalOpening>> get openingsByLevel =>\n      Map.unmodifiable({\n        for (final entry in _openingsByLevel.entries)\n          entry.key: List.unmodifiable(entry.value),\n      });\n''',
    1,
)
text = text.replace(
    '''  void selectLevel(int levelNumber) {\n    final level = building.levelByNumber(levelNumber);''',
    '''  void selectLevel(int levelNumber) {\n    if (_context == EditorWorkspaceContext.buildingLevel) {\n      synchronizeActiveEditorState();\n    }\n    final level = building.levelByNumber(levelNumber);''',
    1,
)
text = text.replace(
    '''  void selectOutdoorZone(String zoneId) {\n    OutdoorZone? zone;''',
    '''  void selectOutdoorZone(String zoneId) {\n    if (_context == EditorWorkspaceContext.buildingLevel) {\n      synchronizeActiveEditorState();\n    }\n    OutdoorZone? zone;''',
    1,
)
text = text.replace(
    '''  void _activateLevel(ComposedBuildingLevel level) {\n    editor.level = level.level;\n    _resetEditorForLevel(level.level);\n  }\n\n  void _resetEditorForLevel(BuildingLevel level) {\n    editor.openings = [];''',
    '''  void synchronizeActiveEditorState() {\n    if (_context != EditorWorkspaceContext.buildingLevel) return;\n    final current = building.levelByNumber(_activeLevelNumber);\n    if (current == null) return;\n\n    _openingsByLevel[_activeLevelNumber] =\n        List<ArchitecturalOpening>.of(editor.openings);\n    final updatedLevel = ComposedBuildingLevel(\n      level: editor.level,\n      levelNumber: current.levelNumber,\n      kind: current.kind,\n      floorToFloorHeightMm: current.floorToFloorHeightMm,\n      zones: current.zones,\n    );\n    final levels = [\n      for (final level in building.levels)\n        if (level.levelNumber == _activeLevelNumber) updatedLevel else level,\n    ];\n    final geometry = Building(\n      id: building.building.id,\n      name: building.building.name,\n      levels: [for (final level in levels) level.level],\n    );\n    building = ComposedBuilding(\n      building: geometry,\n      levels: levels,\n      verticalCores: building.verticalCores,\n    );\n    site = site.copyWith(\n      site: site.site.copyWith(\n        buildings: [\n          for (final candidate in site.site.buildings)\n            if (candidate.id == geometry.id) geometry else candidate,\n        ],\n      ),\n    );\n  }\n\n  void restoreNavigationState({\n    required EditorWorkspaceContext context,\n    String? selectedZoneId,\n    String? activeOutdoorZoneId,\n  }) {\n    if (context == EditorWorkspaceContext.siteOutdoor) {\n      if (activeOutdoorZoneId == null) {\n        throw ArgumentError('Outdoor context requires an active zone.');\n      }\n      selectOutdoorZone(activeOutdoorZoneId);\n      return;\n    }\n    _context = EditorWorkspaceContext.buildingLevel;\n    _activeOutdoorZoneId = null;\n    if (selectedZoneId != null &&\n        !(activeLevel?.zones.any((zone) => zone.id == selectedZoneId) ?? false)) {\n      throw ArgumentError('Restored building zone does not exist.');\n    }\n    _selectedZoneId = selectedZoneId;\n    notifyListeners();\n  }\n\n  void _activateLevel(ComposedBuildingLevel level) {\n    editor.level = level.level;\n    _resetEditorForLevel(\n      level.level,\n      openings: _openingsByLevel[level.levelNumber] ?? const [],\n    );\n  }\n\n  void _resetEditorForLevel(\n    BuildingLevel level, {\n    List<ArchitecturalOpening> openings = const [],\n  }) {\n    editor.openings = List<ArchitecturalOpening>.of(openings);''',
    1,
)
Path(p).write_text(text)

# ---------------------------------------------------------------------------
# Canonical project document + strict JSON codec + durable file store.
# ---------------------------------------------------------------------------
Path('lib/src/features/editor/editor_project_document.dart').write_text(r'''import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/building_composition.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/route_medium.dart';
import '../../domain/site_orientation.dart';
import '../../domain/site_outdoor_model.dart';
import '../../domain/surfaces.dart';
import '../../domain/wall_profile.dart';
import '../../engine/selection_engine.dart';
import 'cable_route_constraints.dart';
import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class EditorProjectResumeState {
  const EditorProjectResumeState({
    required this.selectedSpaceId,
    required this.selectedOpeningId,
    required this.activeSurface,
    required this.viewMode,
    required this.snapEnabled,
    required this.dimensionsVisible,
    required this.floorGridMm,
    required this.zoom,
    required this.roomSequence,
    required this.openingSequence,
  });

  final String? selectedSpaceId;
  final String? selectedOpeningId;
  final RoomSurfaceRef? activeSurface;
  final EditorViewMode viewMode;
  final bool snapEnabled;
  final bool dimensionsVisible;
  final int floorGridMm;
  final double zoom;
  final int roomSequence;
  final int openingSequence;
}

final class RestoredEditorProject {
  const RestoredEditorProject({required this.editor, required this.workspace});

  final EditorController editor;
  final EditorBuildingWorkspace workspace;
}

/// Versioned, canonical persisted state for one editable ElecX workspace.
///
/// Transient pointer/keyboard transactions and route drafts are deliberately
/// excluded. Only committed geometry, components, routes, constraints and the
/// minimal resume context are persisted.
final class EditorProjectDocument {
  const EditorProjectDocument({
    required this.schemaVersion,
    required this.projectId,
    required this.projectName,
    required this.building,
    required this.site,
    required this.workspaceContext,
    required this.activeLevelNumber,
    required this.selectedZoneId,
    required this.activeOutdoorZoneId,
    required this.openingsByLevel,
    required this.resume,
    required this.p2State,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String projectId;
  final String projectName;
  final ComposedBuilding building;
  final ComposedProjectSite site;
  final EditorWorkspaceContext workspaceContext;
  final int activeLevelNumber;
  final String? selectedZoneId;
  final String? activeOutdoorZoneId;
  final Map<int, List<ArchitecturalOpening>> openingsByLevel;
  final EditorProjectResumeState resume;
  final EditorP2State p2State;

  factory EditorProjectDocument.capture(EditorBuildingWorkspace workspace) {
    final editor = workspace.editor;
    if (editor.p2.isManipulating) {
      throw StateError('Cannot save while a component transform is active.');
    }
    if (editor.routeSegments.isNotEmpty || editor.draftStart != null) {
      throw StateError('Cannot save an unfinished editor draft.');
    }
    workspace.synchronizeActiveEditorState();
    return EditorProjectDocument(
      schemaVersion: currentSchemaVersion,
      projectId: workspace.site.site.id,
      projectName: workspace.site.site.name,
      building: workspace.building,
      site: workspace.site,
      workspaceContext: workspace.context,
      activeLevelNumber: workspace.activeLevelNumber,
      selectedZoneId: workspace.selectedZoneId,
      activeOutdoorZoneId: workspace.activeOutdoorZoneId,
      openingsByLevel: workspace.openingsByLevel,
      resume: EditorProjectResumeState(
        selectedSpaceId: editor.selectedSpaceId,
        selectedOpeningId: editor.selectedOpeningId,
        activeSurface: editor.activeSurface,
        viewMode: editor.viewMode,
        snapEnabled: editor.snapEnabled,
        dimensionsVisible: editor.dimensionsVisible,
        floorGridMm: editor.floorGridMm,
        zoom: editor.zoom,
        roomSequence: editor.roomSequence,
        openingSequence: editor.openingSequence,
      ),
      p2State: editor.p2.state,
    );
  }

  RestoredEditorProject restore() {
    final initialLevel = building.levelByNumber(activeLevelNumber);
    if (initialLevel == null) {
      throw StateError('Persisted active level no longer exists.');
    }
    final editor = EditorController.restored(
      level: initialLevel.level,
      openings: openingsByLevel[activeLevelNumber] ?? const [],
    );
    final workspace = EditorBuildingWorkspace(
      editor: editor,
      building: building,
      site: site,
      initialLevelNumber: activeLevelNumber,
      initialOpeningsByLevel: openingsByLevel,
    );
    workspace.restoreNavigationState(
      context: workspaceContext,
      selectedZoneId: selectedZoneId,
      activeOutdoorZoneId: activeOutdoorZoneId,
    );
    editor.restoreResumeState(
      selectedSpaceId: resume.selectedSpaceId,
      selectedOpeningId: resume.selectedOpeningId,
      activeSurface: resume.activeSurface,
      viewMode: resume.viewMode,
      snapEnabled: resume.snapEnabled,
      dimensionsVisible: resume.dimensionsVisible,
      floorGridMm: resume.floorGridMm,
      zoom: resume.zoom,
      roomSequence: resume.roomSequence,
      openingSequence: resume.openingSequence,
    );
    editor.restoreP2State(p2State);
    return RestoredEditorProject(editor: editor, workspace: workspace);
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'projectId': projectId,
        'projectName': projectName,
        'building': _buildingToJson(building),
        'site': _siteToJson(site),
        'workspace': {
          'context': workspaceContext.name,
          'activeLevelNumber': activeLevelNumber,
          'selectedZoneId': selectedZoneId,
          'activeOutdoorZoneId': activeOutdoorZoneId,
          'openingsByLevel': {
            for (final entry in openingsByLevel.entries)
              entry.key.toString(): [
                for (final opening in entry.value) _openingToJson(opening),
              ],
          },
          'resume': _resumeToJson(resume),
        },
        'p2': _p2ToJson(p2State),
      };

  factory EditorProjectDocument.fromJson(Map<String, Object?> json) {
    final version = _int(json['schemaVersion'], 'schemaVersion');
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported ElecX project schema $version; expected '
        '$currentSchemaVersion.',
      );
    }
    final workspace = _map(json['workspace'], 'workspace');
    final openingsRaw = _map(workspace['openingsByLevel'], 'openingsByLevel');
    final openings = <int, List<ArchitecturalOpening>>{};
    for (final entry in openingsRaw.entries) {
      final levelNumber = int.tryParse(entry.key);
      if (levelNumber == null) {
        throw FormatException('Invalid openings level key ${entry.key}.');
      }
      openings[levelNumber] = [
        for (final item in _list(entry.value, 'openingsByLevel.${entry.key}'))
          _openingFromJson(_map(item, 'opening')),
      ];
    }
    return EditorProjectDocument(
      schemaVersion: version,
      projectId: _string(json['projectId'], 'projectId'),
      projectName: _string(json['projectName'], 'projectName'),
      building: _buildingFromJson(_map(json['building'], 'building')),
      site: _siteFromJson(_map(json['site'], 'site')),
      workspaceContext: _enumValue(
        EditorWorkspaceContext.values,
        _string(workspace['context'], 'workspace.context'),
        'workspace.context',
      ),
      activeLevelNumber:
          _int(workspace['activeLevelNumber'], 'workspace.activeLevelNumber'),
      selectedZoneId: _nullableString(workspace['selectedZoneId']),
      activeOutdoorZoneId: _nullableString(workspace['activeOutdoorZoneId']),
      openingsByLevel: Map.unmodifiable(openings),
      resume: _resumeFromJson(_map(workspace['resume'], 'workspace.resume')),
      p2State: _p2FromJson(_map(json['p2'], 'p2')),
    );
  }
}

abstract interface class EditorProjectStore {
  Future<void> save(EditorProjectDocument document);
  Future<EditorProjectDocument?> load(String projectId);
}

final class JsonFileEditorProjectStore implements EditorProjectStore {
  JsonFileEditorProjectStore(this.rootDirectory);

  final Directory rootDirectory;

  static Future<JsonFileEditorProjectStore> openDefault() async {
    final documents = await getApplicationDocumentsDirectory();
    return JsonFileEditorProjectStore(
      Directory(path.join(documents.path, 'ElecX', 'projects')),
    );
  }

  @override
  Future<void> save(EditorProjectDocument document) async {
    await rootDirectory.create(recursive: true);
    final encoded = jsonEncode(document.toJson());
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw StateError('Encoded ElecX project is not a JSON object.');
    }
    // Validate the complete payload before touching the current on-disk file.
    EditorProjectDocument.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );

    final target = _target(document.projectId);
    final temp = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    if (await temp.exists()) await temp.delete();
    await temp.writeAsString(encoded, flush: true);
    if (await backup.exists()) await backup.delete();

    var backedUp = false;
    try {
      if (await target.exists()) {
        await target.rename(backup.path);
        backedUp = true;
      }
      await temp.rename(target.path);
      if (backedUp && await backup.exists()) await backup.delete();
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    final target = _target(projectId);
    final backup = File('${target.path}.bak');
    File? source;
    if (await target.exists()) {
      source = target;
    } else if (await backup.exists()) {
      source = backup;
    }
    if (source == null) return null;
    final raw = jsonDecode(await source.readAsString());
    if (raw is! Map) {
      throw FormatException('ElecX project root must be a JSON object.');
    }
    final document = EditorProjectDocument.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (document.projectId != projectId) {
      throw FormatException('Persisted project id does not match requested id.');
    }
    return document;
  }

  File _target(String projectId) {
    final encoded = base64Url.encode(utf8.encode(projectId)).replaceAll('=', '');
    return File(path.join(rootDirectory.path, '$encoded.elecx.json'));
  }
}

Map<String, Object?> _resumeToJson(EditorProjectResumeState value) => {
      'selectedSpaceId': value.selectedSpaceId,
      'selectedOpeningId': value.selectedOpeningId,
      'activeSurface':
          value.activeSurface == null ? null : _surfaceToJson(value.activeSurface!),
      'viewMode': value.viewMode.name,
      'snapEnabled': value.snapEnabled,
      'dimensionsVisible': value.dimensionsVisible,
      'floorGridMm': value.floorGridMm,
      'zoom': value.zoom,
      'roomSequence': value.roomSequence,
      'openingSequence': value.openingSequence,
    };

EditorProjectResumeState _resumeFromJson(Map<String, Object?> json) =>
    EditorProjectResumeState(
      selectedSpaceId: _nullableString(json['selectedSpaceId']),
      selectedOpeningId: _nullableString(json['selectedOpeningId']),
      activeSurface: json['activeSurface'] == null
          ? null
          : _surfaceFromJson(_map(json['activeSurface'], 'activeSurface')),
      viewMode: _enumValue(
        EditorViewMode.values,
        _string(json['viewMode'], 'viewMode'),
        'viewMode',
      ),
      snapEnabled: _bool(json['snapEnabled'], 'snapEnabled'),
      dimensionsVisible: _bool(json['dimensionsVisible'], 'dimensionsVisible'),
      floorGridMm: _int(json['floorGridMm'], 'floorGridMm'),
      zoom: _double(json['zoom'], 'zoom'),
      roomSequence: _int(json['roomSequence'], 'roomSequence'),
      openingSequence: _int(json['openingSequence'], 'openingSequence'),
    );

Map<String, Object?> _buildingToJson(ComposedBuilding value) => {
      'building': _plainBuildingToJson(value.building),
      'levels': [for (final item in value.levels) _composedLevelToJson(item)],
      'verticalCores': [
        for (final item in value.verticalCores) _verticalCoreToJson(item),
      ],
    };

ComposedBuilding _buildingFromJson(Map<String, Object?> json) =>
    ComposedBuilding(
      building: _plainBuildingFromJson(_map(json['building'], 'building.building')),
      levels: [
        for (final item in _list(json['levels'], 'building.levels'))
          _composedLevelFromJson(_map(item, 'building.level')),
      ],
      verticalCores: [
        for (final item in _list(json['verticalCores'], 'building.verticalCores'))
          _verticalCoreFromJson(_map(item, 'verticalCore')),
      ],
    );

Map<String, Object?> _plainBuildingToJson(Building value) => {
      'id': value.id,
      'name': value.name,
      'levels': [for (final level in value.levels) _levelToJson(level)],
    };

Building _plainBuildingFromJson(Map<String, Object?> json) => Building(
      id: _string(json['id'], 'building.id'),
      name: _string(json['name'], 'building.name'),
      levels: [
        for (final item in _list(json['levels'], 'building.levels'))
          _levelFromJson(_map(item, 'level')),
      ],
    );

Map<String, Object?> _composedLevelToJson(ComposedBuildingLevel value) => {
      'level': _levelToJson(value.level),
      'levelNumber': value.levelNumber,
      'kind': value.kind.name,
      'floorToFloorHeightMm': value.floorToFloorHeightMm,
      'zones': [for (final zone in value.zones) _zoneToJson(zone)],
    };

ComposedBuildingLevel _composedLevelFromJson(Map<String, Object?> json) =>
    ComposedBuildingLevel(
      level: _levelFromJson(_map(json['level'], 'composedLevel.level')),
      levelNumber: _int(json['levelNumber'], 'levelNumber'),
      kind: _enumValue(
        BuildingLevelKind.values,
        _string(json['kind'], 'level.kind'),
        'level.kind',
      ),
      floorToFloorHeightMm:
          _int(json['floorToFloorHeightMm'], 'floorToFloorHeightMm'),
      zones: [
        for (final item in _list(json['zones'], 'zones'))
          _zoneFromJson(_map(item, 'zone')),
      ],
    );

Map<String, Object?> _zoneToJson(BuildingZone value) => {
      'id': value.id,
      'name': value.name,
      'kind': value.kind.name,
      'spaceIds': value.spaceIds.toList()..sort(),
      'apartmentNumber': value.apartmentNumber,
    };

BuildingZone _zoneFromJson(Map<String, Object?> json) => BuildingZone(
      id: _string(json['id'], 'zone.id'),
      name: _string(json['name'], 'zone.name'),
      kind: _enumValue(
        BuildingZoneKind.values,
        _string(json['kind'], 'zone.kind'),
        'zone.kind',
      ),
      spaceIds: [
        for (final value in _list(json['spaceIds'], 'zone.spaceIds'))
          _string(value, 'zone.spaceId'),
      ],
      apartmentNumber: _nullableString(json['apartmentNumber']),
    );

Map<String, Object?> _verticalCoreToJson(VerticalCore value) => {
      'id': value.id,
      'name': value.name,
      'kind': value.kind.name,
      'servedLevelNumbers': value.servedLevelNumbers.toList()..sort(),
      'spaceIdByLevel': {
        for (final entry in value.spaceIdByLevel.entries)
          entry.key.toString(): entry.value,
      },
    };

VerticalCore _verticalCoreFromJson(Map<String, Object?> json) {
  final spaces = _map(json['spaceIdByLevel'], 'verticalCore.spaceIdByLevel');
  return VerticalCore(
    id: _string(json['id'], 'verticalCore.id'),
    name: _string(json['name'], 'verticalCore.name'),
    kind: _enumValue(
      VerticalCoreKind.values,
      _string(json['kind'], 'verticalCore.kind'),
      'verticalCore.kind',
    ),
    servedLevelNumbers: [
      for (final item in _list(json['servedLevelNumbers'], 'servedLevelNumbers'))
        _int(item, 'servedLevelNumber'),
    ],
    spaceIdByLevel: {
      for (final entry in spaces.entries)
        int.parse(entry.key): _string(entry.value, 'spaceIdByLevel'),
    },
  );
}

Map<String, Object?> _siteToJson(ComposedProjectSite value) => {
      'site': _projectSiteToJson(value.site),
      'outdoorZones': [for (final zone in value.outdoorZones) _outdoorToJson(zone)],
      'connections': [
        for (final item in value.connections) _siteConnectionToJson(item),
      ],
    };

ComposedProjectSite _siteFromJson(Map<String, Object?> json) =>
    ComposedProjectSite(
      site: _projectSiteFromJson(_map(json['site'], 'site.site')),
      outdoorZones: [
        for (final item in _list(json['outdoorZones'], 'site.outdoorZones'))
          _outdoorFromJson(_map(item, 'outdoorZone')),
      ],
      connections: [
        for (final item in _list(json['connections'], 'site.connections'))
          _siteConnectionFromJson(_map(item, 'siteConnection')),
      ],
    );

Map<String, Object?> _projectSiteToJson(ProjectSite value) => {
      'id': value.id,
      'name': value.name,
      'buildings': [for (final item in value.buildings) _plainBuildingToJson(item)],
      'projectNorthDegrees': value.projectNorth.northAzimuthDegrees,
      'solarContext': value.solarContext == null
          ? null
          : {
              'latitudeDegrees': value.solarContext!.latitudeDegrees,
              'longitudeDegrees': value.solarContext!.longitudeDegrees,
              'timeZoneOffsetMinutes': value.solarContext!.timeZoneOffsetMinutes,
            },
    };

ProjectSite _projectSiteFromJson(Map<String, Object?> json) {
  final solarRaw = json['solarContext'];
  return ProjectSite(
    id: _string(json['id'], 'site.id'),
    name: _string(json['name'], 'site.name'),
    buildings: [
      for (final item in _list(json['buildings'], 'site.buildings'))
        _plainBuildingFromJson(_map(item, 'site.building')),
    ],
    projectNorth: ProjectNorth(
      northAzimuthDegrees:
          _double(json['projectNorthDegrees'], 'site.projectNorthDegrees'),
    ),
    solarContext: solarRaw == null
        ? null
        : () {
            final solar = _map(solarRaw, 'site.solarContext');
            return SolarSiteContext(
              latitudeDegrees:
                  _double(solar['latitudeDegrees'], 'solar.latitudeDegrees'),
              longitudeDegrees:
                  _double(solar['longitudeDegrees'], 'solar.longitudeDegrees'),
              timeZoneOffsetMinutes: _int(
                solar['timeZoneOffsetMinutes'],
                'solar.timeZoneOffsetMinutes',
              ),
            );
          }(),
  );
}

Map<String, Object?> _outdoorToJson(OutdoorZone value) => {
      'id': value.id,
      'name': value.name,
      'kind': value.kind.name,
      'boundary': _polygonToJson(value.boundary),
      'grid': _gridToJson(value.grid),
    };

OutdoorZone _outdoorFromJson(Map<String, Object?> json) => OutdoorZone(
      id: _string(json['id'], 'outdoor.id'),
      name: _string(json['name'], 'outdoor.name'),
      kind: _enumValue(
        OutdoorZoneKind.values,
        _string(json['kind'], 'outdoor.kind'),
        'outdoor.kind',
      ),
      boundary: _polygonFromJson(_list(json['boundary'], 'outdoor.boundary')),
      grid: _gridFromJson(_map(json['grid'], 'outdoor.grid')),
    );

Map<String, Object?> _siteConnectionToJson(SiteBuildingConnection value) => {
      'id': value.id,
      'kind': value.kind.name,
      'outdoorZoneId': value.outdoorZoneId,
      'buildingId': value.buildingId,
      'levelNumber': value.levelNumber,
      'sitePoint': _pointToJson(value.sitePoint),
      'levelPoint': _pointToJson(value.levelPoint),
      'targetSpaceId': value.targetSpaceId,
    };

SiteBuildingConnection _siteConnectionFromJson(Map<String, Object?> json) =>
    SiteBuildingConnection(
      id: _string(json['id'], 'connection.id'),
      kind: _enumValue(
        SiteConnectionKind.values,
        _string(json['kind'], 'connection.kind'),
        'connection.kind',
      ),
      outdoorZoneId: _string(json['outdoorZoneId'], 'connection.outdoorZoneId'),
      buildingId: _string(json['buildingId'], 'connection.buildingId'),
      levelNumber: _int(json['levelNumber'], 'connection.levelNumber'),
      sitePoint: _pointFromJson(_map(json['sitePoint'], 'connection.sitePoint')),
      levelPoint:
          _pointFromJson(_map(json['levelPoint'], 'connection.levelPoint')),
      targetSpaceId: _nullableString(json['targetSpaceId']),
    );

Map<String, Object?> _levelToJson(BuildingLevel value) => {
      'id': value.id,
      'name': value.name,
      'elevationMm': value.elevationMm,
      'spaces': [for (final item in value.spaces) _spaceToJson(item)],
    };

BuildingLevel _levelFromJson(Map<String, Object?> json) => BuildingLevel(
      id: _string(json['id'], 'level.id'),
      name: _string(json['name'], 'level.name'),
      elevationMm: _int(json['elevationMm'], 'level.elevationMm'),
      spaces: [
        for (final item in _list(json['spaces'], 'level.spaces'))
          _spaceFromJson(_map(item, 'space')),
      ],
    );

Map<String, Object?> _spaceToJson(EngineeringSpace value) => {
      'id': value.id,
      'name': value.name,
      'type': value.type.name,
      'boundary': _polygonToJson(value.boundary),
      'referenceFrame': {
        'origin': _pointToJson(value.referenceFrame.origin),
        'rotationRadians': value.referenceFrame.rotationRadians,
      },
      'grid': _gridToJson(value.grid),
      'wallProfiles': {
        for (final entry in value.wallProfiles.entries)
          entry.key.toString(): [
            for (final point in entry.value.vertices)
              {'xMm': point.xMm, 'yMm': point.yMm},
          ],
      },
    };

EngineeringSpace _spaceFromJson(Map<String, Object?> json) {
  final frame = _map(json['referenceFrame'], 'space.referenceFrame');
  final walls = _map(json['wallProfiles'], 'space.wallProfiles');
  return EngineeringSpace(
    id: _string(json['id'], 'space.id'),
    name: _string(json['name'], 'space.name'),
    type: _enumValue(
      SpaceType.values,
      _string(json['type'], 'space.type'),
      'space.type',
    ),
    boundary: _polygonFromJson(_list(json['boundary'], 'space.boundary')),
    referenceFrame: RoomReferenceFrame(
      origin: _pointFromJson(_map(frame['origin'], 'referenceFrame.origin')),
      rotationRadians:
          _double(frame['rotationRadians'], 'referenceFrame.rotationRadians'),
    ),
    grid: _gridFromJson(_map(json['grid'], 'space.grid')),
    wallProfiles: {
      for (final entry in walls.entries)
        int.parse(entry.key): WallProfile(
          vertices: [
            for (final item in _list(entry.value, 'wallProfile'))
              () {
                final point = _map(item, 'wallProfile.point');
                return WallProfilePoint(
                  _int(point['xMm'], 'wallProfile.xMm'),
                  _int(point['yMm'], 'wallProfile.yMm'),
                );
              }(),
          ],
        ),
    },
  );
}

Map<String, Object?> _gridToJson(GridDefinition value) => {
      'minorStepMm': value.minorStepMm,
      'majorEvery': value.majorEvery,
    };

GridDefinition _gridFromJson(Map<String, Object?> json) => GridDefinition(
      minorStepMm: _int(json['minorStepMm'], 'grid.minorStepMm'),
      majorEvery: _int(json['majorEvery'], 'grid.majorEvery'),
    );

List<Object?> _polygonToJson(MmPolygon value) =>
    [for (final point in value.vertices) _pointToJson(point)];

MmPolygon _polygonFromJson(List<Object?> json) => MmPolygon([
      for (final item in json) _pointFromJson(_map(item, 'polygon.point')),
    ]);

Map<String, Object?> _pointToJson(MmPoint value) => {'x': value.x, 'y': value.y};

MmPoint _pointFromJson(Map<String, Object?> json) => MmPoint(
      _int(json['x'], 'point.x'),
      _int(json['y'], 'point.y'),
    );

Map<String, Object?> _surfaceToJson(RoomSurfaceRef value) => {
      'spaceId': value.spaceId,
      'type': value.type.name,
      'wallIndex': value.wallIndex,
    };

RoomSurfaceRef _surfaceFromJson(Map<String, Object?> json) {
  final spaceId = _string(json['spaceId'], 'surface.spaceId');
  final type = _enumValue(
    SurfacePlaneType.values,
    _string(json['type'], 'surface.type'),
    'surface.type',
  );
  return switch (type) {
    SurfacePlaneType.floor => RoomSurfaceRef.floor(spaceId),
    SurfacePlaneType.ceiling => RoomSurfaceRef.ceiling(spaceId),
    SurfacePlaneType.wall =>
      RoomSurfaceRef.wall(spaceId, _int(json['wallIndex'], 'surface.wallIndex')),
  };
}

Map<String, Object?> _openingToJson(ArchitecturalOpening value) => {
      'id': value.id,
      'hostWall': _surfaceToJson(value.hostWall),
      'type': value.type.name,
      'offsetFromStartMm': value.offsetFromStartMm,
      'widthMm': value.widthMm,
      'heightMm': value.heightMm,
      'sillHeightMm': value.sillHeightMm,
    };

ArchitecturalOpening _openingFromJson(Map<String, Object?> json) =>
    ArchitecturalOpening(
      id: _string(json['id'], 'opening.id'),
      hostWall: _surfaceFromJson(_map(json['hostWall'], 'opening.hostWall')),
      type: _enumValue(
        ArchitecturalOpeningType.values,
        _string(json['type'], 'opening.type'),
        'opening.type',
      ),
      offsetFromStartMm:
          _int(json['offsetFromStartMm'], 'opening.offsetFromStartMm'),
      widthMm: _int(json['widthMm'], 'opening.widthMm'),
      heightMm: _int(json['heightMm'], 'opening.heightMm'),
      sillHeightMm: _int(json['sillHeightMm'], 'opening.sillHeightMm'),
    );

Map<String, Object?> _p2ToJson(EditorP2State value) => {
      'components': [for (final item in value.components) _componentToJson(item)],
      'routes': [for (final item in value.routes) _routeToJson(item)],
      'selection': {
        'ids': value.selection.ids.toList()..sort(),
        'primaryId': value.selection.primaryId,
      },
      'routeConstraints': {
        for (final entry in value.routeConstraints.entries)
          entry.key: entry.value.toJson(),
      },
    };

EditorP2State _p2FromJson(Map<String, Object?> json) {
  final selection = _map(json['selection'], 'p2.selection');
  final constraints = _map(json['routeConstraints'], 'p2.routeConstraints');
  return EditorP2State(
    components: [
      for (final item in _list(json['components'], 'p2.components'))
        _componentFromJson(_map(item, 'component')),
    ],
    routes: [
      for (final item in _list(json['routes'], 'p2.routes'))
        _routeFromJson(_map(item, 'route')),
    ],
    selection: SelectionState(
      ids: {
        for (final item in _list(selection['ids'], 'selection.ids'))
          _string(item, 'selection.id'),
      },
      primaryId: _nullableString(selection['primaryId']),
    ),
    routeConstraints: Map.unmodifiable({
      for (final entry in constraints.entries)
        entry.key: CableRouteConstraints.fromJson(
          _map(entry.value, 'routeConstraints.${entry.key}'),
        ),
    }),
  );
}

Map<String, Object?> _componentToJson(ElectricalComponentPlacement value) => {
      'id': value.id,
      'type': value.type.name,
      'componentTypeId': value.componentTypeId,
      'surface': _surfaceToJson(value.surface),
      'position': {'xMm': value.position.xMm, 'yMm': value.position.yMm},
      'label': value.label,
      'rotationDegrees': value.rotationDegrees,
      'ratedPowerW': value.ratedPowerW,
      'voltageV': value.voltageV,
      'ports': [
        for (final port in value.ports)
          {'id': port.id, 'kind': port.kind.name},
      ],
    };

ElectricalComponentPlacement _componentFromJson(Map<String, Object?> json) {
  final position = _map(json['position'], 'component.position');
  return ElectricalComponentPlacement(
    id: _string(json['id'], 'component.id'),
    type: _enumValue(
      ElectricalComponentType.values,
      _string(json['type'], 'component.type'),
      'component.type',
    ),
    componentTypeId: _string(json['componentTypeId'], 'component.componentTypeId'),
    surface: _surfaceFromJson(_map(json['surface'], 'component.surface')),
    position: SurfacePointMm(
      _int(position['xMm'], 'component.xMm'),
      _int(position['yMm'], 'component.yMm'),
    ),
    label: _string(json['label'], 'component.label'),
    rotationDegrees: _int(json['rotationDegrees'], 'component.rotationDegrees'),
    ratedPowerW: json['ratedPowerW'] == null
        ? null
        : _int(json['ratedPowerW'], 'component.ratedPowerW'),
    voltageV: _int(json['voltageV'], 'component.voltageV'),
    ports: [
      for (final item in _list(json['ports'], 'component.ports'))
        () {
          final port = _map(item, 'component.port');
          return ElectricalPortDefinition(
            id: _string(port['id'], 'component.port.id'),
            kind: _enumValue(
              ElectricalPortKind.values,
              _string(port['kind'], 'component.port.kind'),
              'component.port.kind',
            ),
          );
        }(),
    ],
  );
}

Map<String, Object?> _routeToJson(ElectricalCableRoute value) => {
      'id': value.id,
      'source': _endpointToJson(value.source),
      'target': _endpointToJson(value.target),
      'segments': [for (final item in value.segments) _segmentToJson(item)],
      'cableType': value.cableType,
      'reservePercent': value.reservePercent,
      'medium': {
        'id': value.medium.id,
        'family': value.medium.family.name,
        'flowVisual': value.medium.flowVisual.name,
        'bidirectional': value.medium.bidirectional,
        'protocol': value.medium.protocol,
      },
    };

ElectricalCableRoute _routeFromJson(Map<String, Object?> json) {
  final medium = _map(json['medium'], 'route.medium');
  return ElectricalCableRoute(
    id: _string(json['id'], 'route.id'),
    source: _endpointFromJson(_map(json['source'], 'route.source')),
    target: _endpointFromJson(_map(json['target'], 'route.target')),
    segments: [
      for (final item in _list(json['segments'], 'route.segments'))
        _segmentFromJson(_map(item, 'route.segment')),
    ],
    cableType: _nullableString(json['cableType']),
    reservePercent: _int(json['reservePercent'], 'route.reservePercent'),
    medium: RouteMediumProfile(
      id: _string(medium['id'], 'route.medium.id'),
      family: _enumValue(
        RouteMediumFamily.values,
        _string(medium['family'], 'route.medium.family'),
        'route.medium.family',
      ),
      flowVisual: _enumValue(
        RouteFlowVisualKind.values,
        _string(medium['flowVisual'], 'route.medium.flowVisual'),
        'route.medium.flowVisual',
      ),
      bidirectional: _bool(medium['bidirectional'], 'route.medium.bidirectional'),
      protocol: _nullableString(medium['protocol']),
    ),
  );
}

Map<String, Object?> _endpointToJson(ElectricalEndpointRef value) => {
      'componentId': value.componentId,
      'portId': value.portId,
    };

ElectricalEndpointRef _endpointFromJson(Map<String, Object?> json) =>
    ElectricalEndpointRef(
      componentId: _string(json['componentId'], 'endpoint.componentId'),
      portId: _string(json['portId'], 'endpoint.portId'),
    );

Map<String, Object?> _segmentToJson(ElectricalRouteSegment value) => {
      'surface': _surfaceToJson(value.surface),
      'points': [
        for (final point in value.points) {'xMm': point.xMm, 'yMm': point.yMm},
      ],
    };

ElectricalRouteSegment _segmentFromJson(Map<String, Object?> json) =>
    ElectricalRouteSegment(
      surface: _surfaceFromJson(_map(json['surface'], 'segment.surface')),
      points: [
        for (final item in _list(json['points'], 'segment.points'))
          () {
            final point = _map(item, 'segment.point');
            return SurfacePointMm(
              _int(point['xMm'], 'segment.xMm'),
              _int(point['yMm'], 'segment.yMm'),
            );
          }(),
      ],
    );

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array.');
  return value.cast<Object?>();
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected nullable non-empty string.');
  }
  return value;
}

int _int(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

double _double(Object? value, String field) {
  if (value is! num) throw FormatException('$field must be numeric.');
  return value.toDouble();
}

bool _bool(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be boolean.');
  return value;
}

T _enumValue<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $field value: $name.');
}
''')

# ---------------------------------------------------------------------------
# Regression tests: save -> close -> open -> continue editing.
# ---------------------------------------------------------------------------
Path('test/editor_project_persistence_test.dart').write_text(r'''import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/site_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save close open restores canonical engineering state and continues edit',
      () async {
    final root = await Directory.systemTemp.createTemp('elecx-project-store-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    workspace.updateProjectNorth(const ProjectNorth(northAzimuthDegrees: 90));

    final space = editor.selectedSpace!;
    editor.showWall(0);
    editor.addOpening(ArchitecturalOpeningType.door);
    final wall = editor.activeSurface!;
    final source = editor.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(500, 1200),
    );
    final target = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(2600, 1200),
    );
    editor.p2.select(source.id);
    editor.p2.select(
      target.id,
      mode: SelectionMode.add,
    );
    expect(editor.p2.autoRouteSelectedPair(), isTrue);
    final route = editor.p2.routes.single;
    final interiorPoint = route.segments.single.points.length > 2
        ? route.segments.single.points[1]
        : route.segments.single.points.first;
    final pointIndex = route.segments.single.points.indexOf(interiorPoint);
    expect(
      editor.p2.toggleRouteWaypoint(
        routeId: route.id,
        segmentIndex: 0,
        pointIndex: pointIndex,
        point: interiorPoint,
      ),
      isTrue,
    );

    final savedSpaceId = space.id;
    final document = EditorProjectDocument.capture(workspace);
    final store = JsonFileEditorProjectStore(root);
    await store.save(document);

    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();

    final loaded = await store.load(document.projectId);
    expect(loaded, isNotNull);
    final restored = loaded!.restore();
    addTearDown(() {
      restored.editor.disposeP2State();
      restored.workspace.dispose();
      restored.editor.dispose();
    });

    expect(
      restored.workspace.site.site.projectNorth.northAzimuthDegrees,
      90,
    );
    expect(restored.editor.selectedSpaceId, savedSpaceId);
    expect(restored.editor.openings, hasLength(1));
    expect(restored.editor.p2.components, hasLength(2));
    expect(restored.editor.p2.routes, hasLength(1));
    expect(
      restored.editor.p2.routeConstraintsFor(route.id).mandatoryWaypoints,
      hasLength(1),
    );

    // Reopen starts a fresh history, but continued edits remain undoable and
    // restored id sequences must never collide with persisted identities.
    final newComponent = restored.editor.p2.placeComponent(
      type: ElectricalComponentType.junctionBox,
      surface: wall,
      position: const SurfacePointMm(1700, 1800),
    );
    expect(newComponent.id, isNot(source.id));
    expect(newComponent.id, isNot(target.id));
    expect(restored.editor.p2.canUndo, isTrue);
    restored.editor.p2.undo();
    expect(
      restored.editor.p2.components.any((item) => item.id == newComponent.id),
      isFalse,
    );
  });

  test('workspace level switch persists edited geometry and openings', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });

    final originalCount = editor.level.spaces.length;
    editor.addRectangleRoom(
      const MmPoint(20000, 0),
      const MmPoint(23000, 3000),
    );
    editor.selectSpace(editor.level.spaces.first.id);
    editor.showWall(0);
    editor.addOpening(ArchitecturalOpeningType.window);
    expect(editor.level.spaces, hasLength(originalCount + 1));
    expect(editor.openings, hasLength(1));

    workspace.selectLevel(2);
    workspace.selectLevel(1);

    expect(editor.level.spaces, hasLength(originalCount + 1));
    expect(editor.openings, hasLength(1));
  });

  test('capture rejects active transform and unfinished route draft', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.p2.cancelMoveSelectedComponent();
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });

    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 0);
    final component = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(500, 500),
    );
    editor.p2.select(component.id);
    expect(editor.p2.beginMoveSelectedComponent(), isTrue);
    expect(
      () => EditorProjectDocument.capture(workspace),
      throwsStateError,
    );
    editor.p2.cancelMoveSelectedComponent();

    editor.showWall(0);
    editor.setTool(EditorTool.cableRoute);
    editor.surfaceTap(const SurfacePointMm(100, 100));
    expect(
      () => EditorProjectDocument.capture(workspace),
      throwsStateError,
    );
  });

  test('unsupported schema is rejected explicitly', () {
    expect(
      () => EditorProjectDocument.fromJson(const {
        'schemaVersion': 99,
      }),
      throwsFormatException,
    );
  });
}
''')

# SelectionMode import belongs to engine; keep the test explicit.
p = Path('test/editor_project_persistence_test.dart')
text = p.read_text()
text = text.replace(
    "import 'package:elecx/src/features/editor/editor_project_document.dart';\n",
    "import 'package:elecx/src/features/editor/editor_project_document.dart';\nimport 'package:elecx/src/engine/selection_engine.dart';\nimport 'package:elecx/src/domain/geometry.dart';\n",
    1,
)
p.write_text(text)
