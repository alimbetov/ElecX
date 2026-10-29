import 'dart:convert';

import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_orientation.dart';
import '../apartment/p9_sha256.dart';

enum BuildingCompositionKind {
  detachedHouse,
  residentialTower,
  multiStoreyResidentialBuilding,
  residentialComplex,
  multiBuildingSite,
}

/// Architectural locations only; these values do not define engineering systems.
enum BuildingServiceAnchorKind {
  electricalEntry,
  telecomEntry,
  fireBackboneEntry,
  intercomCctvEntry,
  generatorArea,
  transformerArea,
  pvInverterArea,
  batteryUpsArea,
  evChargingArea,
  externalLightingFeeder,
}

/// Building-local origin in the site frame. The local +Y orientation reuses the
/// canonical integer-angle convention; it does not set or infer Project North.
final class BuildingSitePlacement {
  BuildingSitePlacement({
    required this.xMm,
    required this.yMm,
    required this.orientation,
  }) {
    _coordinate(xMm, 'xMm');
    _coordinate(yMm, 'yMm');
  }

  final int xMm;
  final int yMm;
  final ProjectEngineeringNorth orientation;

  Map<String, Object?> toCanonicalJson() => {
    'xMm': xMm,
    'yMm': yMm,
    'orientationMilliDegrees': orientation.milliDegreesClockwiseFromPositiveY,
  };
}

/// One stable local generation slot, independent of numbering and display code.
/// Persistent LevelIds are allocated later through MutationIdentityReservation.
final class BuildingLevelParameters {
  BuildingLevelParameters({
    required String generationKey,
    required this.ordinal,
    required this.levelNumber,
    required String code,
    required this.kind,
    required this.floorToFloorHeightMm,
  }) : generationKey = _key(generationKey, 'generationKey'),
       code = _text(code, 'code') {
    if (ordinal < 0 || ordinal > 230) {
      throw RangeError.range(ordinal, 0, 230, 'ordinal');
    }
    if (levelNumber < -30 || levelNumber > 200) {
      throw RangeError.range(levelNumber, -30, 200, 'levelNumber');
    }
    if (kind == ProjectLevelKind.unknown) {
      throw ArgumentError(
        'Generated levels require an explicit physical role.',
      );
    }
    _positiveDimension(floorToFloorHeightMm, 'floorToFloorHeightMm');
  }

  final String generationKey;
  final int ordinal;
  final int levelNumber;
  final String code;
  final ProjectLevelKind kind;
  final int floorToFloorHeightMm;

  Map<String, Object?> toCanonicalJson() => {
    'generationKey': generationKey,
    'ordinal': ordinal,
    'levelNumber': levelNumber,
    'code': code,
    'kind': kind.name,
    'floorToFloorHeightMm': floorToFloorHeightMm,
  };
}

/// Physical order is explicit and never inferred from a display number/code.
/// Elevations are derived from the ground datum and positive storey intervals.
final class LevelStackParameters {
  LevelStackParameters({
    required Iterable<BuildingLevelParameters> levels,
    this.groundElevationMm = 0,
  }) : levels = List.unmodifiable(
         List<BuildingLevelParameters>.of(levels)
           ..sort((a, b) => a.ordinal.compareTo(b.ordinal)),
       ) {
    _coordinate(groundElevationMm, 'groundElevationMm');
    if (this.levels.isEmpty || this.levels.length > 231) {
      throw ArgumentError('A stack must contain between 1 and 231 levels.');
    }
    final keys = <String>{};
    final numbers = <int>{};
    final codes = <String>{};
    for (var index = 0; index < this.levels.length; index++) {
      final level = this.levels[index];
      if (level.ordinal != index ||
          !keys.add(level.generationKey) ||
          !numbers.add(level.levelNumber) ||
          !codes.add(level.code)) {
        throw ArgumentError(
          'Level keys, numbers and codes must be unique within a building; '
          'physical ordinals must be contiguous from zero.',
        );
      }
    }
    final ground = this.levels
        .where((level) => level.kind == ProjectLevelKind.ground)
        .toList();
    if (ground.length != 1) {
      throw ArgumentError(
        'A building stack requires exactly one ground datum.',
      );
    }
    final groundOrdinal = ground.single.ordinal;
    for (final level in this.levels) {
      if ((level.ordinal < groundOrdinal) !=
          (level.kind == ProjectLevelKind.basement)) {
        throw ArgumentError('Only basement levels may lie below ground.');
      }
      if (level.kind == ProjectLevelKind.roof &&
          level.ordinal != this.levels.length - 1) {
        throw ArgumentError('A roof must be the uppermost level.');
      }
    }
    // Validate both ends before generation or identity allocation. Integer
    // millimetres stay well inside the exact native/web arithmetic range.
    var below = groundElevationMm;
    var above = groundElevationMm;
    for (final level in this.levels) {
      if (level.ordinal < groundOrdinal) {
        below -= level.floorToFloorHeightMm;
      } else {
        above += level.floorToFloorHeightMm;
      }
    }
    _coordinate(below, 'lowestElevationMm');
    _coordinate(above, 'topElevationMm');
  }

  final List<BuildingLevelParameters> levels;
  final int groundElevationMm;

  Map<String, Object?> toCanonicalJson() => {
    'groundElevationMm': groundElevationMm,
    'levels': [for (final level in levels) level.toCanonicalJson()],
  };
}

