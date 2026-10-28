import '../../../../domain/electrical_circuit_calculation.dart';
import '../../../../domain/electrical_circuit_synthesis.dart';
import '../../../../domain/electrical_load_calculation.dart';
import '../../../../domain/electrical_phase_assignment.dart';
import '../../../../engine/circuit_grouping_engine.dart';
import '../../../../engine/circuit_installation_method_closure_engine.dart';
import '../../../../engine/electrical_circuit_calculation_engine.dart';
import '../../../../engine/electrical_circuit_closure_engine.dart';
import '../../../../engine/electrical_short_circuit_closure_engine.dart';
import '../../../../engine/load_calculation_engine.dart';
import '../../../../engine/phase_assignment_engine.dart';
import '../../../../engine/protective_device_coordination_engine.dart';
import '../../../../engine/residual_current_protection_engine.dart';
import '../wizard_contracts.dart';
import 'apartment_candidate_set_service.dart';
import 'apartment_circuit_calculation_evidence.dart';
import 'apartment_circuit_closure_evidence.dart';
import 'apartment_circuit_installation_method_evidence.dart';
import 'apartment_circuit_synthesis_evidence.dart';
import 'apartment_engineering_evidence_binding.dart';
import 'apartment_engineering_output_projection.dart';
import 'apartment_engineering_requirements.dart';
import 'apartment_engineering_requirements_adapter.dart';
import 'apartment_load_calculation_evidence.dart';
import 'apartment_protection_coordination_evidence.dart';
import 'apartment_residual_current_closure_evidence.dart';
import 'apartment_short_circuit_closure_evidence.dart';
import 'p9_canonical_serialization.dart';
import 'p9_sha256.dart';

const String apartmentEngineeringProposalVersion = 'p9.engineering-proposal.v1';

/// Frozen D1-D8 result bound to one exact apartment candidate.
///
/// The proposal is created during Generate and is then carried unchanged by the
/// reserved P8 command through Preview/Diff and Apply. Apply never reruns the
/// electrical pipeline.
final class ApartmentEngineeringProposal {
  ApartmentEngineeringProposal._({
    required this.candidateSetFingerprint,
    required this.candidateFingerprint,
    required this.intentFingerprint,
    required this.d1RequirementsFingerprint,
    required this.output,
    required this.proposalFingerprint,
  });

  factory ApartmentEngineeringProposal.bind({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required ApartmentEngineeringOutputProjection output,
  }) {
    final d1 = selected.engineeringRequirements;
    if (candidateSetFingerprint.trim().isEmpty) {
      throw ArgumentError.value(
        candidateSetFingerprint,
        'candidateSetFingerprint',
        'Must be non-empty.',
      );
    }
    if (d1.selectedCandidateFingerprint != selected.candidateFingerprint) {
      throw ArgumentError(
        'P9.6 D1 requirements are not bound to the selected candidate.',
      );
    }
    _requireSha256(d1.requirementsFingerprint, 'd1RequirementsFingerprint');
    _requireSha256(output.requirementsFingerprint, 'requirementsFingerprint');
    _requireSha256(output.outputFingerprint, 'outputFingerprint');

    final stable = p9CanonicalSerializeFields([
      const MapEntry('schema', apartmentEngineeringProposalVersion),
      MapEntry('candidateSetFingerprint', candidateSetFingerprint),
      MapEntry('candidateFingerprint', selected.candidateFingerprint),
      MapEntry('intentFingerprint', selected.identity.intentFingerprint),
      MapEntry('templateId', selected.identity.templateIdValue),
      MapEntry('templateVersion', selected.identity.templateVersion.toString()),
      MapEntry('variantSeedId', selected.identity.variantSeedId),
      MapEntry(
        'geometryAlgorithmVersion',
        selected.identity.geometryAlgorithmVersion,
      ),
      MapEntry('geometryFingerprint', selected.identity.geometryFingerprint),
      MapEntry(
        'scoringProfileVersion',
        selected.identity.scoringProfileVersion,
      ),
      MapEntry('d1RequirementsFingerprint', d1.requirementsFingerprint),
      MapEntry('d8RequirementsFingerprint', output.requirementsFingerprint),
      MapEntry('d8OutputFingerprint', output.outputFingerprint),
    ]);

    return ApartmentEngineeringProposal._(
      candidateSetFingerprint: candidateSetFingerprint,
      candidateFingerprint: selected.candidateFingerprint,
      intentFingerprint: selected.identity.intentFingerprint,
      d1RequirementsFingerprint: d1.requirementsFingerprint,
      output: output,
      proposalFingerprint: p9Sha256Hex(stable),
    );
  }

