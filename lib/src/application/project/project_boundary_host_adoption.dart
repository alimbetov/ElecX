import '../../domain/boundary_host_registry.dart';
import '../../domain/boundary_opening_profile_validation.dart';
import '../../domain/boundary_wall_profile_registry.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';

/// One-time P7A-5 migration from a verified legacy editor projection into
/// canonical hosted-object/profile ownership.
///
/// Adoption is deliberately separate from topology split/merge. A legacy
/// project first accepts its exact current hosts as one P3 commit. All later
/// identity-changing topology edits then operate only from canonical registries
/// and remain one atomic topology+host transaction.
final class ProjectBoundaryHostAdoptionService {
  const ProjectBoundaryHostAdoptionService(this._mutations);

  final ProjectMutationSession _mutations;

  bool hasCanonicalHosts(SpaceId spaceId) =>
      _mutations.current.engineeringMetadata.boundaryHostedObjectRegistry
          .forSpace(spaceId)
          .isNotEmpty ||
      _mutations.current.engineeringMetadata.boundaryWallProfileRegistry
          .forSpace(spaceId)
          .isNotEmpty;

  ProjectMutationResult? adopt({
    required SpaceId spaceId,
    required LocalProjectVersion expectedVersion,
    required BoundaryHostedObjectRegistry hostedObjects,
    required BoundaryWallProfileRegistry wallProfiles,
  }) {
    final current = _mutations.current;
    if (current.version != expectedVersion) {
      throw StaleProjectMutationException(
        expectedVersion: expectedVersion,
        currentVersion: current.version,
      );
    }
    final topology = current.index.boundary(spaceId);
    if (topology == null) {
      throw StateError('Space $spaceId has no canonical boundary topology.');
    }
    if (current.engineeringMetadata.boundaryHostedObjectRegistry
            .forSpace(spaceId)
            .isNotEmpty ||
        current.engineeringMetadata.boundaryWallProfileRegistry
            .forSpace(spaceId)
            .isNotEmpty) {
      throw StateError(
        'Space $spaceId already has canonical hosted ownership; legacy '
        'adoption cannot overwrite canonical state.',
      );
    }

    final mergedHosts = BoundaryHostedObjectRegistry({
      ...current.engineeringMetadata.boundaryHostedObjectRegistry.references,
      for (final reference in hostedObjects.forSpace(spaceId))
        reference.objectKey: reference,
    });
    final mergedProfiles = BoundaryWallProfileRegistry({
      ...current.engineeringMetadata.boundaryWallProfileRegistry.profiles,
      for (final entry in wallProfiles.profiles.entries)
        if (entry.key.spaceId == spaceId) entry.key: entry.value,
    });
    mergedHosts.validateAgainst(current.stores.boundaries);
    mergedProfiles.validateAgainst(current.stores.boundaries);
    BoundaryOpeningProfileValidator.validateSpace(
      spaceId: spaceId,
      openings: current.stores.openings.values,
      hostedObjects: mergedHosts,
      wallProfiles: mergedProfiles,
    );

    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion,
        command: _AdoptBoundaryHostsCommand(
          spaceId: spaceId,
          hostedObjects: mergedHosts,
          wallProfiles: mergedProfiles,
        ),
      ),
    );
  }
}

final class _AdoptBoundaryHostsCommand implements ProjectCommand {
  const _AdoptBoundaryHostsCommand({
    required this.spaceId,
    required this.hostedObjects,
    required this.wallProfiles,
  });

  final SpaceId spaceId;
  final BoundaryHostedObjectRegistry hostedObjects;
  final BoundaryWallProfileRegistry wallProfiles;

  @override
  String get commandType => 'p7a.adoptBoundaryHosts';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.index.boundary(spaceId) == null) {
      throw StateError('Space $spaceId has no canonical boundary topology.');
    }
    hostedObjects.validateAgainst(current.stores.boundaries);
    wallProfiles.validateAgainst(current.stores.boundaries);
    BoundaryOpeningProfileValidator.validateSpace(
      spaceId: spaceId,
      openings: current.stores.openings.values,
      hostedObjects: hostedObjects,
      wallProfiles: wallProfiles,
    );
    final metadata = current.engineeringMetadata
        .withBoundaryHostedObjectRegistry(hostedObjects)
        .withBoundaryWallProfileRegistry(wallProfiles);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: metadata,
        stores: current.stores,
      ),
      affectedEntityIds: <EntityId>{spaceId},
    );
  }
}
