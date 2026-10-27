import 'applied_engineering_proposal.dart';
import 'boundary_construction_registry.dart';
import 'boundary_edge_identity_registry.dart';
import 'boundary_host_registry.dart';
import 'boundary_wall_profile_registry.dart';
import 'generation_provenance.dart';

/// Canonical engineering orientation for ElecX project-space coordinates.
///
/// This value deliberately does not imply geographic, magnetic or device
/// north. It only answers where Project North points inside the canonical plan
/// XY frame (+X right, +Y up).
final class ProjectEngineeringNorth {
  const ProjectEngineeringNorth._(this.milliDegreesClockwiseFromPositiveY);

  static const int fullTurnMilliDegrees = 360000;
  static const double fullTurnDegrees = 360.0;

  /// Normalized canonical storage value in [0, 360000).
  final int milliDegreesClockwiseFromPositiveY;

  /// Creates canonical Project North from a user/import angle.
  ///
  /// Input is normalized in degree space before milli-degree quantization. This
  /// keeps extreme-but-finite values away from the integer storage boundary and
  /// makes wrap-around rounding deterministic.
  factory ProjectEngineeringNorth.fromDegrees(double degrees) {
    if (!degrees.isFinite) {
      throw ArgumentError.value(
        degrees,
        'degrees',
        'Project North must be finite.',
      );
    }

    var normalizedDegrees = degrees % fullTurnDegrees;
    if (normalizedDegrees < 0) normalizedDegrees += fullTurnDegrees;

    final milliDegrees = (normalizedDegrees * 1000).round();
    return ProjectEngineeringNorth._(_normalizeMilliDegrees(milliDegrees));
  }

  /// Creates Project North from already-normalized persisted canonical data.
  ///
  /// Persistence decoding is intentionally strict: malformed/out-of-range
  /// values fail rather than being silently normalized.
  factory ProjectEngineeringNorth.fromNormalizedMilliDegrees(int milliDegrees) {
    if (milliDegrees < 0 || milliDegrees >= fullTurnMilliDegrees) {
      throw RangeError.range(
        milliDegrees,
        0,
        fullTurnMilliDegrees - 1,
        'milliDegrees',
        'Persisted Project North must already be normalized.',
      );
    }
    return ProjectEngineeringNorth._(milliDegrees);
  }

  double get degrees => milliDegreesClockwiseFromPositiveY / 1000.0;

  static int _normalizeMilliDegrees(int value) {
    var result = value % fullTurnMilliDegrees;
    if (result < 0) result += fullTurnMilliDegrees;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectEngineeringNorth &&
      other.milliDegreesClockwiseFromPositiveY ==
          milliDegreesClockwiseFromPositiveY;

  @override
  int get hashCode => milliDegreesClockwiseFromPositiveY.hashCode;

  @override
  String toString() =>
      'ProjectEngineeringNorth(${degrees.toStringAsFixed(3)}°)';
}

/// Canonical root-level engineering metadata.
///
/// Null Project North means the engineer has not confirmed project orientation.
/// It must never be interpreted as an implicit 0°.
///
/// [boundaryEdgeIdentityRegistry] is a durable tombstone ledger, not editor
/// session state. It survives save/reopen and guarantees that a BoundaryEdgeId
/// can never be re-parented to another SpaceId later in the project lifecycle.
///
/// [boundaryHostedObjectRegistry] is the P7A-5 authoritative wall-host
/// ownership map for openings, components, cable endpoints and route anchors.
///
/// [boundaryWallProfileRegistry] owns non-default wall profile payloads by the
/// same stable `(SpaceId, BoundaryEdgeId)` identity so split/merge can transform
/// profile geometry inside the same canonical mutation.
///
/// [boundaryConstructionRegistry] owns physical wall thickness/material data.
/// It is intentionally separate from wall elevation geometry and is the only
/// canonical source a penetration authoring flow may use for wall thickness.
///
/// [generationProvenanceRegistry] is the P9.12 canonical lineage store. It is
/// versioned/persisted project state and therefore participates in the same
/// preview, commit and Undo/Redo lifecycle as every other root metadata field.
///
/// [appliedEngineeringProposalRegistry] stores the exact frozen P9 engineering
/// proposal committed by Apply. It is deliberately independent from wizard
/// application classes while retaining canonical D8 output serializations.
final class ProjectEngineeringMetadata {
  const ProjectEngineeringMetadata({
    this.projectNorth,
    this.boundaryEdgeIdentityRegistry =
        const BoundaryEdgeIdentityRegistry.empty(),
    this.boundaryHostedObjectRegistry =
        const BoundaryHostedObjectRegistry.empty(),
    this.boundaryWallProfileRegistry =
        const BoundaryWallProfileRegistry.empty(),
    this.boundaryConstructionRegistry =
        const BoundaryConstructionRegistry.empty(),
    this.generationProvenanceRegistry =
        const GenerationProvenanceRegistry.empty(),
    this.appliedEngineeringProposalRegistry =
        const AppliedEngineeringProposalRegistry.empty(),
  });

