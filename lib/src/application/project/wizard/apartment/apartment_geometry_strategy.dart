import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_access_spine_geometry_generator.dart';
import 'apartment_geometry_generator.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

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
/// V2 accepts bounded semantic access trees/graphs as long as every interior
/// space is reachable from the circulation hub. Wet-core membership is a
/// proximity constraint, not a forced connected packing component: V2 removes
/// it from the spine-side grouping heuristic and validates the authoritative
/// maximum separation after packing instead.
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
    final packingValidation = TopologySemanticValidation(
      blockers: semanticValidation.blockers,
      preferenceMisses: semanticValidation.preferenceMisses,
      metrics: semanticValidation.metrics,
      geometryHandoff: TopologyGeometryHandoff(
        requiredSharedBoundaries: sourceHandoff.requiredSharedBoundaries,
        forbiddenSharedBoundaryPairs:
            sourceHandoff.forbiddenSharedBoundaryPairs,
        requiredExteriorSpaceKeys: sourceHandoff.requiredExteriorSpaceKeys,
        requiredExteriorAssignments: sourceHandoff.requiredExteriorAssignments,
        wetCoreGroups: const [],
        accessIntents: sourceHandoff.accessIntents,
        circulationAnchorKeys: sourceHandoff.circulationAnchorKeys,
        entrySpaceKey: sourceHandoff.entrySpaceKey,
      ),
    );
    final generated = const ApartmentAccessSpineGeometryGenerator(
      accessTopologyPolicy: ApartmentAccessTopologyPolicy.graphReachable,
    ).generate(
      fittedDraft: fittedDraft,
      semanticValidation: packingValidation,
      template: template,
      request: request,
    );
    final candidate = generated.candidate;
    if (candidate == null) {
      return generated;
    }

    final wetSeparationMm = _wetSeparation(
      sourceHandoff.wetCoreGroups,
      [...candidate.interiorSpaces, ...candidate.exteriorAppendages],
    );
    final wetIssue =
        wetSeparationMm > template.wetCorePolicy.maxGroupSeparationMm
            ? GeometryValidationIssue(
                code: 'p9.geometry.wet-core-too-dispersed',
                severity: GeometryValidationSeverity.blocker,
                facts: {
                  'actualMm': wetSeparationMm,
                  'maxMm': template.wetCorePolicy.maxGroupSeparationMm,
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
        failures: generated.failures,
      );
    }
    return ApartmentGeometryGenerationResult(
      candidate: checkedCandidate,
      failures: [
        ...generated.failures,
        P9Failure(
          code: wetIssue.code,
          stage: P9FailureStage.geometry,
          severity: P9FailureSeverity.blocker,
          facts: wetIssue.facts,
        ),
      ],
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
