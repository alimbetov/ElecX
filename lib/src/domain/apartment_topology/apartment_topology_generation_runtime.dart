import 'apartment_candidate_ranking.dart';
import 'apartment_geometry.dart';

enum ApartmentTopologyGenerationFailureCode {
  noCandidates('NO_CANDIDATES'),
  noValidTopologyCandidate('NO_VALID_TOPOLOGY_CANDIDATE');

  const ApartmentTopologyGenerationFailureCode(this.code);

  final String code;
}

/// Fail-closed evaluation envelope for one already-scored P9 candidate.
///
/// P9.1 deliberately reuses [RankedApartmentCandidate] instead of introducing
/// a second scoring model. Upstream semantic/normative/equipment stages add
/// stable blocker codes through [blockerCodes]; geometry blockers are always
/// imported from the candidate itself so a geometrically invalid candidate can
/// never become eligible by accident.
final class ApartmentTopologyCandidateEvaluation {
  ApartmentTopologyCandidateEvaluation._({
    required this.rankedCandidate,
    required List<String> blockerCodes,
  }) : blockerCodes = List.unmodifiable(blockerCodes);

  factory ApartmentTopologyCandidateEvaluation.failClosed({
    required RankedApartmentCandidate rankedCandidate,
    Iterable<String> blockerCodes = const [],
  }) {
    final blockers = <String>{...blockerCodes};
    for (final issue in rankedCandidate.candidate.validation.issues) {
      if (issue.severity == GeometryValidationSeverity.blocker) {
        blockers.add(issue.code);
      }
    }
    final orderedBlockers = blockers.toList()..sort();
    return ApartmentTopologyCandidateEvaluation._(
      rankedCandidate: rankedCandidate,
      blockerCodes: orderedBlockers,
    );
  }

  final RankedApartmentCandidate rankedCandidate;
  final List<String> blockerCodes;

  bool get isEligible => blockerCodes.isEmpty;
}

final class ApartmentTopologyGenerationFailure implements Exception {
  ApartmentTopologyGenerationFailure({
    required this.code,
    required Iterable<ApartmentTopologyCandidateEvaluation> evaluations,
  }) : evaluations = List.unmodifiable(evaluations);

  final ApartmentTopologyGenerationFailureCode code;
  final List<ApartmentTopologyCandidateEvaluation> evaluations;

  @override
  String toString() => 'ApartmentTopologyGenerationFailure(${code.code})';
}

/// Deterministic P9.1 selection result.
///
/// [evaluations] is itself deterministically ordered, so diagnostics and replay
/// do not leak the caller/catalog iteration order.
final class ApartmentTopologyGenerationSelection {
  ApartmentTopologyGenerationSelection({
    required this.selected,
    required Iterable<ApartmentTopologyCandidateEvaluation> evaluations,
  }) : evaluations = List.unmodifiable(evaluations);

  final ApartmentTopologyCandidateEvaluation selected;
  final List<ApartmentTopologyCandidateEvaluation> evaluations;

  RankedApartmentCandidate get selectedCandidate => selected.rankedCandidate;

  List<ApartmentTopologyCandidateEvaluation> get eligible => List.unmodifiable(
        evaluations.where((evaluation) => evaluation.isEligible),
      );

  List<ApartmentTopologyCandidateEvaluation> get rejected => List.unmodifiable(
        evaluations.where((evaluation) => !evaluation.isEligible),
      );
}

/// P9.1 frozen deterministic selection runtime.
///
/// Contract:
/// - invalid candidates never participate in winner selection;
/// - score is descending;
/// - the existing stable hierarchy is family, template, variant seed;
/// - canonical template identity and template version are deterministic
///   tie-breakers after the stable hierarchy;
/// - remaining stable fields make the comparator total without relying on
///   iterable insertion order;
/// - no eligible candidate fails explicitly instead of falling back to first.
final class ApartmentTopologyGenerationRuntime {
  const ApartmentTopologyGenerationRuntime();

  /// Production adapter for already-ranked candidates.
  ///
  /// The selectable score floor is eligibility, not a scoring bonus: a score
  /// below the floor becomes a stable blocker and therefore cannot be rescued
  /// by ordering. Geometry blockers are imported by [failClosed].
  ApartmentTopologyGenerationSelection selectRankedCandidates(
    Iterable<RankedApartmentCandidate> candidates, {
    int? selectableFloorBp,
  }) {
    final evaluations = <ApartmentTopologyCandidateEvaluation>[
      for (final candidate in candidates)
        ApartmentTopologyCandidateEvaluation.failClosed(
          rankedCandidate: candidate,
          blockerCodes: selectableFloorBp != null &&
                  candidate.finalScoreBp < selectableFloorBp
              ? const ['p9.score.below-selectable-floor']
              : const [],
        ),
    ];
    return select(evaluations);
  }

  ApartmentTopologyGenerationSelection select(
    Iterable<ApartmentTopologyCandidateEvaluation> input,
  ) {
    final evaluations = input.toList()..sort(_compareEvaluations);
    if (evaluations.isEmpty) {
      throw ApartmentTopologyGenerationFailure(
        code: ApartmentTopologyGenerationFailureCode.noCandidates,
        evaluations: const [],
      );
    }

    final eligible = evaluations
        .where((evaluation) => evaluation.isEligible)
        .toList(growable: false);
    if (eligible.isEmpty) {
      throw ApartmentTopologyGenerationFailure(
        code: ApartmentTopologyGenerationFailureCode.noValidTopologyCandidate,
        evaluations: evaluations,
      );
    }

    return ApartmentTopologyGenerationSelection(
      selected: eligible.first,
      evaluations: evaluations,
    );
  }

  static int _compareEvaluations(
    ApartmentTopologyCandidateEvaluation left,
    ApartmentTopologyCandidateEvaluation right,
  ) {
    if (left.isEligible != right.isEligible) {
      return left.isEligible ? -1 : 1;
    }
    return compareRankedCandidates(
      left.rankedCandidate,
      right.rankedCandidate,
    );
  }

  /// Frozen P9.1 total order.
  ///
  /// The first four fields preserve the stable hierarchy already used by the
  /// production P9 ranker. Canonical identity/version then make equal stable
  /// positions deterministic even if future catalogs introduce additional
  /// templates at the same stable position.
  static int compareRankedCandidates(
    RankedApartmentCandidate left,
    RankedApartmentCandidate right,
  ) {
    var result = right.finalScoreBp.compareTo(left.finalScoreBp);
    if (result != 0) {
      return result;
    }

    result = left.familyStableOrder.compareTo(right.familyStableOrder);
    if (result != 0) {
      return result;
    }

    result = left.templateStableOrder.compareTo(right.templateStableOrder);
    if (result != 0) {
      return result;
    }

    result = left.variantSeedStableOrder.compareTo(
      right.variantSeedStableOrder,
    );
    if (result != 0) {
      return result;
    }

    result = left.candidate.templateId.value
        .compareTo(right.candidate.templateId.value);
    if (result != 0) {
      return result;
    }

    result = left.candidate.templateVersion
        .compareTo(right.candidate.templateVersion);
    if (result != 0) {
      return result;
    }

    result = left.similaritySignature.stableKey.compareTo(
      right.similaritySignature.stableKey,
    );
    if (result != 0) {
      return result;
    }

    result = left.candidate.areaFitFingerprint.compareTo(
      right.candidate.areaFitFingerprint,
    );
    if (result != 0) {
      return result;
    }

    return left.candidate.geometryFingerprint.compareTo(
      right.candidate.geometryFingerprint,
    );
  }
}
