import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_candidate_ranking.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/project_space_semantics.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

final class ApartmentCandidateRankingInput {
  const ApartmentCandidateRankingInput({
    required this.candidate,
    required this.template,
  });

  final ApartmentGeometryCandidate candidate;
  final ApartmentTopologyTemplate template;
}

final class ApartmentRankingAvailability {
  const ApartmentRankingAvailability({
    required this.sourceCandidateCount,
    required this.validCandidateCount,
    required this.qualifyingCandidateCount,
    required this.minimumUsefulCandidateCount,
    required this.preferredCandidateCount,
  });

  final int sourceCandidateCount;
  final int validCandidateCount;
  final int qualifyingCandidateCount;
  final int minimumUsefulCandidateCount;
  final int preferredCandidateCount;

  bool get belowMinimumUseful =>
      qualifyingCandidateCount < minimumUsefulCandidateCount;
}

final class ApartmentCandidateRankingResult {
  ApartmentCandidateRankingResult({
    required Iterable<RankedApartmentCandidate> rankedCandidates,
    required Iterable<RankedApartmentCandidate> selectedCandidates,
    required this.rankingFingerprint,
    required this.availability,
    required Iterable<P9Failure> failures,
  })  : rankedCandidates = List.unmodifiable(rankedCandidates),
        selectedCandidates = List.unmodifiable(selectedCandidates),
        failures = List.unmodifiable(failures);

  final List<RankedApartmentCandidate> rankedCandidates;
  final List<RankedApartmentCandidate> selectedCandidates;
  final String rankingFingerprint;
  final ApartmentRankingAvailability availability;
  final List<P9Failure> failures;

  bool get hasBlockers => failures.any((failure) => failure.isBlocker);
}

/// Pure deterministic P9.7 scorer/ranker.
///
/// P9.7 never mutates P9.6 geometry and never allocates canonical project IDs.
/// Invalid P9.6 candidates are excluded before any quality score can influence
/// selection.
final class ApartmentCandidateRanker {
  const ApartmentCandidateRanker();

  ApartmentCandidateRankingResult rank({
    required Iterable<ApartmentCandidateRankingInput> candidates,
    required NormalizedApartmentRequest request,
    ApartmentScoringProfile? profile,
  }) {
    final effectiveProfile = profile ?? ApartmentScoringProfile.recommendedV1();
    final source = candidates.toList();
    final profileFailures = _validateProfile(effectiveProfile);
    if (profileFailures.isNotEmpty) {
      return ApartmentCandidateRankingResult(
        rankedCandidates: const [],
        selectedCandidates: const [],
        rankingFingerprint: '',
        availability: ApartmentRankingAvailability(
          sourceCandidateCount: source.length,
          validCandidateCount: 0,
          qualifyingCandidateCount: 0,
          minimumUsefulCandidateCount:
              effectiveProfile.minimumUsefulCandidateCount,
          preferredCandidateCount: effectiveProfile.preferredCandidateCount,
        ),
        failures: profileFailures,
      );
    }

    final valid = source
        .where((input) => input.candidate.validation.accepted)
        .toList();
    if (valid.isEmpty) {
      return ApartmentCandidateRankingResult(
        rankedCandidates: const [],
        selectedCandidates: const [],
        rankingFingerprint: '',
        availability: ApartmentRankingAvailability(
          sourceCandidateCount: source.length,
          validCandidateCount: 0,
          qualifyingCandidateCount: 0,
          minimumUsefulCandidateCount:
              effectiveProfile.minimumUsefulCandidateCount,
          preferredCandidateCount: effectiveProfile.preferredCandidateCount,
        ),
        failures: [
          P9Failure(
            code: 'p9.score.no-valid-candidates',
            stage: P9FailureStage.scoring,
            severity: P9FailureSeverity.blocker,
            facts: {'sourceCandidateCount': source.length},
          ),
        ],
      );
    }

    final scored = <RankedApartmentCandidate>[
      for (final input in valid)
        _score(
          input,
          request: request,
          profile: effectiveProfile,
        ),
    ]..sort(_compareRanked);

    // Exact duplicates are suppressed only after full stable ranking so the
    // highest-ranked deterministic instance survives.
    final deduped = <RankedApartmentCandidate>[];
    final exactKeys = <String>{};
    for (final ranked in scored) {
      if (exactKeys.add(ranked.exactDuplicateKey)) {
        deduped.add(ranked);
      }
    }

    final qualifying = deduped
        .where(
          (candidate) =>
              candidate.finalScoreBp >= effectiveProfile.selectableFloorBp,
        )
        .toList();
    final selected = _selectDiverse(
      qualifying,
      preferredCount: effectiveProfile.preferredCandidateCount,
      maximumCount: effectiveProfile.maximumCandidateCount,
    );
    final fingerprint = _rankingFingerprint(
      profile: effectiveProfile,
      ranked: deduped,
      selected: selected,
    );

    return ApartmentCandidateRankingResult(
      rankedCandidates: deduped,
      selectedCandidates: selected,
      rankingFingerprint: fingerprint,
      availability: ApartmentRankingAvailability(
        sourceCandidateCount: source.length,
        validCandidateCount: valid.length,
        qualifyingCandidateCount: qualifying.length,
        minimumUsefulCandidateCount:
            effectiveProfile.minimumUsefulCandidateCount,
        preferredCandidateCount: effectiveProfile.preferredCandidateCount,
      ),
      failures: const [],
    );
  }

