import '../domain/overcurrent_protection.dart';

const String overcurrentProtectionSelectionVersion =
    'electrical.overcurrent-selection.v1';

/// Selects the smallest compliant protective-device rating.
///
/// The engine proves only overload-current coordination and breaking capacity:
///   Ib <= In <= Iz
///   breakingCapacity >= prospectiveShortCircuitCurrent
///
/// It deliberately does not claim disconnection-time selectivity, upstream /
/// downstream coordination or residual-current protection.
abstract final class OvercurrentProtectionSelectionEngine {
  static OvercurrentProtectionSelectionResult select(
    OvercurrentProtectionRequest request,
  ) {
    _validateRequest(request);

    final accepted = <OvercurrentProtectiveDeviceSpec>[];
    final rejections = <String, List<String>>{};

    for (final candidate in request.candidates) {
      final reasons = <String>[];
      if (!request.allowedKinds.contains(candidate.kind)) {
        reasons.add('device-kind-not-allowed');
      }
      if (candidate.ratedCurrentA < request.designCurrentA) {
        reasons.add('rated-current-below-design-current');
      }
      if (candidate.ratedCurrentA > request.cableAmpacityA) {
        reasons.add('rated-current-exceeds-cable-ampacity');
      }
      if (candidate.breakingCapacityKa * 1000 <
          request.prospectiveShortCircuitCurrentA) {
        reasons
            .add('breaking-capacity-below-prospective-short-circuit-current');
      }

      if (reasons.isEmpty) {
        accepted.add(candidate);
      } else {
        rejections[candidate.id] = List.unmodifiable(reasons);
      }
    }

    accepted.sort((left, right) {
      final current = left.ratedCurrentA.compareTo(right.ratedCurrentA);
      if (current != 0) return current;
      final breaking =
          left.breakingCapacityKa.compareTo(right.breakingCapacityKa);
      if (breaking != 0) return breaking;
      return left.id.compareTo(right.id);
    });

    if (accepted.isEmpty) {
      return OvercurrentProtectionSelectionResult(
        status: OvercurrentSelectionStatus.noCompliantCandidate,
        selected: null,
        rejections: Map.unmodifiable(rejections),
      );
    }

    return OvercurrentProtectionSelectionResult(
      status: OvercurrentSelectionStatus.selected,
      selected: accepted.first,
      rejections: Map.unmodifiable(rejections),
    );
  }

  static void _validateRequest(OvercurrentProtectionRequest request) {
    if (!request.designCurrentA.isFinite || request.designCurrentA <= 0) {
      throw ArgumentError.value(request.designCurrentA, 'designCurrentA');
    }
    if (!request.cableAmpacityA.isFinite || request.cableAmpacityA <= 0) {
      throw ArgumentError.value(request.cableAmpacityA, 'cableAmpacityA');
    }
    if (!request.prospectiveShortCircuitCurrentA.isFinite ||
        request.prospectiveShortCircuitCurrentA <= 0) {
      throw ArgumentError.value(
        request.prospectiveShortCircuitCurrentA,
        'prospectiveShortCircuitCurrentA',
      );
    }
    if (request.allowedKinds.isEmpty) {
      throw ArgumentError('At least one overcurrent device kind is required.');
    }

    final candidateIds = <String>{};
    for (final candidate in request.candidates) {
      if (candidate.id.trim().isEmpty ||
          candidate.sourceId.trim().isEmpty ||
          candidate.sourceRevision.trim().isEmpty) {
        throw ArgumentError(
          'Overcurrent device identity/source fields must be non-empty.',
        );
      }
      if (!candidateIds.add(candidate.id)) {
        throw ArgumentError('Duplicate overcurrent device ${candidate.id}.');
      }
      if (!candidate.ratedCurrentA.isFinite || candidate.ratedCurrentA <= 0) {
        throw ArgumentError.value(candidate.ratedCurrentA, 'ratedCurrentA');
      }
      if (!candidate.breakingCapacityKa.isFinite ||
          candidate.breakingCapacityKa <= 0) {
        throw ArgumentError.value(
          candidate.breakingCapacityKa,
          'breakingCapacityKa',
        );
      }
      if (candidate.poleCount <= 0) {
        throw ArgumentError.value(candidate.poleCount, 'poleCount');
      }
    }
  }
}
