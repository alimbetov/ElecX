import 'dart:convert';

import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../project_mutation_reservation.dart';
import 'building_generation_parameters.dart';

final class BuildingLevelDraft {
  const BuildingLevelDraft._({
    required this.parameters,
    required this.elevationMm,
    required this.reservationSlot,
  });

  final BuildingLevelParameters parameters;
  final int elevationMm;
  final String reservationSlot;
}

/// A transient plan, not a second authoritative building/level store.
final class BuildingLevelStackDraft {
  BuildingLevelStackDraft._({
    required this.buildingGenerationKey,
    required Iterable<BuildingLevelDraft> levels,
  }) : levels = List.unmodifiable(levels);

  final String buildingGenerationKey;
  final List<BuildingLevelDraft> levels;

  Map<String, ReservedEntityIdKind> get reservationSlots => Map.unmodifiable({
        for (final level in levels)
          level.reservationSlot: ReservedEntityIdKind.level,
      });

  String get semanticFingerprint => semanticSha256Hex(
        jsonEncode({
          'schema': 'p10.level-stack.v1',
          'buildingGenerationKey': buildingGenerationKey,
          'levels': [
            for (final level in levels)
              {
                ...level.parameters.toCanonicalJson(),
                'elevationMm': level.elevationMm,
              },
          ],
        }),
      );

  /// Maps one existing immutable reservation into ordinary canonical entities.
  /// Preview revalidation/apply reuse the same reservation. This method neither
  /// allocates IDs nor writes project state; P10.11 owns atomic commit/Undo.
  BuildingLevelMaterialization materialize({
    required BuildingId buildingId,
    required MutationIdentityReservation reservation,
  }) {
    final ids = <String, LevelId>{};
    final allocated = <LevelId>{};
    final entities = <ProjectLevelEntity>[];
    for (final draft in levels) {
      final level = draft.parameters;
      final id = reservation.entityId<LevelId>(draft.reservationSlot);
      if (!allocated.add(id)) {
        throw StateError('Distinct level slots must own independent LevelIds.');
      }
      ids[level.generationKey] = id;
      entities.add(
        ProjectLevelEntity(
          id: id,
          buildingId: buildingId,
          name: level.code,
          levelNumber: level.levelNumber,
          displayOrder: level.ordinal,
          elevationMm: draft.elevationMm,
          kind: level.kind,
          floorToFloorHeightMm: level.floorToFloorHeightMm,
        ),
      );
    }
    return BuildingLevelMaterialization._(ids: ids, levels: entities);
  }
}

final class BuildingLevelMaterialization {
  BuildingLevelMaterialization._({
    required Map<String, LevelId> ids,
    required Iterable<ProjectLevelEntity> levels,
  })  : idsByGenerationKey = Map.unmodifiable(ids),
        levels = List.unmodifiable(levels);

  final Map<String, LevelId> idsByGenerationKey;
  final List<ProjectLevelEntity> levels;
}

/// Pure P10.3 generation using millimetres and explicit physical ordinals.
final class BuildingLevelStackGenerator {
  const BuildingLevelStackGenerator();

  BuildingLevelStackDraft generate({
    required String buildingGenerationKey,
    required LevelStackParameters parameters,
  }) {
    final scope = buildingGenerationKey.trim();
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(scope)) {
      throw ArgumentError('A stable building generation key is required.');
    }
    final levels = parameters.levels;
    final ground = levels.indexWhere(
      (level) => level.kind == ProjectLevelKind.ground,
    );
    final elevations = List<int>.filled(levels.length, 0);
    elevations[ground] = parameters.groundElevationMm;
    for (var index = ground - 1; index >= 0; index--) {
      elevations[index] =
          elevations[index + 1] - levels[index].floorToFloorHeightMm;
    }
    for (var index = ground + 1; index < levels.length; index++) {
      elevations[index] =
          elevations[index - 1] + levels[index - 1].floorToFloorHeightMm;
    }
    return BuildingLevelStackDraft._(
      buildingGenerationKey: scope,
      levels: [
        for (var index = 0; index < levels.length; index++)
          BuildingLevelDraft._(
            parameters: levels[index],
            elevationMm: elevations[index],
            // Escaped semantic path, never a persistent entity identity.
            reservationSlot: jsonEncode([
              'p10.building',
              scope,
              'level',
              levels[index].generationKey,
            ]),
          ),
      ],
    );
  }

  /// Explicit count-based authoring convenience. Codes/numbers are presentation
  /// metadata; the role/slot keys and physical sequence drive generation.
  LevelStackParameters residentialParameters({
    int basementLevels = 0,
    int upperResidentialLevels = 0,
    int technicalLevels = 0,
    bool includeRoof = true,
    int groundElevationMm = 0,
    int basementHeightMm = 3000,
    int groundHeightMm = 3000,
    int residentialHeightMm = 3000,
    int technicalHeightMm = 3000,
    int roofHeightMm = 3000,
  }) {
    if (basementLevels < 0 ||
        basementLevels > 30 ||
        upperResidentialLevels < 0 ||
        technicalLevels < 0 ||
        upperResidentialLevels > 200 ||
        technicalLevels > 200 ||
        upperResidentialLevels + technicalLevels + (includeRoof ? 1 : 0) >
            200) {
      throw ArgumentError('Level counts exceed canonical level-number bounds.');
    }
    for (final height in [
      basementHeightMm,
      groundHeightMm,
      residentialHeightMm,
      technicalHeightMm,
      roofHeightMm,
    ]) {
      if (height < 1 || height > 1000000) {
        throw ArgumentError(
          'Storey heights must be supported positive mm values.',
        );
      }
    }
    final levels = <BuildingLevelParameters>[];
    void add(
      String key,
      int number,
      String code,
      ProjectLevelKind kind,
      int height,
    ) {
      levels.add(
        BuildingLevelParameters(
          generationKey: key,
          ordinal: levels.length,
          levelNumber: number,
          code: code,
          kind: kind,
          floorToFloorHeightMm: height,
        ),
      );
    }

    for (var depth = basementLevels; depth >= 1; depth--) {
      add(
        'basement.$depth',
        -depth,
        'B$depth',
        ProjectLevelKind.basement,
        basementHeightMm,
      );
    }
    add('ground', 0, 'G', ProjectLevelKind.ground, groundHeightMm);
    for (var floor = 1; floor <= upperResidentialLevels; floor++) {
      add(
        'residential.$floor',
        floor,
        floor.toString().padLeft(2, '0'),
        ProjectLevelKind.residential,
        residentialHeightMm,
      );
    }
    for (var floor = 1; floor <= technicalLevels; floor++) {
      add(
        'technical.$floor',
        upperResidentialLevels + floor,
        'T$floor',
        ProjectLevelKind.technical,
        technicalHeightMm,
      );
    }
    if (includeRoof) {
      add(
        'roof',
        upperResidentialLevels + technicalLevels + 1,
        'RF',
        ProjectLevelKind.roof,
        roofHeightMm,
      );
    }
    return LevelStackParameters(
      levels: levels,
      groundElevationMm: groundElevationMm,
    );
  }
}
