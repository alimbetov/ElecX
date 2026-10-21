import '../../application/project/project_navigation_state.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'editor_building_workspace.dart';

enum CanonicalEditorWorkspaceIssueCode {
  projectSiteMismatch,
  activeBuildingRequired,
  activeLevelRequired,
  unsupportedBuilding,
  canonicalLevelMissing,
  legacyLevelBindingMissing,
  legacyLevelMissing,
  canonicalZoneMissing,
  legacyZoneBindingMissing,
  legacyZoneMissing,
  canonicalSpaceMissing,
  legacySpaceBindingMissing,
  legacySpaceMissing,
  ambiguousLegacyBinding,
}

final class CanonicalEditorWorkspaceException implements Exception {
  const CanonicalEditorWorkspaceException({
    required this.code,
    required this.message,
    this.entityId,
  });

  final CanonicalEditorWorkspaceIssueCode code;
  final String message;
  final EntityId? entityId;

  @override
  String toString() => '${code.name}: $message';
}

/// Explicit identity bridge between the canonical project graph and the
/// transitional single-building editor workspace.
///
/// Canonical IDs remain authoritative. Legacy ids are implementation details
/// used only to address the existing canvas model during cutover. A Level is
/// never resolved by [ProjectLevelEntity.levelNumber].
final class CanonicalEditorWorkspaceBinding {
  CanonicalEditorWorkspaceBinding({
    required this.buildingId,
    required this.legacyBuildingId,
    required Map<LevelId, String> legacyLevelIds,
    Map<ZoneId, String> legacyZoneIds = const {},
    Map<SpaceId, String> legacySpaceIds = const {},
  })  : legacyLevelIds = Map.unmodifiable(legacyLevelIds),
        legacyZoneIds = Map.unmodifiable(legacyZoneIds),
        legacySpaceIds = Map.unmodifiable(legacySpaceIds) {
    _requireUniqueValues(this.legacyLevelIds, 'level');
    _requireUniqueValues(this.legacyZoneIds, 'zone');
    _requireUniqueValues(this.legacySpaceIds, 'space');
  }

  final BuildingId buildingId;
  final String legacyBuildingId;
  final Map<LevelId, String> legacyLevelIds;
  final Map<ZoneId, String> legacyZoneIds;
  final Map<SpaceId, String> legacySpaceIds;

  LevelId? canonicalLevelIdForLegacy(String legacyId) =>
      _canonicalIdForLegacy(legacyLevelIds, legacyId);

  ZoneId? canonicalZoneIdForLegacy(String legacyId) =>
      _canonicalIdForLegacy(legacyZoneIds, legacyId);

  SpaceId? canonicalSpaceIdForLegacy(String legacyId) =>
      _canonicalIdForLegacy(legacySpaceIds, legacyId);
}

/// Transitional P5C cutover adapter.
///
/// Direction 1: canonical navigation -> legacy workspace/canvas.
/// Direction 2: legacy canvas room selection -> canonical navigation.
///
/// It deliberately supports exactly one legacy [EditorBuildingWorkspace], so a
/// canonical Building outside [CanonicalEditorWorkspaceBinding.buildingId]
/// fails closed. Multi-building cutover must instantiate/switch the correct
/// workspace rather than silently rebinding by level number or label.
final class CanonicalEditorWorkspaceAdapter {
  const CanonicalEditorWorkspaceAdapter({
    required this.workspace,
    required this.binding,
  });

  final EditorBuildingWorkspace workspace;
  final CanonicalEditorWorkspaceBinding binding;

