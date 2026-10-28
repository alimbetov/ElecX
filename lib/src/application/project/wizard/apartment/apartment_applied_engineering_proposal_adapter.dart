import '../../../../domain/applied_engineering_proposal.dart';
import '../../../../domain/project_identity.dart';
import 'apartment_engineering_output_integrity.dart';
import 'apartment_engineering_output_projection.dart';
import 'apartment_engineering_pipeline.dart';

abstract final class ApartmentAppliedEngineeringProposalAdapter {
  static AppliedEngineeringProposalSnapshot snapshot({
    required LevelId levelId,
    required ApartmentEngineeringProposal proposal,
  }) {
    final output = proposal.output;
    final loadScheduleRows = <String>[
      for (final row in output.loadSchedule) row.stableSerialization,
    ];
    final circuitScheduleRows = <String>[
      for (final row in output.circuitSchedule) row.stableSerialization,
    ];
    final panelSummary = output.panelSummary.stableSerialization;
    final sldNodes = <String>[
      for (final node in output.sldNodes) node.stableSerialization,
    ];
    final sldEdges = <String>[
      for (final edge in output.sldEdges) edge.stableSerialization,
    ];
    final explanations = <String>[
      for (final explanation in output.explanations)
        explanation.stableSerialization,
    ];
    final derivedOutputFingerprint =
        computeApartmentEngineeringOutputFingerprint(
      outputProjectionVersion: apartmentEngineeringOutputProjectionVersion,
      requirementsFingerprint: output.requirementsFingerprint,
      loadScheduleRows: loadScheduleRows,
      circuitScheduleRows: circuitScheduleRows,
      panelSummary: panelSummary,
      sldNodes: sldNodes,
      sldEdges: sldEdges,
      explanations: explanations,
    );
    if (output.outputFingerprint.toLowerCase() != derivedOutputFingerprint) {
      throw StateError(
        'Apartment engineering output fingerprint does not match the D8 payload.',
      );
    }

    return AppliedEngineeringProposalSnapshot(
      levelId: levelId,
      proposalVersion: apartmentEngineeringProposalVersion,
      outputProjectionVersion: apartmentEngineeringOutputProjectionVersion,
      candidateSetFingerprint: proposal.candidateSetFingerprint,
      candidateFingerprint: proposal.candidateFingerprint,
      intentFingerprint: proposal.intentFingerprint,
      d1RequirementsFingerprint: proposal.d1RequirementsFingerprint,
      requirementsFingerprint: output.requirementsFingerprint,
      outputFingerprint: derivedOutputFingerprint,
      proposalFingerprint: proposal.proposalFingerprint,
      loadScheduleRows: loadScheduleRows,
      circuitScheduleRows: circuitScheduleRows,
      panelSummary: panelSummary,
      sldNodes: sldNodes,
      sldEdges: sldEdges,
      explanations: explanations,
    );
  }
}
