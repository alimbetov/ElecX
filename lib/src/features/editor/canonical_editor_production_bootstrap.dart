import '../../application/project/canonical_project_persistence_owner.dart';
import '../../application/project/project_mutation.dart';
import '../../application/project/project_navigation_state.dart';
import '../../application/project/project_repository.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import 'canonical_editor_legacy_bootstrap.dart';
import 'canonical_editor_production_runtime.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'editor_building_workspace.dart';
import 'editor_project_document.dart';
import 'project_persistence_metadata.dart';

final class CanonicalEditorProductionHandle {
  CanonicalEditorProductionHandle._({
    required this.owner,
    required this.session,
    required this.binding,
  }) : runtimeConfig = CanonicalEditorProductionRuntimeConfig(
          resolveRuntime: (workspace, metadata) {
            if (metadata.projectId != owner.projectId.value ||
                workspace.building.building.id != binding.legacyBuildingId) {
              return null;
            }
            return CanonicalEditorResolvedRuntime(
              session: session,
              binding: binding,
              persistenceOwnerProjectId: owner.projectId,
            );
          },
          onCanonicalMutationCommitted: (committedSession, result) {
            if (!identical(committedSession, session)) {
              throw StateError(
                'Canonical production owner rejected a foreign authoring '
                'session.',
              );
            }
            owner.acceptMutation(
              sessionProject: committedSession.project,
              result: result,
            );
            return const CanonicalAuthoringOwnershipReceipt.accepted();
          },
          onAuthoringCommitted: (committedSession, _) {
            if (!identical(committedSession, session) ||
                owner.project.version != committedSession.project.version) {
              throw StateError(
                'Canonical authoring feature hook ran before project ownership '
                'was acknowledged.',
              );
            }
            return const CanonicalAuthoringOwnershipReceipt.accepted();
          },
          onProjectNorthCommitted: (_, result) =>
              _featureReceipt(owner, session, result),
          onSpaceSemanticsCommitted: (_, result) =>
              _featureReceipt(owner, session, result),
          onBoundaryTopologyCommitted: (_, result) =>
              _featureReceipt(owner, session, result),
        );

  final CanonicalProjectPersistenceOwner owner;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorWorkspaceBinding binding;
  final CanonicalEditorProductionRuntimeConfig runtimeConfig;

  Future<void> saveCanonical() => owner.save();

  static Future<CanonicalEditorProductionHandle> loadOrBootstrap({
    required EditorProjectDocument legacyDocument,
    required ProjectRepository repository,
  }) async {
    final bootstrap = CanonicalEditorLegacyBootstrap.create(legacyDocument);
    var owner = await CanonicalProjectPersistenceOwner.load(
      repository: repository,
      projectId: bootstrap.snapshot.id,
    );
    if (owner == null) {
      owner = CanonicalProjectPersistenceOwner(
        snapshot: bootstrap.snapshot,
        repository: repository,
      );
      // First-run canonical identity becomes durable before write capability is
      // exposed. A failed sidecar write therefore leaves the editor in legacy
      // mode instead of enabling canonical writes with ephemeral identities.
      await owner.save();
    }

    _validateLoadedSidecar(
      owner: owner,
      bootstrap: bootstrap,
      legacyDocument: legacyDocument,
    );
    final navigation = _navigationForLegacyResume(
      owner: owner,
      binding: bootstrap.binding,
      legacyDocument: legacyDocument,
    );
    final session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(owner.project),
      idFactory: SecureRandomEntityIdFactory(),
      navigation: navigation,
    );
    return CanonicalEditorProductionHandle._(
      owner: owner,
      session: session,
      binding: bootstrap.binding,
    );
  }
}

CanonicalAuthoringOwnershipReceipt _featureReceipt(
  CanonicalProjectPersistenceOwner owner,
  ProjectStructureAuthoringSession session,
  ProjectMutationResult result,
) {
  if (result.project.id != owner.projectId ||
      result.project.version != owner.version ||
      !identical(result.project, session.project)) {
    throw StateError(
      'Canonical feature hook observed a mutation that is not owned by the '
      'production persistence boundary.',
    );
  }
  return const CanonicalAuthoringOwnershipReceipt.accepted();
}