  List<P9Failure> _validateProfile(ApartmentScoringProfile profile) {
    final failures = <P9Failure>[];
    if (profile.scoringProfileVersion.trim().isEmpty ||
        profile.selectableFloorBp < 0 ||
        profile.selectableFloorBp > 10000 ||
        profile.minimumUsefulCandidateCount <= 0 ||
        profile.preferredCandidateCount < profile.minimumUsefulCandidateCount ||
        profile.maximumCandidateCount < profile.preferredCandidateCount ||
        profile.maximumCandidateCount > 6) {
      failures.add(
        P9Failure(
          code: 'p9.score.invalid-profile',
          stage: P9FailureStage.scoring,
          severity: P9FailureSeverity.blocker,
          facts: {
            'scoringProfileVersion': profile.scoringProfileVersion,
            'selectableFloorBp': profile.selectableFloorBp,
            'minimumUsefulCandidateCount': profile.minimumUsefulCandidateCount,
            'preferredCandidateCount': profile.preferredCandidateCount,
            'maximumCandidateCount': profile.maximumCandidateCount,
          },
        ),
      );
    }

    for (final metric in ApartmentScoreMetric.values) {
      if (!profile.weightBp.containsKey(metric)) {
        failures.add(
          P9Failure(
            code: 'p9.score.missing-metric',
            stage: P9FailureStage.scoring,
            severity: P9FailureSeverity.blocker,
            facts: {'metric': metric.name},
          ),
        );
        continue;
      }
      final weight = profile.weightBp[metric]!;
      if (weight < 0 || weight > 10000) {
        failures.add(
          P9Failure(
            code: 'p9.score.invalid-metric-range',
            stage: P9FailureStage.scoring,
            severity: P9FailureSeverity.blocker,
            facts: {'metric': metric.name, 'weightBp': weight},
          ),
        );
      }
    }
    final weightSum = profile.weightBp.values.fold<int>(0, (a, b) => a + b);
    if (weightSum != 10000) {
      failures.add(
        P9Failure(
          code: 'p9.score.weight-sum',
          stage: P9FailureStage.scoring,
          severity: P9FailureSeverity.blocker,
          facts: {'actualWeightSumBp': weightSum, 'requiredWeightSumBp': 10000},
        ),
      );
    }
    return failures;
  }

