import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_geometry_access_validator.dart';
import 'apartment_geometry_handoff_builder.dart';
import 'apartment_geometry_strategy.dart';
import 'apartment_geometry_structural_validator.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

/// Canonical P9.6 application boundary.
///
/// Production geometry is selectable by P9.7+ only after the strategy-specific
/// report plus strategy-independent structural and semantic/access validation
/// have all passed.
final class ApartmentGeometryStage {
  const ApartmentGeometryStage({
    this.strategy = const GraphAwareApartmentGeometryStrategyV2(),
  });

  final ApartmentGeometryStrategy strategy;

  ApartmentGeometryStageResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) {
    final sourceGeometryHandoff = const ApartmentGeometryHandoffBuilder().build(
      fittedDraft.draft,
    );
    final geometryHandoff = _effectiveGeometryHandoff(
      sourceGeometryHandoff,
      request,
    );
    final effectiveSemanticValidation = TopologySemanticValidation(
      blockers: semanticValidation.blockers,
      preferenceMisses: semanticValidation.preferenceMisses,
      metrics: semanticValidation.metrics,
      geometryHandoff: geometryHandoff,
    );
    final generated = strategy.generate(
      fittedDraft: fittedDraft,
      semanticValidation: effectiveSemanticValidation,
      template: template,
      request: request,
    );
    final rawCandidate = generated.candidate;
    if (rawCandidate == null) {
      return ApartmentGeometryStageResult(
        candidate: null,
        failures: generated.failures,
      );
    }
    if (rawCandidate.geometryAlgorithmVersion != strategy.strategyId) {
      return ApartmentGeometryStageResult(
        candidate: null,
        failures: [
          ...generated.failures,
          P9Failure(
            code: 'p9.geometry.strategy-version-mismatch',
            stage: P9FailureStage.geometry,
            severity: P9FailureSeverity.blocker,
            facts: {
              'strategyId': strategy.strategyId,
              'candidateAlgorithmVersion':
                  rawCandidate.geometryAlgorithmVersion,
            },
          ),
        ],
      );
    }

    final accessReport = const ApartmentGeometryAccessValidator().validate(
      candidate: rawCandidate,
      handoff: geometryHandoff,
    );
    final structuralReport =
        const ApartmentGeometryStructuralValidator().validate(
      candidate: rawCandidate,
      fittedDraft: fittedDraft,
    );
    final postPackingIssues = [
      ...accessReport.issues,
      ...structuralReport.issues,
    ];
    final combinedReport = GeometryValidationReport([
      ...rawCandidate.validation.issues,
      ...postPackingIssues,
    ]);
    final candidate = _copyWithValidation(rawCandidate, combinedReport);
    final failures = <P9Failure>[...generated.failures];
    final existingFailureCodes =
        failures.map((failure) => failure.code).toSet();
    for (final issue in postPackingIssues) {
      if (issue.severity != GeometryValidationSeverity.blocker ||
          !existingFailureCodes.add(issue.code)) {
        continue;
      }
      failures.add(
        P9Failure(
          code: issue.code,
          stage: P9FailureStage.geometry,
          severity: P9FailureSeverity.blocker,
          facts: {
            ...issue.facts,
            if (issue.affectedKeys.isNotEmpty)
              'affectedKeys': issue.affectedKeys.join(','),
          },
        ),
      );
    }

    return ApartmentGeometryStageResult(
      candidate: candidate,
      failures: failures,
    );
  }

  TopologyGeometryHandoff _effectiveGeometryHandoff(
    TopologyGeometryHandoff source,
    NormalizedApartmentRequest request,
  ) {
    if (request.exteriorExposurePreference !=
        ApartmentExteriorExposurePreference.any) {
      return source;
    }
    return TopologyGeometryHandoff(
      requiredSharedBoundaries: source.requiredSharedBoundaries,
      forbiddenSharedBoundaryPairs: source.forbiddenSharedBoundaryPairs,
      requiredExteriorSpaceKeys: source.requiredExteriorSpaceKeys,
      requiredExteriorAssignments: const {},
      wetCoreGroups: source.wetCoreGroups,
      accessIntents: source.accessIntents,
      circulationAnchorKeys: source.circulationAnchorKeys,
      entrySpaceKey: source.entrySpaceKey,
    );
  }

  ApartmentGeometryCandidate _copyWithValidation(
    ApartmentGeometryCandidate source,
    GeometryValidationReport validation,
  ) =>
      ApartmentGeometryCandidate(
        templateId: source.templateId,
        templateVersion: source.templateVersion,
        family: source.family,
        variantSeedId: source.variantSeedId,
        areaFitFingerprint: source.areaFitFingerprint,
        interiorEnvelope: source.interiorEnvelope,
        interiorSpaces: source.interiorSpaces,
        exteriorAppendages: source.exteriorAppendages,
        sharedBoundaries: source.sharedBoundaries,
        exteriorBoundaries: source.exteriorBoundaries,
        openingIntents: source.openingIntents,
        metrics: source.metrics,
        validation: validation,
        geometryAlgorithmVersion: source.geometryAlgorithmVersion,
        geometryFingerprint: source.geometryFingerprint,
      );
}

final class ApartmentGeometryStageResult {
  ApartmentGeometryStageResult({
    required this.candidate,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final ApartmentGeometryCandidate? candidate;
  final List<P9Failure> failures;

  bool get accepted =>
      candidate != null &&
      candidate!.validation.accepted &&
      failures.every((failure) => !failure.isBlocker);
}
