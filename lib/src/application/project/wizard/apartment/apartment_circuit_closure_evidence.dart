import '../../../../domain/cable_spec.dart';
import '../../../../engine/electrical_circuit_closure_engine.dart';
import 'apartment_engineering_requirements.dart';
import 'p9_canonical_serialization.dart';

/// Publishes projection-level conductor and overload evidence only when every
/// calculated circuit has a compliant cable and overcurrent device.
///
/// This service deliberately does not prove installation method, conductor
/// thermal short-circuit withstand, automatic disconnection, RCD/RCBO
/// applicability or selectivity/coordination.
abstract final class ApartmentCircuitClosureEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalCircuitClosureRequest request,
    required ElectricalCircuitClosureResult closure,
  }) {
    final circuitRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.circuit,
    );
    final protectionRequirement = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );

    if (!circuitRequirement.factEvidence.containsKey('circuit.definition') ||
        !circuitRequirement.factEvidence
            .containsKey('circuit.loadAssignments')) {
      throw ArgumentError(
        'D3 evidence requires prior D2 circuit definition/load assignments.',
      );
    }
    if (!closure.isFullyClosed) {
      throw ArgumentError(
        'D3 projection evidence requires every circuit to be fully closed.',
      );
    }

    final expected = ElectricalCircuitClosureEngine.close(request);
    if (_canonicalClosure(expected) != _canonicalClosure(closure)) {
      throw ArgumentError(
        'Circuit closure result does not match the supplied D3 request.',
      );
    }

    final sourceRevision = _policyRevision(closure);
    final updatedCircuit = _replaceFact(
      circuitRequirement,
      rationaleCode: 'p9.requirements.circuit-conductor-closure-proven-partial',
      fact: ApartmentEngineeringFactEvidence(
        factKey: 'circuit.conductorConstraints',
        valueKind: ApartmentEngineeringFactValueKind.text,
        value: _conductorEvidence(closure),
        unit: ApartmentEngineeringFactUnit.code,
        sourceId: electricalCircuitClosureVersion,
        sourceRevision: sourceRevision,
      ),
    );
    final updatedProtection = _replaceFact(
      protectionRequirement,
      rationaleCode: 'p9.requirements.protection-overload-closure-proven-partial',
      fact: ApartmentEngineeringFactEvidence(
        factKey: 'protection.overload',
        valueKind: ApartmentEngineeringFactValueKind.text,
        value: _overloadEvidence(closure),
        unit: ApartmentEngineeringFactUnit.code,
        sourceId: electricalCircuitClosureVersion,
        sourceRevision: sourceRevision,
      ),
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
          if (item.domain == ApartmentEngineeringRequirementDomain.circuit)
            updatedCircuit
          else if (item.domain ==
              ApartmentEngineeringRequirementDomain.protection)
            updatedProtection
          else
            item,
      ],
    );
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

  static ApartmentEngineeringRequirement _replaceFact(
    ApartmentEngineeringRequirement current, {
    required String rationaleCode,
    required ApartmentEngineeringFactEvidence fact,
  }) {
    return ApartmentEngineeringRequirement(
      requirementId: current.requirementId,
      domain: current.domain,
      subjectKind: current.subjectKind,
      subjectStableId: current.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.indeterminate,
      criticality: current.criticality,
      rationaleCode: rationaleCode,
      requiredFactKeys: current.requiredFactKeys,
      factEvidence: [
        for (final existing in current.factEvidence.values)
          if (existing.factKey != fact.factKey) existing,
        fact,
      ],
    );
  }

  static String _policyRevision(ElectricalCircuitClosureResult closure) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(
          outcome.circuitId,
          p9CanonicalSerializeFields([
            MapEntry('sourceId', outcome.policy.sourceId),
            MapEntry('sourceRevision', outcome.policy.sourceRevision),
          ]),
        ),
    ]);
  }

  static String _conductorEvidence(ElectricalCircuitClosureResult closure) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _conductorOutcome(outcome)),
    ]);
  }

  static String _conductorOutcome(ElectricalCircuitClosureOutcome outcome) {
    final candidate = outcome.selectedCable!;
    final cable = candidate.cable;
    final sizing = outcome.selectedCableSizing!;
    return p9CanonicalSerializeFields([
      MapEntry('cableId', cable.id),
      MapEntry(
        'crossSectionMm2',
        cable.conductorCrossSectionMm2!.toString(),
      ),
      MapEntry('conductorCount', cable.conductorCount!.toString()),
      MapEntry('conductorMaterial', cable.conductorMaterial.name),
      MapEntry('ratedVoltageV', cable.ratedVoltageV!.toString()),
      MapEntry('routeLengthMm', candidate.routeLengthMm.toString()),
      MapEntry(
        'maxVoltageDropRatio',
        candidate.maxVoltageDropRatio.toString(),
      ),
      MapEntry('IzA', sizing.governingAmpacityA!.toString()),
      MapEntry('governingSectionId', sizing.governingSectionId!),
      MapEntry('voltageDropV', sizing.voltageDropV!.toString()),
      MapEntry('voltageDropRatio', sizing.voltageDropRatio!.toString()),
      MapEntry('ampacitySourceKey', sizing.ampacitySourceKey ?? 'unspecified'),
      MapEntry('impedanceSourceKey', sizing.impedanceSourceKey ?? 'unspecified'),
      MapEntry('candidateSourceId', candidate.sourceId),
      MapEntry('candidateSourceRevision', candidate.sourceRevision),
      MapEntry('policySourceId', outcome.policy.sourceId),
      MapEntry('policySourceRevision', outcome.policy.sourceRevision),
    ]);
  }

  static String _overloadEvidence(ElectricalCircuitClosureResult closure) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _overloadOutcome(outcome)),
    ]);
  }

  static String _overloadOutcome(ElectricalCircuitClosureOutcome outcome) {
    final device = outcome.selectedProtection!;
    return p9CanonicalSerializeFields([
      MapEntry('IbA', outcome.circuit.calculation.designCurrentA.toString()),
      MapEntry(
        'IzA',
        outcome.selectedCableSizing!.governingAmpacityA!.toString(),
      ),
      MapEntry('InA', device.ratedCurrentA.toString()),
      MapEntry('deviceId', device.id),
      MapEntry('deviceKind', device.kind.name),
      MapEntry('poleCount', device.poleCount.toString()),
      MapEntry('tripCurve', device.tripCurve?.name ?? 'unspecified'),
      MapEntry('breakingCapacityKa', device.breakingCapacityKa.toString()),
      MapEntry(
        'prospectiveShortCircuitCurrentA',
        outcome.policy.prospectiveShortCircuitCurrentA.toString(),
      ),
      MapEntry('deviceSourceId', device.sourceId),
      MapEntry('deviceSourceRevision', device.sourceRevision),
      MapEntry('policySourceId', outcome.policy.sourceId),
      MapEntry('policySourceRevision', outcome.policy.sourceRevision),
    ]);
  }

  static String _canonicalClosure(ElectricalCircuitClosureResult closure) {
    final outcomes = closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    return p9CanonicalSerializeFields([
      for (final outcome in outcomes)
        MapEntry(outcome.circuitId, _canonicalOutcome(outcome)),
    ]);
  }

  static String _canonicalOutcome(ElectricalCircuitClosureOutcome outcome) {
    final selectedCable = outcome.selectedCable;
    final selectedSizing = outcome.selectedCableSizing;
    final selectedProtection = outcome.selectedProtection;
    final materials = outcome.policy.allowedConductorMaterials
        .map((value) => value.name)
        .toList()
      ..sort();
    final protectionKinds = outcome.policy.allowedProtectionKinds
        .map((value) => value.name)
        .toList()
      ..sort();
    return p9CanonicalSerializeFields([
      MapEntry('status', outcome.status.name),
      MapEntry('policySourceId', outcome.policy.sourceId),
      MapEntry('policySourceRevision', outcome.policy.sourceRevision),
      MapEntry(
        'minimumConductorCount',
        outcome.policy.minimumConductorCount.toString(),
      ),
      MapEntry('allowedMaterials', materials.join(',')),
      MapEntry(
        'minimumCableRatedVoltageV',
        outcome.policy.minimumCableRatedVoltageV.toString(),
      ),
      MapEntry(
        'prospectiveShortCircuitCurrentA',
        outcome.policy.prospectiveShortCircuitCurrentA.toString(),
      ),
      MapEntry('allowedProtectionKinds', protectionKinds.join(',')),
      MapEntry(
        'minimumProtectionPoleCount',
        outcome.policy.minimumProtectionPoleCount.toString(),
      ),
      MapEntry('selectedCableId', selectedCable?.cable.id ?? 'none'),
      MapEntry(
        'selectedCableCrossSectionMm2',
        selectedCable?.cable.conductorCrossSectionMm2?.toString() ?? 'none',
      ),
      MapEntry(
        'selectedCableCandidateSourceId',
        selectedCable?.sourceId ?? 'none',
      ),
      MapEntry(
        'selectedCableCandidateRevision',
        selectedCable?.sourceRevision ?? 'none',
      ),
      MapEntry('IzA', selectedSizing?.governingAmpacityA?.toString() ?? 'none'),
      MapEntry(
        'governingSectionId',
        selectedSizing?.governingSectionId ?? 'none',
      ),
      MapEntry(
        'voltageDropRatio',
        selectedSizing?.voltageDropRatio?.toString() ?? 'none',
      ),
      MapEntry('selectedDeviceId', selectedProtection?.id ?? 'none'),
      MapEntry(
        'selectedDeviceInA',
        selectedProtection?.ratedCurrentA.toString() ?? 'none',
      ),
      MapEntry(
        'selectedDeviceIcnKa',
        selectedProtection?.breakingCapacityKa.toString() ?? 'none',
      ),
      MapEntry('selectedDeviceKind', selectedProtection?.kind.name ?? 'none'),
      MapEntry(
        'selectedDevicePoles',
        selectedProtection?.poleCount.toString() ?? 'none',
      ),
      MapEntry('selectedDeviceSourceId', selectedProtection?.sourceId ?? 'none'),
      MapEntry(
        'selectedDeviceSourceRevision',
        selectedProtection?.sourceRevision ?? 'none',
      ),
    ]);
  }
}
