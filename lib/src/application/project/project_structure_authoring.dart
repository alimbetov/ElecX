import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_authoring_error.dart';
import 'project_building_commands.dart';
import 'project_level_commands.dart';
import 'project_mutation.dart';
import 'project_navigation_state.dart';
import 'project_space_commands.dart';

enum ProjectStructureAuthoringIssueCode {
  navigationSiteMismatch,
  activeBuildingRequired,
  activeLevelRequired,
  authoringContextChanged,
  reconciliationProjectMismatch,
  reconciliationVersionMismatch,
}

final class ProjectStructureAuthoringException implements Exception {
  const ProjectStructureAuthoringException({
    required this.code,
    required this.message,
    this.entityId,
    this.relatedEntityId,
  });

  final ProjectStructureAuthoringIssueCode code;
  final String message;
  final EntityId? entityId;
  final EntityId? relatedEntityId;

  @override
  String toString() => '${code.name}: $message';
}

/// Availability of the discoverable P5C primary authoring actions.
///
/// Targeting is derived only from the canonical project and the shared
/// [ProjectNavigationState]. Widgets must not independently guess a parent from
/// labels, level numbers or legacy workspace state.
final class ProjectStructureAuthoringAvailability {
  const ProjectStructureAuthoringAvailability({
    required this.canAddBuilding,
    required this.canAddLevel,
    required this.canAddRoom,
  });

  final bool canAddBuilding;
  final bool canAddLevel;
  final bool canAddRoom;
}

final class CreateBuildingRequest {
  const CreateBuildingRequest({
    required this.name,
    this.displayOrder = 0,
  });

  final String name;
  final int displayOrder;
}

final class CreateLevelRequest {
  const CreateLevelRequest({
    required this.name,
    required this.levelNumber,
    required this.elevationMm,
    this.displayOrder = 0,
  });

  final String name;
  final int levelNumber;
  final int elevationMm;
  final int displayOrder;
}

/// P5C structural room request.
///
/// Geometry/type/usage fields are intentionally not invented here because the
/// current canonical P4 Space entity does not own them yet. The existing plan
/// rectangle interaction may collect geometry before this structural commit;
/// canonical geometry/type/usage integration belongs to the later model stage.
final class CreateRoomRequest {
  const CreateRoomRequest({
    required this.name,
    this.structuralZoneId,
  });

  final String name;
  final ZoneId? structuralZoneId;
}

final class ProjectStructureAuthoringResult<T extends EntityId> {
  const ProjectStructureAuthoringResult({
    required this.createdId,
    required this.project,
    required this.navigation,
    required this.changeSet,
  });

  final T createdId;
  final ProjectAggregateRoot project;
  final ProjectNavigationState navigation;
  final ProjectChangeSet changeSet;
}

/// P5C application/session boundary for +Building / +Level / +Room.
///
/// Each successful operation is exactly one P3 mutation and then one navigation
/// transition. Navigation for the post-commit state is prepared against the
/// validated preview candidate before the live commit, so presentation logic
/// cannot turn a successful canonical commit into an apparent authoring
/// failure afterwards.
final class ProjectStructureAuthoringSession {
  ProjectStructureAuthoringSession({
    required ProjectMutationSession mutations,
    required EntityIdFactory idFactory,
    ProjectNavigationState? navigation,
  })  : _mutations = mutations,
        _idFactory = idFactory,
        _navigation = _initialNavigation(mutations.current, navigation);

  final ProjectMutationSession _mutations;
  final EntityIdFactory _idFactory;
  ProjectNavigationState _navigation;

  ProjectAggregateRoot get project => _mutations.current;
  ProjectNavigationState get navigation => _navigation;

  /// Canonical navigation transitions used by Navigator/tree/breadcrumb UI.
  ///
  /// These methods never mutate engineering state and never identify a Level
  /// by number, label, list index, or widget key. The shared navigation state
  /// remains the single source for active/current/selected presentation.
  void activateBuilding(BuildingId buildingId) {
    _navigation = _navigation.activateBuilding(project, buildingId);
  }

  void activateLevel(LevelId levelId) {
    _navigation = _navigation.activateLevel(project, levelId);
  }

