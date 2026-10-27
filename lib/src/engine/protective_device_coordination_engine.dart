import '../domain/protective_device_coordination.dart';
import 'residual_current_protection_engine.dart';

const String electricalProtectionCoordinationClosureVersion =
    'electrical.protection-coordination-closure.v2';

final class ElectricalProtectionCoordinationClosureRequest {
  ElectricalProtectionCoordinationClosureRequest({
    required this.d5Closure,
    required Iterable<ProtectiveDeviceCoordinationPolicy> policies,
    required Iterable<ResidualCurrentDeviceCoordinationPolicy>
        residualCurrentPolicies,
  })  : policies = List.unmodifiable(policies),
        residualCurrentPolicies = List.unmodifiable(residualCurrentPolicies) {
    if (!d5Closure.isFullyClosed) {
      throw ArgumentError('D6 requires a fully closed D5 result.');
    }

    final outcomesById = {
      for (final outcome in d5Closure.outcomes) outcome.circuitId: outcome,
    };
    final expectedIds = outcomesById.keys.toSet();
    final actualOvercurrentIds = <String>{};

    for (final policy in this.policies) {
      if (!actualOvercurrentIds.add(policy.circuitId)) {
        throw ArgumentError(
          'Duplicate D6 overcurrent policy ${policy.circuitId}.',
        );
      }
      final d5Outcome = outcomesById[policy.circuitId];
      if (d5Outcome == null) {
        throw ArgumentError(
          'D6 overcurrent policy references unknown circuit ${policy.circuitId}.',
        );
      }
      final selectedDownstream =
          d5Outcome.d4Outcome.d3Outcome.selectedProtection!;
      if (policy.evaluatedDownstreamDeviceId != selectedDownstream.id) {
        throw ArgumentError(
          'D6 overcurrent policy downstream device does not match D3 selection '
          'for ${policy.circuitId}.',
        );
      }
    }

    final missingOvercurrent =
        expectedIds.difference(actualOvercurrentIds).toList()..sort();
    if (missingOvercurrent.isNotEmpty) {
      throw ArgumentError(
        'Missing D6 overcurrent policy for circuit(s): '
        '${missingOvercurrent.join(', ')}.',
      );
    }

    final actualResidualIds = <String>{};
    for (final policy in this.residualCurrentPolicies) {
      if (!actualResidualIds.add(policy.circuitId)) {
        throw ArgumentError(
          'Duplicate D6 residual-current policy ${policy.circuitId}.',
        );
      }
      final d5Outcome = outcomesById[policy.circuitId];
      if (d5Outcome == null) {
        throw ArgumentError(
          'D6 residual-current policy references unknown circuit '
          '${policy.circuitId}.',
        );
      }

      final selectedResidual = d5Outcome.selectedDevice;
      if (selectedResidual == null) {
        if (policy.evaluatedDownstreamDeviceId != null ||
            policy.applicability !=
                ResidualCurrentCoordinationApplicability.notRequired) {
          throw ArgumentError(
            'D6 residual-current policy must be explicitly not-required with '
            'no downstream device when D5 selected no residual-current device '
            'for ${policy.circuitId}.',
          );
        }
      } else if (policy.evaluatedDownstreamDeviceId != selectedResidual.id) {
        throw ArgumentError(
          'D6 residual-current policy downstream device does not match D5 '
          'selection for ${policy.circuitId}.',
        );
      }
    }

    final missingResidual = expectedIds.difference(actualResidualIds).toList()
      ..sort();
    if (missingResidual.isNotEmpty) {
      throw ArgumentError(
        'Missing D6 residual-current policy for circuit(s): '
        '${missingResidual.join(', ')}.',
      );
    }
  }

  final ElectricalResidualCurrentClosureResult d5Closure;
  final List<ProtectiveDeviceCoordinationPolicy> policies;
  final List<ResidualCurrentDeviceCoordinationPolicy> residualCurrentPolicies;
}

enum ProtectiveDeviceCoordinationClosureStatus {
  closedRequiredWithEvidence,
  closedNotRequired,
  noCompliantEvidence,
}

enum ResidualCurrentCoordinationClosureStatus {
  closedRequiredWithEvidence,
  closedNotRequired,
  noCompliantEvidence,
}

final class ProtectiveDeviceCoordinationEvidenceEvaluation {
  ProtectiveDeviceCoordinationEvidenceEvaluation({
    required this.evidence,
    required Iterable<String> rejections,
  }) : rejections = List.unmodifiable(rejections);

  final ProtectiveDeviceSelectivityEvidence evidence;
  final List<String> rejections;

  bool get isCompliant => rejections.isEmpty;
}

final class ResidualCurrentCoordinationEvidenceEvaluation {
  ResidualCurrentCoordinationEvidenceEvaluation({
    required this.evidence,
    required Iterable<String> rejections,
  }) : rejections = List.unmodifiable(rejections);

