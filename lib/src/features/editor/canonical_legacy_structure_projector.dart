import '../../domain/building_composition.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_legacy_identity_codec.dart';
import 'editor_project_document.dart';

/// Transitional deterministic materialization of the canonical Building/Level
/// hierarchy into the legacy single-building editor document.
///
/// Canonical state remains authoritative. Existing legacy spaces, zones,
/// openings and editor state are preserved by stable Level binding; newly
/// created canonical Levels receive empty legacy shells whose ids encode the
/// exact canonical LevelId for restart-safe bootstrap.
final class CanonicalLegacyStructureProjector {
  const CanonicalLegacyStructureProjector();

  bool requiresProjection({
    required EditorProjectDocument legacy,
    required ProjectAggregateRoot canonical,
    required CanonicalEditorWorkspaceBinding binding,
  }) {
    final canonicalBuilding = canonical.stores.buildings[binding.buildingId];
    if (canonicalBuilding == null) {
      throw StateError(
        'Canonical Building ${binding.buildingId} is missing from the project.',
      );
    }
    final legacyBuilding = legacy.building.building;
    if (legacyBuilding.id != binding.legacyBuildingId) {
      throw StateError('Legacy document is bound to a different Building.');
    }
    if (legacyBuilding.name != canonicalBuilding.name) return true;
    if (canonicalBuilding.levelIds.length != legacyBuilding.levels.length) {
      return true;
    }
    if (!canonicalBuilding.levelIds.every(binding.legacyLevelIds.containsKey)) {
      return true;
    }

    final composedByLegacyId = {
      for (final item in legacy.building.levels) item.level.id: item,
    };
    for (final levelId in canonicalBuilding.levelIds) {
      final canonicalLevel = canonical.stores.levels[levelId];
      final legacyId = binding.legacyLevelIds[levelId];
      final legacyLevel =
          legacyId == null ? null : composedByLegacyId[legacyId];
      if (canonicalLevel == null || legacyLevel == null) return true;
      if (legacyLevel.level.name != canonicalLevel.name ||
          legacyLevel.level.elevationMm != canonicalLevel.elevationMm ||
          legacyLevel.levelNumber != canonicalLevel.levelNumber ||
          legacyLevel.kind != _legacyKind(canonicalLevel) ||
          legacyLevel.floorToFloorHeightMm !=
              canonicalLevel.floorToFloorHeightMm) {
        return true;
      }
    }
    return false;
  }

  EditorProjectDocument project({
    required EditorProjectDocument legacy,
    required ProjectAggregateRoot canonical,
    required CanonicalEditorWorkspaceBinding binding,
    DateTime? now,
  }) {
    final canonicalBuilding = canonical.stores.buildings[binding.buildingId];
    if (canonicalBuilding == null) {
      throw StateError(
        'Canonical Building ${binding.buildingId} is missing from the project.',
      );
    }
    final existingBuilding = legacy.building;
    if (existingBuilding.building.id != binding.legacyBuildingId) {
      throw StateError('Legacy document is bound to a different Building.');
    }

    final composedByLegacyId = {
      for (final item in existingBuilding.levels) item.level.id: item,
    };
    final canonicalLevels = [
      for (final levelId in canonicalBuilding.levelIds)
        canonical.stores.levels[levelId] ??
            (throw StateError('Canonical Level $levelId is missing.')),
    ]..sort((left, right) {
        final order = left.displayOrder.compareTo(right.displayOrder);
        if (order != 0) return order;
        final number = left.levelNumber.compareTo(right.levelNumber);
        if (number != 0) return number;
        return left.id.value.compareTo(right.id.value);
      });

    _validateLegacyDependencies(
      legacy: legacy,
      canonicalLevels: canonicalLevels,
      binding: binding,
      composedByLegacyId: composedByLegacyId,
    );

    final projectedLevels = <ComposedBuildingLevel>[];
    final newLevelNumberByCanonicalId = <LevelId, int>{};
    for (final canonicalLevel in canonicalLevels) {
      final existingLegacyId = binding.legacyLevelIds[canonicalLevel.id];
      final existing = existingLegacyId == null
          ? null
          : composedByLegacyId[existingLegacyId];
      final legacyLevelId = existingLegacyId ??
          CanonicalLegacyIdentityCodec.encodeLevelId(canonicalLevel.id);
      final level = BuildingLevel(
        id: legacyLevelId,
        name: canonicalLevel.name,
        elevationMm: canonicalLevel.elevationMm,
        spaces: existing?.level.spaces ?? const <EngineeringSpace>[],
      );
      projectedLevels.add(
        ComposedBuildingLevel(
          level: level,
          levelNumber: canonicalLevel.levelNumber,
          kind: _legacyKind(canonicalLevel),
          floorToFloorHeightMm: canonicalLevel.floorToFloorHeightMm,
          zones: existing?.zones ?? const <BuildingZone>[],
        ),
      );
      newLevelNumberByCanonicalId[canonicalLevel.id] =
          canonicalLevel.levelNumber;
    }

    final projectedBuilding = Building(
      id: existingBuilding.building.id,
      name: canonicalBuilding.name,
      levels: [for (final item in projectedLevels) item.level],
    );
    final composedBuilding = ComposedBuilding(
      building: projectedBuilding,
      levels: projectedLevels,
      verticalCores: existingBuilding.verticalCores,
    );
    final siteBuildings = [
      for (final building in legacy.site.site.buildings)
        if (building.id == binding.legacyBuildingId)
          projectedBuilding
        else
          building,
    ];
    if (!siteBuildings.any((item) => item.id == binding.legacyBuildingId)) {
      throw StateError('Bound legacy Building is missing from the Site.');
    }

    final activeLevelNumber = _projectedActiveLevelNumber(
      legacy: legacy,
      canonicalLevels: canonicalLevels,
      binding: binding,
      composedByLegacyId: composedByLegacyId,
      newLevelNumberByCanonicalId: newLevelNumberByCanonicalId,
    );
    final openings = _projectOpenings(
      legacy: legacy,
      binding: binding,
      composedByLegacyId: composedByLegacyId,
      newLevelNumberByCanonicalId: newLevelNumberByCanonicalId,
    );

    return EditorProjectDocument(
      schemaVersion: legacy.schemaVersion,
      metadata: legacy.metadata.touch(now),
      building: composedBuilding,
      site: legacy.site.copyWith(
        site: legacy.site.site.copyWith(buildings: siteBuildings),
      ),
      workspaceContext: legacy.workspaceContext,
      activeLevelNumber: activeLevelNumber,
      selectedZoneId: legacy.selectedZoneId,
      activeOutdoorZoneId: legacy.activeOutdoorZoneId,
      openingsByLevel: Map.unmodifiable(openings),
      resume: legacy.resume,
      p2State: legacy.p2State,
    );
  }

