import '../domain/protective_device_coordination.dart';
import 'residual_current_protection_engine.dart';

const String electricalProtectionCoordinationClosureVersion =
    'electrical.protection-coordination-closure.v1';

final class ElectricalProtectionCoordinationClosureRequest {
  ElectricalProtectionCoordinationClosureRequest({
    required this.d5Closure,
    required Iterable<ProtectiveDeviceCoordinationPolicy> policies,
  }) : policies = List.unmodifiable(policies) {
    if (!d5Closure.isFullyClosed) {
      throw ArgumentError('D6 requires a fully closed D5 result.');
    }

    final outcomesById = {
      for (final outcome in d5Closure.outcomes) outcome.circuitId: outcome,
    };
    final expectedIds = outcomesById.keys.toSet();
    final actualIds = <String>{};

    for (final policy in this.policies) {
      if (!actualIds.add(policy.circuitId)) {
        throw ArgumentError('Duplicate D6 policy ${policy.circuitId}.');
      }
      final d5Outcome = outcomesById[policy.circuitId];
      if (d5Outcome == null) {
        throw ArgumentError(
          'D6 policy references unknown circuit ${policy.circuitId}.',
        );
      }
      final selectedDownstream =
          d5Outcome.d4Outcome.d3Outcome.selectedProtection!;
      if (policy.evaluatedDownstreamDeviceId != selectedDownstream.id) {
        throw ArgumentError(
          'D6 policy downstream device does not match D3 selection for ${policy.circuitId}.',
        );
      }
    }

    final missing = expectedIds.difference(actualIds).toList()..sort();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing D6 policy for circuit(s): ${missing.join(', ')}.',
      );
    }
  }

  final ElectricalResidualCurrentClosureResult d5Closure;
  final List<ProtectiveDeviceCoordinationPolicy> policies;
}

enum ProtectiveDeviceCoordinationClosureStatus {
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

final class ElectricalProtectionCoordinationClosureOutcome {
  ElectricalProtectionCoordinationClosureOutcome({
    required this.d5Outcome,
    required this.policy,
    required Iterable<ProtectiveDeviceCoordinationEvidenceEvaluation>
        evaluations,
    required this.selectedEvidence,
    required this.status,
  }) : evaluations = List.unmodifiable(evaluations) {
    switch (status) {
      case ProtectiveDeviceCoordinationClosureStatus.closedRequiredWithEvidence:
        if (policy.applicability !=
                ProtectiveDeviceCoordinationApplicability.required ||
            selectedEvidence == null) {
          throw ArgumentError(
            'Required D6 closure must carry selected coordination evidence.',
          );
        }
      case ProtectiveDeviceCoordinationClosureStatus.closedNotRequired:
        if (policy.applicability !=
                ProtectiveDeviceCoordinationApplicability.notRequired ||
            selectedEvidence != null) {
          throw ArgumentError(
            'Not-required D6 closure must be explicit and evidence-free.',
          );
        }
      case ProtectiveDeviceCoordinationClosureStatus.noCompliantEvidence:
        if (policy.applicability !=
                ProtectiveDeviceCoordinationApplicability.required ||
            selectedEvidence != null) {
          throw ArgumentError(
            'No-compliant-evidence status is valid only for required D6 policies.',
          );
        }
    }
  }

  final ElectricalResidualCurrentClosureOutcome d5Outcome;
  final ProtectiveDeviceCoordinationPolicy policy;
  final List<ProtectiveDeviceCoordinationEvidenceEvaluation> evaluations;
  final ProtectiveDeviceSelectivityEvidence? selectedEvidence;
  final ProtectiveDeviceCoordinationClosureStatus status;

  String get circuitId => d5Outcome.circuitId;

  bool get isClosed =>
      status ==
          ProtectiveDeviceCoordinationClosureStatus
              .closedRequiredWithEvidence ||
      status == ProtectiveDeviceCoordinationClosureStatus.closedNotRequired;
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
    final d5Outcomes = request.d5Closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));

    return ElectricalProtectionCoordinationClosureResult(
      outcomes: [
        for (final d5Outcome in d5Outcomes)
          _closeCircuit(
            d5Outcome: d5Outcome,
            policy: policies[d5Outcome.circuitId]!,
          ),
      ],
    );
  }

  static ElectricalProtectionCoordinationClosureOutcome _closeCircuit({
    required ElectricalResidualCurrentClosureOutcome d5Outcome,
    required ProtectiveDeviceCoordinationPolicy policy,
  }) {
    if (policy.applicability ==
        ProtectiveDeviceCoordinationApplicability.notRequired) {
      return ElectricalProtectionCoordinationClosureOutcome(
        d5Outcome: d5Outcome,
        policy: policy,
        evaluations: const [],
        selectedEvidence: null,
        status: ProtectiveDeviceCoordinationClosureStatus.closedNotRequired,
      );
    }

    final evaluations = <ProtectiveDeviceCoordinationEvidenceEvaluation>[
      for (final evidence in policy.selectivityEvidence)
        _evaluateEvidence(
          d5Outcome: d5Outcome,
          policy: policy,
          evidence: evidence,
        ),
    ];
    final compliant = evaluations.where((item) => item.isCompliant).toList()
      ..sort(_compareEvidence);

    if (compliant.isEmpty) {
      return ElectricalProtectionCoordinationClosureOutcome(
        d5Outcome: d5Outcome,
        policy: policy,
        evaluations: evaluations,
        selectedEvidence: null,
        status: ProtectiveDeviceCoordinationClosureStatus.noCompliantEvidence,
      );
    }

    return ElectricalProtectionCoordinationClosureOutcome(
      d5Outcome: d5Outcome,
      policy: policy,
      evaluations: evaluations,
      selectedEvidence: compliant.first.evidence,
      status:
          ProtectiveDeviceCoordinationClosureStatus.closedRequiredWithEvidence,
    );
  }

  static ProtectiveDeviceCoordinationEvidenceEvaluation _evaluateEvidence({
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

  static int _compareEvidence(
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