  final ResidualCurrentSelectivityEvidence evidence;
  final List<String> rejections;

  bool get isCompliant => rejections.isEmpty;
}

final class ElectricalProtectionCoordinationClosureOutcome {
  ElectricalProtectionCoordinationClosureOutcome({
    required this.d5Outcome,
    required this.policy,
    required Iterable<ProtectiveDeviceCoordinationEvidenceEvaluation>
        evaluations,
    required this.selectedEvidence,
    required this.status,
    required this.residualCurrentPolicy,
    required Iterable<ResidualCurrentCoordinationEvidenceEvaluation>
        residualCurrentEvaluations,
    required this.selectedResidualCurrentEvidence,
    required this.residualCurrentStatus,
  })  : evaluations = List.unmodifiable(evaluations),
        residualCurrentEvaluations =
            List.unmodifiable(residualCurrentEvaluations) {
    _validateOvercurrentOutcome();
    _validateResidualCurrentOutcome();
  }

  final ElectricalResidualCurrentClosureOutcome d5Outcome;
  final ProtectiveDeviceCoordinationPolicy policy;
  final List<ProtectiveDeviceCoordinationEvidenceEvaluation> evaluations;
  final ProtectiveDeviceSelectivityEvidence? selectedEvidence;
  final ProtectiveDeviceCoordinationClosureStatus status;
  final ResidualCurrentDeviceCoordinationPolicy residualCurrentPolicy;
  final List<ResidualCurrentCoordinationEvidenceEvaluation>
      residualCurrentEvaluations;
  final ResidualCurrentSelectivityEvidence? selectedResidualCurrentEvidence;
  final ResidualCurrentCoordinationClosureStatus residualCurrentStatus;

  String get circuitId => d5Outcome.circuitId;

  bool get isClosed =>
      _isOvercurrentClosed(status) &&
      _isResidualCurrentClosed(residualCurrentStatus);

  void _validateOvercurrentOutcome() {
    switch (status) {
      case ProtectiveDeviceCoordinationClosureStatus.closedRequiredWithEvidence:
        if (policy.applicability !=
                ProtectiveDeviceCoordinationApplicability.required ||
            selectedEvidence == null) {
          throw ArgumentError(
            'Required D6 overcurrent closure must carry selected coordination '
            'evidence.',
          );
        }
      case ProtectiveDeviceCoordinationClosureStatus.closedNotRequired:
        if (policy.applicability !=
                ProtectiveDeviceCoordinationApplicability.notRequired ||
            selectedEvidence != null) {
          throw ArgumentError(
            'Not-required D6 overcurrent closure must be explicit and '
            'evidence-free.',
          );
        }
      case ProtectiveDeviceCoordinationClosureStatus.noCompliantEvidence:
        if (policy.applicability !=
                ProtectiveDeviceCoordinationApplicability.required ||
            selectedEvidence != null) {
          throw ArgumentError(
            'No-compliant-evidence overcurrent status is valid only for '
            'required D6 policies.',
          );
        }
    }
  }

  void _validateResidualCurrentOutcome() {
    switch (residualCurrentStatus) {
      case ResidualCurrentCoordinationClosureStatus.closedRequiredWithEvidence:
        if (residualCurrentPolicy.applicability !=
                ResidualCurrentCoordinationApplicability.required ||
            selectedResidualCurrentEvidence == null) {
          throw ArgumentError(
            'Required D6 residual-current closure must carry selected pair '
            'evidence.',
          );
        }
      case ResidualCurrentCoordinationClosureStatus.closedNotRequired:
        if (residualCurrentPolicy.applicability !=
                ResidualCurrentCoordinationApplicability.notRequired ||
            selectedResidualCurrentEvidence != null) {
          throw ArgumentError(
            'Not-required D6 residual-current closure must be explicit and '
            'evidence-free.',
          );
        }
      case ResidualCurrentCoordinationClosureStatus.noCompliantEvidence:
        if (residualCurrentPolicy.applicability !=
                ResidualCurrentCoordinationApplicability.required ||
            selectedResidualCurrentEvidence != null) {
          throw ArgumentError(
            'No-compliant-evidence residual-current status is valid only for '
            'required D6 policies.',
          );
        }
    }
  }
}

