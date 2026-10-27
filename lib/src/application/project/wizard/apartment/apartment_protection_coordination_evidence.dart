import '../../../../domain/overcurrent_protection.dart';
import '../../../../domain/protective_device_coordination.dart';
import '../../../../domain/residual_current_protection.dart';
import '../../../../engine/protective_device_coordination_engine.dart';
import '../../../../engine/residual_current_protection_engine.dart';
import 'apartment_engineering_requirements.dart';
import 'apartment_residual_current_closure_evidence.dart';
import 'p9_canonical_serialization.dart';

const String apartmentEngineeringRequirementsVersionV5 = 'p9.requirements.v5';

/// Publishes exact manufacturer/source-pinned protection coordination evidence.
///
/// D6 closes two independent coordination planes:
/// - overcurrent selectivity for the exact D3 downstream/upstream pair;
/// - residual-current discrimination for the exact D5 downstream/upstream pair.
///
/// Neither plane is inferred from curve letters, nominal-current ordering,
/// residual-current ratios, device type, or a selective/time-delay label.
abstract final class ApartmentProtectionCoordinationEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalProtectionCoordinationClosureRequest request,
    required ElectricalProtectionCoordinationClosureResult closure,
  }) {
    if (requirements.requirementsVersion !=
        apartmentEngineeringRequirementsVersionV4) {
      throw ArgumentError(
        'D6 migration requires $apartmentEngineeringRequirementsVersionV4 input.',
      );
    }

    final protectionRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );
    _requireD5Lineage(
      protectionRequirement: protectionRequirement,
      d5Closure: request.d5Closure,
    );

    if (!protectionRequirement.requiredFactKeys
        .contains('protection.coordination')) {
      throw ArgumentError(
        'D6 requires protection.coordination in the v4 requirement schema.',
      );
    }
    if (!closure.isFullyClosed) {
      throw ArgumentError(
        'D6 projection evidence requires both overcurrent and residual-current '
        'coordination to be explicitly closed for every circuit.',
      );
    }

    final expected = ProtectiveDeviceCoordinationEngine.close(request);
    if (_canonicalClosure(expected) != _canonicalClosure(closure)) {
      throw ArgumentError(
        'Protection coordination closure does not match the supplied D6 request.',
      );
    }

    final sourceRevision = sourceRevisionValue(closure);
    final evidence = <ApartmentEngineeringFactEvidence>[
      for (final existing in protectionRequirement.factEvidence.values)
        if (existing.factKey != 'protection.coordination') existing,
      ApartmentEngineeringFactEvidence(
        factKey: 'protection.coordination',
        valueKind: ApartmentEngineeringFactValueKind.text,
        value: coordinationEvidenceValue(closure),
        unit: ApartmentEngineeringFactUnit.code,
        sourceId: electricalProtectionCoordinationClosureVersion,
        sourceRevision: sourceRevision,
      ),
    ];
    final evidenceKeys = evidence.map((item) => item.factKey).toSet();
    final allFactsPresent =
        protectionRequirement.requiredFactKeys.every(evidenceKeys.contains);
    if (!allFactsPresent) {
      throw ArgumentError(
        'D6 cannot close protection while required protection facts are missing.',
      );
    }

    final updatedProtection = ApartmentEngineeringRequirement(
      requirementId: protectionRequirement.requirementId,
      domain: protectionRequirement.domain,
      subjectKind: protectionRequirement.subjectKind,
      subjectStableId: protectionRequirement.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.proven,
      criticality: protectionRequirement.criticality,
      rationaleCode: 'p9.requirements.protection-closure-proven',
      requiredFactKeys: protectionRequirement.requiredFactKeys,
      factEvidence: evidence,
    );

    return ApartmentEngineeringDesignRequirements(
      requirementsVersion: apartmentEngineeringRequirementsVersionV5,
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

  static String coordinationEvidenceValue(
    ElectricalProtectionCoordinationClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _evidenceOutcome(outcome)),
    ]);
  }

  static String sourceRevisionValue(
    ElectricalProtectionCoordinationClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _policySerialization(outcome)),
    ]);
  }

  static void _requireD5Lineage({
    required ApartmentEngineeringRequirement protectionRequirement,
    required ElectricalResidualCurrentClosureResult d5Closure,
  }) {
    final residualFact =
        protectionRequirement.factEvidence['protection.residualCurrent'];
    if (residualFact == null) {
      throw ArgumentError(
        'D6 evidence requires prior D5 residual-current evidence.',
      );
    }

    final expectedValue = ApartmentResidualCurrentClosureEvidenceService
        .residualCurrentEvidenceValue(d5Closure);
    final expectedRevision =
        ApartmentResidualCurrentClosureEvidenceService.sourceRevisionValue(
      d5Closure,
    );
    if (residualFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        residualFact.value != expectedValue ||
        residualFact.sourceId != electricalResidualCurrentClosureVersion ||
        residualFact.sourceRevision != expectedRevision) {
      throw ArgumentError(
        'D6 residual-current evidence does not match the supplied D5 closure.',
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
    ElectricalProtectionCoordinationClosureOutcome outcome,
  ) {
    final policy = outcome.policy;
    final selected = outcome.selectedEvidence;
    final residualPolicy = outcome.residualCurrentPolicy;
    final selectedResidual = outcome.selectedResidualCurrentEvidence;
    return p9CanonicalSerializeFields([
      MapEntry('overcurrentApplicability', policy.applicability.name),
      MapEntry('overcurrentRationaleCode', policy.rationaleCode),
      MapEntry(
        'overcurrentDownstreamDeviceId',
        policy.evaluatedDownstreamDeviceId,
      ),
      MapEntry(
        'overcurrentApplicabilityEvidenceIds',
        policy.applicabilityEvidenceIds.join(','),
      ),
      MapEntry(
        'overcurrentUpstreamDeviceId',
        policy.upstreamDevice?.id ?? 'not-applicable',
      ),
      MapEntry('overcurrentStatus', outcome.status.name),
      MapEntry('overcurrentSelectedEvidenceId', selected?.id ?? 'none'),
      MapEntry('overcurrentSelectedKind', selected?.kind.name ?? 'none'),
      MapEntry(
        'overcurrentSelectedLimitA',
        selected?.selectivityLimitA?.toString() ?? 'none',
      ),
      MapEntry('overcurrentSelectedSourceId', selected?.sourceId ?? 'none'),
      MapEntry(
        'overcurrentSelectedSourceRevision',
        selected?.sourceRevision ?? 'none',
      ),
      MapEntry('overcurrentPolicySourceId', policy.sourceId),
      MapEntry('overcurrentPolicySourceRevision', policy.sourceRevision),
      MapEntry(
        'residualApplicability',
        residualPolicy.applicability.name,
      ),
      MapEntry('residualRationaleCode', residualPolicy.rationaleCode),
      MapEntry(
        'residualDownstreamDeviceId',
        residualPolicy.evaluatedDownstreamDeviceId ?? 'none',
      ),
      MapEntry(
        'residualApplicabilityEvidenceIds',
        residualPolicy.applicabilityEvidenceIds.join(','),
      ),
      MapEntry(
        'residualUpstreamDeviceId',
        residualPolicy.upstreamDevice?.id ?? 'not-applicable',
      ),
      MapEntry('residualStatus', outcome.residualCurrentStatus.name),
      MapEntry(
        'residualSelectedEvidenceId',
        selectedResidual?.id ?? 'none',
      ),
      MapEntry(
        'residualSelectedSourceId',
        selectedResidual?.sourceId ?? 'none',
      ),
      MapEntry(
        'residualSelectedSourceRevision',
        selectedResidual?.sourceRevision ?? 'none',
      ),
      MapEntry('residualPolicySourceId', residualPolicy.sourceId),
      MapEntry(
        'residualPolicySourceRevision',
        residualPolicy.sourceRevision,
      ),
    ]);
  }

  static String _policySerialization(
    ElectricalProtectionCoordinationClosureOutcome outcome,
  ) {
    final policy = outcome.policy;
    final evidences = policy.selectivityEvidence.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final residualPolicy = outcome.residualCurrentPolicy;
    final residualEvidences = residualPolicy.selectivityEvidence.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return p9CanonicalSerializeFields([
      MapEntry(
        'd5SourceRevision',
        ApartmentResidualCurrentClosureEvidenceService.sourceRevisionValue(
          ElectricalResidualCurrentClosureResult(outcomes: [outcome.d5Outcome]),
        ),
      ),
      MapEntry('overcurrentApplicability', policy.applicability.name),
      MapEntry('overcurrentRationaleCode', policy.rationaleCode),
      MapEntry(
        'overcurrentDownstreamDeviceId',
        policy.evaluatedDownstreamDeviceId,
      ),
      MapEntry(
        'overcurrentApplicabilityEvidenceIds',
        policy.applicabilityEvidenceIds.join(','),
      ),
      MapEntry(
        'overcurrentUpstreamDevice',
        policy.upstreamDevice == null
            ? 'none'
            : _overcurrentSerialization(policy.upstreamDevice!),
      ),
      for (final evidence in evidences)
        MapEntry(
          'overcurrentSelectivityEvidence',
          _selectivitySerialization(evidence),
        ),
      MapEntry('overcurrentPolicySourceId', policy.sourceId),
      MapEntry('overcurrentPolicySourceRevision', policy.sourceRevision),
      MapEntry('residualApplicability', residualPolicy.applicability.name),
      MapEntry('residualRationaleCode', residualPolicy.rationaleCode),
      MapEntry(
        'residualDownstreamDeviceId',
        residualPolicy.evaluatedDownstreamDeviceId ?? 'none',
      ),
      MapEntry(
        'residualApplicabilityEvidenceIds',
        residualPolicy.applicabilityEvidenceIds.join(','),
      ),
      MapEntry(
        'residualUpstreamDevice',
        residualPolicy.upstreamDevice == null
            ? 'none'
            : _residualDeviceSerialization(residualPolicy.upstreamDevice!),
      ),
      for (final evidence in residualEvidences)
        MapEntry(
          'residualSelectivityEvidence',
          _residualSelectivitySerialization(evidence),
        ),
      MapEntry('residualPolicySourceId', residualPolicy.sourceId),
      MapEntry(
        'residualPolicySourceRevision',
        residualPolicy.sourceRevision,
      ),
    ]);
  }

  static String _selectivitySerialization(
    ProtectiveDeviceSelectivityEvidence evidence,
  ) =>
      p9CanonicalSerializeFields([
        MapEntry('id', evidence.id),
        MapEntry('downstreamDeviceId', evidence.downstreamDeviceId),
        MapEntry('upstreamDeviceId', evidence.upstreamDeviceId),
        MapEntry('kind', evidence.kind.name),
        MapEntry(
          'selectivityLimitA',
          evidence.selectivityLimitA?.toString() ?? 'total',
        ),
        MapEntry('sourceId', evidence.sourceId),
        MapEntry('sourceRevision', evidence.sourceRevision),
      ]);

  static String _residualSelectivitySerialization(
    ResidualCurrentSelectivityEvidence evidence,
  ) =>
      p9CanonicalSerializeFields([
        MapEntry('id', evidence.id),
        MapEntry('downstreamDeviceId', evidence.downstreamDeviceId),
        MapEntry('upstreamDeviceId', evidence.upstreamDeviceId),
        MapEntry('sourceId', evidence.sourceId),
        MapEntry('sourceRevision', evidence.sourceRevision),
      ]);

  static String _overcurrentSerialization(
    OvercurrentProtectiveDeviceSpec device,
  ) =>
      p9CanonicalSerializeFields([
        MapEntry('id', device.id),
        MapEntry('kind', device.kind.name),
        MapEntry('ratedCurrentA', device.ratedCurrentA.toString()),
        MapEntry('breakingCapacityKa', device.breakingCapacityKa.toString()),
        MapEntry('poleCount', device.poleCount.toString()),
        MapEntry('tripCurve', device.tripCurve?.name ?? 'unspecified'),
        MapEntry('sourceId', device.sourceId),
        MapEntry('sourceRevision', device.sourceRevision),
      ]);

  static String _residualDeviceSerialization(
    ResidualCurrentProtectiveDeviceSpec device,
  ) =>
      p9CanonicalSerializeFields([
        MapEntry('id', device.id),
        MapEntry('kind', device.kind.name),
        MapEntry('ratedCurrentA', device.ratedCurrentA.toString()),
        MapEntry(
          'residualOperatingCurrentMa',
          device.residualOperatingCurrentMa.toString(),
        ),
        MapEntry('residualType', device.residualType.name),
        MapEntry('poleCount', device.poleCount.toString()),
        MapEntry(
          'overcurrentDeviceId',
          device.overcurrentDeviceId ?? 'none',
        ),
        MapEntry(
          'conditionalShortCircuitCurrentA',
          device.conditionalShortCircuitCurrentA?.toString() ?? 'none',
        ),
        MapEntry(
          'compatibleBackupOvercurrentDeviceIds',
          device.compatibleBackupOvercurrentDeviceIds.join(','),
        ),
        MapEntry('sourceId', device.sourceId),
        MapEntry('sourceRevision', device.sourceRevision),
      ]);

  static String _canonicalClosure(
    ElectricalProtectionCoordinationClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _canonicalOutcome(outcome)),
    ]);
  }

  static String _canonicalOutcome(
    ElectricalProtectionCoordinationClosureOutcome outcome,
  ) {
    final evaluations = outcome.evaluations.toList()
      ..sort((left, right) => left.evidence.id.compareTo(right.evidence.id));
    final residualEvaluations = outcome.residualCurrentEvaluations.toList()
      ..sort((left, right) => left.evidence.id.compareTo(right.evidence.id));
    return p9CanonicalSerializeFields([
      MapEntry('policy', _policySerialization(outcome)),
      MapEntry('overcurrentStatus', outcome.status.name),
      MapEntry(
        'overcurrentSelectedEvidenceId',
        outcome.selectedEvidence?.id ?? 'none',
      ),
      for (final evaluation in evaluations)
        MapEntry(
          'overcurrent:${evaluation.evidence.id}',
          p9CanonicalSerializeFields([
            MapEntry(
              'evidence',
              _selectivitySerialization(evaluation.evidence),
            ),
            MapEntry('rejections', evaluation.rejections.join(',')),
          ]),
        ),
      MapEntry('residualStatus', outcome.residualCurrentStatus.name),
      MapEntry(
        'residualSelectedEvidenceId',
        outcome.selectedResidualCurrentEvidence?.id ?? 'none',
      ),
      for (final evaluation in residualEvaluations)
        MapEntry(
          'residual:${evaluation.evidence.id}',
          p9CanonicalSerializeFields([
            MapEntry(
              'evidence',
              _residualSelectivitySerialization(evaluation.evidence),
            ),
            MapEntry('rejections', evaluation.rejections.join(',')),
          ]),
        ),
    ]);
  }
}
