import '../domain/overcurrent_protection.dart';
import '../domain/residual_current_protection.dart';
import 'electrical_short_circuit_closure_engine.dart';

const String electricalResidualCurrentClosureVersion =
    'electrical.residual-current-closure.v1';

final class ElectricalResidualCurrentClosureRequest {
  ElectricalResidualCurrentClosureRequest({
    required this.d4Closure,
    required Iterable<ResidualCurrentProtectionPolicy> policies,
  }) : policies = List.unmodifiable(policies) {
    if (!d4Closure.isFullyClosed) {
      throw ArgumentError('D5 requires a fully closed D4 result.');
    }

    final outcomesById = {
      for (final outcome in d4Closure.outcomes) outcome.circuitId: outcome,
    };
    final expectedIds = outcomesById.keys.toSet();
    final actualIds = <String>{};
    for (final policy in this.policies) {
      if (!actualIds.add(policy.circuitId)) {
        throw ArgumentError('Duplicate D5 policy ${policy.circuitId}.');
      }
      final d4Outcome = outcomesById[policy.circuitId];
      if (d4Outcome == null) {
        throw ArgumentError(
          'D5 policy references unknown circuit ${policy.circuitId}.',
        );
      }

      final expectedLoadIds =
          d4Outcome.d3Outcome.circuit.circuit.loadIds.toList()..sort();
      if (!_sameStringList(policy.evaluatedLoadIds, expectedLoadIds)) {
        throw ArgumentError(
          'D5 policy load set does not match circuit ${policy.circuitId}.',
        );
      }

      if (policy.applicability == ResidualCurrentApplicability.required) {
        if (policy.preferredTypes.toSet().length !=
                policy.allowedTypes.length ||
            !policy.preferredTypes.toSet().containsAll(policy.allowedTypes)) {
          throw ArgumentError(
            'D5 preferred residual-current types must explicitly order every allowed type.',
          );
        }
        if (policy.preferredDeviceKinds.toSet().length !=
                policy.allowedDeviceKinds.length ||
            !policy.preferredDeviceKinds
                .toSet()
                .containsAll(policy.allowedDeviceKinds)) {
          throw ArgumentError(
            'D5 preferred device kinds must explicitly order every allowed kind.',
          );
        }
      }
    }

    final missing = expectedIds.difference(actualIds).toList()..sort();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing D5 policy for circuit(s): ${missing.join(', ')}.',
      );
    }
  }

  final ElectricalShortCircuitClosureResult d4Closure;
  final List<ResidualCurrentProtectionPolicy> policies;
}

enum ResidualCurrentClosureStatus {
  closedRequiredWithDevice,
  closedNotRequired,
  noCompliantDevice,
}

final class ResidualCurrentCandidateEvaluation {
  ResidualCurrentCandidateEvaluation({
    required this.candidate,
    required Iterable<String> rejections,
  }) : rejections = List.unmodifiable(rejections);

  final ResidualCurrentProtectiveDeviceSpec candidate;
  final List<String> rejections;

  bool get isCompliant => rejections.isEmpty;
}

final class ElectricalResidualCurrentClosureOutcome {
  ElectricalResidualCurrentClosureOutcome({
    required this.d4Outcome,
    required this.policy,
    required Iterable<ResidualCurrentCandidateEvaluation> evaluations,
    required this.selectedDevice,
    required this.status,
  }) : evaluations = List.unmodifiable(evaluations) {
    switch (status) {
      case ResidualCurrentClosureStatus.closedRequiredWithDevice:
        if (policy.applicability != ResidualCurrentApplicability.required ||
            selectedDevice == null) {
          throw ArgumentError(
            'Required D5 closure must carry a selected residual-current device.',
          );
        }
      case ResidualCurrentClosureStatus.closedNotRequired:
        if (policy.applicability != ResidualCurrentApplicability.notRequired ||
            selectedDevice != null) {
          throw ArgumentError(
            'Not-required D5 closure must be explicit and device-free.',
          );
        }
      case ResidualCurrentClosureStatus.noCompliantDevice:
        if (policy.applicability != ResidualCurrentApplicability.required ||
            selectedDevice != null) {
          throw ArgumentError(
            'No-compliant-device status is valid only for required D5 policies.',
          );
        }
    }
  }

  final ElectricalShortCircuitClosureOutcome d4Outcome;
  final ResidualCurrentProtectionPolicy policy;
  final List<ResidualCurrentCandidateEvaluation> evaluations;
  final ResidualCurrentProtectiveDeviceSpec? selectedDevice;
  final ResidualCurrentClosureStatus status;

  String get circuitId => d4Outcome.circuitId;

  bool get isClosed =>
      status == ResidualCurrentClosureStatus.closedRequiredWithDevice ||
      status == ResidualCurrentClosureStatus.closedNotRequired;
}

final class ElectricalResidualCurrentClosureResult {
  ElectricalResidualCurrentClosureResult({
    required Iterable<ElectricalResidualCurrentClosureOutcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes) {
    if (this.outcomes.isEmpty) {
      throw ArgumentError('D5 result must contain circuit outcomes.');
    }
    final ids = <String>{};
    for (final outcome in this.outcomes) {
      if (!ids.add(outcome.circuitId)) {
        throw ArgumentError('Duplicate D5 outcome ${outcome.circuitId}.');
      }
    }
  }

  final List<ElectricalResidualCurrentClosureOutcome> outcomes;

  bool get isFullyClosed => outcomes.every((outcome) => outcome.isClosed);
}

abstract final class ResidualCurrentProtectionEngine {
  static ElectricalResidualCurrentClosureResult close(
    ElectricalResidualCurrentClosureRequest request,
  ) {
    final policies = {
      for (final policy in request.policies) policy.circuitId: policy,
    };
    final d4Outcomes = request.d4Closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));