  RankedApartmentCandidate _score(
    ApartmentCandidateRankingInput input, {
    required NormalizedApartmentRequest request,
    required ApartmentScoringProfile profile,
  }) {
    final candidate = input.candidate;
    final template = input.template;
    final metricScores = <ApartmentScoreMetric, int>{
      ApartmentScoreMetric.interiorAreaMatch:
          _interiorAreaMatch(candidate, request),
      ApartmentScoreMetric.circulationEfficiency:
          _circulationEfficiency(candidate, template),
      ApartmentScoreMetric.corridorEfficiency:
          _corridorEfficiency(candidate, template),
      ApartmentScoreMetric.wetCoreCompactness:
          _wetCoreCompactness(candidate, template),
      ApartmentScoreMetric.roomAspectQuality:
          _roomAspectQuality(candidate, template),
      ApartmentScoreMetric.privacySeparation:
          _privacySeparation(candidate, template),
      ApartmentScoreMetric.kitchenModeQuality:
          _kitchenModeQuality(candidate, template, request),
      ApartmentScoreMetric.balconyAttachmentQuality:
          _balconyAttachmentQuality(candidate, template, request),
      ApartmentScoreMetric.familyPreferenceMatch:
          _familyPreferenceMatch(candidate, request),
      ApartmentScoreMetric.exteriorExposurePreferenceMatch:
          _exteriorExposurePreferenceMatch(candidate, request),
    };
    final contributions = <ApartmentScoreMetric, int>{};
    var finalScore = 0;
    for (final metric in ApartmentScoreMetric.values) {
      final contribution =
          metricScores[metric]! * profile.weightBp[metric]! ~/ 10000;
      contributions[metric] = contribution;
      finalScore += contribution;
    }
    final seed = _variantSeed(template, candidate.variantSeedId);
    return RankedApartmentCandidate(
      candidate: candidate,
      breakdown: ApartmentScoreBreakdown(
        scoringProfileVersion: profile.scoringProfileVersion,
        metricScoreBp: metricScores,
        weightedContributionBp: contributions,
        finalScoreBp: _clampBp(finalScore),
      ),
      similaritySignature: _similaritySignature(
        candidate,
        template,
        seed,
      ),
      familyStableOrder: candidate.family.index,
      templateStableOrder: template.stableOrder,
      variantSeedStableOrder: seed?.stableOrder ?? 1 << 20,
    );
  }

  /// Inputs: realized interior space area vs each P9.4 fitted target.
  /// Best: <= 0.10% aggregate deviation. Worst: >= 5.00%.
  /// Exterior appendages are intentionally absent from both numerator and
  /// denominator (P9.7-INV-006).
  int _interiorAreaMatch(
    ApartmentGeometryCandidate candidate,
    NormalizedApartmentRequest request,
  ) {
    final requestedMm2 = _maxInt(request.interiorAreaDm2 * 10000, 1);
    var deviationMm2 = 0;
    for (final space in candidate.interiorSpaces) {
      deviationMm2 +=
          (space.realizedAreaMm2 - space.fittedAreaDm2 * 10000).abs();
    }
    final deviationBp = deviationMm2 * 10000 ~/ requestedMm2;
    return _descendingLinear(deviationBp, best: 10, worst: 500);
  }

  /// Inputs: circulation area ratio, opening-graph depth, redundant edges and
  /// branch excess. All are candidate-local deterministic integer facts.
  /// Area ratio best <= 8%, worst >= 22%; graph depth best <= 2, worst >= 6.
  int _circulationEfficiency(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
  ) {
    final specs = _specsByBaseKey(template);
    final circulation = candidate.interiorSpaces.where((space) {
      final spec = specs[_baseKey(space.semanticKey)];
      return spec?.circulationSpace ?? false;
    }).toList();
    final circulationArea = circulation.fold<int>(
      0,
      (sum, space) => sum + space.realizedAreaMm2,
    );
    final areaRatioBp = candidate.metrics.interiorAreaMm2 <= 0
        ? 10000
        : circulationArea * 10000 ~/ candidate.metrics.interiorAreaMm2;
    final graph = _openingGraph(candidate);
    final entry = _entryKey(candidate);
    final depths = entry == null ? const <String, int>{} : _graphDepths(entry, graph);
    final maxDepth = depths.values.isEmpty
        ? 0
        : depths.values.reduce((left, right) => _maxInt(left, right));
    final internalEdgeCount = _internalOpenings(candidate).length;
    final minimumConnectedEdges = _maxInt(candidate.interiorSpaces.length - 1, 0);
    final redundantEdges = _maxInt(internalEdgeCount - minimumConnectedEdges, 0);
    var branchExcess = 0;
    for (final neighbors in graph.values) {
      branchExcess += _maxInt(neighbors.length - 3, 0);
    }

    final areaScore = _descendingLinear(areaRatioBp, best: 800, worst: 2200);
    final depthScore = _descendingLinear(maxDepth, best: 2, worst: 6);
    final edgeScore = _descendingLinear(redundantEdges, best: 0, worst: 4);
    final branchScore = _descendingLinear(branchExcess, best: 0, worst: 4);
    return (areaScore * 45 +
            depthScore * 35 +
            edgeScore * 10 +
            branchScore * 10) ~/
        100;
  }

