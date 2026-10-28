import '../../../../engine/circuit_installation_method_closure_engine.dart';
import '../../../../engine/electrical_circuit_closure_engine.dart';
import '../../../../engine/protective_device_coordination_engine.dart';
import 'apartment_circuit_closure_evidence.dart';
import 'apartment_engineering_requirements.dart';
import 'apartment_protection_coordination_evidence.dart';
import 'p9_canonical_serialization.dart';

const String apartmentEngineeringRequirementsVersionV6 = 'p9.requirements.v6';

/// Publishes installation-method evidence bound to the exact D3-selected cable
/// and the exact source-pinned ampacity sections used to calculate Iz.
abstract final class ApartmentCircuitInstallationMethodEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalCircuitInstallationMethodClosureRequest request,
    required ElectricalCircuitInstallationMethodClosureResult closure,
  }) {
    if (requirements.requirementsVersion !=
        apartmentEngineeringRequirementsVersionV5) {
      throw ArgumentError(
        'D7 migration requires $apartmentEngineeringRequirementsVersionV5 input.',
      );
    }
    if (!closure.isFullyClosed) {
      throw ArgumentError('D7 requires fully closed installation evidence.');
    }

    final circuitRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.circuit,
    );
    final protectionRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );

    _requireD3Lineage(
      circuitRequirement: circuitRequirement,
      closure: closure,
    );
    _requireD6Lineage(
      protectionRequirement: protectionRequirement,
      d6Closure: request.d6Closure,
    );

    final expected = CircuitInstallationMethodClosureEngine.close(request);
    if (_canonicalClosure(expected) != _canonicalClosure(closure)) {
      throw ArgumentError(
        'Installation-method closure does not match the supplied D7 request.',
      );
    }

    final evidence = <ApartmentEngineeringFactEvidence>[
      for (final existing in circuitRequirement.factEvidence.values)
        if (existing.factKey != 'circuit.installationMethod') existing,
      ApartmentEngineeringFactEvidence(
        factKey: 'circuit.installationMethod',
        valueKind: ApartmentEngineeringFactValueKind.text,
        value: installationMethodEvidenceValue(closure),
        unit: ApartmentEngineeringFactUnit.code,
        sourceId: electricalCircuitInstallationMethodClosureVersion,
        sourceRevision: sourceRevisionValue(closure),
      ),
    ];
    final evidenceKeys = evidence.map((item) => item.factKey).toSet();
    final missingFacts = circuitRequirement.requiredFactKeys
        .where((key) => !evidenceKeys.contains(key))
        .toList()
      ..sort();
    if (missingFacts.isNotEmpty) {
      throw ArgumentError(
        'D7 cannot close circuit requirement; missing facts: ${missingFacts.join(', ')}.',
      );
    }

    final updatedCircuit = ApartmentEngineeringRequirement(
      requirementId: circuitRequirement.requirementId,
      domain: circuitRequirement.domain,
      subjectKind: circuitRequirement.subjectKind,
      subjectStableId: circuitRequirement.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.proven,
      criticality: circuitRequirement.criticality,
      rationaleCode: 'p9.requirements.circuit-closure-proven',
      requiredFactKeys: circuitRequirement.requiredFactKeys,
      factEvidence: evidence,
    );

    return ApartmentEngineeringDesignRequirements(
      requirementsVersion: apartmentEngineeringRequirementsVersionV6,
      selectedCandidateFingerprint: requirements.selectedCandidateFingerprint,
      projectionFingerprint: requirements.projectionFingerprint,
      graphFingerprint: requirements.graphFingerprint,
      placementFingerprint: requirements.placementFingerprint,
      normativeEvidenceFingerprint: requirements.normativeEvidenceFingerprint,
      normativeProfileId: requirements.normativeProfileId,
      normativeProfileVersion: requirements.normativeProfileVersion,
      requirements: [
        for (final item in requirements.requirements)
          if (item.requirementId == circuitRequirement.requirementId)
            updatedCircuit
          else
            item,
      ],
    );
  }

  static String installationMethodEvidenceValue(
    ElectricalCircuitInstallationMethodClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _policySerialization(outcome)),
    ]);
  }

  static String sourceRevisionValue(
    ElectricalCircuitInstallationMethodClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(
          outcome.circuitId,
          p9CanonicalSerializeFields([
            MapEntry('policySourceId', outcome.policy.sourceId),
            MapEntry('policySourceRevision', outcome.policy.sourceRevision),
            for (final section in outcome.policy.sections)
              MapEntry(
                section.sectionId,
                p9CanonicalSerializeFields([
                  MapEntry('sourceId', section.sourceId),
                  MapEntry('sourceRevision', section.sourceRevision),
                ]),
              ),
          ]),
        ),
    ]);
  }

  static void _requireD3Lineage({
    required ApartmentEngineeringRequirement circuitRequirement,
    required ElectricalCircuitInstallationMethodClosureResult closure,
  }) {
    final conductorFact =
        circuitRequirement.factEvidence['circuit.conductorConstraints'];
    if (conductorFact == null) {
      throw ArgumentError('D7 requires prior D3 conductor evidence.');
    }

    final d3Closure = ElectricalCircuitClosureResult(
      outcomes: [
        for (final outcome in closure.outcomes)
          outcome.d6Outcome.d5Outcome.d4Outcome.d3Outcome,
      ],
    );
    final expectedValue =
        ApartmentCircuitClosureEvidenceService.conductorEvidenceValue(
            d3Closure);
    final expectedRevision =
        ApartmentCircuitClosureEvidenceService.sourceRevisionValue(d3Closure);
    if (conductorFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        conductorFact.value != expectedValue ||
        conductorFact.sourceId != electricalCircuitClosureVersion ||
        conductorFact.sourceRevision != expectedRevision) {
      throw ArgumentError(
        'D7 conductor evidence does not match the selected D3 cable lineage.',
      );
    }
  }

  static void _requireD6Lineage({
    required ApartmentEngineeringRequirement protectionRequirement,
    required ElectricalProtectionCoordinationClosureResult d6Closure,
  }) {
    final coordinationFact =
        protectionRequirement.factEvidence['protection.coordination'];
    if (coordinationFact == null || !protectionRequirement.isResolved) {
      throw ArgumentError(
        'D7 requires resolved D6 protection coordination evidence.',
      );
    }
    final expectedValue = ApartmentProtectionCoordinationEvidenceService
        .coordinationEvidenceValue(d6Closure);
    final expectedRevision =
        ApartmentProtectionCoordinationEvidenceService.sourceRevisionValue(
      d6Closure,
    );
    if (coordinationFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        coordinationFact.value != expectedValue ||
        coordinationFact.sourceId !=
            electricalProtectionCoordinationClosureVersion ||
        coordinationFact.sourceRevision != expectedRevision) {
      throw ArgumentError(
        'D7 coordination evidence does not match the supplied D6 closure.',
      );
    }
  }

  static ApartmentEngineeringRequirement _singleRequirement(
    ApartmentEngineeringDesignRequirements requirements,
    ApartmentEngineeringRequirementDomain domain,
  ) {
    final matches = requirements.requirements
        .where((item) => item.domain == domain)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'P9 requirements must contain exactly one ${domain.name} requirement; '
        'found ${matches.length}.',
      );
    }
    return matches.single;
  }

  static String _policySerialization(
    ElectricalCircuitInstallationMethodClosureOutcome outcome,
  ) =>
      p9CanonicalSerializeFields([
        MapEntry('cableId', outcome.policy.cableId),
        for (final section in outcome.policy.sections)
          MapEntry(
            section.sectionId,
            p9CanonicalSerializeFields([
              MapEntry('installationMethodId', section.installationMethodId),
              MapEntry('ampacitySourceKey', section.ampacitySourceKey),
              MapEntry('sourceId', section.sourceId),
              MapEntry('sourceRevision', section.sourceRevision),
            ]),
          ),
        MapEntry('policySourceId', outcome.policy.sourceId),
        MapEntry('policySourceRevision', outcome.policy.sourceRevision),
      ]);

  static String _canonicalClosure(
    ElectricalCircuitInstallationMethodClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(
          outcome.circuitId,
          p9CanonicalSerializeFields([
            MapEntry(
              'd6SourceRevision',
              ApartmentProtectionCoordinationEvidenceService
                  .sourceRevisionValue(
                ElectricalProtectionCoordinationClosureResult(
                  outcomes: [outcome.d6Outcome],
                ),
              ),
            ),
            MapEntry('policy', _policySerialization(outcome)),
          ]),
        ),
    ]);
  }
}
