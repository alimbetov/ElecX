import '../../../../domain/electrical_circuit_calculation.dart';
import '../../../../domain/electrical_phase_assignment.dart';
import '../../../../domain/residual_current_protection.dart';
import '../../../../engine/circuit_installation_method_closure_engine.dart';
import '../../../../engine/electrical_circuit_calculation_engine.dart';
import '../../../../engine/electrical_circuit_closure_engine.dart';
import '../../../../engine/electrical_short_circuit_closure_engine.dart';
import '../../../../engine/phase_assignment_engine.dart';
import '../../../../engine/protective_device_coordination_engine.dart';
import '../../../../engine/residual_current_protection_engine.dart';
import 'apartment_circuit_calculation_evidence.dart';
import 'apartment_circuit_closure_evidence.dart';
import 'apartment_circuit_installation_method_evidence.dart';
import 'apartment_engineering_final_gate.dart';
import 'apartment_engineering_requirements.dart';
import 'apartment_protection_coordination_evidence.dart';
import 'apartment_residual_current_closure_evidence.dart';
import 'apartment_short_circuit_closure_evidence.dart';
import 'p9_canonical_serialization.dart';
import 'p9_sha256.dart';

const String apartmentEngineeringOutputProjectionVersion =
    'p9.engineering-output-projection.v1';

enum ApartmentEngineeringSldNodeKind {
  board,
  overcurrentProtection,
  residualCurrentProtection,
  combinedProtection,
  cable,
  loadGroup,
}

final class ApartmentEngineeringLoadScheduleRow {
  const ApartmentEngineeringLoadScheduleRow({
    required this.circuitId,
    required this.loadId,
    required this.assignedPhase,
    required this.kind,
    required this.locationId,
    required this.connectedPowerW,
    required this.utilizedPowerW,
    required this.utilizedReactivePowerVar,
    required this.sourceId,
    required this.sourceRevision,
  });

  final String circuitId;
  final String loadId;
  final String assignedPhase;
  final String kind;
  final String locationId;
  final int connectedPowerW;
  final double utilizedPowerW;
  final double utilizedReactivePowerVar;
  final String sourceId;
  final String sourceRevision;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('circuitId', circuitId),
        MapEntry('loadId', loadId),
        MapEntry('assignedPhase', assignedPhase),
        MapEntry('kind', kind),
        MapEntry('locationId', locationId),
        MapEntry('connectedPowerW', connectedPowerW.toString()),
        MapEntry('utilizedPowerW', utilizedPowerW.toString()),
        MapEntry(
          'utilizedReactivePowerVar',
          utilizedReactivePowerVar.toString(),
        ),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
      ]);
}

final class ApartmentEngineeringInstallationSectionOutput {
  const ApartmentEngineeringInstallationSectionOutput({
    required this.sectionId,
    required this.installationMethodId,
    required this.ampacitySourceKey,
    required this.sourceId,
    required this.sourceRevision,
  });

  final String sectionId;
  final String installationMethodId;
  final String ampacitySourceKey;
  final String sourceId;
  final String sourceRevision;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('sectionId', sectionId),
        MapEntry('installationMethodId', installationMethodId),
        MapEntry('ampacitySourceKey', ampacitySourceKey),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
      ]);
}

final class ApartmentEngineeringCircuitScheduleRow {
  ApartmentEngineeringCircuitScheduleRow({
    required this.circuitId,
    required this.phaseSystem,
    required this.assignedPhase,
    required Iterable<String> loadIds,
    required this.connectedPowerW,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designApparentPowerVa,
    required this.designCurrentA,
    required this.nominalVoltageV,
    required this.cableId,
    required this.cableName,
    required this.conductorMaterial,
    required this.conductorCount,
    required this.conductorCrossSectionMm2,
    required this.routeLengthMm,
    required this.governingAmpacityA,
    required this.governingSectionId,
    required this.voltageDropV,
    required this.voltageDropRatio,
    required this.overcurrentDeviceId,
    required this.overcurrentDeviceKind,
    required this.overcurrentRatedCurrentA,
    required this.overcurrentBreakingCapacityKa,
    required this.overcurrentPoleCount,
    required this.prospectiveShortCircuitCurrentA,
    required this.minimumFaultCurrentA,
    required this.maximumFaultCurrentA,
    required this.disconnectionOperatingTimeS,
    required this.requiredMaxDisconnectionTimeS,
    required this.faultEnergyA2s,
    required this.thermalCapacityA2s,
    required this.residualApplicability,
    required this.residualDeviceId,
    required this.residualDeviceKind,
    required this.residualType,
    required this.residualOperatingCurrentMa,
    required this.overcurrentCoordinationStatus,
    required this.overcurrentCoordinationEvidenceId,
    required this.residualCoordinationStatus,
    required this.residualCoordinationEvidenceId,
    required Iterable<ApartmentEngineeringInstallationSectionOutput>
        installationSections,
  })  : loadIds = List.unmodifiable(loadIds.toList()..sort()),
        installationSections = List.unmodifiable(
          installationSections.toList()
            ..sort((left, right) => left.sectionId.compareTo(right.sectionId)),
        );

