import 'dart:convert';

import '../domain/electrical_circuit_calculation.dart';
import '../domain/electrical_circuit_synthesis.dart';
import '../domain/power_starter_generation.dart';
import '../domain/semantic_sha256.dart';
import 'circuit_grouping_engine.dart';
import 'electrical_circuit_calculation_engine.dart';

const String powerStarterGeneratorVersion = 'p12.power-starter.v1';

/// Composes existing validated electrical kernels into an explainable,
/// deterministic and ID-free POWER candidate. This is not a second P11 graph
/// or an alternative project mutation/persistence owner.
abstract final class PowerStarterGenerationEngine {
  static PowerStarterCandidate generate(PowerStarterGenerationRequest request) {
    final synthesis = CircuitGroupingEngine.synthesize(
      ElectricalCircuitSynthesisRequest(
        loads: request.loads,
        groupingPolicy: request.groupingPolicy,
        dedicatedCircuitPolicy: request.dedicatedCircuitPolicy,
      ),
    );
    final calculations = ElectricalCircuitCalculationEngine.calculate(
      ElectricalCircuitCalculationRequest(
        synthesis: synthesis,
        policies: [
          for (final circuit in synthesis.circuits)
            ElectricalCircuitCalculationPolicy(
              circuitId: circuit.id,
              nominalVoltageV: request.nominalVoltageV,
              diversityPolicy: request.diversityPolicy,
              reservePolicy: request.reservePolicy,
              sourceId: request.voltageEvidenceId,
              sourceRevision: request.voltageEvidenceRevision,
            ),
        ],
      ),
    );

    final proposals = <PowerStarterCircuitProposal>[
      for (final circuit in calculations.circuits)
        PowerStarterCircuitProposal(
          generationKey: 'power:circuit:${semanticSha256Hex(jsonEncode([
                request.boardGenerationKey,
                ...circuit.circuit.loadIds,
              ]))}',
          calculated: circuit,
        ),
    ]..sort(
        (a, b) => a.generationKey.compareTo(b.generationKey),
      );

    final distinctKeys = proposals.map((item) => item.generationKey).toSet();
    if (distinctKeys.length != proposals.length) {
      throw StateError('POWER generation keys must be unique.');
    }

    final fingerprint = semanticSha256Hex(jsonEncode(
      _fingerprintPayload(request, proposals),
    ));
    return PowerStarterCandidate(
      projectId: request.projectId,
      boardGenerationKey: request.boardGenerationKey,
      catalogSnapshotId: request.catalogSnapshotId,
      fingerprint: fingerprint,
      circuits: proposals,
      issues: const [
        PowerStarterIssue(
          code: PowerStarterIssueCode.boardCatalogSelectionRequired,
          explanation:
              'Board model and technical catalog evidence are not resolved.',
        ),
        PowerStarterIssue(
          code: PowerStarterIssueCode.protectiveDeviceEvidenceRequired,
          explanation:
              'Protection selection and coordination evidence are not resolved.',
        ),
        PowerStarterIssue(
          code: PowerStarterIssueCode.cableSelectionEvidenceRequired,
          explanation:
              'Cable catalog, ampacity and voltage-drop evidence are not resolved.',
        ),
        PowerStarterIssue(
          code: PowerStarterIssueCode.physicalRouteNotYetAvailable,
          explanation:
              'Physical route lengths and installation methods belong to P13/P14.',
        ),
      ],
    );
  }

  static Map<String, Object?> _fingerprintPayload(
    PowerStarterGenerationRequest request,
    List<PowerStarterCircuitProposal> proposals,
  ) {
    final orderedLoads = request.loads.toList()
      ..sort((a, b) => a.load.id.compareTo(b.load.id));
    final grouping = request.groupingPolicy;
    final dedicated = request.dedicatedCircuitPolicy;
    final diversity = request.diversityPolicy;
    final reserve = request.reservePolicy;

    return {
      'generatorVersion': powerStarterGeneratorVersion,
      'projectId': request.projectId,
      'boardGenerationKey': request.boardGenerationKey,
      'catalogSnapshotId': request.catalogSnapshotId,
      'voltageEvidence': [
        request.voltageEvidenceId,
        request.voltageEvidenceRevision,
        request.nominalVoltageV,
      ],
      'groupingPolicy': [
        grouping.id,
        grouping.sourceId,
        grouping.sourceRevision,
        grouping.maxGroupedLoadsPerCircuit,
        grouping.maxGroupedConnectedPowerW,
        grouping.separateByLocation,
        grouping.separateByLoadKind,
      ],
      'dedicatedPolicy': [
        dedicated.id,
        dedicated.sourceId,
        dedicated.sourceRevision,
        for (final rule in dedicated.rules)
          [
            rule.id,
            rule.sourceId,
            rule.sourceRevision,
            rule.minimumConnectedPowerW,
            rule.loadKinds.map((kind) => kind.name).toList()..sort(),
            rule.loadIds.toList()..sort(),
          ],
      ],
      'diversityPolicy': [
        diversity.id,
        diversity.sourceId,
        diversity.sourceRevision,
        diversity.factor,
      ],
      'reservePolicy': [
        reserve.id,
        reserve.sourceId,
        reserve.sourceRevision,
        reserve.reserveRatio,
      ],
      'loads': [
        for (final item in orderedLoads)
          [
            item.load.id,
            item.locationId,
            item.kind.name,
            item.requiredPhaseSystem.name,
            item.load.ratedPowerW,
            item.load.quantity,
            item.load.utilizationFactor,
            item.load.powerFactor,
            item.load.reactivePowerKind.name,
            item.load.sourceId,
            item.load.sourceRevision,
          ],
      ],
      'circuits': [
        for (final proposal in proposals)
          [
            proposal.generationKey,
            proposal.loadIds,
            proposal.calculated.circuit.dedicatedRuleId,
            proposal.calculated.calculation.connectedPowerW,
            proposal.calculated.calculation.designPowerW,
            proposal.calculated.calculation.designReactivePowerVar,
            proposal.calculated.calculation.designCurrentA,
          ],
      ],
    };
  }
}
