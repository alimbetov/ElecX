import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

/// Creates one empty building under the canonical root site.
///
/// The persistent [buildingId] must be allocated before command construction,
/// normally through [EntityIdFactory]. The command never derives identity from
/// display order, name or list position.
final class CreateBuildingCommand implements ProjectCommand {
  CreateBuildingCommand({
    required this.buildingId,
    required this.name,
    this.displayOrder = 0,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Building name must be non-empty.');
    }
  }

  final BuildingId buildingId;
  final String name;
  final int displayOrder;

  @override
  String get commandType => 'project.building.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.buildings.containsKey(buildingId)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.buildingAlreadyExists,
        entityId: buildingId,
        message: 'Building $buildingId already exists.',
      );
    }

    final site = current.index.site(current.siteId)!;
    final buildingIds = <BuildingId>{...site.buildingIds, buildingId};
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites);
    final buildings =
        Map<BuildingId, ProjectBuildingEntity>.from(current.stores.buildings);

    sites[site.id] = ProjectSiteEntity(
      id: site.id,
      name: site.name,
      buildingIds: buildingIds,
    );
    buildings[buildingId] = ProjectBuildingEntity(
      id: buildingId,
      siteId: site.id,
      name: name,
      displayOrder: displayOrder,
      levelIds: const <LevelId>[],
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: sites,
        buildings: buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[site.id, buildingId],
    );
  }
}

/// Renames an existing building without changing its stable identity,
/// hierarchy or display order.
final class RenameBuildingCommand implements ProjectCommand {
  RenameBuildingCommand({
    required this.buildingId,
    required this.name,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Building name must be non-empty.');
    }
  }

  final BuildingId buildingId;
  final String name;

  @override
  String get commandType => 'project.building.rename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final building = current.index.building(buildingId);
    if (building == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.buildingNotFound,
        entityId: buildingId,
        message: 'Building $buildingId does not exist.',
      );
    }

    final buildings =
        Map<BuildingId, ProjectBuildingEntity>.from(current.stores.buildings);
    buildings[building.id] = ProjectBuildingEntity(
      id: building.id,
      siteId: building.siteId,
      name: name,
      displayOrder: building.displayOrder,
      levelIds: building.levelIds,
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[building.id],
    );
  }
}