  final String circuitId;
  final String phaseSystem;
  final String assignedPhase;
  final List<String> loadIds;
  final int connectedPowerW;
  final double designPowerW;
  final double designReactivePowerVar;
  final double designApparentPowerVa;
  final double designCurrentA;
  final double nominalVoltageV;
  final String cableId;
  final String cableName;
  final String conductorMaterial;
  final int conductorCount;
  final double conductorCrossSectionMm2;
  final double routeLengthMm;
  final double governingAmpacityA;
  final String governingSectionId;
  final double voltageDropV;
  final double voltageDropRatio;
  final String overcurrentDeviceId;
  final String overcurrentDeviceKind;
  final double overcurrentRatedCurrentA;
  final double overcurrentBreakingCapacityKa;
  final int overcurrentPoleCount;
  final double prospectiveShortCircuitCurrentA;
  final double minimumFaultCurrentA;
  final double maximumFaultCurrentA;
  final double disconnectionOperatingTimeS;
  final double requiredMaxDisconnectionTimeS;
  final double faultEnergyA2s;
  final double thermalCapacityA2s;
  final String residualApplicability;
  final String? residualDeviceId;
  final String? residualDeviceKind;
  final String? residualType;
  final double? residualOperatingCurrentMa;
  final String overcurrentCoordinationStatus;
  final String? overcurrentCoordinationEvidenceId;
  final String residualCoordinationStatus;
  final String? residualCoordinationEvidenceId;
  final List<ApartmentEngineeringInstallationSectionOutput>
      installationSections;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('circuitId', circuitId),
        MapEntry('phaseSystem', phaseSystem),
        MapEntry('assignedPhase', assignedPhase),
        MapEntry('loadIds', loadIds.join(',')),
        MapEntry('connectedPowerW', connectedPowerW.toString()),
        MapEntry('designPowerW', designPowerW.toString()),
        MapEntry('designReactivePowerVar', designReactivePowerVar.toString()),
        MapEntry('designApparentPowerVa', designApparentPowerVa.toString()),
        MapEntry('designCurrentA', designCurrentA.toString()),
        MapEntry('nominalVoltageV', nominalVoltageV.toString()),
        MapEntry('cableId', cableId),
        MapEntry('cableName', cableName),
        MapEntry('conductorMaterial', conductorMaterial),
        MapEntry('conductorCount', conductorCount.toString()),
        MapEntry(
          'conductorCrossSectionMm2',
          conductorCrossSectionMm2.toString(),
        ),
        MapEntry('routeLengthMm', routeLengthMm.toString()),
        MapEntry('governingAmpacityA', governingAmpacityA.toString()),
        MapEntry('governingSectionId', governingSectionId),
        MapEntry('voltageDropV', voltageDropV.toString()),
        MapEntry('voltageDropRatio', voltageDropRatio.toString()),
        MapEntry('overcurrentDeviceId', overcurrentDeviceId),
        MapEntry('overcurrentDeviceKind', overcurrentDeviceKind),
        MapEntry(
          'overcurrentRatedCurrentA',
          overcurrentRatedCurrentA.toString(),
        ),
        MapEntry(
          'overcurrentBreakingCapacityKa',
          overcurrentBreakingCapacityKa.toString(),
        ),
        MapEntry('overcurrentPoleCount', overcurrentPoleCount.toString()),
        MapEntry(
          'prospectiveShortCircuitCurrentA',
          prospectiveShortCircuitCurrentA.toString(),
        ),
        MapEntry('minimumFaultCurrentA', minimumFaultCurrentA.toString()),
        MapEntry('maximumFaultCurrentA', maximumFaultCurrentA.toString()),
        MapEntry(
          'disconnectionOperatingTimeS',
          disconnectionOperatingTimeS.toString(),
        ),
        MapEntry(
          'requiredMaxDisconnectionTimeS',
          requiredMaxDisconnectionTimeS.toString(),
        ),
        MapEntry('faultEnergyA2s', faultEnergyA2s.toString()),
        MapEntry('thermalCapacityA2s', thermalCapacityA2s.toString()),
        MapEntry('residualApplicability', residualApplicability),
        MapEntry('residualDeviceId', residualDeviceId ?? 'none'),
        MapEntry('residualDeviceKind', residualDeviceKind ?? 'none'),
        MapEntry('residualType', residualType ?? 'none'),
        MapEntry(
          'residualOperatingCurrentMa',
          residualOperatingCurrentMa?.toString() ?? 'none',
        ),
        MapEntry(
          'overcurrentCoordinationStatus',
          overcurrentCoordinationStatus,
        ),
        MapEntry(
          'overcurrentCoordinationEvidenceId',
          overcurrentCoordinationEvidenceId ?? 'none',
        ),
        MapEntry('residualCoordinationStatus', residualCoordinationStatus),
        MapEntry(
          'residualCoordinationEvidenceId',
          residualCoordinationEvidenceId ?? 'none',
        ),
        for (final section in installationSections)
          MapEntry('installationSection', section.stableSerialization),
      ]);
}

final class ApartmentEngineeringPhaseSummary {
  const ApartmentEngineeringPhaseSummary({
    required this.phase,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designCurrentA,
  });

  final String phase;
  final double designPowerW;
  final double designReactivePowerVar;
  final double designCurrentA;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('phase', phase),
        MapEntry('designPowerW', designPowerW.toString()),
        MapEntry('designReactivePowerVar', designReactivePowerVar.toString()),
        MapEntry('designCurrentA', designCurrentA.toString()),
      ]);
}