  void selectZone(ZoneId zoneId) {
    _navigation = _navigation.selectZone(project, zoneId);
  }

  void selectRoom(SpaceId spaceId) {
    _navigation = _navigation.selectSpace(project, spaceId);
  }

  void clearSelection() {
    _navigation = _navigation.clearSelection();
  }

  /// Pure availability derived from the exact navigation state that the action
  /// methods will use. It deliberately does not auto-repair stale navigation;
  /// external structural mutations must call [reconcileNavigation] explicitly.
  ProjectStructureAuthoringAvailability get availability {
    final current = _mutations.current;
    final buildingId = _navigation.activeBuildingId;
    final levelId = _navigation.activeLevelId;

    final building =
        buildingId == null ? null : current.index.building(buildingId);
    final level = levelId == null ? null : current.index.level(levelId);
    final hasBuilding = building != null && building.siteId == current.siteId;
    final hasLevel =
        level != null && hasBuilding && level.buildingId == building.id;

    return ProjectStructureAuthoringAvailability(
      canAddBuilding: current.index.site(current.siteId) != null,
      canAddLevel: hasBuilding,
      canAddRoom: hasLevel,
    );
  }

  ProjectStructureAuthoringResult<BuildingId> createBuilding(
    CreateBuildingRequest input,
  ) {
    final id = _idFactory.newBuildingId();
    final command = CreateBuildingCommand(
      buildingId: id,
      name: input.name,
      displayOrder: input.displayOrder,
    );
    final request = ProjectMutationRequest(
      expectedVersion: project.version,
      command: command,
    );

    final preview = _mutations.preview(request);
    final nextNavigation = _navigation.activateBuilding(preview.candidate, id);
    final committed = _requireCommit(_mutations.commit(request), command);
    _navigation = nextNavigation;

    return ProjectStructureAuthoringResult<BuildingId>(
      createdId: id,
      project: committed.project,
      navigation: _navigation,
      changeSet: committed.changeSet,
    );
  }

  ProjectStructureAuthoringResult<LevelId> createLevel(
    CreateLevelRequest input, {
    BuildingId? expectedActiveBuildingId,
  }) {
    final buildingId = _requireActiveBuilding();
    if (expectedActiveBuildingId != null &&
        buildingId != expectedActiveBuildingId) {
      throw ProjectStructureAuthoringException(
        code: ProjectStructureAuthoringIssueCode.authoringContextChanged,
        entityId: buildingId,
        relatedEntityId: expectedActiveBuildingId,
        message: 'Active Building changed while +Level authoring was in '
            'progress.',
      );
    }

    final id = _idFactory.newLevelId();
    final command = CreateLevelCommand(
      levelId: id,
      buildingId: buildingId,
      name: input.name,
      levelNumber: input.levelNumber,
      elevationMm: input.elevationMm,
      displayOrder: input.displayOrder,
    );
    final request = ProjectMutationRequest(
      expectedVersion: project.version,
      command: command,
    );

    final preview = _mutations.preview(request);
    final nextNavigation = _navigation.activateLevel(preview.candidate, id);
    final committed = _requireCommit(_mutations.commit(request), command);
    _navigation = nextNavigation;

    return ProjectStructureAuthoringResult<LevelId>(
      createdId: id,
      project: committed.project,
      navigation: _navigation,
      changeSet: committed.changeSet,
    );
  }

