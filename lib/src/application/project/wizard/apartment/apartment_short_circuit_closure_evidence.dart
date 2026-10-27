import '../../../../engine/electrical_short_circuit_closure_engine.dart';
import 'apartment_circuit_closure_evidence.dart';
import 'apartment_engineering_requirements.dart';
import 'p9_canonical_serialization.dart';

/// Publishes D4 short-circuit and automatic-disconnection evidence only when
/// every D3-closed circuit is also fully closed by the D4 safety engine.
///
/// Residual-current protection and selectivity/coordination are deliberately
/// outside this increment and therefore remain unresolved.
abstract final class ApartmentShortCircuitClosureEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalShortCircuitClosureRequest request,
    required ElectricalShortCircuitClosureResult closure,
  }) {
    final circuitRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.circuit,
    );
    final protectionRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );
    final conductorFact =
        circuitRequirement.factEvidence['circuit.conductorConstraints'];
    if (conductorFact == null) {
      throw ArgumentError(
        'D4 evidence requires prior D3 conductor-constraint evidence.',
      );
    }
    final overloadFact =
        protectionRequirement.factEvidence['protection.overload'];
    if (overloadFact == null) {
      throw ArgumentError('D4 evidence requires prior D3 overload evidence.');
    }

    final expectedConductorEvidence =
        ApartmentCircuitClosureEvidenceService.conductorEvidenceValue(
      request.d3Closure,
    );
    final expectedOverloadEvidence =
        ApartmentCircuitClosureEvidenceService.overloadEvidenceValue(
      request.d3Closure,
    );
    if (conductorFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        conductorFact.value != expectedConductorEvidence) {
      throw ArgumentError(
        'D4 conductor evidence does not match the supplied D3 closure.',
      );
    }
    if (overloadFact.valueKind != ApartmentEngineeringFactValueKind.text ||
        overloadFact.value != expectedOverloadEvidence) {
      throw ArgumentError(
        'D4 overload evidence does not match the supplied D3 closure.',
      );
    }
    if (!closure.isFullyClosed) {
      throw ArgumentError(
        'D4 projection evidence requires every circuit to be fully closed.',
      );
    }

    final expected = ElectricalShortCircuitClosureEngine.close(request);
    if (_canonicalClosure(expected) != _canonicalClosure(closure)) {
      throw ArgumentError(
        'Short-circuit closure result does not match the supplied D4 request.',
      );
    }

    final sourceRevision = _sourceRevision(closure);
    final updatedProtection = ApartmentEngineeringRequirement(
      requirementId: protectionRequirement.requirementId,
      domain: protectionRequirement.domain,
      subjectKind: protectionRequirement.subjectKind,
      subjectStableId: protectionRequirement.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.indeterminate,
      criticality: protectionRequirement.criticality,
      rationaleCode:
          'p9.requirements.protection-short-circuit-disconnection-proven-partial',
      requiredFactKeys: protectionRequirement.requiredFactKeys,
      factEvidence: [
        for (final existing in protectionRequirement.factEvidence.values)
          if (existing.factKey != 'protection.shortCircuit' &&
              existing.factKey != 'protection.disconnection')
            existing,
        ApartmentEngineeringFactEvidence(
          factKey: 'protection.shortCircuit',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: shortCircuitEvidenceValue(closure),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalShortCircuitClosureVersion,
          sourceRevision: sourceRevision,
        ),
        ApartmentEngineeringFactEvidence(
          factKey: 'protection.disconnection',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: disconnectionEvidenceValue(closure),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalShortCircuitClosureVersion,
          sourceRevision: sourceRevision,
        ),
      ],
    );

    return ApartmentEngineeringDesignRequirements(
      requirementsVersion: requirements.requirementsVersion,
      selectedCandidateFingerprint: requirements.selectedCandidateFingerprint,
      projectionFingerprint: requirements.projectionFingerprint,
      graphFingerprint: requirements.graphFingerprint,
      placementFingerprint: requirements.placementFingerprint,
      normativeEvidenceFingerprint: requirements.normativeEvidenceFingerprint,
      normativeProfileId: requirements.normativeProfileId,
      normativeProfileVersion: requirements.normativeProfileVersion,
      requirements: [
        for (final item in requirements.requirements)
          if (item.domain == ApartmentEngineeringRequirementDomain.protection)
            updatedProtection
          else
            item,
      ],
    );
  }

  /// Canonical D4 short-circuit proof used by D5+ for exact-lineage binding.
  static String shortCircuitEvidenceValue(
    ElectricalShortCircuitClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(
          outcome.circuitId,
          p9CanonicalSerializeFields([
            MapEntry('deviceId', outcome.d3Outcome.selectedProtection!.id),
            MapEntry(
              'breakingCapacityKa',
              outcome.d3Outcome.selectedProtection!.breakingCapacityKa
                  .toString(),
            ),
            MapEntry('cableId', outcome.d3Outcome.selectedCable!.cable.id),
            MapEntry(
              'd3ProspectiveShortCircuitCurrentA',
              outcome.d3Outcome.policy.prospectiveShortCircuitCurrentA
                  .toString(),
            ),
            MapEntry(
              'thermalFaultCurrentA',
              outcome.thermalFault!.faultCurrentA.toString(),
            ),
            MapEntry(
              'thermalLoopImpedanceOhm',
              outcome.thermalFault!.loopImpedanceOhm.toString(),
            ),
            MapEntry('faultEnergyA2s', outcome.faultEnergyA2s!.toString()),
            MapEntry(
              'thermalCapacityA2s',
              outcome.thermalCapacityA2s!.toString(),
            ),
            MapEntry(
              'protectiveCrossSectionMm2',
              outcome.policy.thermalEvidence!.crossSectionMm2.toString(),
            ),
            MapEntry(
              'kCoefficientArootSPerMm2',
              outcome.policy.thermalEvidence!.kCoefficientArootSPerMm2
                  .toString(),
            ),
            MapEntry(
              'thermalOperatingTimeUpperBoundS',
              outcome.thermalOperatingTimeS!.toString(),
            ),
          ]),
        ),
    ]);
  }

  /// Canonical D4 automatic-disconnection proof used by D5+ for lineage.
  static String disconnectionEvidenceValue(
    ElectricalShortCircuitClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(
          outcome.circuitId,
          p9CanonicalSerializeFields([
            MapEntry('deviceId', outcome.d3Outcome.selectedProtection!.id),
            MapEntry(
              'minimumFaultCurrentA',
              outcome.disconnectionFault!.faultCurrentA.toString(),
            ),
            MapEntry(
              'loopResistanceOhm',
              outcome.disconnectionFault!.loopResistanceOhm.toString(),
            ),
            MapEntry(
              'loopReactanceOhm',
              outcome.disconnectionFault!.loopReactanceOhm.toString(),
            ),
            MapEntry(
              'loopImpedanceOhm',
              outcome.disconnectionFault!.loopImpedanceOhm.toString(),
            ),
            MapEntry(
              'requiredMaxDisconnectionTimeS',
              outcome.policy.requiredMaxDisconnectionTimeS!.toString(),
            ),
            MapEntry(
              'operatingTimeUpperBoundS',
              outcome.disconnectionOperatingTimeS!.toString(),
            ),
            MapEntry(
              'timeCurrentSourceId',
              outcome.policy.timeCurrentEvidence!.sourceId,
            ),
            MapEntry(
              'timeCurrentSourceRevision',
              outcome.policy.timeCurrentEvidence!.sourceRevision,
            ),
          ]),
        ),
    ]);
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
        'P9.5-A must contain exactly one ${domain.name} requirement; found '
        '${matches.length}.',
      );
    }
    return matches.single;
  }

  static String _sourceRevision(ElectricalShortCircuitClosureResult closure) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _policySerialization(outcome)),
    ]);
  }

  static String _policySerialization(
    ElectricalShortCircuitClosureOutcome outcome,
  ) {
    final policy = outcome.policy;
    final timeCurrent = policy.timeCurrentEvidence!;
    final thermal = policy.thermalEvidence!;
    final device = outcome.d3Outcome.selectedProtection!;
    final cableCandidate = outcome.d3Outcome.selectedCable!;
    return p9CanonicalSerializeFields([
      MapEntry('d3CableId', cableCandidate.cable.id),
      MapEntry(
        'd3CableConductorCrossSectionMm2',
        cableCandidate.cable.conductorCrossSectionMm2!.toString(),
      ),
      MapEntry('d3CableSourceId', cableCandidate.sourceId),
      MapEntry('d3CableSourceRevision', cableCandidate.sourceRevision),
      MapEntry('d3DeviceId', device.id),
      MapEntry('d3DeviceSourceId', device.sourceId),
      MapEntry('d3DeviceSourceRevision', device.sourceRevision),
      MapEntry('d3PolicySourceId', outcome.d3Outcome.policy.sourceId),
      MapEntry(
        'd3PolicySourceRevision',
        outcome.d3Outcome.policy.sourceRevision,
      ),
      MapEntry('policySourceId', policy.sourceId),
      MapEntry('policySourceRevision', policy.sourceRevision),
      MapEntry(
        'requiredMaxDisconnectionTimeS',
        policy.requiredMaxDisconnectionTimeS!.toString(),
      ),
      MapEntry(
        'disconnectionFaultCase',
        _faultCaseSerialization(policy.disconnectionFaultCase!),
      ),
      MapEntry(
        'thermalFaultCase',
        _faultCaseSerialization(policy.thermalFaultCase!),
      ),
      MapEntry('timeCurrentDeviceId', timeCurrent.deviceId),
      MapEntry('timeCurrentSourceId', timeCurrent.sourceId),
      MapEntry('timeCurrentSourceRevision', timeCurrent.sourceRevision),
      MapEntry(
        'timeCurrentPoints',
        p9CanonicalSerializeFields([
          for (final point in timeCurrent.points)
            MapEntry(
              point.minimumFaultCurrentA.toString(),
              point.maximumOperatingTimeS.toString(),
            ),
        ]),
      ),
      MapEntry('thermalCableId', thermal.cableId),
      MapEntry('thermalCrossSectionMm2', thermal.crossSectionMm2.toString()),
      MapEntry(
        'thermalKCoefficientArootSPerMm2',
        thermal.kCoefficientArootSPerMm2.toString(),
      ),
      MapEntry('thermalSourceId', thermal.sourceId),
      MapEntry('thermalSourceRevision', thermal.sourceRevision),
    ]);
  }

  static String _faultCaseSerialization(FaultLoopCaseEvidence evidence) =>
      p9CanonicalSerializeFields([
        MapEntry('id', evidence.id),
        MapEntry('faultVoltageV', evidence.faultVoltageV.toString()),
        MapEntry(
          'sourceResistanceOhm',
          evidence.sourceResistanceOhm.toString(),
        ),
        MapEntry(
          'sourceReactanceOhm',
          evidence.sourceReactanceOhm.toString(),
        ),
        MapEntry(
          'phaseResistanceOhmPerKm',
          evidence.phaseResistanceOhmPerKm.toString(),
        ),
        MapEntry(
          'phaseReactanceOhmPerKm',
          evidence.phaseReactanceOhmPerKm.toString(),
        ),
        MapEntry(
          'protectiveResistanceOhmPerKm',
          evidence.protectiveResistanceOhmPerKm.toString(),
        ),
        MapEntry(
          'protectiveReactanceOhmPerKm',
          evidence.protectiveReactanceOhmPerKm.toString(),
        ),
        MapEntry('sourceId', evidence.sourceId),
        MapEntry('sourceRevision', evidence.sourceRevision),
      ]);

  static String _canonicalClosure(
    ElectricalShortCircuitClosureResult closure,
  ) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _canonicalOutcome(outcome)),
    ]);
  }

  static String _canonicalOutcome(
    ElectricalShortCircuitClosureOutcome outcome,
  ) =>
      p9CanonicalSerializeFields([
        MapEntry('policy', _nullablePolicySerialization(outcome)),
        MapEntry('d3DeviceId', outcome.d3Outcome.selectedProtection!.id),
        MapEntry(
          'd3DeviceIcnKa',
          outcome.d3Outcome.selectedProtection!.breakingCapacityKa.toString(),
        ),
        MapEntry('d3CableId', outcome.d3Outcome.selectedCable!.cable.id),
        MapEntry(
          'd3CableConductorCrossSectionMm2',
          outcome.d3Outcome.selectedCable!.cable.conductorCrossSectionMm2
              .toString(),
        ),
        MapEntry(
          'd3ProspectiveShortCircuitCurrentA',
          outcome.d3Outcome.policy.prospectiveShortCircuitCurrentA.toString(),
        ),
        MapEntry(
          'disconnectionFault',
          _faultResultSerialization(outcome.disconnectionFault),
        ),
        MapEntry(
          'thermalFault',
          _faultResultSerialization(outcome.thermalFault),
        ),
        MapEntry(
          'disconnectionOperatingTimeS',
          outcome.disconnectionOperatingTimeS?.toString() ?? 'none',
        ),
        MapEntry(
          'thermalOperatingTimeS',
          outcome.thermalOperatingTimeS?.toString() ?? 'none',
        ),
        MapEntry(
          'faultEnergyA2s',
          outcome.faultEnergyA2s?.toString() ?? 'none',
        ),
        MapEntry(
          'thermalCapacityA2s',
          outcome.thermalCapacityA2s?.toString() ?? 'none',
        ),
        MapEntry(
          'upstreamConsistencyStatus',
          outcome.upstreamConsistencyStatus.name,
        ),
        MapEntry('disconnectionStatus', outcome.disconnectionStatus.name),
        MapEntry('thermalStatus', outcome.thermalStatus.name),
        MapEntry('reasons', outcome.reasons.join(',')),
      ]);

  static String _nullablePolicySerialization(
    ElectricalShortCircuitClosureOutcome outcome,
  ) {
    final policy = outcome.policy;
    return p9CanonicalSerializeFields([
      MapEntry('sourceId', policy.sourceId),
      MapEntry('sourceRevision', policy.sourceRevision),
      MapEntry(
        'requiredMaxDisconnectionTimeS',
        policy.requiredMaxDisconnectionTimeS?.toString() ?? 'none',
      ),
      MapEntry(
        'disconnectionFaultCase',
        policy.disconnectionFaultCase == null
            ? 'none'
            : _faultCaseSerialization(policy.disconnectionFaultCase!),
      ),
      MapEntry(
        'thermalFaultCase',
        policy.thermalFaultCase == null
            ? 'none'
            : _faultCaseSerialization(policy.thermalFaultCase!),
      ),
      MapEntry(
        'timeCurrentEvidence',
        policy.timeCurrentEvidence == null
            ? 'none'
            : p9CanonicalSerializeFields([
                MapEntry('deviceId', policy.timeCurrentEvidence!.deviceId),
                MapEntry('sourceId', policy.timeCurrentEvidence!.sourceId),
                MapEntry(
                  'sourceRevision',
                  policy.timeCurrentEvidence!.sourceRevision,
                ),
                for (final point in policy.timeCurrentEvidence!.points)
                  MapEntry(
                    point.minimumFaultCurrentA.toString(),
                    point.maximumOperatingTimeS.toString(),
                  ),
              ]),
      ),
      MapEntry(
        'thermalEvidence',
        policy.thermalEvidence == null
            ? 'none'
            : p9CanonicalSerializeFields([
                MapEntry('cableId', policy.thermalEvidence!.cableId),
                MapEntry(
                  'crossSectionMm2',
                  policy.thermalEvidence!.crossSectionMm2.toString(),
                ),
                MapEntry(
                  'kCoefficientArootSPerMm2',
                  policy.thermalEvidence!.kCoefficientArootSPerMm2.toString(),
                ),
                MapEntry('sourceId', policy.thermalEvidence!.sourceId),
                MapEntry(
                  'sourceRevision',
                  policy.thermalEvidence!.sourceRevision,
                ),
              ]),
      ),
    ]);
  }

  static String _faultResultSerialization(FaultLoopCalculationResult? result) =>
      result == null
          ? 'none'
          : p9CanonicalSerializeFields([
              MapEntry('caseId', result.caseId),
              MapEntry('routeLengthMm', result.routeLengthMm.toString()),
              MapEntry(
                'loopResistanceOhm',
                result.loopResistanceOhm.toString(),
              ),
              MapEntry(
                'loopReactanceOhm',
                result.loopReactanceOhm.toString(),
              ),
              MapEntry(
                'loopImpedanceOhm',
                result.loopImpedanceOhm.toString(),
              ),
              MapEntry('faultCurrentA', result.faultCurrentA.toString()),
            ]);
}