final class ApartmentEngineeringPanelSummary {
  ApartmentEngineeringPanelSummary({
    required this.boardPhaseSystem,
    required this.lineNeutralVoltageV,
    required this.lineLineVoltageV,
    required this.maxPhaseCurrentA,
    required this.phaseCurrentImbalanceRatio,
    required this.branchCircuitCount,
    required Iterable<ApartmentEngineeringPhaseSummary> phaseLoads,
  }) : phaseLoads = List.unmodifiable(
          phaseLoads.toList()
            ..sort((left, right) => left.phase.compareTo(right.phase)),
        );

  final String boardPhaseSystem;
  final double lineNeutralVoltageV;
  final double? lineLineVoltageV;
  final double maxPhaseCurrentA;
  final double phaseCurrentImbalanceRatio;
  final int branchCircuitCount;
  final List<ApartmentEngineeringPhaseSummary> phaseLoads;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('boardPhaseSystem', boardPhaseSystem),
        MapEntry('lineNeutralVoltageV', lineNeutralVoltageV.toString()),
        MapEntry('lineLineVoltageV', lineLineVoltageV?.toString() ?? 'none'),
        MapEntry('maxPhaseCurrentA', maxPhaseCurrentA.toString()),
        MapEntry(
          'phaseCurrentImbalanceRatio',
          phaseCurrentImbalanceRatio.toString(),
        ),
        MapEntry('branchCircuitCount', branchCircuitCount.toString()),
        for (final phase in phaseLoads)
          MapEntry('phaseLoad', phase.stableSerialization),
      ]);
}

final class ApartmentEngineeringSldNode {
  const ApartmentEngineeringSldNode({
    required this.id,
    required this.kind,
    required this.circuitId,
    required this.referenceId,
  });

  final String id;
  final ApartmentEngineeringSldNodeKind kind;
  final String? circuitId;
  final String referenceId;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('id', id),
        MapEntry('kind', kind.name),
        MapEntry('circuitId', circuitId ?? 'none'),
        MapEntry('referenceId', referenceId),
      ]);
}

final class ApartmentEngineeringSldEdge {
  const ApartmentEngineeringSldEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.circuitId,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String circuitId;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('id', id),
        MapEntry('fromNodeId', fromNodeId),
        MapEntry('toNodeId', toNodeId),
        MapEntry('circuitId', circuitId),
      ]);
}

final class ApartmentEngineeringExplanation {
  const ApartmentEngineeringExplanation({
    required this.code,
    required this.circuitId,
    required this.value,
    required this.sourceId,
    required this.sourceRevision,
  });

  final String code;
  final String? circuitId;
  final String value;
  final String sourceId;
  final String sourceRevision;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('code', code),
        MapEntry('circuitId', circuitId ?? 'none'),
        MapEntry('value', value),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
      ]);
}

final class ApartmentEngineeringOutputProjection {
  ApartmentEngineeringOutputProjection({
    required Iterable<ApartmentEngineeringLoadScheduleRow> loadSchedule,
    required Iterable<ApartmentEngineeringCircuitScheduleRow> circuitSchedule,
    required this.panelSummary,
    required Iterable<ApartmentEngineeringSldNode> sldNodes,
    required Iterable<ApartmentEngineeringSldEdge> sldEdges,
    required Iterable<ApartmentEngineeringExplanation> explanations,
    required this.requirementsFingerprint,
    required this.outputFingerprint,
  })  : loadSchedule = List.unmodifiable(loadSchedule),
        circuitSchedule = List.unmodifiable(circuitSchedule),
        sldNodes = List.unmodifiable(sldNodes),
        sldEdges = List.unmodifiable(sldEdges),
        explanations = List.unmodifiable(explanations);

  final List<ApartmentEngineeringLoadScheduleRow> loadSchedule;
  final List<ApartmentEngineeringCircuitScheduleRow> circuitSchedule;
  final ApartmentEngineeringPanelSummary panelSummary;
  final List<ApartmentEngineeringSldNode> sldNodes;
  final List<ApartmentEngineeringSldEdge> sldEdges;
  final List<ApartmentEngineeringExplanation> explanations;
  final String requirementsFingerprint;
  final String outputFingerprint;
}