final class ElectricalProtectionCoordinationClosureResult {
  ElectricalProtectionCoordinationClosureResult({
    required Iterable<ElectricalProtectionCoordinationClosureOutcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes) {
    if (this.outcomes.isEmpty) {
      throw ArgumentError('D6 result must contain circuit outcomes.');
    }
    final ids = <String>{};
    for (final outcome in this.outcomes) {
      if (!ids.add(outcome.circuitId)) {
        throw ArgumentError('Duplicate D6 outcome ${outcome.circuitId}.');
      }
    }
  }

  final List<ElectricalProtectionCoordinationClosureOutcome> outcomes;

  bool get isFullyClosed => outcomes.every((outcome) => outcome.isClosed);
}

abstract final class ProtectiveDeviceCoordinationEngine {
  static ElectricalProtectionCoordinationClosureResult close(
    ElectricalProtectionCoordinationClosureRequest request,
  ) {
    final policies = {
      for (final policy in request.policies) policy.circuitId: policy,
    };
    final residualPolicies = {
      for (final policy in request.residualCurrentPolicies)
        policy.circuitId: policy,
    };
    final d5Outcomes = request.d5Closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));

    return ElectricalProtectionCoordinationClosureResult(
      outcomes: [
        for (final d5Outcome in d5Outcomes)
          _closeCircuit(
            d5Outcome: d5Outcome,
            policy: policies[d5Outcome.circuitId]!,
            residualCurrentPolicy: residualPolicies[d5Outcome.circuitId]!,
          ),
      ],
    );
  }

  static ElectricalProtectionCoordinationClosureOutcome _closeCircuit({
    required ElectricalResidualCurrentClosureOutcome d5Outcome,
    required ProtectiveDeviceCoordinationPolicy policy,
    required ResidualCurrentDeviceCoordinationPolicy residualCurrentPolicy,
  }) {
    final overcurrent = _closeOvercurrent(
      d5Outcome: d5Outcome,
      policy: policy,
    );
    final residualCurrent = _closeResidualCurrent(
      d5Outcome: d5Outcome,
      policy: residualCurrentPolicy,
    );

    return ElectricalProtectionCoordinationClosureOutcome(
      d5Outcome: d5Outcome,
      policy: policy,
      evaluations: overcurrent.evaluations,
      selectedEvidence: overcurrent.selectedEvidence,
      status: overcurrent.status,
      residualCurrentPolicy: residualCurrentPolicy,
      residualCurrentEvaluations: residualCurrent.evaluations,
      selectedResidualCurrentEvidence: residualCurrent.selectedEvidence,
      residualCurrentStatus: residualCurrent.status,
    );
  }

  static _OvercurrentClosure _closeOvercurrent({
    required ElectricalResidualCurrentClosureOutcome d5Outcome,
    required ProtectiveDeviceCoordinationPolicy policy,
  }) {
    if (policy.applicability ==
        ProtectiveDeviceCoordinationApplicability.notRequired) {
      return const _OvercurrentClosure(
        evaluations: [],
        selectedEvidence: null,
        status: ProtectiveDeviceCoordinationClosureStatus.closedNotRequired,
      );
    }

    final evaluations = <ProtectiveDeviceCoordinationEvidenceEvaluation>[
      for (final evidence in policy.selectivityEvidence)
        _evaluateOvercurrentEvidence(
          d5Outcome: d5Outcome,
          policy: policy,
          evidence: evidence,
        ),
    ];
    final compliant = evaluations.where((item) => item.isCompliant).toList()
      ..sort(_compareOvercurrentEvidence);

    if (compliant.isEmpty) {
      return _OvercurrentClosure(
        evaluations: evaluations,
        selectedEvidence: null,
        status: ProtectiveDeviceCoordinationClosureStatus.noCompliantEvidence,
      );
    }

    return _OvercurrentClosure(
      evaluations: evaluations,
      selectedEvidence: compliant.first.evidence,
      status:
          ProtectiveDeviceCoordinationClosureStatus.closedRequiredWithEvidence,
    );
  }

  static _ResidualCurrentClosure _closeResidualCurrent({
    required ElectricalResidualCurrentClosureOutcome d5Outcome,
    required ResidualCurrentDeviceCoordinationPolicy policy,
  }) {
    if (policy.applicability ==
        ResidualCurrentCoordinationApplicability.notRequired) {
      return const _ResidualCurrentClosure(
        evaluations: [],
        selectedEvidence: null,
        status: ResidualCurrentCoordinationClosureStatus.closedNotRequired,
      );
    }

    final evaluations = <ResidualCurrentCoordinationEvidenceEvaluation>[
      for (final evidence in policy.selectivityEvidence)
        _evaluateResidualCurrentEvidence(
          d5Outcome: d5Outcome,
          policy: policy,
          evidence: evidence,
        ),
    ];
    final compliant = evaluations.where((item) => item.isCompliant).toList()
      ..sort(
        (left, right) => left.evidence.id.compareTo(right.evidence.id),
      );

    if (compliant.isEmpty) {
      return _ResidualCurrentClosure(
        evaluations: evaluations,
        selectedEvidence: null,
        status: ResidualCurrentCoordinationClosureStatus.noCompliantEvidence,
      );
    }

    return _ResidualCurrentClosure(
      evaluations: evaluations,
      selectedEvidence: compliant.first.evidence,
      status: ResidualCurrentCoordinationClosureStatus.closedRequiredWithEvidence,
    );
  }

  static ProtectiveDeviceCoordinationEvidenceEvaluation
      _evaluateOvercurrentEvidence({
    required ElectricalResidualCurrentClosureOutcome d5Outcome,
    required ProtectiveDeviceCoordinationPolicy policy,
    required ProtectiveDeviceSelectivityEvidence evidence,
  }) {
    final reasons = <String>[];
    final downstream = d5Outcome.d4Outcome.d3Outcome.selectedProtection!;
    final upstream = policy.upstreamDevice!;
    final prospectiveShortCircuitCurrentA =
        d5Outcome.d4Outcome.d3Outcome.policy.prospectiveShortCircuitCurrentA;

    if (evidence.downstreamDeviceId != downstream.id) {
      reasons.add('coordination-downstream-device-mismatch');
    }
    if (evidence.upstreamDeviceId != upstream.id) {
      reasons.add('coordination-upstream-device-mismatch');
    }

    switch (evidence.kind) {
      case ProtectiveDeviceSelectivityKind.total:
        break;
      case ProtectiveDeviceSelectivityKind.limited:
        if (evidence.selectivityLimitA! < prospectiveShortCircuitCurrentA) {
          reasons
              .add('selectivity-limit-below-prospective-short-circuit-current');
        }
    }

    return ProtectiveDeviceCoordinationEvidenceEvaluation(
      evidence: evidence,
      rejections: reasons,
    );
  }

  static ResidualCurrentCoordinationEvidenceEvaluation
      _evaluateResidualCurrentEvidence({
    required ElectricalResidualCurrentClosureOutcome d5Outcome,
    required ResidualCurrentDeviceCoordinationPolicy policy,
    required ResidualCurrentSelectivityEvidence evidence,
  }) {
    final reasons = <String>[];
    final downstream = d5Outcome.selectedDevice!;
    final upstream = policy.upstreamDevice!;

    if (evidence.downstreamDeviceId != downstream.id) {
      reasons.add('residual-coordination-downstream-device-mismatch');
    }
    if (evidence.upstreamDeviceId != upstream.id) {
      reasons.add('residual-coordination-upstream-device-mismatch');
    }

    return ResidualCurrentCoordinationEvidenceEvaluation(
      evidence: evidence,
      rejections: reasons,
    );
  }

  static int _compareOvercurrentEvidence(
    ProtectiveDeviceCoordinationEvidenceEvaluation left,
    ProtectiveDeviceCoordinationEvidenceEvaluation right,
  ) {
    final leftEvidence = left.evidence;
    final rightEvidence = right.evidence;

    final byKind = _kindRank(leftEvidence.kind).compareTo(
      _kindRank(rightEvidence.kind),
    );
    if (byKind != 0) return byKind;

    if (leftEvidence.kind == ProtectiveDeviceSelectivityKind.limited &&
        rightEvidence.kind == ProtectiveDeviceSelectivityKind.limited) {
      final byLimit = rightEvidence.selectivityLimitA!.compareTo(
        leftEvidence.selectivityLimitA!,
      );
      if (byLimit != 0) return byLimit;
    }

    return leftEvidence.id.compareTo(rightEvidence.id);
  }

  static int _kindRank(ProtectiveDeviceSelectivityKind kind) => switch (kind) {
        ProtectiveDeviceSelectivityKind.total => 0,
        ProtectiveDeviceSelectivityKind.limited => 1,
      };
}