  final ProjectEngineeringNorth? projectNorth;
  final BoundaryEdgeIdentityRegistry boundaryEdgeIdentityRegistry;
  final BoundaryHostedObjectRegistry boundaryHostedObjectRegistry;
  final BoundaryWallProfileRegistry boundaryWallProfileRegistry;
  final BoundaryConstructionRegistry boundaryConstructionRegistry;
  final GenerationProvenanceRegistry generationProvenanceRegistry;
  final AppliedEngineeringProposalRegistry appliedEngineeringProposalRegistry;

  ProjectEngineeringMetadata copyWith({
    ProjectEngineeringNorth? projectNorth,
    bool clearProjectNorth = false,
    BoundaryEdgeIdentityRegistry? boundaryEdgeIdentityRegistry,
    BoundaryHostedObjectRegistry? boundaryHostedObjectRegistry,
    BoundaryWallProfileRegistry? boundaryWallProfileRegistry,
    BoundaryConstructionRegistry? boundaryConstructionRegistry,
    GenerationProvenanceRegistry? generationProvenanceRegistry,
    AppliedEngineeringProposalRegistry? appliedEngineeringProposalRegistry,
  }) {
    if (clearProjectNorth && projectNorth != null) {
      throw ArgumentError(
        'projectNorth and clearProjectNorth cannot be supplied together.',
      );
    }
    return ProjectEngineeringMetadata(
      projectNorth:
          clearProjectNorth ? null : projectNorth ?? this.projectNorth,
      boundaryEdgeIdentityRegistry:
          boundaryEdgeIdentityRegistry ?? this.boundaryEdgeIdentityRegistry,
      boundaryHostedObjectRegistry:
          boundaryHostedObjectRegistry ?? this.boundaryHostedObjectRegistry,
      boundaryWallProfileRegistry:
          boundaryWallProfileRegistry ?? this.boundaryWallProfileRegistry,
      boundaryConstructionRegistry:
          boundaryConstructionRegistry ?? this.boundaryConstructionRegistry,
      generationProvenanceRegistry:
          generationProvenanceRegistry ?? this.generationProvenanceRegistry,
      appliedEngineeringProposalRegistry: appliedEngineeringProposalRegistry ??
          this.appliedEngineeringProposalRegistry,
    );
  }

  ProjectEngineeringMetadata withProjectNorth(ProjectEngineeringNorth north) =>
      copyWith(projectNorth: north);

  ProjectEngineeringMetadata withoutProjectNorth() =>
      copyWith(clearProjectNorth: true);

  ProjectEngineeringMetadata withBoundaryEdgeIdentityRegistry(
    BoundaryEdgeIdentityRegistry registry,
  ) =>
      copyWith(boundaryEdgeIdentityRegistry: registry);

  ProjectEngineeringMetadata withBoundaryHostedObjectRegistry(
    BoundaryHostedObjectRegistry registry,
  ) =>
      copyWith(boundaryHostedObjectRegistry: registry);

  ProjectEngineeringMetadata withBoundaryWallProfileRegistry(
    BoundaryWallProfileRegistry registry,
  ) =>
      copyWith(boundaryWallProfileRegistry: registry);