  /// Inputs: corridor area ratio and corridor rectangle elongation.
  /// Non-spine families: best area <= 12%, worst >= 25%.
  /// corridorSpine/centralCorridor: best <= 18%, worst >= 35%, so a qualified
  /// spine is not penalized merely for existing.
  int _corridorEfficiency(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
  ) {
    final specs = _specsByBaseKey(template);
    final corridors = candidate.interiorSpaces.where((space) {
      return specs[_baseKey(space.semanticKey)]?.usage == SpaceUsage.corridor;
    }).toList();
    if (corridors.isEmpty) {
      return 10000;
    }
    final corridorArea = corridors.fold<int>(
      0,
      (sum, space) => sum + space.realizedAreaMm2,
    );
    final ratioBp = candidate.metrics.interiorAreaMm2 <= 0
        ? 10000
        : corridorArea * 10000 ~/ candidate.metrics.interiorAreaMm2;
    final spineFamily = candidate.family == ApartmentTopologyFamily.corridorSpine ||
        candidate.family == ApartmentTopologyFamily.centralCorridor;
    final areaScore = _descendingLinear(
      ratioBp,
      best: spineFamily ? 1800 : 1200,
      worst: spineFamily ? 3500 : 2500,
    );
    var elongationTotal = 0;
    for (final corridor in corridors) {
      final shortSide = _maxInt(
        _minInt(corridor.polygon.widthMm, corridor.polygon.heightMm),
        1,
      );
      final longSide =
          _maxInt(corridor.polygon.widthMm, corridor.polygon.heightMm);
      elongationTotal += longSide * 10000 ~/ shortSide;
    }
    final elongationBp = elongationTotal ~/ corridors.length;
    final lengthScore = _descendingLinear(
      elongationBp,
      best: spineFamily ? 70000 : 45000,
      worst: 140000,
    );
    return (areaScore * 70 + lengthScore * 30) ~/ 100;
  }

  /// Inputs: P9.6 measured maximum wet-core separation.
  /// Best <= 25% of the template hard limit (at least 1000 mm); worst equals
  /// the hard limit. A hard-limit violation never reaches P9.7 selectable input.
  int _wetCoreCompactness(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
  ) {
    final hardMax = _maxInt(template.wetCorePolicy.maxGroupSeparationMm, 1);
    final best = _maxInt(1000, hardMax ~/ 4);
    return _descendingLinear(
      candidate.metrics.wetCoreMaxSeparationMm,
      best: best,
      worst: hardMax,
    );
  }

  /// Inputs: actual width/height aspect against each template's hard range.
  /// Best band is the hard range intersected with 0.75..1.50; outside that
  /// band score falls linearly to zero at the hard limits. Circulation spaces
  /// are excluded because corridor shape quality is scored separately.
  int _roomAspectQuality(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
  ) {
    final specs = _specsByBaseKey(template);
    var weightedScore = 0;
    var totalWeight = 0;
    for (final space in candidate.interiorSpaces) {
      final spec = specs[_baseKey(space.semanticKey)];
      if (spec == null || spec.circulationSpace) {
        continue;
      }
      final height = _maxInt(space.polygon.heightMm, 1);
      final aspectBp = space.polygon.widthMm * 10000 ~/ height;
      final hardMin = spec.geometry.minAspectBp;
      final hardMax = spec.geometry.maxAspectBp;
      var preferredMin = _maxInt(hardMin, 7500);
      var preferredMax = _minInt(hardMax, 15000);
      if (preferredMin > preferredMax) {
        final midpoint = (hardMin + hardMax) ~/ 2;
        preferredMin = midpoint;
        preferredMax = midpoint;
      }
      final score = _rangeQuality(
        aspectBp,
        hardMin: hardMin,
        preferredMin: preferredMin,
        preferredMax: preferredMax,
        hardMax: hardMax,
      );
      final weight = _maxInt(spec.areaWeightBp, 1);
      weightedScore += score * weight;
      totalWeight += weight;
    }
    return totalWeight == 0 ? 10000 : weightedScore ~/ totalWeight;
  }