  ProjectStructureAuthoringResult<SpaceId> createRoom(
    CreateRoomRequest input, {
    LevelId? expectedActiveLevelId,
  }) {
    final levelId = _requireActiveLevel();
    if (expectedActiveLevelId != null && levelId != expectedActiveLevelId) {
      throw ProjectStructureAuthoringException(
        code: ProjectStructureAuthoringIssueCode.authoringContextChanged,
        entityId: levelId,
        relatedEntityId: expectedActiveLevelId,
        message: 'Active Level changed while +Room authoring was in progress.',
      );
    }

    final zoneId = input.structuralZoneId;
    if (zoneId != null) {
      final zone = project.index.zone(zoneId);
      if (zone == null) {
        throw ProjectAuthoringException(
          code: ProjectAuthoringIssueCode.structuralZoneNotFound,
          entityId: zoneId,
          message: 'Structural zone $zoneId does not exist.',
        );
      }
      if (zone.levelId != levelId) {
        throw ProjectAuthoringException(
          code: ProjectAuthoringIssueCode.structuralZoneLevelMismatch,
          entityId: zone.id,
          relatedEntityId: zone.levelId,
          message:
              'Structural zone ${zone.id} belongs to level ${zone.levelId}, '
              'not active level $levelId.',
        );
      }
    }

    final id = _idFactory.newSpaceId();
    final command = CreateSpaceCommand(
      spaceId: id,
      levelId: levelId,
      name: input.name,
      structuralZoneId: zoneId,
    );
    final request = ProjectMutationRequest(
      expectedVersion: project.version,
      command: command,
    );

    final preview = _mutations.preview(request);
    final nextNavigation = _navigation.selectSpace(preview.candidate, id);
    final committed = _requireCommit(_mutations.commit(request), command);
    _navigation = nextNavigation;

    return ProjectStructureAuthoringResult<SpaceId>(
      createdId: id,
      project: committed.project,
      navigation: _navigation,
      changeSet: committed.changeSet,
    );
  }

  /// Reconciles current location after one external structural mutation,
  /// Undo, or Redo that has already committed through the shared mutation
  /// session. Unrelated or skipped snapshots are rejected fail-closed because
  /// neighbor fallback depends on the immediate before/after graph pair.
  void reconcileNavigation({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot after,
  }) {
    final current = project;
    if (before.id != current.id ||
        after.id != current.id ||
        before.siteId != current.siteId ||
        after.siteId != current.siteId) {
      throw ProjectStructureAuthoringException(
        code: ProjectStructureAuthoringIssueCode.reconciliationProjectMismatch,
        entityId: current.id,
        message: 'Navigation reconciliation snapshots must belong to the '
            'current project and site.',
      );
    }
    if (after.version != current.version ||
        after.version.value != before.version.value + 1) {
      throw ProjectStructureAuthoringException(
        code: ProjectStructureAuthoringIssueCode.reconciliationVersionMismatch,
        entityId: current.id,
        message: 'Navigation reconciliation requires the immediate committed '
            'before/after versions ending at ${current.version}.',
      );
    }

    _navigation =
        _navigation.reconcileAfterMutation(before: before, after: after);
  }

  BuildingId _requireActiveBuilding() {
    final id = _navigation.activeBuildingId;
    final building = id == null ? null : project.index.building(id);
    if (building == null || building.siteId != project.siteId) {
      throw ProjectStructureAuthoringException(
        code: ProjectStructureAuthoringIssueCode.activeBuildingRequired,
        entityId: id,
        relatedEntityId: project.siteId,
        message: '+Level requires an explicit active BuildingId in the '
            'current site.',
      );
    }
    return building.id;
  }

  LevelId _requireActiveLevel() {
    final id = _navigation.activeLevelId;
    final level = id == null ? null : project.index.level(id);
    if (level == null || level.buildingId != _navigation.activeBuildingId) {
      throw ProjectStructureAuthoringException(
        code: ProjectStructureAuthoringIssueCode.activeLevelRequired,
        entityId: id,
        relatedEntityId: _navigation.activeBuildingId,
        message: '+Room requires a valid active BuildingId/LevelId context.',
      );
    }
    return level.id;
  }

  ProjectMutationResult _requireCommit(
    ProjectMutationResult? result,
    ProjectCommand command,
  ) {
    if (result == null) {
      throw StateError(
        '${command.commandType} unexpectedly produced an empty mutation.',
      );
    }
    return result;
  }
}

ProjectNavigationState _initialNavigation(
  ProjectAggregateRoot project,
  ProjectNavigationState? navigation,
) {
  if (navigation != null && navigation.siteId != project.siteId) {
    throw ProjectStructureAuthoringException(
      code: ProjectStructureAuthoringIssueCode.navigationSiteMismatch,
      entityId: navigation.siteId,
      relatedEntityId: project.siteId,
      message: 'Authoring navigation belongs to site ${navigation.siteId}, '
          'not current site ${project.siteId}.',
    );
  }
  return (navigation ?? ProjectNavigationState.initial(project))
      .reconcile(project);
}