  final String candidateSetFingerprint;
  final String candidateFingerprint;
  final String intentFingerprint;
  final String d1RequirementsFingerprint;
  final ApartmentEngineeringOutputProjection output;
  final String proposalFingerprint;

  void validateAgainst({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
  }) {
    final d1 = selected.engineeringRequirements;
    if (this.candidateSetFingerprint != candidateSetFingerprint ||
        candidateFingerprint != selected.candidateFingerprint ||
        intentFingerprint != selected.identity.intentFingerprint ||
        d1RequirementsFingerprint != d1.requirementsFingerprint) {
      throw ArgumentError(
        'P9.6 engineering proposal does not match the selected candidate set.',
      );
    }

    final rebound = ApartmentEngineeringProposal.bind(
      candidateSetFingerprint: candidateSetFingerprint,
      selected: selected,
      output: output,
    );
    if (rebound.proposalFingerprint != proposalFingerprint) {
      throw ArgumentError('P9.6 engineering proposal fingerprint mismatch.');
    }
  }
}

/// Authoritative policy/evidence source for the D2-D7 electrical stages.
///
/// The source supplies source-pinned requests only. All calculations and
/// closure results are produced by the existing engines, so policy data cannot
/// replace or bypass the engineering algorithms.
abstract interface class ApartmentEngineeringPipelineSource {
  ElectricalCircuitCalculationRequest calculationRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  });

  ElectricalPhaseAssignmentRequest phaseAssignmentRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ElectricalCircuitCalculationResult calculation,
  });

  ElectricalCircuitClosureRequest circuitClosureRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ElectricalCircuitCalculationResult calculation,
  });

  ElectricalShortCircuitClosureRequest shortCircuitClosureRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ElectricalCircuitClosureResult d3Closure,
  });

  ElectricalResidualCurrentClosureRequest residualCurrentClosureRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ElectricalShortCircuitClosureResult d4Closure,
  });

  ElectricalProtectionCoordinationClosureRequest coordinationClosureRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ElectricalResidualCurrentClosureResult d5Closure,
  });

  ElectricalCircuitInstallationMethodClosureRequest
      installationMethodClosureRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ElectricalProtectionCoordinationClosureResult d6Closure,
  });
}

/// Authoritative inputs that close the D1 -> D2 gap.
///
/// Supply facts must be source-pinned. Load and synthesis requests are executed
/// by the canonical engines; this source is not allowed to provide precomputed
/// load/synthesis results. Production orchestration requires this capability.
abstract interface class ApartmentEngineeringPipelinePreD2Source {
  Iterable<ApartmentEngineeringFactEvidence> supplyEvidence({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ApartmentEngineeringDesignRequirements requirements,
  });

  ElectricalLoadCalculationRequest loadCalculationRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ApartmentEngineeringDesignRequirements requirements,
  });

  ElectricalCircuitSynthesisRequest circuitSynthesisRequest({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalLoadCalculationRequest loadRequest,
    required ElectricalLoadCalculationResult loadCalculation,
  });
}

abstract interface class ApartmentEngineeringPipeline {
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  });
}