  /// Inputs: opening graph depth from entry and direct bedroom/day adjacency.
  /// Bedrooms at depth >= 2 get full entry-separation credit; a direct bedroom
  /// to day-space opening reduces, but never invalidates, the quality score.
  int _privacySeparation(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
  ) {
    final specs = _specsByBaseKey(template);
    final bedrooms = candidate.interiorSpaces.where((space) {
      return specs[_baseKey(space.semanticKey)]?.usage == SpaceUsage.bedroom;
    }).toList();
    if (bedrooms.isEmpty) {
      return 10000;
    }
    final dayKeys = candidate.interiorSpaces.where((space) {
      final usage = specs[_baseKey(space.semanticKey)]?.usage;
      return usage == SpaceUsage.livingRoom ||
          usage == SpaceUsage.kitchenLiving ||
          usage == SpaceUsage.kitchen;
    }).map((space) => space.semanticKey).toSet();
    final graph = _openingGraph(candidate);
    final entry = _entryKey(candidate);
    final depths = entry == null ? const <String, int>{} : _graphDepths(entry, graph);
    var total = 0;
    for (final bedroom in bedrooms) {
      final depth = depths[bedroom.semanticKey] ?? 0;
      final depthScore = depth >= 2 ? 10000 : depth == 1 ? 4000 : 0;
      final directToDay = (graph[bedroom.semanticKey] ?? const <String>{})
          .any(dayKeys.contains);
      final dayExposureScore = directToDay ? 4000 : 10000;
      total += (depthScore * 70 + dayExposureScore * 30) ~/ 100;
    }
    return total ~/ bedrooms.length;
  }

  /// Inputs are candidate-local kitchen spaces/openings/shared boundaries.
  /// Semantic mismatch is not repaired here; P9.5 already rejects it.
  int _kitchenModeQuality(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
    NormalizedApartmentRequest request,
  ) {
    final specs = _specsByBaseKey(template);
    final kitchens = candidate.interiorSpaces.where((space) {
      final usage = specs[_baseKey(space.semanticKey)]?.usage;
      return usage == SpaceUsage.kitchen || usage == SpaceUsage.kitchenLiving;
    }).toList();
    if (kitchens.isEmpty) {
      return 0;
    }
    switch (request.kitchenMode) {
      case ApartmentKitchenMode.kitchenLiving:
        final combined = kitchens.any((space) =>
            specs[_baseKey(space.semanticKey)]?.usage == SpaceUsage.kitchenLiving);
        return combined ? 10000 : 0;
      case ApartmentKitchenMode.openPlan:
        final kitchenKeys = kitchens.map((space) => space.semanticKey).toSet();
        final dayKeys = candidate.interiorSpaces.where((space) {
          return specs[_baseKey(space.semanticKey)]?.usage == SpaceUsage.livingRoom;
        }).map((space) => space.semanticKey).toSet();
        var bestBoundary = 0;
        var hasOpenPassage = false;
        for (final opening in _internalOpenings(candidate)) {
          final from = opening.fromSpaceKey!;
          final to = opening.toSpaceKey!;
          final matches = (kitchenKeys.contains(from) && dayKeys.contains(to)) ||
              (kitchenKeys.contains(to) && dayKeys.contains(from));
          if (matches && opening.kind == GeometryOpeningKind.openPassage) {
            hasOpenPassage = true;
          }
        }
        for (final boundary in candidate.sharedBoundaries) {
          final matches = (kitchenKeys.contains(boundary.pair.leftKey) &&
                  dayKeys.contains(boundary.pair.rightKey)) ||
              (kitchenKeys.contains(boundary.pair.rightKey) &&
                  dayKeys.contains(boundary.pair.leftKey));
          if (matches) {
            bestBoundary = _maxInt(bestBoundary, boundary.lengthMm);
          }
        }
        if (!hasOpenPassage) {
          return 0;
        }
        final boundaryScore = _ascendingLinear(bestBoundary, worst: 1200, best: 2400);
        return 7000 + boundaryScore * 3000 ~/ 10000;
      case ApartmentKitchenMode.separate:
        final separateKitchen = kitchens.any((space) =>
            specs[_baseKey(space.semanticKey)]?.usage == SpaceUsage.kitchen);
        if (!separateKitchen) {
          return 0;
        }
        final kitchenKeys = kitchens.map((space) => space.semanticKey).toSet();
        final graph = _openingGraph(candidate);
        final connected = kitchenKeys.any(
          (key) => (graph[key] ?? const <String>{}).isNotEmpty,
        );
        return connected ? 10000 : 7000;
    }
  }

