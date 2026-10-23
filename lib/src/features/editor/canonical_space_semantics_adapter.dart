import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/project_space_semantics.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'editor_building_workspace.dart';

enum CanonicalSpaceSemanticsIssueCode {
  unsupportedBuilding,
  canonicalSpaceMissing,
  canonicalLevelMissing,
  legacyLevelBindingMissing,
  legacyLevelMissing,
  legacySpaceBindingMissing,
  legacySpaceMissing,
}

final class CanonicalSpaceSemanticsException implements Exception {
  const CanonicalSpaceSemanticsException({
    required this.code,
    required this.message,
    this.entityId,
  });

  final CanonicalSpaceSemanticsIssueCode code;
  final String message;
  final EntityId? entityId;

  @override
  String toString() => '${code.name}: $message';
}

/// Read-only P6E compatibility projection for the currently selected Space.
///
/// Canonical P6 semantics stay authoritative. The legacy [EngineeringSpace]
/// contributes transitional geometry only and is resolved exclusively through
/// explicit canonical-to-legacy bindings. No wall index, edge index or legacy
/// opening host is promoted back into the canonical project graph.
final class CanonicalSpaceSemanticsProjection {
  CanonicalSpaceSemanticsProjection({
    required this.projectId,
    required this.projectVersion,
    required this.space,
    required this.legacySpace,
    required Iterable<ProjectOpeningEntity> openings,
    required Iterable<ProjectSpaceAdjacencyEntity> adjacencies,
    required Iterable<ProjectOverlayClassificationEntity> overlays,
    required Map<SpaceId, ProjectSpaceEntity> adjacentSpaces,
  })  : openings = List.unmodifiable(openings),
        adjacencies = List.unmodifiable(adjacencies),
        overlays = List.unmodifiable(overlays),
        adjacentSpaces = Map.unmodifiable(adjacentSpaces);

  final ProjectId projectId;
  final LocalProjectVersion projectVersion;
  final ProjectSpaceEntity space;
  final EngineeringSpace legacySpace;
  final List<ProjectOpeningEntity> openings;
  final List<ProjectSpaceAdjacencyEntity> adjacencies;
  final List<ProjectOverlayClassificationEntity> overlays;
  final Map<SpaceId, ProjectSpaceEntity> adjacentSpaces;

  SpaceUsage get usage => space.usage;
  SpaceId get spaceId => space.id;
  LevelId get levelId => space.levelId;

  ProjectSpaceEntity? adjacentSpaceFor(ProjectSpaceAdjacencyEntity adjacency) {
    final otherId =
        adjacency.spaceAId == spaceId ? adjacency.spaceBId : adjacency.spaceAId;
    return adjacentSpaces[otherId];
  }
}

final class CanonicalSpaceSemanticsAdapter {
  const CanonicalSpaceSemanticsAdapter({
    required this.workspace,
    required this.binding,
  });

  final EditorBuildingWorkspace workspace;
  final CanonicalEditorWorkspaceBinding binding;

  CanonicalSpaceSemanticsProjection resolve({
    required ProjectAggregateRoot project,
    required SpaceId spaceId,
  }) {
    if (workspace.building.building.id != binding.legacyBuildingId) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.unsupportedBuilding,
        entityId: binding.buildingId,
        message: 'The editor workspace is not the legacy Building bound to '
            '${binding.buildingId}.',
      );
    }

    final space = project.index.space(spaceId);
    if (space == null) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.canonicalSpaceMissing,
        entityId: spaceId,
        message: 'Canonical Space $spaceId does not exist.',
      );
    }

    final level = project.index.level(space.levelId);
    if (level == null || level.buildingId != binding.buildingId) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.canonicalLevelMissing,
        entityId: space.levelId,
        message: 'Canonical Space $spaceId is outside the bound Building '
            '${binding.buildingId}.',
      );
    }

    final legacyLevelId = binding.legacyLevelIds[level.id];
    if (legacyLevelId == null) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.legacyLevelBindingMissing,
        entityId: level.id,
        message: 'No legacy Level binding exists for canonical Level '
            '${level.id}.',
      );
    }

    final legacyLevel = workspace.building.levels
        .where((candidate) => candidate.level.id == legacyLevelId)
        .firstOrNull;
    if (legacyLevel == null) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.legacyLevelMissing,
        entityId: level.id,
        message: 'Bound legacy Level $legacyLevelId does not exist.',
      );
    }

    final legacySpaceId = binding.legacySpaceIds[spaceId];
    if (legacySpaceId == null) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.legacySpaceBindingMissing,
        entityId: spaceId,
        message: 'No legacy Space binding exists for canonical Space $spaceId.',
      );
    }

    final legacySpace = legacyLevel.level.spaces
        .where((candidate) => candidate.id == legacySpaceId)
        .firstOrNull;
    if (legacySpace == null) {
      throw CanonicalSpaceSemanticsException(
        code: CanonicalSpaceSemanticsIssueCode.legacySpaceMissing,
        entityId: spaceId,
        message: 'Bound legacy Space $legacySpaceId does not exist on Level '
            '$legacyLevelId.',
      );
    }

    final openings = _sortedById<ProjectOpeningEntity>(
      project.index.openingsBySpaceId[spaceId]
              ?.map(project.index.opening)
              .whereType<ProjectOpeningEntity>() ??
          const <ProjectOpeningEntity>[],
      (value) => value.id,
    );
    final adjacencies = _sortedById<ProjectSpaceAdjacencyEntity>(
      project.index.adjacenciesBySpaceId[spaceId]
              ?.map(project.index.adjacency)
              .whereType<ProjectSpaceAdjacencyEntity>() ??
          const <ProjectSpaceAdjacencyEntity>[],
      (value) => value.id,
    );
    final overlays = _sortedById<ProjectOverlayClassificationEntity>(
      project.index.overlaysBySpaceId[spaceId]
              ?.map(project.index.overlay)
              .whereType<ProjectOverlayClassificationEntity>() ??
          const <ProjectOverlayClassificationEntity>[],
      (value) => value.id,
    );
    final adjacentSpaces = <SpaceId, ProjectSpaceEntity>{};
    for (final opening in openings) {
      for (final connectedSpaceId in opening.connectedSpaceIds) {
        if (connectedSpaceId == spaceId) continue;
        final connected = project.index.space(connectedSpaceId);
        if (connected != null) adjacentSpaces[connected.id] = connected;
      }
    }
    for (final adjacency in adjacencies) {
      final otherId = adjacency.spaceAId == spaceId
          ? adjacency.spaceBId
          : adjacency.spaceAId;
      final other = project.index.space(otherId);
      if (other != null) adjacentSpaces[other.id] = other;
    }

    return CanonicalSpaceSemanticsProjection(
      projectId: project.id,
      projectVersion: project.version,
      space: space,
      legacySpace: legacySpace,
      openings: openings,
      adjacencies: adjacencies,
      overlays: overlays,
      adjacentSpaces: adjacentSpaces,
    );
  }
}

List<T> _sortedById<T>(Iterable<T> source, EntityId Function(T value) idOf) {
  final values = List<T>.of(source);
  values.sort((a, b) => idOf(a).toString().compareTo(idOf(b).toString()));
  return values;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
