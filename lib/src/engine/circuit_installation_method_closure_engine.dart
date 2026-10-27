import '../domain/circuit_installation_method.dart';
import 'protective_device_coordination_engine.dart';

const String electricalCircuitInstallationMethodClosureVersion =
    'electrical.circuit-installation-method-closure.v1';

final class ElectricalCircuitInstallationMethodClosureRequest {
  ElectricalCircuitInstallationMethodClosureRequest({
    required this.d6Closure,
    required Iterable<CircuitInstallationMethodPolicy> policies,
  }) : policies = List.unmodifiable(policies) {
    if (!d6Closure.isFullyClosed) {
      throw ArgumentError('D7 requires a fully closed D6 result.');
    }

    final outcomesById = {
      for (final outcome in d6Closure.outcomes) outcome.circuitId: outcome,
    };
    final expectedIds = outcomesById.keys.toSet();
    final actualIds = <String>{};

    for (final policy in this.policies) {
      if (!actualIds.add(policy.circuitId)) {
        throw ArgumentError('Duplicate D7 policy ${policy.circuitId}.');
      }
      final d6Outcome = outcomesById[policy.circuitId];
      if (d6Outcome == null) {
        throw ArgumentError(
          'D7 policy references unknown circuit ${policy.circuitId}.',
        );
      }

      final d3Outcome = d6Outcome.d5Outcome.d4Outcome.d3Outcome;
      final selectedCable = d3Outcome.selectedCable!;
      if (policy.cableId != selectedCable.cable.id) {
        throw ArgumentError(
          'D7 policy cable does not match D3 selection for ${policy.circuitId}.',
        );
      }

      final ampacityBySection = {
        for (final section in selectedCable.ampacitySections)
          section.sectionId: section,
      };
      final expectedSectionIds = ampacityBySection.keys.toSet();
      final actualSectionIds = policy.sections
          .map((section) => section.sectionId)
          .toSet();
      if (!_sameStringSet(expectedSectionIds, actualSectionIds)) {
        throw ArgumentError(
          'D7 installation sections do not match D3 ampacity sections for ${policy.circuitId}.',
        );
      }

      for (final section in policy.sections) {
        final ampacity = ampacityBySection[section.sectionId]!;
        final sourceKey = ampacity.sourceKey;
        if (sourceKey == null || sourceKey.trim().isEmpty) {
          throw ArgumentError(
            'D7 cannot bind installation method to an ampacity section without sourceKey.',
          );
        }
        if (section.ampacitySourceKey != sourceKey) {
          throw ArgumentError(
            'D7 installation method ampacity source does not match D3 section ${section.sectionId}.',
          );
        }
      }
    }

    final missing = expectedIds.difference(actualIds).toList()..sort();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing D7 policy for circuit(s): ${missing.join(', ')}.',
      );
    }
  }

  final ElectricalProtectionCoordinationClosureResult d6Closure;
  final List<CircuitInstallationMethodPolicy> policies;
}

final class ElectricalCircuitInstallationMethodClosureOutcome {
  const ElectricalCircuitInstallationMethodClosureOutcome({
    required this.d6Outcome,
    required this.policy,
  });

  final ElectricalProtectionCoordinationClosureOutcome d6Outcome;
  final CircuitInstallationMethodPolicy policy;

  String get circuitId => d6Outcome.circuitId;
}

final class ElectricalCircuitInstallationMethodClosureResult {
  ElectricalCircuitInstallationMethodClosureResult({
    required Iterable<ElectricalCircuitInstallationMethodClosureOutcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes) {
    if (this.outcomes.isEmpty) {
      throw ArgumentError('D7 result must contain circuit outcomes.');
    }
    final ids = <String>{};
    for (final outcome in this.outcomes) {
      if (!ids.add(outcome.circuitId)) {
        throw ArgumentError('Duplicate D7 outcome ${outcome.circuitId}.');
      }
    }
  }

  final List<ElectricalCircuitInstallationMethodClosureOutcome> outcomes;

  bool get isFullyClosed => outcomes.isNotEmpty;
}

abstract final class CircuitInstallationMethodClosureEngine {
  static ElectricalCircuitInstallationMethodClosureResult close(
    ElectricalCircuitInstallationMethodClosureRequest request,
  ) {
    final policies = {
      for (final policy in request.policies) policy.circuitId: policy,
    };
    final d6Outcomes = request.d6Closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));

    return ElectricalCircuitInstallationMethodClosureResult(
      outcomes: [
        for (final d6Outcome in d6Outcomes)
          ElectricalCircuitInstallationMethodClosureOutcome(
            d6Outcome: d6Outcome,
            policy: policies[d6Outcome.circuitId]!,
          ),
      ],
    );
  }
}

bool _sameStringSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
