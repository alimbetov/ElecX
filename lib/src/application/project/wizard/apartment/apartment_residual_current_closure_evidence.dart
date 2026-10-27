import '../../../../engine/electrical_short_circuit_closure_engine.dart';
import '../../../../engine/residual_current_protection_engine.dart';
import 'apartment_circuit_closure_evidence.dart';
import 'apartment_engineering_requirements.dart';
import 'apartment_short_circuit_closure_evidence.dart';
import 'p9_canonical_serialization.dart';

const String apartmentEngineeringRequirementsVersionV4 = 'p9.requirements.v4';

/// Publishes source-pinned RCD/RCBO applicability and selected-device evidence.
///
/// D5 deliberately migrates the P9 requirement envelope from v3 to v4 by
/// adding the still-unresolved `protection.coordination` fact. Therefore even a
/// fully closed residual-current result cannot prematurely mark the protection
/// domain as complete before D6 selectivity/coordination evidence exists.
abstract final class ApartmentResidualCurrentClosureEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalResidualCurrentClosureRequest request,
    required ElectricalResidualCurrentClosureResult closure,
  }) {
    if (requirements.requirementsVersion !=
        apartmentEngineeringRequirementsVersion) {
      throw ArgumentError(
        'D5 migration requires ${apartmentEngineeringRequirementsVersion} input.',
      );
    }

    final protectionRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );
    final d3Closure = ElectricalCircuitClosureResult(
      outcomes: [
        for (final outcome in request.d4Closure.outcomes) outcome.d3Outcome,
      ],
    );

    _requireD3OverloadLineage(
      protectionRequirement: protectionRequirement,
      d3Closure: d3Closure,
    );
    _requireD4Lineage(
      protectionRequirement: protectionRequirement,
      d4Closure: request.d4Closure,
    );

    if (!closure.isFullyClosed) {
      throw ArgumentError(
        'D5 projection evidence requires every circuit to be explicitly closed.',
      );
    }

    final expected = ResidualCurrentProtectionEngine.close(request);
    if (_canonicalClosure(expected) != _canonicalClosure(closure)) {
      throw ArgumentError(
        'Residual-current closure result does not match the supplied D5 request.',
      );
    }

    final requiredFacts = <String>{
      ...protectionRequirement.requiredFactKeys,
      'protection.coordination',
    }.toList()
      ..sort();
    final sourceRevision = sourceRevisionValue(closure);
    final updatedProtection = ApartmentEngineeringRequirement(
      requirementId: protectionRequirement.requirementId,
      domain: protectionRequirement.domain,
      subjectKind: protectionRequirement.subjectKind,
      subjectStableId: protectionRequirement.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.indeterminate,
      criticality: protectionRequirement.criticality,
      rationaleCode:
          'p9.requirements.protection-residual-current-proven-coordination-pending',
      requiredFactKeys: requiredFacts,
      factEvidence: [
        for (final existing in protectionRequirement.factEvidence.values)
          if (existing.factKey != 'protection.residualCurrent') existing,
        ApartmentEngineeringFactEvidence(
          factKey: 'protection.residualCurrent',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: residualCurrentEvidenceValue(closure),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalResidualCurrentClosureVersion,
          sourceRevision: sourceRevision,
        ),
      ],
    );

    return ApartmentEngineeringDesignRequirements(
      requirementsVersion: apartmentEngineeringRequirementsVersionV4,
      selectedCandidateFingerprint: requirements.selectedCandidateFingerprint,
      projectionFingerprint: requirements.projectionFingerprint,
      graphFingerprint: requirements.graphFingerprint,
      placementFingerprint: requirements.placementFingerprint,
      normativeEvidenceFingerprint: requirements.normativeEvidenceFingerprint,
      normativeProfileId: requirements.normativeProfileId,
      normativeProfileVersion: requirements.normativeProfileVersion,
      requirements: [
        for (final item in requirements.requirements)
          if (item.requirementId == protectionRequirement.requirementId)
            updatedProtection
          else
            item,
      ],
    );
  }

  static String residualCurrentEvidenceValue(
    ElectricalResidualCurrentClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _evidenceOutcome(outcome)),
    ]);
  }

  static String sourceRevisionValue(
    ElectricalResidualCurrentClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _policySerialization(outcome)),
    ]);
  }

  static void _requireD3OverloadLineage({
    required ApartmentEngineeringRequirement protectionRequirement,
    required ElectricalCircuitClosureResult d3Closure,
  }) {
    final overloadFact = protectionRequirement.factEvidence['protection.overload'];
    if (overloadFact == null) {
      throw ArgumentError('D5 evidence requires prior D3 overload evidence.');
    }
    final expectedValue =
        ApartmentCircuitClosureEvidenceService.overloadEvidenceValue(d3Closure);
    final expectedRevision =
        ApartmentCircuitClosureEvidenceService.sourceRevisionValue(d3Closure);
    if (overloadFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        overloadFact.value != expectedValue ||
        overloadFact.sourceId != electricalCircuitClosureVersion ||
        overloadFact.sourceRevision != expectedRevision) {
      throw ArgumentError(
        'D5 overload evidence does not match the D4/D3 closure lineage.',
      );
    }
  }

  static void _requireD4Lineage({
    required ApartmentEngineeringRequirement protectionRequirement,
    required ElectricalShortCircuitClosureResult d4Closure,
  }) {
    final shortCircuitFact =
        protectionRequirement.factEvidence['protection.shortCircuit'];
    final disconnectionFact =
        protectionRequirement.factEvidence['protection.disconnection'];
    if (shortCircuitFact == null || disconnectionFact == null) {
      throw ArgumentError(
        'D5 evidence requires prior D4 short-circuit and disconnection evidence.',
      );
    }

    final expectedRevision =
        ApartmentShortCircuitClosureEvidenceService.sourceRevisionValue(
      d4Closure,
    );
    final expectedShortCircuit =
        ApartmentShortCircuitClosureEvidenceService.shortCircuitEvidenceValue(
      d4Closure,
    );
    final expectedDisconnection =
        ApartmentShortCircuitClosureEvidenceService.disconnectionEvidenceValue(
      d4Closure,
    );

    if (shortCircuitFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        shortCircuitFact.value != expectedShortCircuit ||
        shortCircuitFact.sourceId != electricalShortCircuitClosureVersion ||
        shortCircuitFact.sourceRevision != expectedRevision) {
      throw ArgumentError(
        'D5 short-circuit evidence does not match the supplied D4 closure.',
      );
    }
    if (disconnectionFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        disconnectionFact.value != expectedDisconnection ||
        disconnectionFact.sourceId != electricalShortCircuitClosureVersion ||
        disconnectionFact.sourceRevision != expectedRevision) {
      throw ArgumentError(
        'D5 disconnection evidence does not match the supplied D4 closure.',
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

  static String _evidenceOutcome(
    ElectricalResidualCurrentClosureOutcome outcome,
  ) {
    final policy = outcome.policy;
    final selected = outcome.selectedDevice;
    final allowedTypes = policy.allowedTypes.map((item) => item.name).toList()
      ..sort();
    final allowedKinds =
        policy.allowedDeviceKinds.map((item) => item.name).toList()..sort();
    return p9CanonicalSerializeFields([
      MapEntry('applicability', policy.applicability.name),
      MapEntry('rationaleCode', policy.rationaleCode),
      MapEntry(
        'applicabilityEvidenceIds',
        policy.applicabilityEvidenceIds.join(','),
      ),
      MapEntry(
        'loadCharacteristicEvidenceIds',
        policy.loadCharacteristicEvidenceIds.join(','),
      ),
      MapEntry(
        'maximumResidualOperatingCurrentMa',
        policy.maximumResidualOperatingCurrentMa?.toString() ?? 'not-applicable',
      ),
      MapEntry('allowedTypes', allowedTypes.join(',')),
      MapEntry(
        'preferredTypes',
        policy.preferredTypes.map((item) => item.name).join(','),
      ),
      MapEntry('allowedDeviceKinds', allowedKinds.join(',')),
      MapEntry(
        'preferredDeviceKinds',
        policy.preferredDeviceKinds.map((item) => item.name).join(','),
      ),
      MapEntry(
        'minimumPoleCount',
        policy.minimumPoleCount?.toString() ?? 'not-applicable',
      ),
      MapEntry(
        'sensitivityPreference',
        policy.sensitivityPreference?.name ?? 'not-applicable',
      ),
      MapEntry('status', outcome.status.name),
      MapEntry(
        'd3OvercurrentDeviceId',
        outcome.d4Outcome.d3Outcome.selectedProtection!.id,
      ),
      MapEntry('selectedDeviceId', selected?.id ?? 'none'),
      MapEntry('selectedDeviceKind', selected?.kind.name ?? 'none'),
      MapEntry('selectedResidualType', selected?.residualType.name ?? 'none'),
      MapEntry(
        'selectedRatedCurrentA',
        selected?.ratedCurrentA.toString() ?? 'none',
      ),
      MapEntry(
        'selectedResidualOperatingCurrentMa',
        selected?.residualOperatingCurrentMa.toString() ?? 'none',
      ),
      MapEntry('selectedPoleCount', selected?.poleCount.toString() ?? 'none'),
      MapEntry(
        'selectedOvercurrentDeviceId',
        selected?.overcurrentDeviceId ?? 'none',
      ),
      MapEntry(
        'selectedConditionalShortCircuitCurrentA',
        selected?.conditionalShortCircuitCurrentA?.toString() ?? 'none',
      ),
      MapEntry(
        'selectedCompatibleBackupOvercurrentDeviceIds',
        selected?.compatibleBackupOvercurrentDeviceIds.join(',') ?? 'none',
      ),
      MapEntry('selectedSourceId', selected?.sourceId ?? 'none'),
      MapEntry('selectedSourceRevision', selected?.sourceRevision ?? 'none'),
      MapEntry('policySourceId', policy.sourceId),
      MapEntry('policySourceRevision', policy.sourceRevision),
    ]);
  }

  static String _policySerialization(
    ElectricalResidualCurrentClosureOutcome outcome,
  ) {
    final policy = outcome.policy;
    final candidates = policy.candidates.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return p9CanonicalSerializeFields([
      MapEntry(
        'd4SourceRevision',
        ApartmentShortCircuitClosureEvidenceService.sourceRevisionValue(
          ElectricalShortCircuitClosureResult(outcomes: [outcome.d4Outcome]),
        ),
      ),
      MapEntry('applicability', policy.applicability.name),
      MapEntry('rationaleCode', policy.rationaleCode),
      MapEntry(
        'applicabilityEvidenceIds',
        policy.applicabilityEvidenceIds.join(','),
      ),
      MapEntry(
        'loadCharacteristicEvidenceIds',
        policy.loadCharacteristicEvidenceIds.join(','),
      ),
      MapEntry(
        'maximumResidualOperatingCurrentMa',
        policy.maximumResidualOperatingCurrentMa?.toString() ?? 'none',
      ),
      MapEntry(
        'allowedTypes',
        (policy.allowedTypes.map((item) => item.name).toList()..sort()).join(','),
      ),
      MapEntry(
        'preferredTypes',
        policy.preferredTypes.map((item) => item.name).join(','),
      ),
      MapEntry(
        'allowedDeviceKinds',
        (policy.allowedDeviceKinds.map((item) => item.name).toList()..sort())
            .join(','),
      ),
      MapEntry(
        'preferredDeviceKinds',
        policy.preferredDeviceKinds.map((item) => item.name).join(','),
      ),
      MapEntry(
        'minimumPoleCount',
        policy.minimumPoleCount?.toString() ?? 'none',
      ),
      MapEntry(
        'sensitivityPreference',
        policy.sensitivityPreference?.name ?? 'none',
      ),
      MapEntry('policySourceId', policy.sourceId),
      MapEntry('policySourceRevision', policy.sourceRevision),
      for (final candidate in candidates)
        MapEntry('candidate', _candidateSerialization(candidate)),
    ]);
  }

  static String _candidateSerialization(candidate) =>
      p9CanonicalSerializeFields([
        MapEntry('id', candidate.id),
        MapEntry('kind', candidate.kind.name),
        MapEntry('ratedCurrentA', candidate.ratedCurrentA.toString()),
        MapEntry(
          'residualOperatingCurrentMa',
          candidate.residualOperatingCurrentMa.toString(),
        ),
        MapEntry('residualType', candidate.residualType.name),
        MapEntry('poleCount', candidate.poleCount.toString()),
        MapEntry(
          'overcurrentDeviceId',
          candidate.overcurrentDeviceId ?? 'none',
        ),
        MapEntry(
          'conditionalShortCircuitCurrentA',
          candidate.conditionalShortCircuitCurrentA?.toString() ?? 'none',
        ),
        MapEntry(
          'compatibleBackupOvercurrentDeviceIds',
          candidate.compatibleBackupOvercurrentDeviceIds.join(','),
        ),
        MapEntry('sourceId', candidate.sourceId),
        MapEntry('sourceRevision', candidate.sourceRevision),
      ]);

  static String _canonicalClosure(
    ElectricalResidualCurrentClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _canonicalOutcome(outcome)),
    ]);
  }

  static String _canonicalOutcome(
    ElectricalResidualCurrentClosureOutcome outcome,
  ) {
    final evaluations = outcome.evaluations.toList()
      ..sort((left, right) => left.candidate.id.compareTo(right.candidate.id));
    return p9CanonicalSerializeFields([
      MapEntry('policy', _policySerialization(outcome)),
      MapEntry('status', outcome.status.name),
      MapEntry('selectedDeviceId', outcome.selectedDevice?.id ?? 'none'),
      for (final evaluation in evaluations)
        MapEntry(
          evaluation.candidate.id,
          p9CanonicalSerializeFields([
            MapEntry('candidate', _candidateSerialization(evaluation.candidate)),
            MapEntry('rejections', evaluation.rejections.join(',')),
          ]),
        ),
    ]);
  }
}
