import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/project_space_semantics.dart';
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
/// Policy v2 also reserves enough fitted area for the semantic circulation hub
/// to be realizable as a bounded P9.6 access spine. The reserve is derived only
/// from typed access edges and catalog dimensional minima; no geometry solver or
/// presentation state participates in P9.4.
final class ApartmentAreaFitter {
  const ApartmentAreaFitter();

  static const String areaPolicyVersion = '2';
  static const String allocatorVersion = '2';
  static const int maxSafeAreaDm2 = 1000000000;
  static const int squareMillimetresPerSquareDecimetre = 10000;

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

    final reserve = _circulationReserve(draft, interior);
    if (reserve != null) {
      final current = allocations[reserve.space.semanticKey]!;
      if (reserve.targetAreaDm2 > reserve.space.sourceSpec.maxAreaDm2) {
        return ApartmentAreaFitResult(
          fittedDraft: null,
          failures: [
            _failure(
              'p9.area.circulation-geometry-reserve',
              facts: {
                'semanticKey': reserve.space.semanticKey,
                'requiredAreaDm2': reserve.targetAreaDm2,
                'maximumAreaDm2': reserve.space.sourceSpec.maxAreaDm2,
              },
            ),
          ],
        );
      }
      final needed = reserve.targetAreaDm2 > current
          ? reserve.targetAreaDm2 - current
          : 0;
      if (needed > remaining) {
        return ApartmentAreaFitResult(
          fittedDraft: null,
          failures: [
            _failure(
              'p9.area.circulation-geometry-reserve',
              facts: {
                'semanticKey': reserve.space.semanticKey,
                'requiredAdditionalDm2': needed,
                'availableDm2': remaining,
              },
            ),
          ],
        );
      }
      allocations[reserve.space.semanticKey] = current + needed;
      remaining -= needed;
    }

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

  _CirculationReserve? _circulationReserve(
    ApartmentTopologyDraft draft,
    List<DraftSpace> interior,
  ) {
    DraftSpace? distribution;
    for (final space in interior) {
      if (space.usage == SpaceUsage.corridor) {
        distribution = space;
        break;
      }
    }
    if (distribution == null) {
      for (final space in interior) {
        if (space.usage == SpaceUsage.entranceHall) {
          distribution = space;
          break;
        }
      }
    }
    if (distribution == null) {
      return null;
    }

    final byKey = {for (final space in interior) space.semanticKey: space};
    final neighbors = <DraftSpace>[];
    for (final edge in draft.circulation.accessEdges) {
      String? neighborKey;
      if (edge.fromSpaceKey == distribution.semanticKey) {
        neighborKey = edge.toSpaceKey;
      } else if (edge.toSpaceKey == distribution.semanticKey) {
        neighborKey = edge.fromSpaceKey;
      }
      if (neighborKey == null) {
        continue;
      }
      final neighbor = byKey[neighborKey];
      if (neighbor != null && !neighbors.contains(neighbor)) {
        neighbors.add(neighbor);
      }
    }
    if (neighbors.isEmpty) {
      return null;
    }
    neighbors.sort(_compareSpace);

    var leftSpanMm = 0;
    var rightSpanMm = 0;
    for (final neighbor in neighbors) {
      final geometry = neighbor.sourceSpec.geometry;
      final exposure = geometry.minExteriorExposureMm ?? 0;
      final spanMm = geometry.minShortSideMm > exposure
          ? geometry.minShortSideMm
          : exposure;
      if (leftSpanMm <= rightSpanMm) {
        leftSpanMm += spanMm;
      } else {
        rightSpanMm += spanMm;
      }
    }

    final distributionGeometry = distribution.sourceSpec.geometry;
    var requiredLengthMm = leftSpanMm > rightSpanMm ? leftSpanMm : rightSpanMm;
    final minLong = distributionGeometry.minLongSideMm ?? 0;
    if (requiredLengthMm < minLong) {
      requiredLengthMm = minLong;
    }
    final requiredAreaMm2 =
        requiredLengthMm * distributionGeometry.minShortSideMm;
    var targetAreaDm2 =
        (requiredAreaMm2 + squareMillimetresPerSquareDecimetre - 1) ~/
            squareMillimetresPerSquareDecimetre;
    if (targetAreaDm2 < distribution.sourceSpec.preferredAreaDm2) {
      targetAreaDm2 = distribution.sourceSpec.preferredAreaDm2;
    }
    return _CirculationReserve(
      space: distribution,
      targetAreaDm2: targetAreaDm2,
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

final class _CirculationReserve {
  const _CirculationReserve({
    required this.space,
    required this.targetAreaDm2,
  });

  final DraftSpace space;
  final int targetAreaDm2;
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