abstract final class ApartmentEngineeringOutputProjectionService {
  static ApartmentEngineeringOutputProjection project({
    required ElectricalCircuitInstallationMethodClosureResult d7Closure,
    required ElectricalPhaseAssignmentResult phaseAssignment,
    required ApartmentEngineeringDesignRequirements requirements,
  }) {
    final gate = ApartmentEngineeringFinalGateService.evaluate(requirements);
    if (!gate.accepted) {
      throw StateError(
        'D8 output projection requires an accepted final engineering gate: '
        '${gate.blockerCodes.join(', ')}.',
      );
    }
    if (!d7Closure.isFullyClosed) {
      throw ArgumentError('D8 requires a fully closed D7 result.');
    }

    final d7Outcomes = d7Closure.outcomes.toList()
      ..sort((left, right) => left.circuitId.compareTo(right.circuitId));
    final phaseByCircuit = {
      for (final assigned in phaseAssignment.circuits) assigned.id: assigned,
    };
    final expectedIds = d7Outcomes.map((outcome) => outcome.circuitId).toSet();
    final phaseIds = phaseByCircuit.keys.toSet();
    if (!_sameStringSet(expectedIds, phaseIds)) {
      throw ArgumentError(
        'D8 phase-assignment circuit set must exactly match D7 closure.',
      );
    }

    _requireCalculatedCircuitBinding(
      d7Outcomes: d7Outcomes,
      phaseByCircuit: phaseByCircuit,
    );
    _requireFinalEvidenceLineage(
      requirements: requirements,
      d7Closure: d7Closure,
      phaseAssignment: phaseAssignment,
    );

    final loadSchedule = <ApartmentEngineeringLoadScheduleRow>[];
    final circuitSchedule = <ApartmentEngineeringCircuitScheduleRow>[];
    final sldNodes = <ApartmentEngineeringSldNode>[
      const ApartmentEngineeringSldNode(
        id: 'sld:board',
        kind: ApartmentEngineeringSldNodeKind.board,
        circuitId: null,
        referenceId: 'distribution-board',
      ),
    ];
    final sldEdges = <ApartmentEngineeringSldEdge>[];
    final explanations = <ApartmentEngineeringExplanation>[];

    for (final d7 in d7Outcomes) {
      final d6 = d7.d6Outcome;
      final d5 = d6.d5Outcome;
      final d4 = d5.d4Outcome;
      final d3 = d4.d3Outcome;
      final calculated = d3.circuit;
      final calculation = calculated.calculation;
      final assigned = phaseByCircuit[d7.circuitId]!;
      final selectedCable = d3.selectedCable;
      final sizing = d3.selectedCableSizing;
      final overcurrent = d3.selectedProtection;
      final disconnectionFault = d4.disconnectionFault;
      final thermalFault = d4.thermalFault;
      if (selectedCable == null ||
          sizing == null ||
          overcurrent == null ||
          disconnectionFault == null ||
          thermalFault == null ||
          d4.disconnectionOperatingTimeS == null ||
          d4.faultEnergyA2s == null ||
          d4.thermalCapacityA2s == null) {
        throw StateError(
          'D8 cannot project incomplete D3/D4 evidence for ${d7.circuitId}.',
        );
      }

      final cable = selectedCable.cable;
      final crossSection = cable.conductorCrossSectionMm2;
      final conductorCount = cable.conductorCount;
      final governingAmpacity = sizing.governingAmpacityA;
      final governingSection = sizing.governingSectionId;
      final voltageDropV = sizing.voltageDropV;
      final voltageDropRatio = sizing.voltageDropRatio;
      if (crossSection == null ||
          conductorCount == null ||
          governingAmpacity == null ||
          governingSection == null ||
          voltageDropV == null ||
          voltageDropRatio == null) {
        throw StateError(
          'D8 cannot project incomplete cable evidence for ${d7.circuitId}.',
        );
      }

      final phase = _assignedPhaseLabel(assigned);
      final contributions = {
        for (final contribution in calculation.contributions)
          contribution.loadId: contribution,
      };
      for (final synthesizedLoad in calculated.circuit.loads) {
        final contribution = contributions[synthesizedLoad.load.id];
        if (contribution == null) {
          throw StateError(
            'D8 load ${synthesizedLoad.load.id} has no D2 contribution.',
          );
        }
        loadSchedule.add(
          ApartmentEngineeringLoadScheduleRow(
            circuitId: d7.circuitId,
            loadId: synthesizedLoad.load.id,
            assignedPhase: phase,
            kind: synthesizedLoad.kind.name,
            locationId: synthesizedLoad.locationId,
            connectedPowerW: contribution.connectedPowerW,
            utilizedPowerW: contribution.utilizedPowerW,
            utilizedReactivePowerVar: contribution.utilizedReactivePowerVar,
            sourceId: synthesizedLoad.load.sourceId,
            sourceRevision: synthesizedLoad.load.sourceRevision,
          ),
        );
      }

      final residual = d5.selectedDevice;
      final installationSections = [
        for (final section in d7.policy.sections)
          ApartmentEngineeringInstallationSectionOutput(
            sectionId: section.sectionId,
            installationMethodId: section.installationMethodId,
            ampacitySourceKey: section.ampacitySourceKey,
            sourceId: section.sourceId,
            sourceRevision: section.sourceRevision,
          ),
      ];
      circuitSchedule.add(
        ApartmentEngineeringCircuitScheduleRow(
          circuitId: d7.circuitId,
          phaseSystem: calculated.phaseSystem.name,
          assignedPhase: phase,
          loadIds: calculated.circuit.loadIds,
          connectedPowerW: calculation.connectedPowerW,
          designPowerW: calculation.designPowerW,
          designReactivePowerVar: calculation.designReactivePowerVar,
          designApparentPowerVa: calculation.designApparentPowerVa,
          designCurrentA: calculation.designCurrentA,
          nominalVoltageV: calculation.nominalVoltageV,
          cableId: cable.id,
          cableName: cable.name,
          conductorMaterial: cable.conductorMaterial.name,
          conductorCount: conductorCount,
          conductorCrossSectionMm2: crossSection,
          routeLengthMm: selectedCable.routeLengthMm,
          governingAmpacityA: governingAmpacity,
          governingSectionId: governingSection,
          voltageDropV: voltageDropV,
          voltageDropRatio: voltageDropRatio,
          overcurrentDeviceId: overcurrent.id,
          overcurrentDeviceKind: overcurrent.kind.name,
          overcurrentRatedCurrentA: overcurrent.ratedCurrentA,
          overcurrentBreakingCapacityKa: overcurrent.breakingCapacityKa,
          overcurrentPoleCount: overcurrent.poleCount,
          prospectiveShortCircuitCurrentA:
              d3.policy.prospectiveShortCircuitCurrentA,
          minimumFaultCurrentA: disconnectionFault.faultCurrentA,
          maximumFaultCurrentA: thermalFault.faultCurrentA,
          disconnectionOperatingTimeS: d4.disconnectionOperatingTimeS!,
          requiredMaxDisconnectionTimeS:
              d4.policy.requiredMaxDisconnectionTimeS,
          faultEnergyA2s: d4.faultEnergyA2s!,
          thermalCapacityA2s: d4.thermalCapacityA2s!,
          residualApplicability: d5.policy.applicability.name,
          residualDeviceId: residual?.id,
          residualDeviceKind: residual?.kind.name,
          residualType: residual?.residualType.name,
          residualOperatingCurrentMa: residual?.residualOperatingCurrentMa,
          overcurrentCoordinationStatus: d6.status.name,
          overcurrentCoordinationEvidenceId: d6.selectedEvidence?.id,
          residualCoordinationStatus: d6.residualCurrentStatus.name,
          residualCoordinationEvidenceId:
              d6.selectedResidualCurrentEvidence?.id,
          installationSections: installationSections,
        ),
      );

      _appendSld(
        nodes: sldNodes,
        edges: sldEdges,
        circuitId: d7.circuitId,
        overcurrentDeviceId: overcurrent.id,
        residualDevice: residual,
        cableId: cable.id,
      );
      explanations.addAll(_explanations(d7: d7, assigned: assigned));
    }

    loadSchedule.sort((left, right) {
      final byCircuit = left.circuitId.compareTo(right.circuitId);
      return byCircuit != 0 ? byCircuit : left.loadId.compareTo(right.loadId);
    });
    circuitSchedule.sort(
      (left, right) => left.circuitId.compareTo(right.circuitId),
    );
    sldNodes.sort((left, right) => left.id.compareTo(right.id));
    sldEdges.sort((left, right) => left.id.compareTo(right.id));
    explanations.sort((left, right) {
      final byCircuit =
          (left.circuitId ?? '').compareTo(right.circuitId ?? '');
      return byCircuit != 0 ? byCircuit : left.code.compareTo(right.code);
    });

    final panelSummary = ApartmentEngineeringPanelSummary(
      boardPhaseSystem: phaseAssignment.boardPhaseSystem.name,
      lineNeutralVoltageV: phaseAssignment.lineNeutralVoltageV,
      lineLineVoltageV: phaseAssignment.lineLineVoltageV,
      maxPhaseCurrentA: phaseAssignment.maxPhaseCurrentA,
      phaseCurrentImbalanceRatio: phaseAssignment.phaseCurrentImbalanceRatio,
      branchCircuitCount: d7Outcomes.length,
      phaseLoads: [
        for (final load in phaseAssignment.phaseLoads)
          ApartmentEngineeringPhaseSummary(
            phase: load.phase.name,
            designPowerW: load.designPowerW,
            designReactivePowerVar: load.designReactivePowerVar,
            designCurrentA: load.designCurrentA,
          ),
      ],
    );

    final outputSerialization = p9CanonicalSerializeFields([
      MapEntry('version', apartmentEngineeringOutputProjectionVersion),
      MapEntry('requirementsFingerprint', requirements.requirementsFingerprint),
      MapEntry('phaseAssignmentVersion', electricalPhaseAssignmentVersion),
      for (final row in loadSchedule)
        MapEntry('loadScheduleRow', row.stableSerialization),
      for (final row in circuitSchedule)
        MapEntry('circuitScheduleRow', row.stableSerialization),
      MapEntry('panelSummary', panelSummary.stableSerialization),
      for (final node in sldNodes)
        MapEntry('sldNode', node.stableSerialization),
      for (final edge in sldEdges)
        MapEntry('sldEdge', edge.stableSerialization),
      for (final explanation in explanations)
        MapEntry('explanation', explanation.stableSerialization),
    ]);

    return ApartmentEngineeringOutputProjection(
      loadSchedule: loadSchedule,
      circuitSchedule: circuitSchedule,
      panelSummary: panelSummary,
      sldNodes: sldNodes,
      sldEdges: sldEdges,
      explanations: explanations,
      requirementsFingerprint: requirements.requirementsFingerprint,
      outputFingerprint: p9Sha256Hex(outputSerialization),
    );
  }

