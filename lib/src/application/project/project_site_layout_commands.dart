import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_site_layout.dart';
import 'project_mutation.dart';

/// Moves the explicit Site transform only; local geometry, durable hosts and
/// generation baselines are preserved. Canonical validation rejects collisions.
final class UpdateBuildingSitePlacementCommand implements ProjectCommand {
  const UpdateBuildingSitePlacementCommand(
      {required this.buildingId, required this.placement});
  final BuildingId buildingId;
  final ProjectBuildingSitePlacement placement;
  @override
  String get commandType => 'project.site.update-building-placement';
  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.buildings[buildingId]?.siteId != current.siteId) {
      throw const SiteLayoutException('p10.site-layout.foreign-building');
    }
    final layout = current.engineeringMetadata.siteLayout;
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
            stores: current.stores,
            engineeringMetadata: current.engineeringMetadata.copyWith(
                siteLayout: layout.copyWith(placements: {
              ...layout.placements,
              buildingId: placement
            }))),
        affectedEntityIds: {current.siteId, buildingId});
  }
}

final class RemoveSharedSiteAnchorCommand implements ProjectCommand {
  const RemoveSharedSiteAnchorCommand(this.anchorId);
  final ServiceEntryId anchorId;
  @override
  String get commandType => 'project.site.remove-shared-anchor';
  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final layout = current.engineeringMetadata.siteLayout;
    if (!layout.sharedAnchors.containsKey(anchorId)) {
      throw const SiteLayoutException('p10.site-layout.anchor-missing');
    }
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
            stores: current.stores,
            engineeringMetadata: current.engineeringMetadata.copyWith(
                siteLayout: layout.copyWith(
                    sharedAnchors: {...layout.sharedAnchors}
                      ..remove(anchorId)))),
        affectedEntityIds: {current.siteId, anchorId});
  }
}
