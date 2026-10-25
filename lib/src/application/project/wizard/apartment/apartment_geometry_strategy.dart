import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_access_spine_geometry_generator.dart';
import 'apartment_geometry_access_validator.dart';
import 'apartment_geometry_generator.dart';
import 'apartment_geometry_structural_validator.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

/// Versioned P9.6 packing strategy boundary.
///
/// P9.4 fitted areas and P9.5 semantic constraints are strategy-independent.
/// Different bounded geometry solvers may be qualified against the same input
/// without changing upstream fingerprints or allocating canonical project IDs.
abstract interface class ApartmentGeometryStrategy {
  String get strategyId;

  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  });
}

/// Historical access-spine strategy retained as an explicit V1 implementation.
///
/// V1 accepts only hub-and-spoke semantic access: every non-hub interior space
/// must have a direct access edge to the distribution hub.
final class AccessSpineApartmentGeometryStrategyV1
    implements ApartmentGeometryStrategy {
  const AccessSpineApartmentGeometryStrategyV1();

  @override
  String get strategyId =>
      ApartmentAccessSpineGeometryGenerator.accessSpineV1AlgorithmVersion;

  @override
  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) =>
      const ApartmentAccessSpineGeometryGenerator().generate(
        fittedDraft: fittedDraft,
        semanticValidation: semanticValidation,
        template: template,
        request: request,
      );
}