  static void _requireCalculatedCircuitBinding({
    required List<ElectricalCircuitInstallationMethodClosureOutcome> d7Outcomes,
    required Map<String, PhaseAssignedElectricalCircuit> phaseByCircuit,
  }) {
    for (final d7 in d7Outcomes) {
      final calculated = d7.d6Outcome.d5Outcome.d4Outcome.d3Outcome.circuit;
      final assigned = phaseByCircuit[d7.circuitId]!;
      if (_calculatedCircuitBinding(calculated) !=
          _calculatedCircuitBinding(assigned.circuit)) {
        throw ArgumentError(
          'D8 phase assignment is not bound to the D7 calculated circuit '
          '${d7.circuitId}.',
        );
      }
    }
  }

  static void _requireFinalEvidenceLineage({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalCircuitInstallationMethodClosureResult d7Closure,
    required ElectricalPhaseAssignmentResult phaseAssignment,
  }) {
    final circuit = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.circuit,
    );
    final protection = _singleRequirement(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );
    final d3Closure = ElectricalCircuitClosureResult(
      outcomes: [
        for (final outcome in d7Closure.outcomes)
          outcome.d6Outcome.d5Outcome.d4Outcome.d3Outcome,
      ],
    );
    final d4Closure = ElectricalShortCircuitClosureResult(
      outcomes: [
        for (final outcome in d7Closure.outcomes)
          outcome.d6Outcome.d5Outcome.d4Outcome,
      ],
    );
    final d5Closure = ElectricalResidualCurrentClosureResult(
      outcomes: [
        for (final outcome in d7Closure.outcomes)
          outcome.d6Outcome.d5Outcome,
      ],
    );
    final d6Closure = ElectricalProtectionCoordinationClosureResult(
      outcomes: [for (final outcome in d7Closure.outcomes) outcome.d6Outcome],
    );
    final calculation = ElectricalCircuitCalculationResult(
      circuits: [for (final outcome in d3Closure.outcomes) outcome.circuit],
    );