  /// Opens the exact canonical Level/Zone/Space represented by [navigation].
  ///
  /// The complete target is resolved and validated before the legacy workspace
  /// is mutated. Therefore a missing Zone/Space binding cannot partially switch
  /// the canvas to another Level and then fail. The only use of the legacy
  /// level number is the final call into the old workspace API *after* the
  /// Level has already been resolved by an explicit canonical LevelId -> legacy
  /// BuildingLevel.id binding.
  void applyCanonicalNavigation({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
  }) {
    _validateProjectAndBuilding(project, navigation);
    final levelId = navigation.activeLevelId;
    if (levelId == null) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.activeLevelRequired,
        message: 'The legacy canvas requires an explicit canonical LevelId.',
      );
    }

    final canonicalLevel = project.index.level(levelId);
    if (canonicalLevel == null ||
        canonicalLevel.buildingId != binding.buildingId) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.canonicalLevelMissing,
        entityId: levelId,
        message:
            'Canonical Level $levelId is not available in the bound Building.',
      );
    }

    final legacyLevelId = binding.legacyLevelIds[levelId];
    if (legacyLevelId == null) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacyLevelBindingMissing,
        entityId: levelId,
        message: 'No legacy editor binding exists for canonical Level $levelId.',
      );
    }

    final legacyLevel = workspace.building.levels
        .where((candidate) => candidate.level.id == legacyLevelId)
        .firstOrNull;
    if (legacyLevel == null) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacyLevelMissing,
        entityId: levelId,
        message: 'Bound legacy Level id $legacyLevelId does not exist.',
      );
    }

    // Resolve every child target before calling selectLevel/selectZone/selectSpace.
    // This keeps a rejected cutover observationally atomic for the canvas.
    final zoneId = navigation.selectedZoneId;
    final legacyZoneId = zoneId == null
        ? null
        : _resolveLegacyZoneId(
            project: project,
            levelId: levelId,
            zoneId: zoneId,
            legacyLevelId: legacyLevelId,
          );
    final spaceId = navigation.selectedSpaceId;
    final legacySpaceId = spaceId == null
        ? null
        : _resolveLegacySpaceId(
            project: project,
            levelId: levelId,
            spaceId: spaceId,
            legacyLevelId: legacyLevelId,
          );

    workspace.selectLevel(legacyLevel.levelNumber);
    workspace.selectZone(legacyZoneId);

    if (legacySpaceId != null) {
      workspace.editor.selectSpace(legacySpaceId);
    } else if (legacyZoneId != null) {
      // A Zone may be the selected leaf. The old selectZone() API selects its
      // first space as a side effect, so clear canvas room selection to keep
      // the canonical leaf authoritative.
      workspace.editor.selectSpace(null);
    }
  }

  /// Projects the current legacy Level/Zone/Space selection back onto the
  /// canonical navigation state without using levelNumber as identity.
  ///
  /// This is the transition hook for existing canvas interactions that still
  /// call EditorController.selectSpace(). It must be removed once the editor
  /// controller itself owns canonical typed ids.
  ProjectNavigationState pullLegacySelection({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
  }) {
    _validateProjectAndBuilding(
      project,
      navigation,
      requireActiveBuilding: false,
    );

    if (workspace.building.building.id != binding.legacyBuildingId) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.unsupportedBuilding,
        entityId: binding.buildingId,
        message: 'The editor workspace is not the legacy Building bound to '
            '${binding.buildingId}.',
      );
    }

    final legacyLevel = workspace.activeLevel;
    if (legacyLevel == null) {
      throw const CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacyLevelMissing,
        message: 'The editor workspace has no active legacy Level.',
      );
    }
    final levelId = binding.canonicalLevelIdForLegacy(legacyLevel.level.id);
    if (levelId == null || project.index.level(levelId) == null) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacyLevelBindingMissing,
        message: 'Active legacy Level ${legacyLevel.level.id} has no canonical '
            'binding.',
      );
    }

    var next = navigation.activateLevel(project, levelId);

    final legacySpaceId = workspace.editor.selectedSpaceId;
    if (legacySpaceId != null) {
      final spaceId = binding.canonicalSpaceIdForLegacy(legacySpaceId);
      if (spaceId == null) {
        throw CanonicalEditorWorkspaceException(
          code: CanonicalEditorWorkspaceIssueCode.legacySpaceBindingMissing,
          message:
              'Selected legacy Space $legacySpaceId has no canonical binding.',
        );
      }
      return next.selectSpace(project, spaceId);
    }

    final legacyZoneId = workspace.selectedZoneId;
    if (legacyZoneId != null) {
      final zoneId = binding.canonicalZoneIdForLegacy(legacyZoneId);
      if (zoneId == null) {
        throw CanonicalEditorWorkspaceException(
          code: CanonicalEditorWorkspaceIssueCode.legacyZoneBindingMissing,
          message: 'Selected legacy Zone $legacyZoneId has no canonical '
              'binding.',
        );
      }
      return next.selectZone(project, zoneId);
    }

    return next.clearSelection();
  }

  void _validateProjectAndBuilding(
    ProjectAggregateRoot project,
    ProjectNavigationState navigation, {
    bool requireActiveBuilding = true,
  }) {
    if (navigation.siteId != project.siteId) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.projectSiteMismatch,
        entityId: navigation.siteId,
        message: 'Navigation and canonical project belong to different Sites.',
      );
    }

    final activeBuildingId = navigation.activeBuildingId;
    if (activeBuildingId == null) {
      if (!requireActiveBuilding) return;
      throw const CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.activeBuildingRequired,
        message: 'The legacy canvas requires an explicit canonical BuildingId.',
      );
    }
    if (activeBuildingId != binding.buildingId ||
        workspace.building.building.id != binding.legacyBuildingId) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.unsupportedBuilding,
        entityId: activeBuildingId,
        message: 'Canonical Building $activeBuildingId is not bound to this '
            'editor workspace.',
      );
    }
  }

  String _resolveLegacyZoneId({
    required ProjectAggregateRoot project,
    required LevelId levelId,
    required ZoneId zoneId,
    required String legacyLevelId,
  }) {
    final canonicalZone = project.index.zone(zoneId);
    if (canonicalZone == null || canonicalZone.levelId != levelId) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.canonicalZoneMissing,
        entityId: zoneId,
        message:
            'Canonical Zone $zoneId does not belong to active Level $levelId.',
      );
    }
    final legacyZoneId = binding.legacyZoneIds[zoneId];
    if (legacyZoneId == null) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacyZoneBindingMissing,
        entityId: zoneId,
        message: 'No legacy editor binding exists for canonical Zone $zoneId.',
      );
    }
    final legacyLevel = workspace.building.levels
        .where((candidate) => candidate.level.id == legacyLevelId)
        .firstOrNull;
    final exists = legacyLevel?.zones.any(
          (candidate) => candidate.id == legacyZoneId,
        ) ??
        false;
    if (!exists) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacyZoneMissing,
        entityId: zoneId,
        message: 'Bound legacy Zone id $legacyZoneId does not exist.',
      );
    }
    return legacyZoneId;
  }

  String _resolveLegacySpaceId({
    required ProjectAggregateRoot project,
    required LevelId levelId,
    required SpaceId spaceId,
    required String legacyLevelId,
  }) {
    final canonicalSpace = project.index.space(spaceId);
    if (canonicalSpace == null || canonicalSpace.levelId != levelId) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.canonicalSpaceMissing,
        entityId: spaceId,
        message:
            'Canonical Space $spaceId does not belong to active Level $levelId.',
      );
    }
    final legacySpaceId = binding.legacySpaceIds[spaceId];
    if (legacySpaceId == null) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacySpaceBindingMissing,
        entityId: spaceId,
        message:
            'No legacy editor binding exists for canonical Space $spaceId.',
      );
    }
    final legacyLevel = workspace.building.levels
        .where((candidate) => candidate.level.id == legacyLevelId)
        .firstOrNull;
    final exists = legacyLevel?.level.spaces.any(
          (space) => space.id == legacySpaceId,
        ) ??
        false;
    if (!exists) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.legacySpaceMissing,
        entityId: spaceId,
        message:
            'Bound legacy Space id $legacySpaceId does not exist on canvas.',
      );
    }
    return legacySpaceId;
  }
}

T? _canonicalIdForLegacy<T extends EntityId>(
  Map<T, String> bindings,
  String legacyId,
) {
  for (final entry in bindings.entries) {
    if (entry.value == legacyId) return entry.key;
  }
  return null;
}

void _requireUniqueValues<T extends EntityId>(
  Map<T, String> bindings,
  String kind,
) {
  final seen = <String>{};
  for (final legacyId in bindings.values) {
    if (!seen.add(legacyId)) {
      throw CanonicalEditorWorkspaceException(
        code: CanonicalEditorWorkspaceIssueCode.ambiguousLegacyBinding,
        message: 'Multiple canonical $kind ids map to legacy id $legacyId.',
      );
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
