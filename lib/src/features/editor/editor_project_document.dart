import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/building_composition.dart';
import '../../domain/cable_identity.dart';
import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/route_medium.dart';
import '../../domain/site_orientation.dart';
import '../../domain/site_outdoor_model.dart';
import '../../domain/surfaces.dart';
import '../../domain/wall_profile.dart';
import '../../engine/selection_engine.dart';
import 'cable_route_constraints.dart';
import 'canonical_room_surface_resume.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'circuit_sizing_evidence.dart';
import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'project_persistence_metadata.dart';
import 'project_save_diagnostics.dart';
import 'project_schema_migrator.dart';

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
    this.canonicalSurface,
  });

  final String? selectedSpaceId;
  final String? selectedOpeningId;

  /// Legacy-only resume address. Canonical runtime writes this as null and
  /// persists [canonicalSurface] instead, so wallIndex cannot survive Save.
  final RoomSurfaceRef? activeSurface;
  final CanonicalRoomSurfaceResume? canonicalSurface;
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
    required this.metadata,
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

  static const currentSchemaVersion =
      EditorProjectSchemaMigrator.currentSchemaVersion;

  final int schemaVersion;
  final EditorProjectMetadata metadata;
  String get projectId => metadata.projectId;
  String get projectName => metadata.projectName;
  DateTime get createdAt => metadata.createdAt;
  DateTime get updatedAt => metadata.updatedAt;
  final ComposedBuilding building;
  final ComposedProjectSite site;
  final EditorWorkspaceContext workspaceContext;
  final int activeLevelNumber;
  final String? selectedZoneId;
  final String? activeOutdoorZoneId;
  final Map<int, List<ArchitecturalOpening>> openingsByLevel;
  final EditorProjectResumeState resume;
  final EditorP2State p2State;

  factory EditorProjectDocument.capture(
    EditorBuildingWorkspace workspace, {
    EditorProjectMetadata? metadata,
    DateTime? now,
  }) {
    final editor = workspace.editor;
    // Keep the low-level persistence contract stable for callers that use
    // capture() directly. User-facing structured diagnostics run in the
    // editor preflight before capture.
    if (editor.p2.isManipulating) {
      throw StateError('Cannot save while a component transform is active.');
    }
    if (editor.routeSegments.isNotEmpty || editor.draftStart != null) {
      throw StateError('Cannot save an unfinished editor draft.');
    }
    final blockingIssue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (blockingIssue != null) {
      throw EditorProjectSaveBlockedException(blockingIssue);
    }
    workspace.synchronizeActiveEditorState();
    final projectMetadata = metadata ??
        EditorProjectMetadata.create(
          projectName: workspace.site.site.name,
          projectId: workspace.site.site.id,
          now: now,
        );
    final canonicalRuntime =
        CanonicalRoomSurfaceRuntimeRegistry.hasCanonicalRuntime(editor);
    final canonicalSurface = canonicalRuntime
        ? CanonicalRoomSurfaceRuntimeRegistry.capture(editor)
        : null;

    return EditorProjectDocument(
      schemaVersion: currentSchemaVersion,
      metadata: projectMetadata,
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
        // Once canonical runtime owns the workspace we never serialize a wall
        // ordinal. If stable resolution is blocked, Save resumes at Plan.
        activeSurface: canonicalRuntime ? null : editor.activeSurface,
        canonicalSurface: canonicalSurface,
        viewMode: canonicalRuntime ? EditorViewMode.plan : editor.viewMode,
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
    final stableResume = resume.canonicalSurface;
    editor.restoreResumeState(
      selectedSpaceId: resume.selectedSpaceId,
      selectedOpeningId: resume.selectedOpeningId,
      activeSurface: stableResume == null ? resume.activeSurface : null,
      viewMode: stableResume == null ? resume.viewMode : EditorViewMode.plan,
      snapEnabled: resume.snapEnabled,
      dimensionsVisible: resume.dimensionsVisible,
      floorGridMm: resume.floorGridMm,
      zoom: resume.zoom,
      roomSequence: resume.roomSequence,
      openingSequence: resume.openingSequence,
    );
    if (stableResume != null) {
      CanonicalRoomSurfaceRuntimeRegistry.stageResume(editor, stableResume);
    }
    editor.restoreP2State(p2State);
    return RestoredEditorProject(editor: editor, workspace: workspace);
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'metadata': {
          'projectId': metadata.projectId,
          'projectName': metadata.projectName,
          'createdAt': metadata.createdAt.toUtc().toIso8601String(),
          'updatedAt': metadata.updatedAt.toUtc().toIso8601String(),
        },
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

  factory EditorProjectDocument.fromJson(
    Map<String, Object?> json, {
    DateTime? legacyTimestamp,
  }) {
    final migrated = EditorProjectSchemaMigrator.migrate(
      json,
      legacyTimestamp: legacyTimestamp,
    );
    final version = _int(migrated['schemaVersion'], 'schemaVersion');
    final metadataJson = _map(migrated['metadata'], 'metadata');
    final workspace = _map(migrated['workspace'], 'workspace');
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
    final createdAt = DateTime.parse(
      _string(metadataJson['createdAt'], 'metadata.createdAt'),
    ).toUtc();
    final updatedAt = DateTime.parse(
      _string(metadataJson['updatedAt'], 'metadata.updatedAt'),
    ).toUtc();
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('metadata.updatedAt precedes createdAt.');
    }
    return EditorProjectDocument(
      schemaVersion: version,
      metadata: EditorProjectMetadata(
        projectId: _string(metadataJson['projectId'], 'metadata.projectId'),
        projectName: _string(
          metadataJson['projectName'],
          'metadata.projectName',
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      building: _buildingFromJson(_map(migrated['building'], 'building')),
      site: _siteFromJson(_map(migrated['site'], 'site')),
      workspaceContext: _enumValue(
        EditorWorkspaceContext.values,
        _string(workspace['context'], 'workspace.context'),
        'workspace.context',
      ),
      activeLevelNumber: _int(
        workspace['activeLevelNumber'],
        'workspace.activeLevelNumber',
      ),
      selectedZoneId: _nullableString(workspace['selectedZoneId']),
      activeOutdoorZoneId: _nullableString(workspace['activeOutdoorZoneId']),
      openingsByLevel: Map.unmodifiable(openings),
      resume: _resumeFromJson(_map(workspace['resume'], 'workspace.resume')),
      p2State: _p2FromJson(_map(migrated['p2'], 'p2')),
    );
  }
}

abstract interface class EditorProjectStore {
  Future<void> save(EditorProjectDocument document);
  Future<EditorProjectDocument?> load(String projectId);
  Future<List<EditorProjectDocument>> list();
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
    final stat = await source.stat();
    final document = EditorProjectDocument.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
      legacyTimestamp: stat.modified.toUtc(),
    );
    if (document.projectId != projectId) {
      throw FormatException(
        'Persisted project id does not match requested id.',
      );
    }
    return document;
  }

  @override
  Future<List<EditorProjectDocument>> list() async {
    if (!await rootDirectory.exists()) return const [];
    final sourcesByBasePath = <String, File>{};
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final isPrimary = entity.path.endsWith('.elecx.json');
      final isBackup = entity.path.endsWith('.elecx.json.bak');
      if (!isPrimary && !isBackup) continue;
      final basePath = isBackup
          ? entity.path.substring(0, entity.path.length - '.bak'.length)
          : entity.path;
      if (isPrimary) {
        sourcesByBasePath[basePath] = entity;
      } else {
        sourcesByBasePath.putIfAbsent(basePath, () => entity);
      }
    }

    final result = <EditorProjectDocument>[];
    for (final source in sourcesByBasePath.values) {
      try {
        final raw = jsonDecode(await source.readAsString());
        if (raw is! Map) continue;
        final stat = await source.stat();
        result.add(
          EditorProjectDocument.fromJson(
            raw.map((key, value) => MapEntry(key.toString(), value)),
            legacyTimestamp: stat.modified.toUtc(),
          ),
        );
      } on FormatException {
        // One damaged project must not hide every healthy project in the Hub.
        continue;
      } on FileSystemException {
        // A file can disappear between directory enumeration and read.
        continue;
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<EditorProjectDocument>.unmodifiable(result);
  }

  File _target(String projectId) {
    final encoded =
        base64Url.encode(utf8.encode(projectId)).replaceAll('=', '');
    return File(path.join(rootDirectory.path, '$encoded.elecx.json'));
  }
}

Map<String, Object?> _resumeToJson(EditorProjectResumeState value) => {
      'selectedSpaceId': value.selectedSpaceId,
      'selectedOpeningId': value.selectedOpeningId,
      'activeSurface': value.activeSurface == null
          ? null
          : _surfaceToJson(value.activeSurface!),
      'canonicalSurface': value.canonicalSurface?.toJson(),
      'viewMode': value.viewMode.name,
      'snapEnabled': value.snapEnabled,
      'dimensionsVisible': value.dimensionsVisible,
      'floorGridMm': value.floorGridMm,
      'zoom': value.zoom,
      'roomSequence': value.roomSequence,
      'openingSequence': value.openingSequence,
    };

EditorProjectResumeState _resumeFromJson(Map<String, Object?> json) {
  final canonicalRaw = json['canonicalSurface'];
  return EditorProjectResumeState(
    selectedSpaceId: _nullableString(json['selectedSpaceId']),
    selectedOpeningId: _nullableString(json['selectedOpeningId']),
    activeSurface: json['activeSurface'] == null
        ? null
        : _surfaceFromJson(_map(json['activeSurface'], 'activeSurface')),
    canonicalSurface: canonicalRaw == null
        ? null
        : CanonicalRoomSurfaceResume.fromJson(
            _map(canonicalRaw, 'canonicalSurface'),
          ),
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
}

Map<String, Object?> _buildingToJson(ComposedBuilding value) => {
      'building': _plainBuildingToJson(value.building),
      'levels': [for (final item in value.levels) _composedLevelToJson(item)],
      'verticalCores': [
        for (final item in value.verticalCores) _verticalCoreToJson(item),
      ],
    };

ComposedBuilding _buildingFromJson(
  Map<String, Object?> json,
) =>
    ComposedBuilding(
      building:
          _plainBuildingFromJson(_map(json['building'], 'building.building')),
      levels: [
        for (final item in _list(json['levels'], 'building.levels'))
          _composedLevelFromJson(_map(item, 'building.level')),
      ],
      verticalCores: [
        for (final item
            in _list(json['verticalCores'], 'building.verticalCores'))
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
      floorToFloorHeightMm: _int(
        json['floorToFloorHeightMm'],
        'floorToFloorHeightMm',
      ),
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
      for (final item in _list(
        json['servedLevelNumbers'],
        'servedLevelNumbers',
      ))
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
      'outdoorZones': [
        for (final zone in value.outdoorZones) _outdoorToJson(zone)
      ],
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
      'buildings': [
        for (final item in value.buildings) _plainBuildingToJson(item)
      ],
      'projectNorthDegrees': value.projectNorth.northAzimuthDegrees,
      'solarContext': value.solarContext == null
          ? null
          : {
              'latitudeDegrees': value.solarContext!.latitudeDegrees,
              'longitudeDegrees': value.solarContext!.longitudeDegrees,
              'timeZoneOffsetMinutes':
                  value.solarContext!.timeZoneOffsetMinutes,
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
      northAzimuthDegrees: _double(
        json['projectNorthDegrees'],
        'site.projectNorthDegrees',
      ),
    ),
    solarContext: solarRaw == null
        ? null
        : () {
            final solar = _map(solarRaw, 'site.solarContext');
            return SolarSiteContext(
              latitudeDegrees: _double(
                solar['latitudeDegrees'],
                'solar.latitudeDegrees',
              ),
              longitudeDegrees: _double(
                solar['longitudeDegrees'],
                'solar.longitudeDegrees',
              ),
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

SiteBuildingConnection _siteConnectionFromJson(
  Map<String, Object?> json,
) =>
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
      sitePoint:
          _pointFromJson(_map(json['sitePoint'], 'connection.sitePoint')),
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
      rotationRadians: _double(
        frame['rotationRadians'],
        'referenceFrame.rotationRadians',
      ),
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

List<Object?> _polygonToJson(MmPolygon value) => [
      for (final point in value.vertices) _pointToJson(point),
    ];

MmPolygon _polygonFromJson(List<Object?> json) => MmPolygon([
      for (final item in json) _pointFromJson(_map(item, 'polygon.point')),
    ]);

Map<String, Object?> _pointToJson(MmPoint value) => {
      'x': value.x,
      'y': value.y,
    };

MmPoint _pointFromJson(Map<String, Object?> json) =>
    MmPoint(_int(json['x'], 'point.x'), _int(json['y'], 'point.y'));

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
    SurfacePlaneType.wall => RoomSurfaceRef.wall(
        spaceId,
        _int(json['wallIndex'], 'surface.wallIndex'),
      ),
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
      offsetFromStartMm: _int(
        json['offsetFromStartMm'],
        'opening.offsetFromStartMm',
      ),
      widthMm: _int(json['widthMm'], 'opening.widthMm'),
      heightMm: _int(json['heightMm'], 'opening.heightMm'),
      sillHeightMm: _int(json['sillHeightMm'], 'opening.sillHeightMm'),
    );

Map<String, Object?> _p2ToJson(EditorP2State value) => {
      'components': [
        for (final item in value.components) _componentToJson(item)
      ],
      'routes': [for (final item in value.routes) _routeToJson(item)],
      'selection': {
        'ids': value.selection.ids.toList()..sort(),
        'primaryId': value.selection.primaryId,
      },
      'routeConstraints': {
        for (final entry in value.routeConstraints.entries)
          entry.key: entry.value.toJson(),
      },
      'circuitBundles': [
        for (final bundle in value.circuitBundles) _circuitBundleToJson(bundle),
      ],
      'sizingEvidenceByRoute': {
        for (final entry in value.sizingEvidenceByRoute.entries)
          entry.key: entry.value.toJson(),
      },
    };

EditorP2State _p2FromJson(Map<String, Object?> json) {
  final selection = _map(json['selection'], 'p2.selection');
  final constraints = _map(json['routeConstraints'], 'p2.routeConstraints');
  final sizingEvidence = _map(
    json['sizingEvidenceByRoute'],
    'p2.sizingEvidenceByRoute',
  );
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
    circuitBundles: [
      for (final item in _list(json['circuitBundles'], 'p2.circuitBundles'))
        _circuitBundleFromJson(_map(item, 'circuitBundle')),
    ],
    sizingEvidenceByRoute: Map.unmodifiable({
      for (final entry in sizingEvidence.entries)
        entry.key: CircuitSizingEvidence.fromJson(
          _map(entry.value, 'sizingEvidence.${entry.key}'),
        ),
    }),
  );
}

Map<String, Object?> _circuitBundleToJson(CircuitCableBundle value) => {
      'circuit': {
        'id': value.circuit.id,
        'name': value.circuit.name,
        'boardId': value.circuit.boardId,
        'protectiveDeviceId': value.circuit.protectiveDeviceId,
      },
      'cable': {
        'id': value.cable.id,
        'routeId': value.cable.routeId,
        'circuitId': value.cable.circuitId,
        'designation': value.cable.designation,
        'cableSpecId': value.cable.cableSpecId,
        'endA': _terminationToJson(value.cable.endA),
        'endB': _terminationToJson(value.cable.endB),
      },
      'protectiveDevice': value.protectiveDevice == null
          ? null
          : {
              'id': value.protectiveDevice!.id,
              'boardId': value.protectiveDevice!.boardId,
              'designation': value.protectiveDevice!.designation,
              'poleCount': value.protectiveDevice!.poleCount,
              'ratedCurrentA': value.protectiveDevice!.ratedCurrentA,
            },
    };

CircuitCableBundle _circuitBundleFromJson(Map<String, Object?> json) {
  final circuitJson = _map(json['circuit'], 'circuitBundle.circuit');
  final cableJson = _map(json['cable'], 'circuitBundle.cable');
  final deviceRaw = json['protectiveDevice'];
  final circuit = CircuitRef(
    id: _string(circuitJson['id'], 'circuit.id'),
    name: _string(circuitJson['name'], 'circuit.name'),
    boardId: _nullableString(circuitJson['boardId']),
    protectiveDeviceId: _nullableString(circuitJson['protectiveDeviceId']),
  );
  final cable = CableIdentity(
    id: _string(cableJson['id'], 'cable.id'),
    routeId: _string(cableJson['routeId'], 'cable.routeId'),
    circuitId: _string(cableJson['circuitId'], 'cable.circuitId'),
    designation: _string(cableJson['designation'], 'cable.designation'),
    cableSpecId: _nullableString(cableJson['cableSpecId']),
    endA: _terminationFromJson(_map(cableJson['endA'], 'cable.endA')),
    endB: _terminationFromJson(_map(cableJson['endB'], 'cable.endB')),
  );
  final protectiveDevice = deviceRaw == null
      ? null
      : () {
          final device = _map(deviceRaw, 'circuitBundle.protectiveDevice');
          return ProtectiveDeviceRef(
            id: _string(device['id'], 'protectiveDevice.id'),
            boardId: _string(device['boardId'], 'protectiveDevice.boardId'),
            designation: _string(
              device['designation'],
              'protectiveDevice.designation',
            ),
            poleCount: device['poleCount'] == null
                ? null
                : _int(device['poleCount'], 'protectiveDevice.poleCount'),
            ratedCurrentA: device['ratedCurrentA'] == null
                ? null
                : _double(
                    device['ratedCurrentA'],
                    'protectiveDevice.ratedCurrentA',
                  ),
          );
        }();
  return CircuitCableBundle(
    circuit: circuit,
    cable: cable,
    protectiveDevice: protectiveDevice,
  );
}

Map<String, Object?> _terminationToJson(CableTerminationRef value) => {
      'componentId': value.componentId,
      'portId': value.portId,
      'terminalId': value.terminalId,
    };

CableTerminationRef _terminationFromJson(Map<String, Object?> json) =>
    CableTerminationRef(
      componentId: _string(json['componentId'], 'termination.componentId'),
      portId: _string(json['portId'], 'termination.portId'),
      terminalId: _nullableString(json['terminalId']),
    );

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
        for (final port in value.ports) {'id': port.id, 'kind': port.kind.name},
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
    componentTypeId: _string(
      json['componentTypeId'],
      'component.componentTypeId',
    ),
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
  final routeId = _string(json['id'], 'route.id');
  final segments = [
    for (final item in _list(json['segments'], 'route.segments'))
      _segmentFromJson(_map(item, 'route.segment')),
  ];
  _validatePersistedRouteAnchorIds(routeId, segments);
  return ElectricalCableRoute(
    id: routeId,
    source: _endpointFromJson(_map(json['source'], 'route.source')),
    target: _endpointFromJson(_map(json['target'], 'route.target')),
    segments: segments,
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
      bidirectional: _bool(
        medium['bidirectional'],
        'route.medium.bidirectional',
      ),
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
      'anchorIds': [for (final anchorId in value.anchorIds) anchorId.value],
    };

ElectricalRouteSegment _segmentFromJson(Map<String, Object?> json) {
  final points = [
    for (final item in _list(json['points'], 'segment.points'))
      () {
        final point = _map(item, 'segment.point');
        return SurfacePointMm(
          _int(point['xMm'], 'segment.xMm'),
          _int(point['yMm'], 'segment.yMm'),
        );
      }(),
  ];
  final anchorIds = [
    for (final item in _list(json['anchorIds'], 'segment.anchorIds'))
      RouteAnchorId(_string(item, 'segment.anchorId')),
  ];
  if (anchorIds.isNotEmpty && anchorIds.length != points.length) {
    throw FormatException(
      'segment.anchorIds must be empty for a legacy segment or match the '
      'segment.points length exactly.',
    );
  }
  return ElectricalRouteSegment(
    surface: _surfaceFromJson(_map(json['surface'], 'segment.surface')),
    points: points,
    anchorIds: anchorIds,
  );
}

void _validatePersistedRouteAnchorIds(
  String routeId,
  List<ElectricalRouteSegment> segments,
) {
  final seen = <String>{};
  for (final segment in segments) {
    for (final anchorId in segment.anchorIds) {
      if (anchorId.value.startsWith('p7a-transition:')) {
        throw FormatException(
          'Route $routeId persists projection-only anchor ${anchorId.value}.',
        );
      }
      if (!seen.add(anchorId.value)) {
        throw FormatException(
          'Route $routeId contains duplicate durable anchor id '
          '${anchorId.value}.',
        );
      }
    }
  }
}

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