  /// Inputs: appendage realized/fitted area, shared attachment length, opening
  /// host and variant seed host preference. No appendage area enters the
  /// interior-area metric.
  int _balconyAttachmentQuality(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
    NormalizedApartmentRequest request,
  ) {
    if (request.balconyCount == 0) {
      return 10000;
    }
    if (candidate.exteriorAppendages.isEmpty) {
      return 0;
    }
    final specs = _specsByBaseKey(template);
    final seed = _variantSeed(template, candidate.variantSeedId);
    var total = 0;
    for (final appendage in candidate.exteriorAppendages) {
      var boundaryLength = 0;
      String? hostKey;
      for (final boundary in candidate.sharedBoundaries) {
        if (boundary.pair.leftKey == appendage.semanticKey ||
            boundary.pair.rightKey == appendage.semanticKey) {
          if (boundary.lengthMm > boundaryLength) {
            boundaryLength = boundary.lengthMm;
            hostKey = boundary.pair.leftKey == appendage.semanticKey
                ? boundary.pair.rightKey
                : boundary.pair.leftKey;
          }
        }
      }
      final hasOpening = _internalOpenings(candidate).any((opening) {
        return opening.fromSpaceKey == appendage.semanticKey ||
            opening.toSpaceKey == appendage.semanticKey;
      });
      final attachmentScore = hasOpening
          ? _ascendingLinear(boundaryLength, worst: 600, best: 1800)
          : 0;
      final targetMm2 = _maxInt(appendage.fittedAreaDm2 * 10000, 1);
      final errorBp =
          (appendage.realizedAreaMm2 - targetMm2).abs() * 10000 ~/ targetMm2;
      final areaScore = _descendingLinear(errorBp, best: 10, worst: 500);
      final hostUsage = hostKey == null
          ? null
          : specs[_baseKey(hostKey)]?.usage;
      final hostScore = switch (seed?.balconyStrategy) {
        BalconyAttachmentStrategy.bedroom =>
          hostUsage == SpaceUsage.bedroom ? 10000 : 5000,
        BalconyAttachmentStrategy.daySpace =>
          hostUsage == SpaceUsage.livingRoom ||
                  hostUsage == SpaceUsage.kitchenLiving
              ? 10000
              : 5000,
        BalconyAttachmentStrategy.bestExteriorExposure || null => 10000,
      };
      total += (attachmentScore * 60 + areaScore * 25 + hostScore * 15) ~/ 100;
    }
    return total ~/ candidate.exteriorAppendages.length;
  }

  int _familyPreferenceMatch(
    ApartmentGeometryCandidate candidate,
    NormalizedApartmentRequest request,
  ) {
    final preferred = request.preferredFamily;
    if (preferred == null) {
      return 10000;
    }
    return candidate.family == preferred ? 10000 : 0;
  }

  /// Candidate-local exposure only. Envelope sides are local geometry sides;
  /// this metric makes no Building facade/cardinal-orientation claim.
  int _exteriorExposurePreferenceMatch(
    ApartmentGeometryCandidate candidate,
    NormalizedApartmentRequest request,
  ) {
    if (request.exteriorExposurePreference ==
        ApartmentExteriorExposurePreference.any) {
      return 10000;
    }
    final sides = candidate.exteriorBoundaries.map((edge) => edge.side).toSet();
    switch (request.exteriorExposurePreference) {
      case ApartmentExteriorExposurePreference.any:
        return 10000;
      case ApartmentExteriorExposurePreference.oneSide:
        if (sides.length <= 1) {
          return 10000;
        }
        return sides.length == 2 ? 5000 : 0;
      case ApartmentExteriorExposurePreference.corner:
        if (sides.length != 2) {
          return sides.length == 1 ? 3000 : 0;
        }
        final values = sides.toList();
        return _opposite(values[0], values[1]) ? 0 : 10000;
      case ApartmentExteriorExposurePreference.oppositeSides:
        if (sides.length != 2) {
          return 0;
        }
        final values = sides.toList();
        return _opposite(values[0], values[1]) ? 10000 : 0;
    }
  }

