import 'project_model.dart';

enum BuildingLevelKind {
  basement,
  ground,
  residential,
  technical,
  roof,
}

enum BuildingZoneKind {
  apartment,
  common,
  technical,
  parking,
  storage,
  utility,
}

/// Logical grouping of physical spaces on one level.
///
/// A zone never owns geometry itself. Geometry stays in [EngineeringSpace],
/// while the zone provides the semantic grouping needed for apartments,
/// common areas, parking, service rooms and technical areas.
final class BuildingZone {
  BuildingZone({
    required this.id,
    required this.name,
    required this.kind,
    required Iterable<String> spaceIds,
    this.apartmentNumber,
  }) : spaceIds = Set.unmodifiable(spaceIds) {
    if (id.isEmpty) throw ArgumentError('Zone id must be non-empty.');
    if (name.isEmpty) throw ArgumentError('Zone name must be non-empty.');
    if (this.spaceIds.isEmpty) {
      throw ArgumentError('A building zone must contain at least one space.');
    }
    if (kind == BuildingZoneKind.apartment &&
        (apartmentNumber == null || apartmentNumber!.isEmpty)) {
      throw ArgumentError('Apartment zone requires apartmentNumber.');
    }
    if (kind != BuildingZoneKind.apartment && apartmentNumber != null) {
      throw ArgumentError('Only apartment zones may have apartmentNumber.');
    }
  }

  final String id;
  final String name;
  final BuildingZoneKind kind;
  final Set<String> spaceIds;
  final String? apartmentNumber;
}

/// Building level with signed storey number and semantic zones.
///
/// Level numbering is independent from elevation. That lets the model support
/// B30..B1, ground/0 and residential floors 1..16 without encoding naming rules
/// into geometry or electrical calculations.
final class ComposedBuildingLevel {
  ComposedBuildingLevel({
    required this.level,
    required this.levelNumber,
    required this.kind,
    this.floorToFloorHeightMm = 3000,
    this.zones = const [],
  }) {
    if (levelNumber < -30 || levelNumber > 200) {
      throw RangeError.range(levelNumber, -30, 200, 'levelNumber');
    }
    if (floorToFloorHeightMm <= 0) {
      throw ArgumentError.value(
        floorToFloorHeightMm,
        'floorToFloorHeightMm',
        'Must be positive.',
      );
    }
    _validateZoneReferences();
  }

  final BuildingLevel level;
  final int levelNumber;
  final BuildingLevelKind kind;
  final int floorToFloorHeightMm;
  final List<BuildingZone> zones;

  String get displayName {
    if (levelNumber < 0) return 'B${levelNumber.abs()}';
    if (levelNumber == 0) return '0';
    return '$levelNumber';
  }

  Iterable<BuildingZone> get apartments =>
      zones.where((zone) => zone.kind == BuildingZoneKind.apartment);

  BuildingZone? zoneForSpace(String spaceId) {
    for (final zone in zones) {
      if (zone.spaceIds.contains(spaceId)) return zone;
    }
    return null;
  }

  void _validateZoneReferences() {
    final validSpaceIds = level.spaces.map((space) => space.id).toSet();
    final claimed = <String>{};
    for (final zone in zones) {
      for (final id in zone.spaceIds) {
        if (!validSpaceIds.contains(id)) {
          throw ArgumentError(
            'Zone ${zone.id} references unknown space $id on level ${level.id}.',
          );
        }
        if (!claimed.add(id)) {
          throw ArgumentError(
            'Space $id belongs to more than one zone on level ${level.id}.',
          );
        }
      }
    }
  }
}

/// Vertical element crossing one or more levels.
///
/// Used for stairs, lift shafts, electrical risers, plumbing/service shafts and
/// cable risers. Surface routing can later connect level-local routes through
/// these stable vertical topology objects.
enum VerticalCoreKind {
  stair,
  elevator,
  electricalRiser,
  serviceShaft,
  cableRiser,
}

final class VerticalCore {
  VerticalCore({
    required this.id,
    required this.name,
    required this.kind,
    required Iterable<int> servedLevelNumbers,
    this.spaceIdByLevel = const {},
  }) : servedLevelNumbers = Set.unmodifiable(servedLevelNumbers) {
    if (id.isEmpty) throw ArgumentError('Vertical core id must be non-empty.');
    if (this.servedLevelNumbers.isEmpty) {
      throw ArgumentError('Vertical core must serve at least one level.');
    }
    for (final level in this.servedLevelNumbers) {
      if (level < -30 || level > 200) {
        throw RangeError.range(level, -30, 200, 'servedLevelNumbers');
      }
    }
    for (final level in spaceIdByLevel.keys) {
      if (!this.servedLevelNumbers.contains(level)) {
        throw ArgumentError(
          'spaceIdByLevel contains unserved level $level for core $id.',
        );
      }
    }
  }