/// Runs the canonical engineering chain once for one selected apartment.
///
/// The unnamed constructor preserves the already-qualified legacy D2-D8 source
/// contract. Production composition must use [production], which additionally
/// closes supply, load and circuit-synthesis evidence before D2 and verifies
/// that the D2 request is bound to that exact synthesized circuit set.
final class ApartmentEngineeringPipelineOrchestrator
    implements ApartmentEngineeringPipeline {
  const ApartmentEngineeringPipelineOrchestrator({required this.source})
      : preD2Source = null;

  const ApartmentEngineeringPipelineOrchestrator.production({
    required this.source,
    required this.preD2Source,
  });

  final ApartmentEngineeringPipelineSource source;
  final ApartmentEngineeringPipelinePreD2Source? preD2Source;

  bool get hasAuthoritativePreD2Inputs => preD2Source != null;

  @override
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) {
    final d1 = selected.engineeringRequirements;
    var requirements = d1;
    ElectricalCircuitSynthesisResult? authoritativeSynthesis;

    final preD2 = preD2Source;
    if (preD2 != null) {
      final supplyEvidence = preD2
          .supplyEvidence(
            selected: selected,
            context: context,
            requirements: requirements,
          )
          .toList(growable: false);
      _requireSupplyOnlyEvidence(supplyEvidence);
      requirements = requirements.bindAuthoritativeEvidence(supplyEvidence);
      _requireProvenDomain(
        requirements,
        ApartmentEngineeringRequirementDomain.supply,
        'D1 supply evidence',
      );

      final loadRequest = preD2.loadCalculationRequest(
        selected: selected,
        context: context,
        requirements: requirements,
      );
      final loadCalculation = LoadCalculationEngine.calculate(loadRequest);
      requirements = ApartmentLoadCalculationEvidenceService.apply(
        requirements: requirements,
        request: loadRequest,
        calculation: loadCalculation,
      );

      final synthesisRequest = preD2.circuitSynthesisRequest(
        selected: selected,
        context: context,
        requirements: requirements,
        loadRequest: loadRequest,
        loadCalculation: loadCalculation,
      );
      _requireSynthesisLoadLineage(
        loadRequest: loadRequest,
        synthesisRequest: synthesisRequest,
      );
      authoritativeSynthesis =
          CircuitGroupingEngine.synthesize(synthesisRequest);
      requirements = ApartmentCircuitSynthesisEvidenceService.apply(
        requirements: requirements,
        request: synthesisRequest,
        synthesis: authoritativeSynthesis,
      );
    }

    final calculationRequest = source.calculationRequest(
      selected: selected,
      context: context,
    );
    if (authoritativeSynthesis != null) {
      _requireSynthesisLineage(
        authoritativeSynthesis,
        calculationRequest.synthesis,
      );
    }
    final calculation =
        ElectricalCircuitCalculationEngine.calculate(calculationRequest);

    final assignmentRequest = source.phaseAssignmentRequest(
      selected: selected,
      context: context,
      calculation: calculation,
    );
    final assignment = PhaseAssignmentEngine.assign(assignmentRequest);
    requirements = ApartmentCircuitCalculationEvidenceService.apply(
      requirements: requirements,
      calculationRequest: calculationRequest,
      calculation: calculation,
      assignmentRequest: assignmentRequest,
      assignment: assignment,
    );

    final d3Request = source.circuitClosureRequest(
      selected: selected,
      context: context,
      calculation: calculation,
    );
    final d3Closure = ElectricalCircuitClosureEngine.close(d3Request);
    requirements = ApartmentCircuitClosureEvidenceService.apply(
      requirements: requirements,
      request: d3Request,
      closure: d3Closure,
    );

    final d4Request = source.shortCircuitClosureRequest(
      selected: selected,
      context: context,
      d3Closure: d3Closure,
    );
    final d4Closure = ElectricalShortCircuitClosureEngine.close(d4Request);
    requirements = ApartmentShortCircuitClosureEvidenceService.apply(
      requirements: requirements,
      request: d4Request,
      closure: d4Closure,
    );

    final d5Request = source.residualCurrentClosureRequest(
      selected: selected,
      context: context,
      d4Closure: d4Closure,
    );
    final d5Closure = ResidualCurrentProtectionEngine.close(d5Request);
    requirements = ApartmentResidualCurrentClosureEvidenceService.apply(
      requirements: requirements,
      request: d5Request,
      closure: d5Closure,
    );

    final d6Request = source.coordinationClosureRequest(
      selected: selected,
      context: context,
      d5Closure: d5Closure,
    );
    final d6Closure = ProtectiveDeviceCoordinationEngine.close(d6Request);
    requirements = ApartmentProtectionCoordinationEvidenceService.apply(
      requirements: requirements,
      request: d6Request,
      closure: d6Closure,
    );

    final d7Request = source.installationMethodClosureRequest(
      selected: selected,
      context: context,
      d6Closure: d6Closure,
    );
    final d7Closure = CircuitInstallationMethodClosureEngine.close(d7Request);
    requirements = ApartmentCircuitInstallationMethodEvidenceService.apply(
      requirements: requirements,
      request: d7Request,
      closure: d7Closure,
    );

    final output = ApartmentEngineeringOutputProjectionService.project(
      d7Closure: d7Closure,
      phaseAssignment: assignment,
      requirements: requirements,
    );
    return ApartmentEngineeringProposal.bind(
      candidateSetFingerprint: candidateSetFingerprint,
      selected: selected,
      output: output,
    );
  }
}