  List<RankedApartmentCandidate> _selectDiverse(
    List<RankedApartmentCandidate> qualifying, {
    required int preferredCount,
    required int maximumCount,
  }) {
    final limit = _minInt(preferredCount, maximumCount);
    final selected = <RankedApartmentCandidate>[];
    final deferredNearDuplicates = <RankedApartmentCandidate>[];
    final nearDuplicateKeys = <String>{};

    for (final candidate in qualifying) {
      if (selected.length >= limit) {
        break;
      }
      final key = candidate.similaritySignature.nearDuplicateKey;
      if (nearDuplicateKeys.add(key)) {
        selected.add(candidate);
      } else {
        deferredNearDuplicates.add(candidate);
      }
    }
    if (selected.length < limit) {
      for (final candidate in deferredNearDuplicates) {
        if (selected.length >= limit) {
          break;
        }
        selected.add(candidate);
      }
    }
    return List.unmodifiable(selected);
  }

  String _rankingFingerprint({
    required ApartmentScoringProfile profile,
    required List<RankedApartmentCandidate> ranked,
    required List<RankedApartmentCandidate> selected,
  }) =>
      p9Sha256Hex(
        <String>[
          'p9.apartment.ranking',
          'scoringProfileVersion=${profile.scoringProfileVersion}',
          for (final candidate in ranked)
            'ranked=${candidate.candidate.geometryFingerprint}|${candidate.finalScoreBp}',
          for (final candidate in selected)
            'selected=${candidate.candidate.geometryFingerprint}',
        ].join('\n'),
      );

  CandidateSimilaritySignature _similaritySignature(
    ApartmentGeometryCandidate candidate,
    ApartmentTopologyTemplate template,
    TopologyVariantSeed? seed,
  ) {
    final specs = _specsByBaseKey(template);
    final edges = <String>[];
    for (final opening in _internalOpenings(candidate)) {
      final leftUsage =
          specs[_baseKey(opening.fromSpaceKey!)]?.usage.name ?? 'unknown';
      final rightUsage =
          specs[_baseKey(opening.toSpaceKey!)]?.usage.name ?? 'unknown';
      final pair = leftUsage.compareTo(rightUsage) <= 0
          ? '$leftUsage>$rightUsage'
          : '$rightUsage>$leftUsage';
      edges.add('$pair:${opening.kind.name}');
    }
    edges.sort();
    final wet = candidate.interiorSpaces.where((space) {
      final spec = specs[_baseKey(space.semanticKey)];
      return spec?.wetSpace == true ||
          spec?.usage == SpaceUsage.kitchen ||
          spec?.usage == SpaceUsage.kitchenLiving;
    }).map((space) => specs[_baseKey(space.semanticKey)]?.usage.name ?? 'unknown').toList()
      ..sort();
    final exposure = candidate.exteriorBoundaries
        .map((edge) => edge.side.name)
        .toSet()
        .toList()
      ..sort();
    return CandidateSimilaritySignature(
      family: candidate.family,
      templateIdValue: candidate.templateId.value,
      adjacencyGraphClass: edges.join(','),
      wetCoreGrouping: wet.join(','),
      entryOrientation: seed?.entrySide.name ?? 'unknown',
      exteriorExposurePattern: exposure.join(','),
      mirrored: seed?.mirrored ?? false,
    );
  }
}

int _compareRanked(
  RankedApartmentCandidate left,
  RankedApartmentCandidate right,
) {
  final score = right.finalScoreBp.compareTo(left.finalScoreBp);
  if (score != 0) {
    return score;
  }
  final family = left.familyStableOrder.compareTo(right.familyStableOrder);
  if (family != 0) {
    return family;
  }
  final template = left.templateStableOrder.compareTo(right.templateStableOrder);
  if (template != 0) {
    return template;
  }
  final seed = left.variantSeedStableOrder.compareTo(right.variantSeedStableOrder);
  if (seed != 0) {
    return seed;
  }
  return left.candidate.geometryFingerprint
      .compareTo(right.candidate.geometryFingerprint);
}