    return ElectricalResidualCurrentClosureResult(
      outcomes: [
        for (final d4Outcome in d4Outcomes)
          _closeCircuit(
            d4Outcome: d4Outcome,
            policy: policies[d4Outcome.circuitId]!,
          ),
      ],
    );
  }

  static ElectricalResidualCurrentClosureOutcome _closeCircuit({
    required ElectricalShortCircuitClosureOutcome d4Outcome,
    required ResidualCurrentProtectionPolicy policy,
  }) {
    if (policy.applicability == ResidualCurrentApplicability.notRequired) {
      return ElectricalResidualCurrentClosureOutcome(
        d4Outcome: d4Outcome,
        policy: policy,
        evaluations: const [],
        selectedDevice: null,
        status: ResidualCurrentClosureStatus.closedNotRequired,
      );
    }

    final evaluations = <ResidualCurrentCandidateEvaluation>[
      for (final candidate in policy.candidates)
        _evaluateCandidate(
          d4Outcome: d4Outcome,
          policy: policy,
          candidate: candidate,
        ),
    ];
    final compliant = evaluations.where((item) => item.isCompliant).toList()
      ..sort((left, right) => _compareCandidates(
            policy,
            left.candidate,
            right.candidate,
          ));

    if (compliant.isEmpty) {
      return ElectricalResidualCurrentClosureOutcome(
        d4Outcome: d4Outcome,
        policy: policy,
        evaluations: evaluations,
        selectedDevice: null,
        status: ResidualCurrentClosureStatus.noCompliantDevice,
      );
    }

    return ElectricalResidualCurrentClosureOutcome(
      d4Outcome: d4Outcome,
      policy: policy,
      evaluations: evaluations,
      selectedDevice: compliant.first.candidate,
      status: ResidualCurrentClosureStatus.closedRequiredWithDevice,
    );
  }

  static ResidualCurrentCandidateEvaluation _evaluateCandidate({
    required ElectricalShortCircuitClosureOutcome d4Outcome,
    required ResidualCurrentProtectionPolicy policy,
    required ResidualCurrentProtectiveDeviceSpec candidate,
  }) {
    final reasons = <String>[];
    final d3Outcome = d4Outcome.d3Outcome;
    final selectedOvercurrent = d3Outcome.selectedProtection!;
    final prospectiveShortCircuitCurrentA =
        d3Outcome.policy.prospectiveShortCircuitCurrentA;

    if (!policy.allowedDeviceKinds.contains(candidate.kind)) {
      reasons.add('device-kind-not-allowed');
    }
    if (!policy.allowedTypes.contains(candidate.residualType)) {
      reasons.add('residual-current-type-not-allowed');
    }
    if (candidate.residualOperatingCurrentMa >
        policy.maximumResidualOperatingCurrentMa!) {
      reasons.add('residual-operating-current-exceeds-policy-maximum');
    }
    if (candidate.poleCount < policy.minimumPoleCount!) {
      reasons.add('pole-count-below-policy-minimum');
    }

    switch (candidate.kind) {
      case ResidualCurrentDeviceKind.rcd:
        if (candidate.ratedCurrentA < selectedOvercurrent.ratedCurrentA) {
          reasons.add('rcd-rated-current-below-upstream-overcurrent-rating');
        }
        if (candidate.conditionalShortCircuitCurrentA! <
            prospectiveShortCircuitCurrentA) {
          reasons.add('rcd-conditional-short-circuit-current-insufficient');
        }
        if (!candidate.compatibleBackupOvercurrentDeviceIds
            .contains(selectedOvercurrent.id)) {
          reasons.add('rcd-backup-overcurrent-device-not-compatible');
        }
      case ResidualCurrentDeviceKind.rcbo:
        if (selectedOvercurrent.kind != OvercurrentDeviceKind.rcbo) {
          reasons.add('rcbo-cannot-replace-d3-selected-overcurrent-device');
        }
        if (candidate.overcurrentDeviceId != selectedOvercurrent.id) {
          reasons.add('rcbo-does-not-bind-d3-selected-overcurrent-device');
        }
        if ((candidate.ratedCurrentA - selectedOvercurrent.ratedCurrentA)
                .abs() >
            1e-9) {
          reasons.add('rcbo-rated-current-does-not-match-d3-device');
        }
    }

    return ResidualCurrentCandidateEvaluation(
      candidate: candidate,
      rejections: reasons,
    );
  }

  static int _compareCandidates(
    ResidualCurrentProtectionPolicy policy,
    ResidualCurrentProtectiveDeviceSpec left,
    ResidualCurrentProtectiveDeviceSpec right,
  ) {
    final byKind = policy.preferredDeviceKinds
        .indexOf(left.kind)
        .compareTo(policy.preferredDeviceKinds.indexOf(right.kind));
    if (byKind != 0) return byKind;

    final byType = policy.preferredTypes
        .indexOf(left.residualType)
        .compareTo(policy.preferredTypes.indexOf(right.residualType));
    if (byType != 0) return byType;

    final bySensitivity = switch (policy.sensitivityPreference!) {
      ResidualCurrentSensitivityPreference.lowestAvailable => left
          .residualOperatingCurrentMa
          .compareTo(right.residualOperatingCurrentMa),
      ResidualCurrentSensitivityPreference.highestPermitted => right
          .residualOperatingCurrentMa
          .compareTo(left.residualOperatingCurrentMa),
    };
    if (bySensitivity != 0) return bySensitivity;

    return left.id.compareTo(right.id);
  }
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