  ProjectEngineeringMetadata withBoundaryConstructionRegistry(
    BoundaryConstructionRegistry registry,
  ) =>
      copyWith(boundaryConstructionRegistry: registry);

  ProjectEngineeringMetadata withGenerationProvenanceRegistry(
    GenerationProvenanceRegistry registry,
  ) =>
      copyWith(generationProvenanceRegistry: registry);

  ProjectEngineeringMetadata withAppliedEngineeringProposalRegistry(
    AppliedEngineeringProposalRegistry registry,
  ) =>
      copyWith(appliedEngineeringProposalRegistry: registry);

  @override
  bool operator ==(Object other) =>
      other is ProjectEngineeringMetadata &&
      other.projectNorth == projectNorth &&
      other.boundaryEdgeIdentityRegistry.sameAs(boundaryEdgeIdentityRegistry) &&
      other.boundaryHostedObjectRegistry.sameAs(boundaryHostedObjectRegistry) &&
      other.boundaryWallProfileRegistry.sameAs(boundaryWallProfileRegistry) &&
      other.boundaryConstructionRegistry.sameAs(boundaryConstructionRegistry) &&
      other.generationProvenanceRegistry.sameAs(generationProvenanceRegistry) &&
      other.appliedEngineeringProposalRegistry
          .sameAs(appliedEngineeringProposalRegistry);

  @override
  int get hashCode {
    var result = projectNorth.hashCode;
    final entries = boundaryEdgeIdentityRegistry.owners.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    for (final entry in entries) {
      result = Object.hash(result, entry.key, entry.value);
    }
    final hostedEntries = boundaryHostedObjectRegistry.references.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in hostedEntries) {
      final reference = entry.value;
      result = Object.hash(
        result,
        entry.key,
        reference.objectKind,
        reference.host,
        reference.geometryKind,
        reference.startOffsetMm,
        reference.endOffsetMm,
      );
    }
    final profileEntries = boundaryWallProfileRegistry.profiles.entries.toList()
      ..sort((a, b) {
        final bySpace = a.key.spaceId.value.compareTo(b.key.spaceId.value);
        if (bySpace != 0) return bySpace;
        return a.key.edgeId.value.compareTo(b.key.edgeId.value);
      });
    for (final entry in profileEntries) {
      result = Object.hash(result, entry.key);
      for (final point in entry.value.vertices) {
        result = Object.hash(result, point.xMm, point.yMm);
      }
    }
    final constructionEntries =
        boundaryConstructionRegistry.profiles.entries.toList()
          ..sort((a, b) {
            final bySpace = a.key.spaceId.value.compareTo(b.key.spaceId.value);
            if (bySpace != 0) return bySpace;
            return a.key.edgeId.value.compareTo(b.key.edgeId.value);
          });
    for (final entry in constructionEntries) {
      result = Object.hash(
        result,
        entry.key,
        entry.value.kind,
        entry.value.thicknessMm,
        entry.value.materialId,
        entry.value.fireRatingId,
      );
    }
    final manifests = generationProvenanceRegistry.manifests.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    for (final entry in manifests) {
      final manifest = entry.value;
      result = Object.hash(
        result,
        entry.key,
        manifest.selectedCandidateFingerprint,
        manifest.normalizedIntentFingerprint,
      );
    }
    final provenances = generationProvenanceRegistry.entities.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    for (final entry in provenances) {
      final provenance = entry.value;
      result = Object.hash(
        result,
        entry.key,
        provenance.generationId,
        provenance.generationKey,
        provenance.generatedBaselineFingerprint,
        provenance.lockedFromRegeneration,
      );
      final overridden = provenance.overriddenProperties.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final key in overridden) {
        result = Object.hash(result, key);
      }
    }
    final applied = appliedEngineeringProposalRegistry.byLevel.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    for (final entry in applied) {
      final snapshot = entry.value;
      result = Object.hash(
        result,
        entry.key,
        snapshot.proposalFingerprint,
        snapshot.outputFingerprint,
        snapshot.requirementsFingerprint,
      );
    }
    return result;
  }
}
