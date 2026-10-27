import '../../../../domain/applied_engineering_proposal.dart';
import '../../../../domain/project_identity.dart';
import 'apartment_engineering_output_projection.dart';
import 'apartment_engineering_pipeline.dart';

abstract final class ApartmentAppliedEngineeringProposalAdapter {
  static AppliedEngineeringProposalSnapshot snapshot({
    required LevelId levelId,
    required ApartmentEngineeringProposal proposal,
  }) {
    final output = proposal.output;
    return AppliedEngineeringProposalSnapshot(
      levelId: levelId,
      proposalVersion: apartmentEngineeringProposalVersion,
      outputProjectionVersion: apartmentEngineeringOutputProjectionVersion,
      candidateSetFingerprint: proposal.candidateSetFingerprint,
      candidateFingerprint: proposal.candidateFingerprint,
      intentFingerprint: proposal.intentFingerprint,
      d1RequirementsFingerprint: proposal.d1RequirementsFingerprint,
      requirementsFingerprint: output.requirementsFingerprint,
      outputFingerprint: output.outputFingerprint,
      proposalFingerprint: proposal.proposalFingerprint,
      loadScheduleRows: [
        for (final row in output.loadSchedule) row.stableSerialization,
      ],
      circuitScheduleRows: [
        for (final row in output.circuitSchedule) row.stableSerialization,
      ],
      panelSummary: output.panelSummary.stableSerialization,
      sldNodes: [for (final node in output.sldNodes) node.stableSerialization],
      sldEdges: [for (final edge in output.sldEdges) edge.stableSerialization],
      explanations: [
        for (final explanation in output.explanations)
          explanation.stableSerialization,
      ],
    );
  }
}
