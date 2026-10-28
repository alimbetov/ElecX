import '../../application/project/canonical_project_persistence_owner.dart';
import '../../application/project/project_mutation.dart';
import '../../application/project/project_mutation_reservation.dart';
import '../../application/project/project_repository.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../application/project/wizard/apartment/apartment_engineering_pipeline.dart';
import '../../application/project/wizard/project_wizard_mutation_port.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import 'canonical_editor_legacy_bootstrap.dart';
import 'canonical_editor_production_runtime.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'editor_project_document.dart';

final class CanonicalEditorProductionHandle {
  CanonicalEditorProductionHandle._({
    required this.owner,
    required this.session,
    required this.wizardMutations,
    required this.binding,
    this.apartmentEngineeringPipeline,
  }) : runtimeConfig = CanonicalEditorProductionRuntimeConfig(
          resolveRuntime: (workspace, metadata) {
            if (metadata.projectId != owner.projectId.value ||
                workspace.building.building.id != binding.legacyBuildingId) {
              return null;
            }
            return CanonicalEditorResolvedRuntime(
              session: session,
              wizardMutations: wizardMutations,
              binding: binding,
              apartmentEngineeringPipeline: apartmentEngineeringPipeline,
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
  final ProjectWizardMutationPort wizardMutations;
  final CanonicalEditorWorkspaceBinding binding;

  /// Optional source-backed P9 capability supplied by the outer production
  /// composition root. The canonical bootstrap never fabricates electrical
  /// supply, load or protection inputs when this capability is absent.
  final ApartmentEngineeringPipeline? apartmentEngineeringPipeline;

  final CanonicalEditorProductionRuntimeConfig runtimeConfig;

  Future<void> saveCanonical() => owner.save();

  /// Publishes one successful Wizard commit into the same canonical persistence
  /// owner used by ordinary authoring. Foreign or already-acknowledged results
  /// fail closed through the canonical owner identity/version contract.
  void acceptWizardCommit(ReservedProjectMutationCommitResult result) {
    if (!identical(result.mutation.project, session.project)) {
      throw StateError(
        'Canonical production owner rejected a Wizard commit from a foreign '
        'mutation timeline.',
      );
    }
    owner.acceptMutation(
      sessionProject: session.project,
      result: result.mutation,
    );
  }

  /// Rebuilds only the legacy/canonical binding after structural projection.
  /// Owner, mutation session, Wizard port, engineering capability and Undo/Redo
  /// history stay shared.
  CanonicalEditorProductionHandle rebindToLegacy(
    EditorProjectDocument legacyDocument,
  ) {
    final bootstrap = CanonicalEditorLegacyBootstrap.create(legacyDocument);
    _validateLoadedSidecar(
      owner: owner,
      bootstrap: bootstrap,
      legacyDocument: legacyDocument,
    );
    return CanonicalEditorProductionHandle._(
      owner: owner,
      session: session,
      wizardMutations: wizardMutations,
      binding: bootstrap.binding,
      apartmentEngineeringPipeline: apartmentEngineeringPipeline,
    );
  }

  static Future<CanonicalEditorProductionHandle> loadOrBootstrap({
    required EditorProjectDocument legacyDocument,
    required ProjectRepository repository,
    ApartmentEngineeringPipeline? apartmentEngineeringPipeline,
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
    final mutations = ProjectMutationSession(owner.project);
    final idFactory = SecureRandomEntityIdFactory();
    final session = ProjectStructureAuthoringSession(
      mutations: mutations,
      idFactory: idFactory,
      navigation: navigation,
    );
    final wizardMutations = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: idFactory,
    );
    return CanonicalEditorProductionHandle._(
      owner: owner,
      session: session,
      wizardMutations: wizardMutations,
      binding: bootstrap.binding,
      apartmentEngineeringPipeline: apartmentEngineeringPipeline,
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
        legacySpace.boundary.vertices.length !=
            topology.orderedEdgeIds.length) {
      throw StateError(
        'Canonical sidecar geometry does not match materialized legacy space '
        '${entry.value}.',
      );
    }
    for (var index = 0; index < legacySpace.boundary.vertices.length; index++) {
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
  final selectedZoneId =
      legacyDocument.selectedZoneId == null || activeLevelId == null
          ? null
          : _canonicalForLegacy(
              binding.legacyZoneIds,
              legacyDocument.selectedZoneId!,
              where: (zoneId) =>
                  owner.project.index.zone(zoneId)?.levelId == activeLevelId,
            );
  final selectedSpaceId =
      legacyDocument.resume.selectedSpaceId == null || activeLevelId == null
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
