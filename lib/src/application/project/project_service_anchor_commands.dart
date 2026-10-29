import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_service_anchor.dart';
import 'project_mutation.dart';

final class UpdateServiceAnchorCommand implements ProjectCommand {
  const UpdateServiceAnchorCommand(
      {required this.anchor, this.boundaryBinding});
  final ProjectServiceAnchor anchor;
  final ServiceAnchorBoundaryBinding? boundaryBinding;
  @override
  String get commandType => 'project.service-anchor.update';
  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final layout = current.engineeringMetadata.siteLayout;
    final before = layout.serviceAnchors[anchor.id];
    if (before == null || anchor.siteId != current.siteId) {
      throw const ServiceAnchorException('p10.service-anchor.not-found');
    }
    var hosts = current.engineeringMetadata.boundaryHostedObjectRegistry;
    final previous = hosts.serviceEntryHost(anchor.id);
    if (before is ProjectBoundaryServiceAnchor) {
      hosts = hosts.remove(
          BoundaryHostedObjectRegistry.serviceEntryObjectKey(anchor.id));
    }
    if (anchor case final ProjectBoundaryServiceAnchor entry) {
      final binding = boundaryBinding ??
          (previous != null &&
                  previous.objectKind ==
                      BoundaryHostedObjectKind.serviceEntry &&
                  previous.geometryKind == BoundaryHostGeometryKind.point
              ? ServiceAnchorBoundaryBinding(
                  host: previous.host, offsetMm: previous.startOffsetMm!)
              : null);
      if (binding == null || binding.host.spaceId != entry.spaceId) {
        throw const ServiceAnchorException(
            'p10.service-anchor.wall-binding-missing');
      }
      hosts = hosts.putServiceEntry(
          id: anchor.id, host: binding.host, offsetMm: binding.offsetMm);
    } else if (boundaryBinding != null) {
      throw const ServiceAnchorException(
          'p10.service-anchor.unexpected-wall-binding');
    }
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
            stores: current.stores,
            engineeringMetadata: current.engineeringMetadata.copyWith(
                siteLayout: layout.copyWith(serviceAnchors: {
                  ...layout.serviceAnchors,
                  anchor.id: anchor
                }),
                boundaryHostedObjectRegistry: hosts)),
        affectedEntityIds: {anchor.id, current.siteId});
  }
}

final class RemoveServiceAnchorCommand implements ProjectCommand {
  const RemoveServiceAnchorCommand(this.anchorId);
  final ServiceEntryId anchorId;
  @override
  String get commandType => 'project.service-anchor.remove';
  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final layout = current.engineeringMetadata.siteLayout;
    final anchor = layout.serviceAnchors[anchorId];
    if (anchor == null) {
      throw const ServiceAnchorException('p10.service-anchor.not-found');
    }
    final hosts = anchor is ProjectBoundaryServiceAnchor
        ? current.engineeringMetadata.boundaryHostedObjectRegistry.remove(
            BoundaryHostedObjectRegistry.serviceEntryObjectKey(anchorId))
        : current.engineeringMetadata.boundaryHostedObjectRegistry;
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
            stores: current.stores,
            engineeringMetadata: current.engineeringMetadata.copyWith(
                siteLayout: layout.copyWith(
                    serviceAnchors: {...layout.serviceAnchors}
                      ..remove(anchorId)),
                boundaryHostedObjectRegistry: hosts)),
        affectedEntityIds: {anchorId, current.siteId});
  }
}
