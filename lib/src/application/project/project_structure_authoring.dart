import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_building_commands.dart';
import 'project_level_commands.dart';
import 'project_mutation.dart';
import 'project_navigation_state.dart';
import 'project_space_commands.dart';

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
        _navigation = (navigation ??
                ProjectNavigationState.initial(mutations.current))
            .reconcile(mutations.current);

  final ProjectMutationSession _mutations;
  final EntityIdFactory _idFactory;
  ProjectNavigationState _navigation;

  ProjectAggregateRoot get project => _mutations.current;
  ProjectNavigationState get navigation => _navigation;

  ProjectStructureAuthoringAvailability get availability {
    final current = _mutations.current;
    final reconciled = _navigation.reconcile(current);
    final buildingId = reconciled.activeBuildingId;
    final levelId = reconciled.activeLevelId;

    final hasBuilding =
        buildingId != null && current.index.building(buildingId) != null;
    final hasLevel = levelId != null &&
        current.index.level(levelId) != null &&
        hasBuilding &&
        current.index.level(levelId)!.buildingId == buildingId;

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
    CreateLevelRequest input,
  ) {
    final buildingId = _requireActiveBuilding();
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
    CreateRoomRequest input,
  ) {
    final levelId = _requireActiveLevel();
    final zoneId = input.structuralZoneId;
    if (zoneId != null) {
      final zone = project.index.zone(zoneId);
      if (zone == null || zone.levelId != levelId) {
        throw StateError(
          'Room structural zone must exist on the active Level.',
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

  /// Reconciles current location after external structural mutation/Undo/Redo.
  void reconcileNavigation({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot after,
  }) {
    _navigation = _navigation.reconcileAfterMutation(before: before, after: after);
  }

  BuildingId _requireActiveBuilding() {
    final id = _navigation.activeBuildingId;
    if (id == null || project.index.building(id) == null) {
      throw StateError('+Level requires an explicit active BuildingId.');
    }
    return id;
  }

  LevelId _requireActiveLevel() {
    final id = _navigation.activeLevelId;
    if (id == null) {
      throw StateError('+Room requires an explicit active LevelId.');
    }
    final level = project.index.level(id);
    if (level == null || level.buildingId != _navigation.activeBuildingId) {
      throw StateError('+Room requires a valid active Building/Level context.');
    }
    return id;
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
