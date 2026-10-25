import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

final class ApartmentAreaFitResult {
  ApartmentAreaFitResult({
    required this.fittedDraft,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final AreaFittedTopologyDraft? fittedDraft;
  final List<P9Failure> failures;

  bool get hasBlockers => failures.any((failure) => failure.isBlocker);
  bool get isValid => fittedDraft != null && !hasBlockers;
}

/// P9.4 deterministic integer area allocator.
///
/// Interior area is allocated exactly in square-decimetres. Exterior appendages
/// are allocated independently from their template preferred targets and never
/// consume the requested interior total.
///
/// Policy v4 restores the authoritative P9.4 stage boundary: area allocation is
/// geometry-agnostic. P9.6 owns layout/packing feasibility and must not force
/// area transfers back into this stage.
final class ApartmentAreaFitter {
  const ApartmentAreaFitter();

  static const String areaPolicyVersion = '4';
  static const String allocatorVersion = '4';
  static const int maxSafeAreaDm2 = 1000000000;

  ApartmentAreaFitResult fit({
    required ApartmentTopologyDraft draft,
    required NormalizedApartmentRequest request,
  }) {
    final spaces = draft.spaces.toList()..sort(_compareSpace);
    final failures = _validateInputs(draft, request, spaces);
    if (failures.any((failure) => failure.isBlocker)) {
      return ApartmentAreaFitResult(fittedDraft: null, failures: failures);
    }

    final interior = spaces
        .where(
          (space) =>
              space.areaParticipation ==
              SpaceAreaParticipation.requestedInteriorArea,
        )
        .toList();

    final minimumTotal = interior.fold<int>(
      0,
      (total, space) => total + space.sourceSpec.minAreaDm2,
    );
    final maximumTotal = interior.fold<int>(
      0,
      (total, space) => total + space.sourceSpec.maxAreaDm2,
    );
    if (minimumTotal > maxSafeAreaDm2 || maximumTotal > maxSafeAreaDm2) {
      return ApartmentAreaFitResult(
        fittedDraft: null,
        failures: [
          _failure(
            'p9.area.integer-overflow-guard',
            facts: {
              'minimumTotalDm2': minimumTotal,
              'maximumTotalDm2': maximumTotal,
              'guardDm2': maxSafeAreaDm2,
            },
          ),
        ],
      );
    }
    if (request.interiorAreaDm2 < minimumTotal) {
      return ApartmentAreaFitResult(
        fittedDraft: null,
        failures: [
          _failure(
            'p9.area.request-below-minimum',
            facts: {
              'requestedInteriorAreaDm2': request.interiorAreaDm2,
              'minimumInteriorAreaDm2': minimumTotal,
            },
          ),
        ],
      );
    }
    if (request.interiorAreaDm2 > maximumTotal) {
      return ApartmentAreaFitResult(
        fittedDraft: null,
        failures: [
          _failure(
            'p9.area.request-above-maximum',
            facts: {
              'requestedInteriorAreaDm2': request.interiorAreaDm2,
              'maximumInteriorAreaDm2': maximumTotal,
            },
          ),
        ],
      );
    }

    final allocations = <String, int>{
      for (final space in interior)
        space.semanticKey: space.sourceSpec.minAreaDm2,
    };
    var remaining = request.interiorAreaDm2 - minimumTotal;
    final nearFixed =
        interior.where((space) => space.sourceSpec.nearFixedArea).toList();
    final flexible =
        interior.where((space) => !space.sourceSpec.nearFixedArea).toList();

    // Near-fixed service spaces reach preferred targets before flexible spaces.
    remaining = _distributeToward(
      spaces: nearFixed,
      allocations: allocations,
      remaining: remaining,
      targetArea: (space) => space.sourceSpec.preferredAreaDm2,
    );
    remaining = _distributeToward(
      spaces: flexible,
      allocations: allocations,
      remaining: remaining,
      targetArea: (space) => space.sourceSpec.preferredAreaDm2,
    );

    // Beyond preferred targets, flexible spaces expand first. Near-fixed spaces
    // exceed preferred only if the flexible envelope is exhausted.
    remaining = _distributeToward(
      spaces: flexible,
      allocations: allocations,
      remaining: remaining,
      targetArea: (space) => space.sourceSpec.maxAreaDm2,
    );
    remaining = _distributeToward(
      spaces: nearFixed,
      allocations: allocations,
      remaining: remaining,
      targetArea: (space) => space.sourceSpec.maxAreaDm2,
    );

    if (remaining != 0) {
      return ApartmentAreaFitResult(
        fittedDraft: null,
        failures: [
          _failure(
            'p9.area.unallocated-residual',
            facts: {
              'requestedInteriorAreaDm2': request.interiorAreaDm2,
              'residualDm2': remaining,
            },
          ),
        ],
      );
    }

    final fittedSpaces = <FittedSpaceArea>[
      for (final space in spaces)
        FittedSpaceArea(
          semanticKey: space.semanticKey,
          participation: space.areaParticipation,
          areaDm2: space.areaParticipation ==
                  SpaceAreaParticipation.requestedInteriorArea
              ? allocations[space.semanticKey]!
              : space.sourceSpec.preferredAreaDm2,
          minAreaDm2: space.sourceSpec.minAreaDm2,
          preferredAreaDm2: space.sourceSpec.preferredAreaDm2,
          maxAreaDm2: space.sourceSpec.maxAreaDm2,
        ),
    ];
    final allocatedInterior = fittedSpaces
        .where(
          (space) =>
              space.participation ==
              SpaceAreaParticipation.requestedInteriorArea,
        )
        .fold<int>(0, (total, space) => total + space.areaDm2);
    final exteriorAppendage = fittedSpaces
        .where(
          (space) =>
              space.participation == SpaceAreaParticipation.exteriorAppendage,
        )
        .fold<int>(0, (total, space) => total + space.areaDm2);
    final residual = request.interiorAreaDm2 - allocatedInterior;
    if (residual != 0) {
      return ApartmentAreaFitResult(
        fittedDraft: null,
        failures: [
          _failure(
            'p9.area.unallocated-residual',
            facts: {'residualDm2': residual},
          ),
        ],
      );
    }

    final fingerprint = p9Sha256Hex(
      <String>[
        'p9.apartment.area-fit',
        'draft=${draft.draftFingerprint}',
        'requestedInteriorAreaDm2=${request.interiorAreaDm2}',
        'areaPolicyVersion=$areaPolicyVersion',
        'allocatorVersion=$allocatorVersion',
        for (final space in fittedSpaces)
          '${space.semanticKey}|${_participationCode(space.participation)}|${space.areaDm2}',
      ].join('\n'),
    );

    return ApartmentAreaFitResult(
      fittedDraft: AreaFittedTopologyDraft(
        draft: draft,
        requestedInteriorAreaDm2: request.interiorAreaDm2,
        spaces: fittedSpaces,
        allocatedInteriorAreaDm2: allocatedInterior,
        exteriorAppendageAreaDm2: exteriorAppendage,
        interiorResidualDm2: residual,
        areaPolicyVersion: areaPolicyVersion,
        allocatorVersion: allocatorVersion,
        areaFitFingerprint: fingerprint,
      ),
      failures: const [],
    );
  }

  List<P9Failure> _validateInputs(
    ApartmentTopologyDraft draft,
    NormalizedApartmentRequest request,
    List<DraftSpace> spaces,
  ) {
    final failures = <P9Failure>[];
    if (draft.intentFingerprint != request.intentFingerprint) {
      failures.add(
        _failure(
          'p9.area.invalid-constraint',
          facts: {
            'reason': 'requestDraftIntentMismatch',
            'draftIntentFingerprint': draft.intentFingerprint,
            'requestIntentFingerprint': request.intentFingerprint,
          },
        ),
      );
    }
    if (request.interiorAreaDm2 <= 0 ||
        request.interiorAreaDm2 > maxSafeAreaDm2) {
      failures.add(
        _failure(
          'p9.area.integer-overflow-guard',
          facts: {
            'requestedInteriorAreaDm2': request.interiorAreaDm2,
            'guardDm2': maxSafeAreaDm2,
          },
        ),
      );
    }

    final seen = <String>{};
    var interiorCount = 0;
    for (final space in spaces) {
      if (!seen.add(space.semanticKey)) {
        failures.add(
          _failure(
            'p9.area.duplicate-space-key',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      final spec = space.sourceSpec;
      if (space.areaParticipation != spec.areaParticipation) {
        failures.add(
          _failure(
            'p9.area.invalid-participation',
            facts: {
              'semanticKey': space.semanticKey,
              'draftParticipation': _participationCode(space.areaParticipation),
              'specParticipation': _participationCode(spec.areaParticipation),
            },
          ),
        );
      }
      if (spec.minAreaDm2 <= 0 ||
          spec.minAreaDm2 > spec.preferredAreaDm2 ||
          spec.preferredAreaDm2 > spec.maxAreaDm2 ||
          spec.maxAreaDm2 > maxSafeAreaDm2) {
        failures.add(
          _failure(
            'p9.area.invalid-constraint',
            facts: {
              'semanticKey': space.semanticKey,
              'minAreaDm2': spec.minAreaDm2,
              'preferredAreaDm2': spec.preferredAreaDm2,
              'maxAreaDm2': spec.maxAreaDm2,
            },
          ),
        );
      }
      if (space.areaParticipation ==
          SpaceAreaParticipation.requestedInteriorArea) {
        interiorCount++;
        if (spec.areaWeightBp <= 0) {
          failures.add(
            _failure(
              'p9.area.invalid-constraint',
              facts: {
                'semanticKey': space.semanticKey,
                'areaWeightBp': spec.areaWeightBp,
                'reason': 'nonPositiveInteriorWeight',
              },
            ),
          );
        }
      } else if (spec.preferredAreaDm2 < spec.minAreaDm2 ||
          spec.preferredAreaDm2 > spec.maxAreaDm2) {
        failures.add(
          _failure(
            'p9.area.appendage-target-out-of-range',
            facts: {
              'semanticKey': space.semanticKey,
              'targetAreaDm2': spec.preferredAreaDm2,
            },
          ),
        );
      }
    }
    if (interiorCount == 0) {
      failures.add(
        _failure(
          'p9.area.invalid-constraint',
          facts: {'reason': 'noInteriorParticipants'},
        ),
      );
    }
    return failures;
  }

  int _distributeToward({
    required List<DraftSpace> spaces,
    required Map<String, int> allocations,
    required int remaining,
    required int Function(DraftSpace space) targetArea,
  }) {
    var residual = remaining;
    while (residual > 0) {
      final eligible = spaces
          .where(
            (space) => allocations[space.semanticKey]! < targetArea(space),
          )
          .toList()
        ..sort(_compareSpace);
      if (eligible.isEmpty) {
        return residual;
      }

      final phaseResidual = residual;
      final totalWeight = eligible.fold<int>(
        0,
        (total, space) => total + space.sourceSpec.areaWeightBp,
      );
      var distributed = 0;
      for (final space in eligible) {
        final current = allocations[space.semanticKey]!;
        final capacity = targetArea(space) - current;
        final proportional =
            (phaseResidual * space.sourceSpec.areaWeightBp) ~/ totalWeight;
        final share = proportional < capacity ? proportional : capacity;
        if (share <= 0) {
          continue;
        }
        allocations[space.semanticKey] = current + share;
        distributed += share;
      }
      residual -= distributed;
      if (residual == 0) {
        return 0;
      }
      if (distributed > 0) {
        continue;
      }

      eligible.sort(
        (left, right) {
          final leftUnmet =
              (targetArea(left) - allocations[left.semanticKey]!) *
                  left.sourceSpec.areaWeightBp;
          final rightUnmet =
              (targetArea(right) - allocations[right.semanticKey]!) *
                  right.sourceSpec.areaWeightBp;
          final priority = rightUnmet.compareTo(leftUnmet);
          return priority != 0
              ? priority
              : left.semanticKey.compareTo(right.semanticKey);
        },
      );
      var progressed = false;
      for (final space in eligible) {
        if (residual == 0) {
          break;
        }
        final current = allocations[space.semanticKey]!;
        if (current >= targetArea(space)) {
          continue;
        }
        allocations[space.semanticKey] = current + 1;
        residual--;
        progressed = true;
      }
      if (!progressed) {
        return residual;
      }
    }
    return residual;
  }
}

int _compareSpace(DraftSpace left, DraftSpace right) =>
    left.semanticKey.compareTo(right.semanticKey);

String _participationCode(SpaceAreaParticipation participation) =>
    switch (participation) {
      SpaceAreaParticipation.requestedInteriorArea => 'requestedInteriorArea',
      SpaceAreaParticipation.exteriorAppendage => 'exteriorAppendage',
    };

P9Failure _failure(String code, {Map<String, Object?> facts = const {}}) =>
    P9Failure(
      code: code,
      stage: P9FailureStage.area,
      severity: P9FailureSeverity.blocker,
      facts: facts,
    );
