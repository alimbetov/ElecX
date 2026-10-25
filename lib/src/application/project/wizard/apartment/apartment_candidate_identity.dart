import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_candidate_ranking.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_sha256.dart';

/// Exact transient identity for one qualified/ranked P9 apartment candidate.
///
/// This is deliberately distinct from `geometryFingerprint`:
/// geometry identifies the realized P9.6 shape, while candidate identity also
/// binds the user intent and the versioned P9.7 scoring semantics. It never
/// contains canonical project entity IDs, rank position or presentation state.
final class ApartmentCandidateIdentity {
  const ApartmentCandidateIdentity({
    required this.candidateFingerprint,
    required this.intentFingerprint,
    required this.catalogVersion,
    required this.generatorVersion,
    required this.templateIdValue,
    required this.templateVersion,
    required this.variantSeedId,
    required this.geometryAlgorithmVersion,
    required this.geometryFingerprint,
    required this.scoringProfileVersion,
  });

  final String candidateFingerprint;
  final String intentFingerprint;
  final int catalogVersion;
  final String generatorVersion;
  final String templateIdValue;
  final int templateVersion;
  final String variantSeedId;
  final String geometryAlgorithmVersion;
  final String geometryFingerprint;
  final String scoringProfileVersion;

  ApartmentCandidateSelection toSelection() => ApartmentCandidateSelection(
        candidateFingerprint: candidateFingerprint,
        templateIdValue: templateIdValue,
        templateVersion: templateVersion,
        variantSeedId: variantSeedId,
      );

  bool matchesSelection(ApartmentCandidateSelection selection) =>
      selection.candidateFingerprint == candidateFingerprint &&
      selection.templateIdValue == templateIdValue &&
      selection.templateVersion == templateVersion &&
      selection.variantSeedId == variantSeedId;
}

/// Identity envelope for the ordered card set exposed by P9.9.
///
/// Candidate order is intentionally part of the set fingerprint because it is
/// the deterministic P9.7 recommendation order. Rank position remains absent
/// from each individual [ApartmentCandidateIdentity].
final class ApartmentCandidateSetIdentity {
  ApartmentCandidateSetIdentity({
    required this.intentFingerprint,
    required this.catalogVersion,
    required this.generatorVersion,
    required this.scoringProfileVersion,
    required this.diversityPolicyVersion,
    required Iterable<ApartmentCandidateIdentity> orderedCandidates,
    required this.candidateSetFingerprint,
  }) : orderedCandidates = List.unmodifiable(orderedCandidates);

  final String intentFingerprint;
  final int catalogVersion;
  final String generatorVersion;
  final String scoringProfileVersion;
  final String diversityPolicyVersion;
  final List<ApartmentCandidateIdentity> orderedCandidates;
  final String candidateSetFingerprint;

  ApartmentCandidateIdentity? resolveSelection(
    ApartmentCandidateSelection selection,
  ) {
    for (final candidate in orderedCandidates) {
      if (candidate.matchesSelection(selection)) {
        return candidate;
      }
    }
    return null;
  }

  bool containsSelection(ApartmentCandidateSelection selection) =>
      resolveSelection(selection) != null;
}

/// Deterministic P9 candidate identity boundary used by P9.9 session state.
///
/// Stable inputs:
/// - normalized user intent;
/// - catalog/provider/generator versions;
/// - topology identity;
/// - P9.4/P9.6 fingerprints;
/// - versioned P9.7 score breakdown.
///
/// Explicitly excluded:
/// ranking position, vector scene/SVG, locale, theme, responsive width,
/// orientation, input modality, zoom/pan and canonical project entity IDs.
final class ApartmentCandidateIdentityService {
  const ApartmentCandidateIdentityService();

  static const String candidateIdentitySchemaVersion =
      'p9.candidate.identity.v1';
  static const String candidateSetIdentitySchemaVersion =
      'p9.candidate-set.identity.v1';