    _requireFact(
      requirement: circuit,
      factKey: 'circuit.definition',
      expectedValue: _definitionEvidence(phaseAssignment),
      expectedSourceId: electricalCircuitCalculationVersion,
      expectedSourceRevision: electricalPhaseAssignmentVersion,
    );
    _requireFact(
      requirement: circuit,
      factKey: 'circuit.loadAssignments',
      expectedValue: _assignmentEvidence(calculation),
      expectedSourceId: electricalCircuitCalculationVersion,
      expectedSourceRevision: electricalPhaseAssignmentVersion,
    );
    final d3Revision =
        ApartmentCircuitClosureEvidenceService.sourceRevisionValue(d3Closure);
    _requireFact(
      requirement: circuit,
      factKey: 'circuit.conductorConstraints',
      expectedValue:
          ApartmentCircuitClosureEvidenceService.conductorEvidenceValue(
        d3Closure,
      ),
      expectedSourceId: electricalCircuitClosureVersion,
      expectedSourceRevision: d3Revision,
    );
    _requireFact(
      requirement: protection,
      factKey: 'protection.overload',
      expectedValue: ApartmentCircuitClosureEvidenceService.overloadEvidenceValue(
        d3Closure,
      ),
      expectedSourceId: electricalCircuitClosureVersion,
      expectedSourceRevision: d3Revision,
    );

    final d4Revision =
        ApartmentShortCircuitClosureEvidenceService.sourceRevisionValue(
      d4Closure,
    );
    _requireFact(
      requirement: protection,
      factKey: 'protection.shortCircuit',
      expectedValue:
          ApartmentShortCircuitClosureEvidenceService.shortCircuitEvidenceValue(
        d4Closure,
      ),
      expectedSourceId: electricalShortCircuitClosureVersion,
      expectedSourceRevision: d4Revision,
    );
    _requireFact(
      requirement: protection,
      factKey: 'protection.disconnection',
      expectedValue:
          ApartmentShortCircuitClosureEvidenceService.disconnectionEvidenceValue(
        d4Closure,
      ),
      expectedSourceId: electricalShortCircuitClosureVersion,
      expectedSourceRevision: d4Revision,
    );