/// Graph-aware P9.6 strategy.
///
/// V2 owns a bounded deterministic solver portfolio. Access-spine packing is
/// attempted first. If it cannot satisfy geometry, access, structural, or
/// wet-core proximity contracts, the bounded facade-strip solver is evaluated
/// as a second backend. A backend is never selected merely because it produced
/// geometry.
///
/// Wet-core membership remains a proximity constraint. The access-spine
/// backend uses each wet group only as a deterministic co-location heuristic;
/// the authoritative maximum separation is still validated independently after
/// packing and therefore cannot be bypassed by the heuristic.
final class GraphAwareApartmentGeometryStrategyV2
    implements ApartmentGeometryStrategy {
  const GraphAwareApartmentGeometryStrategyV2();

  @override
  String get strategyId =>
      ApartmentAccessSpineGeometryGenerator.graphAwareV2AlgorithmVersion;

  @override
  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) {
    final sourceHandoff = semanticValidation.geometryHandoff;
    final packingHandoff = TopologyGeometryHandoff(
      requiredSharedBoundaries: sourceHandoff.requiredSharedBoundaries,
      forbiddenSharedBoundaryPairs: sourceHandoff.forbiddenSharedBoundaryPairs,
      requiredExteriorSpaceKeys: sourceHandoff.requiredExteriorSpaceKeys,
      requiredExteriorAssignments: sourceHandoff.requiredExteriorAssignments,
      wetCoreGroups: sourceHandoff.wetCoreGroups,
      accessIntents: sourceHandoff.accessIntents,
      circulationAnchorKeys: sourceHandoff.circulationAnchorKeys,
      entrySpaceKey: sourceHandoff.entrySpaceKey,
    );
    final packingValidation = TopologySemanticValidation(
      blockers: semanticValidation.blockers,
      preferenceMisses: semanticValidation.preferenceMisses,
      metrics: semanticValidation.metrics,
      geometryHandoff: packingHandoff,
    );

    final primary = const ApartmentAccessSpineGeometryGenerator(
      accessTopologyPolicy: ApartmentAccessTopologyPolicy.graphReachable,
    ).generate(
      fittedDraft: fittedDraft,
      semanticValidation: packingValidation,
      template: template,
      request: request,
    );
    final primaryBaseAccepted = _backendAccepted(
      primary.candidate,
      fittedDraft: fittedDraft,
      handoff: packingHandoff,
    );
    final primaryWetSeparation = _candidateWetSeparation(
      primary.candidate,
      sourceHandoff.wetCoreGroups,
    );
    final maxWetSeparation = template.wetCorePolicy.maxGroupSeparationMm;
    final primaryQualified = primaryBaseAccepted &&
        primaryWetSeparation != null &&
        primaryWetSeparation <= maxWetSeparation;

    ApartmentGeometryGenerationResult selected = primary;
    if (!primaryQualified) {
      final fallback = const ApartmentGeometryGenerator().generate(
        fittedDraft: fittedDraft,
        semanticValidation: packingValidation,
        template: template,
        request: request,
      );
      final fallbackBaseAccepted = _backendAccepted(
        fallback.candidate,
        fittedDraft: fittedDraft,
        handoff: packingHandoff,
      );
      final fallbackWetSeparation = _candidateWetSeparation(
        fallback.candidate,
        sourceHandoff.wetCoreGroups,
      );
      final fallbackQualified = fallbackBaseAccepted &&
          fallbackWetSeparation != null &&
          fallbackWetSeparation <= maxWetSeparation;

      if (fallbackQualified) {
        selected = fallback;
      } else if (primaryBaseAccepted && fallbackBaseAccepted) {
        final primaryWet = primaryWetSeparation ?? 1 << 30;
        final fallbackWet = fallbackWetSeparation ?? 1 << 30;
        selected = fallbackWet < primaryWet ? fallback : primary;
      } else if (!primaryBaseAccepted && fallbackBaseAccepted) {
        selected = fallback;
      } else if (primary.candidate == null && fallback.candidate != null) {
        selected = fallback;
      }
    }

    final selectedCandidate = selected.candidate;
    if (selectedCandidate == null) {
      return selected;
    }
    final candidate = _adoptBackendCandidate(selectedCandidate);

    final wetSeparationMm = _wetSeparation(
      sourceHandoff.wetCoreGroups,
      [...candidate.interiorSpaces, ...candidate.exteriorAppendages],
    );
    final wetIssue = wetSeparationMm > maxWetSeparation
        ? GeometryValidationIssue(
            code: 'p9.geometry.wet-core-too-dispersed',
            severity: GeometryValidationSeverity.blocker,
            facts: {
              'actualMm': wetSeparationMm,
              'maxMm': maxWetSeparation,
            },
          )
        : null;
    final validation = GeometryValidationReport([
      ...candidate.validation.issues,
      if (wetIssue != null) wetIssue,
    ]);
    final metrics = GeometryMetrics(
      interiorAreaMm2: candidate.metrics.interiorAreaMm2,
      appendageAreaMm2: candidate.metrics.appendageAreaMm2,
      maxAreaErrorMm2: candidate.metrics.maxAreaErrorMm2,
      sharedBoundaryLengthMm: candidate.metrics.sharedBoundaryLengthMm,
      exteriorExposureLengthMm: candidate.metrics.exteriorExposureLengthMm,
      wetCoreMaxSeparationMm: wetSeparationMm,
    );
    final checkedCandidate = ApartmentGeometryCandidate(
      templateId: candidate.templateId,
      templateVersion: candidate.templateVersion,
      family: candidate.family,
      variantSeedId: candidate.variantSeedId,
      areaFitFingerprint: candidate.areaFitFingerprint,
      interiorEnvelope: candidate.interiorEnvelope,
      interiorSpaces: candidate.interiorSpaces,
      exteriorAppendages: candidate.exteriorAppendages,
      sharedBoundaries: candidate.sharedBoundaries,
      exteriorBoundaries: candidate.exteriorBoundaries,
      openingIntents: candidate.openingIntents,
      metrics: metrics,
      validation: validation,
      geometryAlgorithmVersion: candidate.geometryAlgorithmVersion,
      geometryFingerprint: candidate.geometryFingerprint,
    );
    if (wetIssue == null) {
      return ApartmentGeometryGenerationResult(
        candidate: checkedCandidate,
        failures: selected.failures,
      );
    }
    return ApartmentGeometryGenerationResult(
      candidate: checkedCandidate,
      failures: [
        ...selected.failures,
        P9Failure(
          code: wetIssue.code,
          stage: P9FailureStage.geometry,
          severity: P9FailureSeverity.blocker,
          facts: wetIssue.facts,
        ),
      ],
    );
  }

  bool _backendAccepted(
    ApartmentGeometryCandidate? candidate, {
    required AreaFittedTopologyDraft fittedDraft,
    required TopologyGeometryHandoff handoff,
  }) {
    if (candidate == null || !candidate.validation.accepted) {
      return false;
    }
    final access = const ApartmentGeometryAccessValidator().validate(
      candidate: candidate,
      handoff: handoff,
    );
    if (!access.accepted) {
      return false;
    }
    final structural = const ApartmentGeometryStructuralValidator().validate(
      candidate: candidate,
      fittedDraft: fittedDraft,
    );
    return structural.accepted;
  }

  int? _candidateWetSeparation(
    ApartmentGeometryCandidate? candidate,
    List<List<String>> wetCoreGroups,
  ) {
    if (candidate == null) {
      return null;
    }
    return _wetSeparation(
      wetCoreGroups,
      [...candidate.interiorSpaces, ...candidate.exteriorAppendages],
    );
  }

  ApartmentGeometryCandidate _adoptBackendCandidate(
    ApartmentGeometryCandidate candidate,
  ) {
    if (candidate.geometryAlgorithmVersion == strategyId) {
      return candidate;
    }
    final fingerprint = p9Sha256Hex(
      'p9.apartment.geometry.strategy\n'
      'strategy=$strategyId\n'
      'backend=${candidate.geometryAlgorithmVersion}\n'
      'backendFingerprint=${candidate.geometryFingerprint}',
    );
    return ApartmentGeometryCandidate(
      templateId: candidate.templateId,
      templateVersion: candidate.templateVersion,
      family: candidate.family,
      variantSeedId: candidate.variantSeedId,
      areaFitFingerprint: candidate.areaFitFingerprint,
      interiorEnvelope: candidate.interiorEnvelope,
      interiorSpaces: candidate.interiorSpaces,
      exteriorAppendages: candidate.exteriorAppendages,
      sharedBoundaries: candidate.sharedBoundaries,
      exteriorBoundaries: candidate.exteriorBoundaries,
      openingIntents: candidate.openingIntents,
      metrics: candidate.metrics,
      validation: candidate.validation,
      geometryAlgorithmVersion: strategyId,
      geometryFingerprint: fingerprint,
    );
  }
}

int _wetSeparation(
  List<List<String>> groups,
  List<GeneratedSpaceGeometry> spaces,
) {
  final byKey = {for (final space in spaces) space.semanticKey: space};
  var maximum = 0;
  for (final group in groups) {
    for (var first = 0; first < group.length; first++) {
      for (var second = first + 1; second < group.length; second++) {
        final a = byKey[group[first]];
        final b = byKey[group[second]];
        if (a == null || b == null) {
          continue;
        }
        final dx = _axisGap(
          a.polygon.minX,
          a.polygon.maxX,
          b.polygon.minX,
          b.polygon.maxX,
        );
        final dy = _axisGap(
          a.polygon.minY,
          a.polygon.maxY,
          b.polygon.minY,
          b.polygon.maxY,
        );
        final separation = dx + dy;
        if (separation > maximum) {
          maximum = separation;
        }
      }
    }
  }
  return maximum;
}

int _axisGap(int aMin, int aMax, int bMin, int bMax) {
  if (aMax < bMin) {
    return bMin - aMax;
  }
  if (bMax < aMin) {
    return aMin - bMax;
  }
  return 0;
}
