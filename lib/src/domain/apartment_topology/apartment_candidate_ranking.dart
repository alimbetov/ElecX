import '../apartment_topology.dart';
import 'apartment_geometry.dart';

enum ApartmentScoreMetric {
  interiorAreaMatch,
  circulationEfficiency,
  corridorEfficiency,
  wetCoreCompactness,
  roomAspectQuality,
  privacySeparation,
  kitchenModeQuality,
  balconyAttachmentQuality,
  familyPreferenceMatch,
  exteriorExposurePreferenceMatch,
}

/// Versioned P9.7 score configuration.
///
/// Validation is intentionally performed by the application ranker so an
/// invalid developer profile is reported through typed `p9.score.*` failures
/// instead of throwing during application startup.
final class ApartmentScoringProfile {
  ApartmentScoringProfile({
    required this.scoringProfileVersion,
    required Map<ApartmentScoreMetric, int> weightBp,
    this.selectableFloorBp = 5000,
    this.preferredCandidateCount = 4,
    this.minimumUsefulCandidateCount = 3,
    this.maximumCandidateCount = 6,
  }) : weightBp = Map.unmodifiable(weightBp);

  final String scoringProfileVersion;
  final Map<ApartmentScoreMetric, int> weightBp;
  final int selectableFloorBp;
  final int preferredCandidateCount;
  final int minimumUsefulCandidateCount;
  final int maximumCandidateCount;

  static ApartmentScoringProfile recommendedV1() => ApartmentScoringProfile(
        scoringProfileVersion: 'p9.score.v1',
        weightBp: const {
          ApartmentScoreMetric.interiorAreaMatch: 1600,
          ApartmentScoreMetric.circulationEfficiency: 1400,
          ApartmentScoreMetric.corridorEfficiency: 1000,
          ApartmentScoreMetric.wetCoreCompactness: 1200,
          ApartmentScoreMetric.roomAspectQuality: 1200,
          ApartmentScoreMetric.privacySeparation: 1000,
          ApartmentScoreMetric.kitchenModeQuality: 800,
          ApartmentScoreMetric.balconyAttachmentQuality: 600,
          ApartmentScoreMetric.familyPreferenceMatch: 600,
          ApartmentScoreMetric.exteriorExposurePreferenceMatch: 600,
        },
      );
}

final class ApartmentScoreBreakdown {
  ApartmentScoreBreakdown({
    required this.scoringProfileVersion,
    required Map<ApartmentScoreMetric, int> metricScoreBp,
    required Map<ApartmentScoreMetric, int> weightedContributionBp,
    required this.finalScoreBp,
  })  : metricScoreBp = Map.unmodifiable(metricScoreBp),
        weightedContributionBp = Map.unmodifiable(weightedContributionBp);

  final String scoringProfileVersion;
  final Map<ApartmentScoreMetric, int> metricScoreBp;
  final Map<ApartmentScoreMetric, int> weightedContributionBp;
  final int finalScoreBp;
}

/// Stable structural signature used by P9.7 diversity policy.
///
/// It deliberately contains only candidate-local/template-local facts. No
/// locale, rendering, wall IDs, timestamps or persistent project identities
/// participate in recommendation diversity.
final class CandidateSimilaritySignature {
  const CandidateSimilaritySignature({
    required this.family,
    required this.templateIdValue,
    required this.adjacencyGraphClass,
    required this.wetCoreGrouping,
    required this.entryOrientation,
    required this.exteriorExposurePattern,
    required this.mirrored,
  });

  final ApartmentTopologyFamily family;
  final String templateIdValue;
  final String adjacencyGraphClass;
  final String wetCoreGrouping;
  final String entryOrientation;
  final String exteriorExposurePattern;
  final bool mirrored;

  String get stableKey => <String>[
        family.code,
        templateIdValue,
        adjacencyGraphClass,
        wetCoreGrouping,
        entryOrientation,
        exteriorExposurePattern,
        mirrored ? 'mirror' : 'direct',
      ].join('|');

  /// Near-duplicate policy intentionally normalizes mirroring. A mirrored copy
  /// stays explainable in [stableKey] but does not crowd out a materially
  /// different candidate card when one is available.
  String get nearDuplicateKey => <String>[
        family.code,
        templateIdValue,
        adjacencyGraphClass,
        wetCoreGrouping,
        entryOrientation,
        exteriorExposurePattern,
      ].join('|');
}

final class RankedApartmentCandidate {
  const RankedApartmentCandidate({
    required this.candidate,
    required this.breakdown,
    required this.similaritySignature,
    required this.familyStableOrder,
    required this.templateStableOrder,
    required this.variantSeedStableOrder,
  });

  final ApartmentGeometryCandidate candidate;
  final ApartmentScoreBreakdown breakdown;
  final CandidateSimilaritySignature similaritySignature;
  final int familyStableOrder;
  final int templateStableOrder;
  final int variantSeedStableOrder;

  int get finalScoreBp => breakdown.finalScoreBp;

  String get exactDuplicateKey =>
      '${candidate.areaFitFingerprint}|${candidate.geometryFingerprint}';
}