  ApartmentCandidateIdentity identifyCandidate({
    required NormalizedApartmentRequest request,
    required RankedApartmentCandidate rankedCandidate,
    required int catalogVersion,
    required String generatorVersion,
  }) {
    _requirePositive(catalogVersion, 'catalogVersion');
    final normalizedGeneratorVersion =
        _requireNonEmpty(generatorVersion, 'generatorVersion');
    final candidate = rankedCandidate.candidate;
    if (!candidate.validation.accepted) {
      throw ArgumentError(
        'Candidate identity may only be created for accepted P9.6 geometry.',
      );
    }
    if (request.intentFingerprint.trim().isEmpty) {
      throw ArgumentError.value(
        request.intentFingerprint,
        'request.intentFingerprint',
        'Must be non-empty.',
      );
    }

    final breakdown = rankedCandidate.breakdown;
    final canonical = <String>[
      candidateIdentitySchemaVersion,
      'requestSchemaVersion=${request.schemaVersion}',
      'intentFingerprint=${request.intentFingerprint}',
      'catalogVersion=$catalogVersion',
      'generatorVersion=$normalizedGeneratorVersion',
      'templateId=${candidate.templateId.value}',
      'templateVersion=${candidate.templateVersion}',
      'family=${candidate.family.code}',
      'variantSeedId=${candidate.variantSeedId}',
      'areaFitFingerprint=${candidate.areaFitFingerprint}',
      'geometryAlgorithmVersion=${candidate.geometryAlgorithmVersion}',
      'geometryFingerprint=${candidate.geometryFingerprint}',
      'scoringProfileVersion=${breakdown.scoringProfileVersion}',
      for (final metric in ApartmentScoreMetric.values) ...[
        'metric.${metric.name}.scoreBp=${_metricValue(breakdown.metricScoreBp, metric, 'metricScoreBp')}',
        'metric.${metric.name}.weightedContributionBp=${_metricValue(breakdown.weightedContributionBp, metric, 'weightedContributionBp')}',
      ],
      'finalScoreBp=${breakdown.finalScoreBp}',
    ].join('\n');

    return ApartmentCandidateIdentity(
      candidateFingerprint: p9Sha256Hex(canonical),
      intentFingerprint: request.intentFingerprint,
      catalogVersion: catalogVersion,
      generatorVersion: normalizedGeneratorVersion,
      templateIdValue: candidate.templateId.value,
      templateVersion: candidate.templateVersion,
      variantSeedId: candidate.variantSeedId,
      geometryAlgorithmVersion: candidate.geometryAlgorithmVersion,
      geometryFingerprint: candidate.geometryFingerprint,
      scoringProfileVersion: breakdown.scoringProfileVersion,
    );
  }

  ApartmentCandidateSetIdentity identifySet({
    required NormalizedApartmentRequest request,
    required int catalogVersion,
    required String generatorVersion,
    required String scoringProfileVersion,
    required String diversityPolicyVersion,
    required Iterable<ApartmentCandidateIdentity> orderedCandidates,
  }) {
    _requirePositive(catalogVersion, 'catalogVersion');
    final normalizedGeneratorVersion =
        _requireNonEmpty(generatorVersion, 'generatorVersion');
    final normalizedScoringProfileVersion =
        _requireNonEmpty(scoringProfileVersion, 'scoringProfileVersion');
    final normalizedDiversityPolicyVersion =
        _requireNonEmpty(diversityPolicyVersion, 'diversityPolicyVersion');
    final candidates = List<ApartmentCandidateIdentity>.unmodifiable(
      orderedCandidates,
    );

    final fingerprints = <String>{};
    for (final candidate in candidates) {
      if (candidate.intentFingerprint != request.intentFingerprint ||
          candidate.catalogVersion != catalogVersion ||
          candidate.generatorVersion != normalizedGeneratorVersion ||
          candidate.scoringProfileVersion !=
              normalizedScoringProfileVersion) {
        throw ArgumentError(
          'Candidate set contains identity from a different request/version envelope.',
        );
      }
      if (!fingerprints.add(candidate.candidateFingerprint)) {
        throw ArgumentError(
          'Candidate set contains duplicate candidateFingerprint '
          '${candidate.candidateFingerprint}.',
        );
      }
    }

    final canonical = <String>[
      candidateSetIdentitySchemaVersion,
      'intentFingerprint=${request.intentFingerprint}',
      'catalogVersion=$catalogVersion',
      'generatorVersion=$normalizedGeneratorVersion',
      'scoringProfileVersion=$normalizedScoringProfileVersion',
      'diversityPolicyVersion=$normalizedDiversityPolicyVersion',
      'candidateCount=${candidates.length}',
      for (var index = 0; index < candidates.length; index++)
        'candidate[$index]=${candidates[index].candidateFingerprint}',
    ].join('\n');

    return ApartmentCandidateSetIdentity(
      intentFingerprint: request.intentFingerprint,
      catalogVersion: catalogVersion,
      generatorVersion: normalizedGeneratorVersion,
      scoringProfileVersion: normalizedScoringProfileVersion,
      diversityPolicyVersion: normalizedDiversityPolicyVersion,
      orderedCandidates: candidates,
      candidateSetFingerprint: p9Sha256Hex(canonical),
    );
  }
}

int _metricValue(
  Map<ApartmentScoreMetric, int> values,
  ApartmentScoreMetric metric,
  String mapName,
) {
  final value = values[metric];
  if (value == null) {
    throw ArgumentError('$mapName is missing ${metric.name}.');
  }
  return value;
}

String _requireNonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}

void _requirePositive(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Must be positive.');
  }
}