  void _validateLegacyDependencies({
    required EditorProjectDocument legacy,
    required List<ProjectLevelEntity> canonicalLevels,
    required CanonicalEditorWorkspaceBinding binding,
    required Map<String, ComposedBuildingLevel> composedByLegacyId,
  }) {
    final oldNumbers = <LevelId, int>{};
    for (final entry in binding.legacyLevelIds.entries) {
      final existing = composedByLegacyId[entry.value];
      if (existing != null) oldNumbers[entry.key] = existing.levelNumber;
    }
    final renumbered = canonicalLevels.any(
      (level) =>
          oldNumbers.containsKey(level.id) &&
          oldNumbers[level.id] != level.levelNumber,
    );
    if (renumbered && legacy.building.verticalCores.isNotEmpty) {
      throw StateError(
        'Cannot project renumbered Levels while legacy vertical cores still '
        'address levels by number.',
      );
    }
    if (renumbered &&
        legacy.site.connections.any(
          (connection) => connection.buildingId == binding.legacyBuildingId,
        )) {
      throw StateError(
        'Cannot project renumbered Levels while site connections still '
        'address the bound Building by level number.',
      );
    }
  }

  int _projectedActiveLevelNumber({
    required EditorProjectDocument legacy,
    required List<ProjectLevelEntity> canonicalLevels,
    required CanonicalEditorWorkspaceBinding binding,
    required Map<String, ComposedBuildingLevel> composedByLegacyId,
    required Map<LevelId, int> newLevelNumberByCanonicalId,
  }) {
    ComposedBuildingLevel? activeLegacy;
    for (final item in legacy.building.levels) {
      if (item.levelNumber == legacy.activeLevelNumber) {
        activeLegacy = item;
        break;
      }
    }
    if (activeLegacy != null) {
      final canonicalId =
          binding.canonicalLevelIdForLegacy(activeLegacy.level.id);
      final projected =
          canonicalId == null ? null : newLevelNumberByCanonicalId[canonicalId];
      if (projected != null) return projected;
    }
    for (final level in canonicalLevels) {
      if (level.elevationMm == 0) return level.levelNumber;
    }
    return canonicalLevels.first.levelNumber;
  }

  Map<int, List<ArchitecturalOpening>> _projectOpenings({
    required EditorProjectDocument legacy,
    required CanonicalEditorWorkspaceBinding binding,
    required Map<String, ComposedBuildingLevel> composedByLegacyId,
    required Map<LevelId, int> newLevelNumberByCanonicalId,
  }) {
    final projected = <int, List<ArchitecturalOpening>>{};
    for (final entry in binding.legacyLevelIds.entries) {
      final oldLevel = composedByLegacyId[entry.value];
      final newNumber = newLevelNumberByCanonicalId[entry.key];
      if (oldLevel == null || newNumber == null) continue;
      projected[newNumber] = List.unmodifiable(
        legacy.openingsByLevel[oldLevel.levelNumber] ?? const [],
      );
    }
    for (final newNumber in newLevelNumberByCanonicalId.values) {
      projected.putIfAbsent(newNumber, () => const []);
    }
    return projected;
  }
}

BuildingLevelKind _legacyKind(ProjectLevelEntity level) => switch (level.kind) {
      ProjectLevelKind.unknown when level.levelNumber < 0 =>
        BuildingLevelKind.basement,
      ProjectLevelKind.unknown when level.levelNumber == 0 =>
        BuildingLevelKind.ground,
      ProjectLevelKind.unknown => BuildingLevelKind.residential,
      ProjectLevelKind.basement => BuildingLevelKind.basement,
      ProjectLevelKind.ground => BuildingLevelKind.ground,
      ProjectLevelKind.residential => BuildingLevelKind.residential,
      ProjectLevelKind.technical => BuildingLevelKind.technical,
      ProjectLevelKind.roof => BuildingLevelKind.roof,
    };