  final String id;
  final String name;
  final VerticalCoreKind kind;
  final Set<int> servedLevelNumbers;
  final Map<int, String> spaceIdByLevel;
}

/// Full semantic model of one building above the geometric [Building].
final class ComposedBuilding {
  ComposedBuilding({
    required this.building,
    required this.levels,
    this.verticalCores = const [],
  }) {
    if (levels.isEmpty) throw ArgumentError('Building must contain levels.');
    final numbers = <int>{};
    final ids = <String>{};
    for (final item in levels) {
      if (!numbers.add(item.levelNumber)) {
        throw ArgumentError('Duplicate level number ${item.levelNumber}.');
      }
      if (!ids.add(item.level.id)) {
        throw ArgumentError('Duplicate level id ${item.level.id}.');
      }
    }
    final buildingLevelIds = building.levels.map((level) => level.id).toSet();
    if (!ids.every(buildingLevelIds.contains)) {
      throw ArgumentError(
        'Every composed level must reference a level from the building.',
      );
    }
  }

  final Building building;
  final List<ComposedBuildingLevel> levels;
  final List<VerticalCore> verticalCores;

  List<ComposedBuildingLevel> get orderedLevels {
    final result = [...levels]
      ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
    return result;
  }

  ComposedBuildingLevel? levelByNumber(int number) {
    for (final level in levels) {
      if (level.levelNumber == number) return level;
    }
    return null;
  }
}

/// Creates repeated storeys while preserving stable per-level identities.
///
/// A typical floor is copied as data, not referenced by pointer. This makes it
/// possible to edit one apartment or room on one floor without silently
/// mutating all repeated storeys.
abstract final class BuildingLevelRepeater {
  static List<ComposedBuildingLevel> repeat({
    required ComposedBuildingLevel source,
    required int fromLevel,
    required int toLevel,
    required int baseElevationMm,
    required int floorToFloorHeightMm,
  }) {
    if (fromLevel > toLevel) {
      throw ArgumentError('fromLevel must be <= toLevel.');
    }
    if (floorToFloorHeightMm <= 0) {
      throw ArgumentError('floorToFloorHeightMm must be positive.');
    }

    return [
      for (var number = fromLevel; number <= toLevel; number++)
        _cloneLevel(
          source,
          levelNumber: number,
          elevationMm:
              baseElevationMm + (number - fromLevel) * floorToFloorHeightMm,
          floorToFloorHeightMm: floorToFloorHeightMm,
        ),
    ];
  }

  static ComposedBuildingLevel _cloneLevel(
    ComposedBuildingLevel source, {
    required int levelNumber,
    required int elevationMm,
    required int floorToFloorHeightMm,
  }) {
    final prefix = 'L$levelNumber';
    final idMap = <String, String>{};
    final spaces = [
      for (final space in source.level.spaces)
        () {
          final id = '$prefix:${space.id}';
          idMap[space.id] = id;
          return EngineeringSpace(
            id: id,
            name: space.name,
            type: space.type,
            boundary: space.boundary,
            referenceFrame: space.referenceFrame,
            grid: space.grid,
            wallProfiles: space.wallProfiles,
          );
        }(),
    ];

    final level = BuildingLevel(
      id: '$prefix:${source.level.id}',
      name: levelNumber < 0 ? 'Подвал ${levelNumber.abs()}' : 'Этаж $levelNumber',
      elevationMm: elevationMm,
      spaces: spaces,
    );

    final zones = [
      for (final zone in source.zones)
        BuildingZone(
          id: '$prefix:${zone.id}',
          name: zone.name,
          kind: zone.kind,
          apartmentNumber: zone.apartmentNumber == null
              ? null
              : '$levelNumber-${zone.apartmentNumber}',
          spaceIds: zone.spaceIds.map((id) => idMap[id]!),
        ),
    ];

    return ComposedBuildingLevel(
      level: level,
      levelNumber: levelNumber,
      kind: levelNumber < 0 ? BuildingLevelKind.basement : source.kind,
      floorToFloorHeightMm: floorToFloorHeightMm,
      zones: zones,
    );
  }
}
