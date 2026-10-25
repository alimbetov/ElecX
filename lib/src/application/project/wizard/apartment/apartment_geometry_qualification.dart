import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import 'apartment_geometry_generator.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

/// Production P9.6 entrypoint.
///
/// The low-level geometry generator builds a candidate. This wrapper performs
/// post-geometry qualification against the exact semantic handoff so a semantic
/// access edge can never disappear silently during geometry realization.
final class QualifiedApartmentGeometryGenerator {
  const QualifiedApartmentGeometryGenerator();

  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) {
    final generated = const ApartmentGeometryGenerator().generate(
      fittedDraft: fittedDraft,
      semanticValidation: semanticValidation,
      template: template,
      request: request,
    );
    final candidate = generated.candidate;
    if (candidate == null) {
      return generated;
    }

    final accessIssues = const ApartmentGeometryAccessValidator().validate(
      candidate: candidate,
      semanticValidation: semanticValidation,
      entrySpaceKey: fittedDraft.draft.circulation.entrySpaceKey,
    );
    if (accessIssues.isEmpty) {
      return generated;
    }

    final validation = GeometryValidationReport([
      ...candidate.validation.issues,
      ...accessIssues,
    ]);
    final qualified = ApartmentGeometryCandidate(
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
      validation: validation,
      geometryAlgorithmVersion: candidate.geometryAlgorithmVersion,
      geometryFingerprint: candidate.geometryFingerprint,
    );

    return ApartmentGeometryGenerationResult(
      candidate: qualified,
      failures: [
        ...generated.failures,
        P9Failure(
          code: 'p9.geometry.access-realization-invalid',
          stage: P9FailureStage.geometry,
          severity: P9FailureSeverity.blocker,
          facts: {
            'issueCount': accessIssues.length,
            'issueCodes': accessIssues.map((issue) => issue.code).join(','),
          },
        ),
      ],
    );
  }
}

/// Verifies semantic access after geometry has been built.
///
/// This is deliberately independent from the layout algorithm. P9.6 may evolve
/// from facade-strip to another bounded solver without weakening the invariant:
/// every semantic access edge must become an opening and every interior space
/// must remain reachable from the apartment entry through realized openings.
final class ApartmentGeometryAccessValidator {
  const ApartmentGeometryAccessValidator();

  List<GeometryValidationIssue> validate({
    required ApartmentGeometryCandidate candidate,
    required TopologySemanticValidation semanticValidation,
    required String entrySpaceKey,
  }) {
    final issues = <GeometryValidationIssue>[];
    final realizedOpenings = <String, GeometryOpeningKind>{};
    for (final opening in candidate.openingIntents) {
      if (opening.kind == GeometryOpeningKind.primaryEntry ||
          opening.fromSpaceKey == null ||
          opening.toSpaceKey == null) {
        continue;
      }
      final pair = SemanticSpacePair(
        opening.fromSpaceKey!,
        opening.toSpaceKey!,
      );
      realizedOpenings['${pair.stableKey}|${opening.kind.name}'] = opening.kind;
    }

    for (final intent in semanticValidation.geometryHandoff.accessIntents) {
      final expectedKind = intent.kind == DraftAccessKind.openPassage
          ? GeometryOpeningKind.openPassage
          : GeometryOpeningKind.door;
      final key = '${intent.pair.stableKey}|${expectedKind.name}';
      if (!realizedOpenings.containsKey(key)) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.required-opening-missing',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [intent.pair.leftKey, intent.pair.rightKey],
            facts: {'openingKind': expectedKind.name},
          ),
        );
      }
    }

    final primaryEntries = candidate.openingIntents
        .where(
          (opening) =>
              opening.kind == GeometryOpeningKind.primaryEntry &&
              opening.fromSpaceKey == entrySpaceKey,
        )
        .length;
    if (primaryEntries != 1) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.invalid-entry',
          severity: GeometryValidationSeverity.blocker,
          affectedKeys: [entrySpaceKey],
          facts: {'matchingPrimaryEntryCount': primaryEntries},
        ),
      );
    }

    final graph = <String, Set<String>>{};
    for (final opening in candidate.openingIntents) {
      final from = opening.fromSpaceKey;
      final to = opening.toSpaceKey;
      if (opening.kind == GeometryOpeningKind.primaryEntry ||
          from == null ||
          to == null) {
        continue;
      }
      graph.putIfAbsent(from, () => <String>{}).add(to);
      graph.putIfAbsent(to, () => <String>{}).add(from);
    }

    final visited = <String>{};
    if (entrySpaceKey.isNotEmpty) {
      visited.add(entrySpaceKey);
      final queue = <String>[entrySpaceKey];
      var index = 0;
      while (index < queue.length) {
        final current = queue[index++];
        final neighbors = (graph[current] ?? const <String>{}).toList()..sort();
        for (final next in neighbors) {
          if (visited.add(next)) {
            queue.add(next);
          }
        }
      }
    }

    for (final space in candidate.interiorSpaces) {
      if (!visited.contains(space.semanticKey)) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.unreachable-space',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [space.semanticKey],
            facts: {'entrySpaceKey': entrySpaceKey},
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }
}
