import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_access_spine_geometry_generator.dart';
import 'apartment_geometry_access_validator.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

/// Canonical P9.6 application boundary.
///
/// Production geometry is created by the access-preserving spine layout and is
/// selectable by P9.7+ only after structural validation and post-packing access
/// preservation have both passed.
final class ApartmentGeometryStage {
  const ApartmentGeometryStage();

  ApartmentGeometryStageResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) {
    final generated = const ApartmentAccessSpineGeometryGenerator().generate(
      fittedDraft: fittedDraft,
      semanticValidation: semanticValidation,
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

    final accessReport = const ApartmentGeometryAccessValidator().validate(
      candidate: rawCandidate,
      handoff: semanticValidation.geometryHandoff,
    );
    final combinedReport = GeometryValidationReport([
      ...rawCandidate.validation.issues,
      ...accessReport.issues,
    ]);
    final candidate = _copyWithValidation(rawCandidate, combinedReport);
    final failures = <P9Failure>[...generated.failures];
    final existingFailureCodes = failures.map((failure) => failure.code).toSet();
    for (final issue in accessReport.issues) {
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
