import 'generation_provenance.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';

/// Additive integrity checks for persisted P9 generation provenance.
///
/// The generated baseline fingerprint is the immutable hash of the original
/// generated payload. It intentionally is not recomputed from the current
/// canonical entity because manual overrides legitimately change that entity
/// while preserving the original baseline lineage.
abstract final class GenerationProvenanceIntegrityValidator {
  static final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');

  static List<GenerationProvenanceIssue> validate(
    GenerationProvenanceRegistry registry, {
    ProjectAggregateRoot? project,
  }) {
    final issues = <GenerationProvenanceIssue>[];

    for (final provenance in registry.entities.values) {
      if (!_sha256.hasMatch(provenance.generatedBaselineFingerprint)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.invalidBaseline,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Generated baseline fingerprint must be a canonical '
                'lowercase SHA-256 value.',
          ),
        );
      }

      final manifest = registry.manifests[provenance.generationId];
      if (manifest != null &&
          manifest.removedGenerationKeys.contains(provenance.generationKey)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            entityId: provenance.entityId,
            generationId: provenance.generationId,
            message: 'Active generationKey ${provenance.generationKey} is '
                'also recorded as removed in the generation manifest.',
          ),
        );
      }
    }

    if (project != null) {
      for (final manifest in registry.manifests.values) {
        _validateTargetLineage(project, manifest, issues);
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow(
    GenerationProvenanceRegistry registry, {
    ProjectAggregateRoot? project,
  }) {
    final issues = validate(registry, project: project);
    if (issues.isNotEmpty) {
      throw GenerationProvenanceValidationException(issues);
    }
  }

  static void _validateTargetLineage(
    ProjectAggregateRoot project,
    GenerationManifest manifest,
    List<GenerationProvenanceIssue> issues,
  ) {
    if (manifest.projectId != project.id) {
      issues.add(_lineageIssue(
        manifest,
        'Generation target project ${manifest.projectId} does not match '
        'canonical project ${project.id}.',
      ));
      return;
    }

    final stores = project.stores;
    final building = stores.buildings[manifest.buildingId];
    if (building == null || building.siteId != project.siteId) {
      issues.add(_lineageIssue(
        manifest,
        'Generation target building ${manifest.buildingId} is missing or '
        'belongs to a foreign site.',
      ));
      return;
    }

    final level = stores.levels[manifest.levelId];
    if (level == null || level.buildingId != manifest.buildingId) {
      issues.add(_lineageIssue(
        manifest,
        'Generation target level ${manifest.levelId} is missing or does not '
        'belong to building ${manifest.buildingId}.',
      ));
      return;
    }

    final zone = stores.zones[manifest.apartmentZoneId];
    if (zone == null ||
        zone.levelId != manifest.levelId ||
        zone.kind != ProjectStructuralZoneKind.apartment) {
      issues.add(_lineageIssue(
        manifest,
        'Generation target apartment zone ${manifest.apartmentZoneId} is '
        'missing, foreign, or not an apartment zone on ${manifest.levelId}.',
      ));
      return;
    }

    for (final entityId in manifest.generatedEntityIds) {
      if (!_belongsToTarget(entityId, stores, manifest, zone.spaceIds)) {
        issues.add(
          GenerationProvenanceIssue(
            code: GenerationProvenanceIssueCode.entityManifestMismatch,
            entityId: entityId,
            generationId: manifest.generationId,
            message: 'Generated entity $entityId is missing or does not '
                'belong to generation target ${manifest.apartmentZoneId}.',
          ),
        );
      }
    }
  }

  static GenerationProvenanceIssue _lineageIssue(
    GenerationManifest manifest,
    String message,
  ) =>
      GenerationProvenanceIssue(
        code: GenerationProvenanceIssueCode.entityManifestMismatch,
        generationId: manifest.generationId,
        message: message,
      );

  static bool _belongsToTarget(
    EntityId entityId,
    ProjectEntityStores stores,
    GenerationManifest manifest,
    Set<SpaceId> apartmentSpaceIds,
  ) {
    if (entityId is ZoneId) {
      return entityId == manifest.apartmentZoneId;
    }
    if (entityId is SpaceId) {
      final space = stores.spaces[entityId];
      return space != null &&
          space.levelId == manifest.levelId &&
          apartmentSpaceIds.contains(entityId);
    }
    if (entityId is OpeningId) {
      final opening = stores.openings[entityId];
      if (opening == null || opening.levelId != manifest.levelId) return false;
      return opening.connectedSpaceIds.any(apartmentSpaceIds.contains);
    }
    if (entityId is SpaceAdjacencyId) {
      final adjacency = stores.adjacencies[entityId];
      if (adjacency == null) return false;
      final a = stores.spaces[adjacency.spaceAId];
      final b = stores.spaces[adjacency.spaceBId];
      if (a == null || b == null) return false;
      return a.levelId == manifest.levelId &&
          b.levelId == manifest.levelId &&
          (apartmentSpaceIds.contains(adjacency.spaceAId) ||
              apartmentSpaceIds.contains(adjacency.spaceBId));
    }
    if (entityId is BoundaryEdgeId) {
      for (final entry in stores.boundaries.entries) {
        if (entry.value.edges.containsKey(entityId)) {
          final space = stores.spaces[entry.key];
          return space != null &&
              space.levelId == manifest.levelId &&
              apartmentSpaceIds.contains(entry.key);
        }
      }
      return false;
    }
    return false;
  }
}