Map<String, TopologySpaceSpec> _specsByBaseKey(
  ApartmentTopologyTemplate template,
) =>
    {for (final spec in template.spaces) spec.semanticKey: spec};

String _baseKey(String semanticKey) {
  final separator = semanticKey.lastIndexOf(':');
  return separator < 0 ? semanticKey : semanticKey.substring(0, separator);
}

TopologyVariantSeed? _variantSeed(
  ApartmentTopologyTemplate template,
  String seedId,
) {
  for (final seed in template.variantSeeds) {
    if (seed.seedId == seedId) {
      return seed;
    }
  }
  return null;
}

List<OpeningIntent> _internalOpenings(ApartmentGeometryCandidate candidate) =>
    candidate.openingIntents
        .where(
          (opening) =>
              opening.kind != GeometryOpeningKind.primaryEntry &&
              opening.fromSpaceKey != null &&
              opening.toSpaceKey != null,
        )
        .toList();

String? _entryKey(ApartmentGeometryCandidate candidate) {
  for (final opening in candidate.openingIntents) {
    if (opening.kind == GeometryOpeningKind.primaryEntry) {
      return opening.fromSpaceKey;
    }
  }
  return null;
}

Map<String, Set<String>> _openingGraph(ApartmentGeometryCandidate candidate) {
  final graph = <String, Set<String>>{};
  for (final opening in _internalOpenings(candidate)) {
    final from = opening.fromSpaceKey!;
    final to = opening.toSpaceKey!;
    graph.putIfAbsent(from, () => <String>{}).add(to);
    graph.putIfAbsent(to, () => <String>{}).add(from);
  }
  return graph;
}

Map<String, int> _graphDepths(
  String start,
  Map<String, Set<String>> graph,
) {
  final depths = <String, int>{start: 0};
  final queue = <String>[start];
  var index = 0;
  while (index < queue.length) {
    final current = queue[index++];
    final neighbors = (graph[current] ?? const <String>{}).toList()..sort();
    for (final next in neighbors) {
      if (depths.containsKey(next)) {
        continue;
      }
      depths[next] = depths[current]! + 1;
      queue.add(next);
    }
  }
  return depths;
}

bool _opposite(GeometryEnvelopeSide first, GeometryEnvelopeSide second) =>
    (first == GeometryEnvelopeSide.north && second == GeometryEnvelopeSide.south) ||
    (first == GeometryEnvelopeSide.south && second == GeometryEnvelopeSide.north) ||
    (first == GeometryEnvelopeSide.east && second == GeometryEnvelopeSide.west) ||
    (first == GeometryEnvelopeSide.west && second == GeometryEnvelopeSide.east);

int _rangeQuality(
  int value, {
  required int hardMin,
  required int preferredMin,
  required int preferredMax,
  required int hardMax,
}) {
  if (value < hardMin || value > hardMax) {
    return 0;
  }
  if (value >= preferredMin && value <= preferredMax) {
    return 10000;
  }
  if (value < preferredMin) {
    return _ascendingLinear(value, worst: hardMin, best: preferredMin);
  }
  return _descendingLinear(value, best: preferredMax, worst: hardMax);
}

int _descendingLinear(
  int value, {
  required int best,
  required int worst,
}) {
  if (worst <= best) {
    return value <= best ? 10000 : 0;
  }
  if (value <= best) {
    return 10000;
  }
  if (value >= worst) {
    return 0;
  }
  return (worst - value) * 10000 ~/ (worst - best);
}

int _ascendingLinear(
  int value, {
  required int worst,
  required int best,
}) {
  if (best <= worst) {
    return value >= best ? 10000 : 0;
  }
  if (value <= worst) {
    return 0;
  }
  if (value >= best) {
    return 10000;
  }
  return (value - worst) * 10000 ~/ (best - worst);
}

int _clampBp(int value) {
  if (value < 0) {
    return 0;
  }
  if (value > 10000) {
    return 10000;
  }
  return value;
}

int _minInt(int left, int right) => left < right ? left : right;
int _maxInt(int left, int right) => left > right ? left : right;