    _requireFact(
      requirement: protection,
      factKey: 'protection.residualCurrent',
      expectedValue: ApartmentResidualCurrentClosureEvidenceService
          .residualCurrentEvidenceValue(d5Closure),
      expectedSourceId: electricalResidualCurrentClosureVersion,
      expectedSourceRevision:
          ApartmentResidualCurrentClosureEvidenceService.sourceRevisionValue(
        d5Closure,
      ),
    );
    _requireFact(
      requirement: protection,
      factKey: 'protection.coordination',
      expectedValue: ApartmentProtectionCoordinationEvidenceService
          .coordinationEvidenceValue(d6Closure),
      expectedSourceId: electricalProtectionCoordinationClosureVersion,
      expectedSourceRevision:
          ApartmentProtectionCoordinationEvidenceService.sourceRevisionValue(
        d6Closure,
      ),
    );
    _requireFact(
      requirement: circuit,
      factKey: 'circuit.installationMethod',
      expectedValue: ApartmentCircuitInstallationMethodEvidenceService
          .installationMethodEvidenceValue(d7Closure),
      expectedSourceId: electricalCircuitInstallationMethodClosureVersion,
      expectedSourceRevision:
          ApartmentCircuitInstallationMethodEvidenceService.sourceRevisionValue(
        d7Closure,
      ),
    );
  }

  static void _requireFact({
    required ApartmentEngineeringRequirement requirement,
    required String factKey,
    required String expectedValue,
    required String expectedSourceId,
    required String expectedSourceRevision,
  }) {
    final fact = requirement.factEvidence[factKey];
    if (fact == null ||
        fact.valueKind != ApartmentEngineeringFactValueKind.text ||
        fact.unit != ApartmentEngineeringFactUnit.code ||
        fact.value != expectedValue ||
        fact.sourceId != expectedSourceId ||
        fact.sourceRevision != expectedSourceRevision) {
      throw ArgumentError(
        'D8 final evidence $factKey does not match the supplied D2-D7 lineage.',
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
        'D8 requires exactly one ${domain.name} requirement; '
        'found ${matches.length}.',
      );
    }
    return matches.single;
  }

  static String _definitionEvidence(ElectricalPhaseAssignmentResult result) {
    final assignedCircuits = result.circuits.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return p9CanonicalSerializeFields([
      MapEntry('boardPhaseSystem', result.boardPhaseSystem.name),
      MapEntry('lineNeutralVoltageV', result.lineNeutralVoltageV.toString()),
      MapEntry(
        'lineLineVoltageV',
        result.lineLineVoltageV?.toString() ?? 'n/a',
      ),
      for (final assigned in assignedCircuits)
        MapEntry(
          assigned.id,
          p9CanonicalSerializeFields([
            MapEntry('phaseSystem', assigned.circuit.phaseSystem.name),
            MapEntry(
              'phase',
              assigned.phase?.name ?? 'threePhaseBalanced',
            ),
            MapEntry(
              'connectedPowerW',
              assigned.circuit.calculation.connectedPowerW.toString(),
            ),
            MapEntry(
              'designPowerW',
              assigned.circuit.calculation.designPowerW.toString(),
            ),
            MapEntry(
              'designReactivePowerVar',
              assigned.circuit.calculation.designReactivePowerVar.toString(),
            ),
            MapEntry(
              'designApparentPowerVa',
              assigned.circuit.calculation.designApparentPowerVa.toString(),
            ),
            MapEntry(
              'designCurrentA',
              assigned.circuit.calculation.designCurrentA.toString(),
            ),
            MapEntry('policySourceId', assigned.circuit.policySourceId),
            MapEntry(
              'policySourceRevision',
              assigned.circuit.policySourceRevision,
            ),
          ]),
        ),
    ]);
  }

  static String _assignmentEvidence(
    ElectricalCircuitCalculationResult calculation,
  ) {
    final circuits = calculation.circuits.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return p9CanonicalSerializeFields([
      for (final calculated in circuits)
        MapEntry(calculated.id, calculated.circuit.loadIds.join(',')),
    ]);
  }

  static String _assignedPhaseLabel(PhaseAssignedElectricalCircuit assigned) =>
      assigned.phase?.name ?? 'balanced-three-phase';

  static void _appendSld({
    required List<ApartmentEngineeringSldNode> nodes,
    required List<ApartmentEngineeringSldEdge> edges,
    required String circuitId,
    required String overcurrentDeviceId,
    required ResidualCurrentProtectiveDeviceSpec? residualDevice,
    required String cableId,
  }) {
    final protectionNodeId = 'sld:$circuitId:protection';
    final isCombined =
        residualDevice?.kind == ResidualCurrentDeviceKind.rcbo &&
            residualDevice?.overcurrentDeviceId == overcurrentDeviceId;
    nodes.add(
      ApartmentEngineeringSldNode(
        id: protectionNodeId,
        kind: isCombined
            ? ApartmentEngineeringSldNodeKind.combinedProtection
            : ApartmentEngineeringSldNodeKind.overcurrentProtection,
        circuitId: circuitId,
        referenceId: overcurrentDeviceId,
      ),
    );
    edges.add(
      ApartmentEngineeringSldEdge(
        id: 'sld:$circuitId:edge:board-protection',
        fromNodeId: 'sld:board',
        toNodeId: protectionNodeId,
        circuitId: circuitId,
      ),
    );

    var upstreamNodeId = protectionNodeId;
    if (residualDevice != null && !isCombined) {
      final residualNodeId = 'sld:$circuitId:residual';
      nodes.add(
        ApartmentEngineeringSldNode(
          id: residualNodeId,
          kind: ApartmentEngineeringSldNodeKind.residualCurrentProtection,
          circuitId: circuitId,
          referenceId: residualDevice.id,
        ),
      );
      edges.add(
        ApartmentEngineeringSldEdge(
          id: 'sld:$circuitId:edge:protection-residual',
          fromNodeId: protectionNodeId,
          toNodeId: residualNodeId,
          circuitId: circuitId,
        ),
      );
      upstreamNodeId = residualNodeId;
    }

    final cableNodeId = 'sld:$circuitId:cable';
    final loadNodeId = 'sld:$circuitId:loads';
    nodes
      ..add(
        ApartmentEngineeringSldNode(
          id: cableNodeId,
          kind: ApartmentEngineeringSldNodeKind.cable,
          circuitId: circuitId,
          referenceId: cableId,
        ),
      )
      ..add(
        ApartmentEngineeringSldNode(
          id: loadNodeId,
          kind: ApartmentEngineeringSldNodeKind.loadGroup,
          circuitId: circuitId,
          referenceId: circuitId,
        ),
      );
    edges
      ..add(
        ApartmentEngineeringSldEdge(
          id: 'sld:$circuitId:edge:protection-cable',
          fromNodeId: upstreamNodeId,
          toNodeId: cableNodeId,
          circuitId: circuitId,
        ),
      )
      ..add(
        ApartmentEngineeringSldEdge(
          id: 'sld:$circuitId:edge:cable-loads',
          fromNodeId: cableNodeId,
          toNodeId: loadNodeId,
          circuitId: circuitId,
        ),
      );
  }

  static List<ApartmentEngineeringExplanation> _explanations({
    required ElectricalCircuitInstallationMethodClosureOutcome d7,
    required PhaseAssignedElectricalCircuit assigned,
  }) {
    final d6 = d7.d6Outcome;
    final d5 = d6.d5Outcome;
    final d4 = d5.d4Outcome;
    final d3 = d4.d3Outcome;
    final calculated = d3.circuit;
    final sizing = d3.selectedCableSizing!;
    final cable = d3.selectedCable!;
    final overcurrent = d3.selectedProtection!;
    final residual = d5.selectedDevice;
    return [
      ApartmentEngineeringExplanation(
        code: 'phase.assignment',
        circuitId: d7.circuitId,
        value: _assignedPhaseLabel(assigned),
        sourceId: electricalPhaseAssignmentVersion,
        sourceRevision: calculated.policySourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'cable.governingAmpacity',
        circuitId: d7.circuitId,
        value:
            '${sizing.governingSectionId}:${sizing.governingAmpacityA}A',
        sourceId: cable.sourceId,
        sourceRevision: cable.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'cable.voltageDrop',
        circuitId: d7.circuitId,
        value: '${sizing.voltageDropV}V:${sizing.voltageDropRatio}',
        sourceId: sizing.impedanceSourceKey!,
        sourceRevision: cable.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'protection.ibInIz',
        circuitId: d7.circuitId,
        value:
            '${calculated.calculation.designCurrentA}<=${overcurrent.ratedCurrentA}<=${sizing.governingAmpacityA}',
        sourceId: overcurrent.sourceId,
        sourceRevision: overcurrent.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'shortCircuit.disconnection',
        circuitId: d7.circuitId,
        value:
            '${d4.disconnectionFault!.faultCurrentA}A:${d4.disconnectionOperatingTimeS}s<=${d4.policy.requiredMaxDisconnectionTimeS}s',
        sourceId: d4.policy.sourceId,
        sourceRevision: d4.policy.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'shortCircuit.thermal',
        circuitId: d7.circuitId,
        value: '${d4.faultEnergyA2s}<=${d4.thermalCapacityA2s}',
        sourceId: d4.policy.sourceId,
        sourceRevision: d4.policy.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'residual.policy',
        circuitId: d7.circuitId,
        value: residual == null
            ? d5.policy.applicability.name
            : '${residual.kind.name}:${residual.residualType.name}:${residual.residualOperatingCurrentMa}mA',
        sourceId: d5.policy.sourceId,
        sourceRevision: d5.policy.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'coordination.overcurrent',
        circuitId: d7.circuitId,
        value: d6.selectedEvidence?.id ?? d6.status.name,
        sourceId: d6.selectedEvidence?.sourceId ?? d6.policy.sourceId,
        sourceRevision:
            d6.selectedEvidence?.sourceRevision ?? d6.policy.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'coordination.residualCurrent',
        circuitId: d7.circuitId,
        value: d6.selectedResidualCurrentEvidence?.id ??
            d6.residualCurrentStatus.name,
        sourceId: d6.selectedResidualCurrentEvidence?.sourceId ??
            d6.residualCurrentPolicy.sourceId,
        sourceRevision: d6.selectedResidualCurrentEvidence?.sourceRevision ??
            d6.residualCurrentPolicy.sourceRevision,
      ),
      ApartmentEngineeringExplanation(
        code: 'installation.method',
        circuitId: d7.circuitId,
        value: d7.policy.sections
            .map(
              (section) =>
                  '${section.sectionId}:${section.installationMethodId}',
            )
            .join(','),
        sourceId: d7.policy.sourceId,
        sourceRevision: d7.policy.sourceRevision,
      ),
    ];
  }

  static String _calculatedCircuitBinding(CalculatedElectricalCircuit circuit) {
    final calculation = circuit.calculation;
    final loadIds = circuit.circuit.loadIds.toList()..sort();
    return p9CanonicalSerializeFields([
      MapEntry('id', circuit.id),
      MapEntry('phaseSystem', circuit.phaseSystem.name),
      MapEntry('loadIds', loadIds.join(',')),
      MapEntry('connectedPowerW', calculation.connectedPowerW.toString()),
      MapEntry('designPowerW', calculation.designPowerW.toString()),
      MapEntry(
        'designReactivePowerVar',
        calculation.designReactivePowerVar.toString(),
      ),
      MapEntry(
        'designApparentPowerVa',
        calculation.designApparentPowerVa.toString(),
      ),
      MapEntry('designCurrentA', calculation.designCurrentA.toString()),
      MapEntry('nominalVoltageV', calculation.nominalVoltageV.toString()),
      MapEntry('diversityPolicyId', calculation.diversityPolicyId),
      MapEntry('diversityFactor', calculation.diversityFactor.toString()),
      MapEntry('reservePolicyId', calculation.reservePolicyId),
      MapEntry('reserveRatio', calculation.reserveRatio.toString()),
      MapEntry('policySourceId', circuit.policySourceId),
      MapEntry('policySourceRevision', circuit.policySourceRevision),
    ]);
  }
}

bool _sameStringSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