bool _isOvercurrentClosed(ProtectiveDeviceCoordinationClosureStatus status) =>
    status ==
        ProtectiveDeviceCoordinationClosureStatus.closedRequiredWithEvidence ||
    status == ProtectiveDeviceCoordinationClosureStatus.closedNotRequired;

bool _isResidualCurrentClosed(ResidualCurrentCoordinationClosureStatus status) =>
    status == ResidualCurrentCoordinationClosureStatus.closedRequiredWithEvidence ||
    status == ResidualCurrentCoordinationClosureStatus.closedNotRequired;

final class _OvercurrentClosure {
  const _OvercurrentClosure({
    required this.evaluations,
    required this.selectedEvidence,
    required this.status,
  });

  final List<ProtectiveDeviceCoordinationEvidenceEvaluation> evaluations;
  final ProtectiveDeviceSelectivityEvidence? selectedEvidence;
  final ProtectiveDeviceCoordinationClosureStatus status;
}

final class _ResidualCurrentClosure {
  const _ResidualCurrentClosure({
    required this.evaluations,
    required this.selectedEvidence,
    required this.status,
  });

  final List<ResidualCurrentCoordinationEvidenceEvaluation> evaluations;
  final ResidualCurrentSelectivityEvidence? selectedEvidence;
  final ResidualCurrentCoordinationClosureStatus status;
}