final class TypicalFloorSelection {
  TypicalFloorSelection({
    required String definitionKey,
    required Iterable<String> levelGenerationKeys,
  }) : definitionKey = _key(definitionKey, 'definitionKey'),
       levelGenerationKeys = Set.unmodifiable(
         levelGenerationKeys.map((key) => _key(key, 'levelGenerationKey')),
       ) {
    if (this.levelGenerationKeys.isEmpty) {
      throw ArgumentError('A typical-floor selection must target a level.');
    }
  }

  final String definitionKey;
  final Set<String> levelGenerationKeys;

  Map<String, Object?> toCanonicalJson() => {
    'definitionKey': definitionKey,
    'levelGenerationKeys': levelGenerationKeys.toList()..sort(),
  };
}

final class CommonCoreParameters {
  CommonCoreParameters({
    required this.stairCount,
    required this.liftCount,
    required this.serviceShaftCount,
    required this.corridorWidthMm,
    this.includeTechnicalRoom = false,
  }) {
    for (final value in [stairCount, liftCount, serviceShaftCount]) {
      if (value < 0 || value > 32) {
        throw RangeError.range(value, 0, 32, 'coreCount');
      }
    }
    _positiveDimension(corridorWidthMm, 'corridorWidthMm');
  }

  final int stairCount;
  final int liftCount;
  final int serviceShaftCount;
  final int corridorWidthMm;
  final bool includeTechnicalRoom;

  Map<String, Object?> toCanonicalJson() => {
    'stairCount': stairCount,
    'liftCount': liftCount,
    'serviceShaftCount': serviceShaftCount,
    'corridorWidthMm': corridorWidthMm,
    'includeTechnicalRoom': includeTechnicalRoom,
  };
}

final class ServiceAnchorParameters {
  ServiceAnchorParameters({
    Iterable<BuildingServiceAnchorKind> kinds = const [],
  }) : kinds = Set.unmodifiable(kinds);

  final Set<BuildingServiceAnchorKind> kinds;

  Map<String, Object?> toCanonicalJson() => {
    'kinds': kinds.map((kind) => kind.name).toList()..sort(),
  };
}

final class BuildingTemplateRef {
  BuildingTemplateRef({
    required this.id,
    required this.templateVersion,
    required this.catalogVersion,
  }) {
    if (id.value != id.value.trim() ||
        templateVersion <= 0 ||
        catalogVersion <= 0) {
      throw ArgumentError('Template identity and versions must be canonical.');
    }
  }

  final TemplateId id;
  final int templateVersion;
  final int catalogVersion;

  Map<String, Object?> toCanonicalJson() => {
    'id': id.value,
    'templateVersion': templateVersion,
    'catalogVersion': catalogVersion,
  };
}

/// P10.1 validated immutable request. No canonical project mutation or identity
/// allocation occurs here. Stable JSON escapes user strings before hashing.
final class BuildingGenerationParameters {
  BuildingGenerationParameters({
    required this.kind,
    required this.siteId,
    required String displayName,
    required this.placement,
    required this.levelStack,
    required this.commonCore,
    required this.serviceAnchors,
    this.typicalFloor,
    this.template,
    this.schemaVersion = supportedSchemaVersion,
    String generatorVersion = currentGeneratorVersion,
  }) : displayName = _text(displayName, 'displayName'),
       generatorVersion = _text(generatorVersion, 'generatorVersion') {
    if (schemaVersion != supportedSchemaVersion ||
        this.generatorVersion != currentGeneratorVersion) {
      throw ArgumentError('Unsupported P10 request/generator version.');
    }
    final levelKeys = levelStack.levels
        .map((level) => level.generationKey)
        .toSet();
    if (typicalFloor != null &&
        !levelKeys.containsAll(typicalFloor!.levelGenerationKeys)) {
      throw ArgumentError(
        'Typical floors must reference declared level slots.',
      );
    }
  }

  static const int supportedSchemaVersion = 1;
  static const String currentGeneratorVersion = 'p10.composition.v1';

  final BuildingCompositionKind kind;
  final SiteId siteId;
  final String displayName;
  final BuildingSitePlacement placement;
  final LevelStackParameters levelStack;
  final TypicalFloorSelection? typicalFloor;
  final CommonCoreParameters commonCore;
  final ServiceAnchorParameters serviceAnchors;
  final BuildingTemplateRef? template;
  final int schemaVersion;
  final String generatorVersion;

  Map<String, Object?> toCanonicalJson() => {
    'schemaVersion': schemaVersion,
    'generatorVersion': generatorVersion,
    'kind': kind.name,
    'siteId': siteId.value,
    'displayName': displayName,
    'placement': placement.toCanonicalJson(),
    'levelStack': levelStack.toCanonicalJson(),
    'typicalFloor': typicalFloor?.toCanonicalJson(),
    'commonCore': commonCore.toCanonicalJson(),
    'serviceAnchors': serviceAnchors.toCanonicalJson(),
    'template': template?.toCanonicalJson(),
  };

  String get canonicalSerialization => jsonEncode(toCanonicalJson());
  String get requestFingerprint => p9Sha256Hex(canonicalSerialization);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, field, 'Required.');
  return normalized;
}

String _key(String value, String field) {
  final normalized = _text(value, field);
  if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected a stable semantic key.');
  }
  return normalized;
}

void _coordinate(int value, String field) {
  if (value < -1000000000 || value > 1000000000) {
    throw RangeError.range(value, -1000000000, 1000000000, field);
  }
}

void _positiveDimension(int value, String field) {
  if (value < 1 || value > 1000000) {
    throw RangeError.range(value, 1, 1000000, field);
  }
}