const Set<String> _supplyFactKeys = {
  'supply.availablePowerW',
  'supply.frequencyHz',
  'supply.phaseCount',
  'supply.prospectiveShortCircuitCurrentA',
  'supply.voltageV',
};

void _requireSupplyOnlyEvidence(
  Iterable<ApartmentEngineeringFactEvidence> evidence,
) {
  for (final fact in evidence) {
    if (!_supplyFactKeys.contains(fact.factKey)) {
      throw ArgumentError(
        'Pre-D2 source may only provide authoritative supply facts; '
        'received ${fact.factKey}.',
      );
    }
  }
}

void _requireProvenDomain(
  ApartmentEngineeringDesignRequirements requirements,
  ApartmentEngineeringRequirementDomain domain,
  String stage,
) {
  final matches = requirements.requirements
      .where((requirement) => requirement.domain == domain)
      .toList(growable: false);
  if (matches.length != 1 ||
      matches.single.evidenceState !=
          ApartmentEngineeringRequirementEvidenceState.proven) {
    throw StateError('$stage must be complete and proven before continuing.');
  }
}

void _requireSynthesisLoadLineage({
  required ElectricalLoadCalculationRequest loadRequest,
  required ElectricalCircuitSynthesisRequest synthesisRequest,
}) {
  if (loadRequest.loads.length != synthesisRequest.loads.length) {
    throw ArgumentError(
      'Circuit synthesis load set must exactly match the calculated load set.',
    );
  }
  final expected = {for (final load in loadRequest.loads) load.id: load};
  for (final candidate in synthesisRequest.loads) {
    final load = expected[candidate.load.id];
    if (load == null || !_sameLoad(load, candidate.load)) {
      throw ArgumentError(
        'Circuit synthesis load ${candidate.load.id} is not bound to the '
        'authoritative load request.',
      );
    }
  }
}

void _requireSynthesisLineage(
  ElectricalCircuitSynthesisResult expected,
  ElectricalCircuitSynthesisResult actual,
) {
  if (expected.circuits.length != actual.circuits.length) {
    throw ArgumentError(
      'D2 calculation request is not bound to the authoritative synthesis.',
    );
  }
  final actualById = {
    for (final circuit in actual.circuits) circuit.id: circuit,
  };
  for (final left in expected.circuits) {
    final right = actualById[left.id];
    if (right == null || !_sameSynthesizedCircuit(left, right)) {
      throw ArgumentError(
        'D2 calculation request is not bound to the authoritative synthesis '
        'for circuit ${left.id}.',
      );
    }
  }
}

bool _sameSynthesizedCircuit(
  SynthesizedElectricalCircuit left,
  SynthesizedElectricalCircuit right,
) {
  if (left.id != right.id ||
      left.requiredPhaseSystem != right.requiredPhaseSystem ||
      left.dedicated != right.dedicated ||
      left.groupingPolicyId != right.groupingPolicyId ||
      left.groupingPolicyRevision != right.groupingPolicyRevision ||
      left.dedicatedPolicyId != right.dedicatedPolicyId ||
      left.dedicatedPolicyRevision != right.dedicatedPolicyRevision ||
      left.dedicatedRuleId != right.dedicatedRuleId ||
      left.loads.length != right.loads.length) {
    return false;
  }
  for (var index = 0; index < left.loads.length; index++) {
    final a = left.loads[index];
    final b = right.loads[index];
    if (a.kind != b.kind ||
        a.locationId != b.locationId ||
        a.requiredPhaseSystem != b.requiredPhaseSystem ||
        !_sameLoad(a.load, b.load)) {
      return false;
    }
  }
  return true;
}

bool _sameLoad(ElectricalLoadInput left, ElectricalLoadInput right) =>
    left.id == right.id &&
    left.ratedPowerW == right.ratedPowerW &&
    left.quantity == right.quantity &&
    left.utilizationFactor == right.utilizationFactor &&
    left.powerFactor == right.powerFactor &&
    left.reactivePowerKind == right.reactivePowerKind &&
    left.sourceId == right.sourceId &&
    left.sourceRevision == right.sourceRevision;

void _requireSha256(String value, String fieldName) {
  final normalized = value.trim().toLowerCase();
  final valid = normalized.length == 64 &&
      normalized.codeUnits.every(
        (unit) => (unit >= 48 && unit <= 57) || (unit >= 97 && unit <= 102),
      );
  if (!valid) {
    throw ArgumentError.value(value, fieldName, 'Expected SHA-256 hex value.');
  }
}