void _validateLoadedSidecar({
  required CanonicalProjectPersistenceOwner owner,
  required CanonicalEditorLegacyBootstrapResult bootstrap,
  required EditorProjectDocument legacyDocument,
}) {
  if (owner.projectId.value != legacyDocument.projectId ||
      owner.project.siteId != bootstrap.snapshot.aggregate.siteId) {
    throw StateError(
      'Canonical sidecar does not belong to legacy project '
      '${legacyDocument.projectId}.',
    );
  }
  final project = owner.project;
  final binding = bootstrap.binding;
  final building = project.index.building(binding.buildingId);
  if (building == null) {
    throw StateError(
      'Canonical sidecar is missing bound building ${binding.buildingId}.',
    );
  }
  for (final levelId in binding.legacyLevelIds.keys) {
    final level = project.index.level(levelId);
    if (level == null || level.buildingId != binding.buildingId) {
      throw StateError(
        'Canonical sidecar is missing bound level $levelId.',
      );
    }
  }
  for (final entry in binding.legacySpaceIds.entries) {
    final space = project.index.space(entry.key);
    final topology = project.index.boundary(entry.key);
    if (space == null || topology == null) {
      throw StateError(
        'Canonical sidecar is missing bound space ${entry.key} '
        '(${entry.value}).',
      );
    }
    final legacyLevelId = binding.legacyLevelIds[space.levelId];
    if (legacyLevelId == null) {
      throw StateError(
        'Canonical space ${entry.key} has no bound legacy level.',
      );
    }
    BuildingLevel? legacyLevel;
    for (final candidate in legacyDocument.building.building.levels) {
      if (candidate.id == legacyLevelId) {
        legacyLevel = candidate;
        break;
      }
    }
    EngineeringSpace? legacySpace;
    for (final candidate in legacyLevel?.spaces ?? const <EngineeringSpace>[]) {
      if (candidate.id == entry.value) {
        legacySpace = candidate;
        break;
      }
    }
    if (legacySpace == null ||
        legacySpace.boundary.vertices.length != topology.orderedEdgeIds.length) {
      throw StateError(
        'Canonical sidecar geometry does not match materialized legacy space '
        '${entry.value}.',
      );
    }
    for (var index = 0;
        index < legacySpace.boundary.vertices.length;
        index++) {
      final legacyPoint = legacySpace.boundary.vertices[index];
      final edge = topology.edges[topology.orderedEdgeIds[index]];
      if (edge == null ||
          edge.start.xMm != legacyPoint.x ||
          edge.start.yMm != legacyPoint.y) {
        throw StateError(
          'Canonical sidecar geometry diverged from materialized legacy space '
          '${entry.value} at boundary vertex $index.',
        );
      }
    }
  }
}

ProjectNavigationState _navigationForLegacyResume({
  required CanonicalProjectPersistenceOwner owner,
  required CanonicalEditorWorkspaceBinding binding,
  required EditorProjectDocument legacyDocument,
}) {
  final legacyLevel =
      legacyDocument.building.levelByNumber(legacyDocument.activeLevelNumber);
  final activeLevelId = legacyLevel == null
      ? null
      : _canonicalForLegacy(
          binding.legacyLevelIds,
          legacyLevel.level.id,
        );
  final selectedZoneId = legacyDocument.selectedZoneId == null ||
          activeLevelId == null
      ? null
      : _canonicalForLegacy(
          binding.legacyZoneIds,
          legacyDocument.selectedZoneId!,
          where: (zoneId) =>
              owner.project.index.zone(zoneId)?.levelId == activeLevelId,
        );
  final selectedSpaceId = legacyDocument.resume.selectedSpaceId == null ||
          activeLevelId == null
      ? null
      : _canonicalForLegacy(
          binding.legacySpaceIds,
          legacyDocument.resume.selectedSpaceId!,
          where: (spaceId) =>
              owner.project.index.space(spaceId)?.levelId == activeLevelId,
        );
  return ProjectNavigationState.restore(
    owner.project,
    activeBuildingId: binding.buildingId,
    activeLevelId: activeLevelId,
    selectedZoneId: selectedZoneId,
    selectedSpaceId: selectedSpaceId,
  );
}

T? _canonicalForLegacy<T extends EntityId>(
  Map<T, String> mapping,
  String legacyId, {
  bool Function(T id)? where,
}) {
  for (final entry in mapping.entries) {
    if (entry.value == legacyId && (where == null || where(entry.key))) {
      return entry.key;
    }
  }
  return null;
}
