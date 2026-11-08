import 'package:elecx/src/application/project/engineering/engineering_proposal_diff.dart';
import 'package:elecx/src/application/project/engineering/p12_engineering_proposal_source.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/engine/power_evidence_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_service_anchor_fixture.dart';

final class _FixedP12ProposalSource implements P12EngineeringProposalSource {
  const _FixedP12ProposalSource(this.snapshot);

  final P12EngineeringProposalSnapshot? snapshot;

  @override
  P12EngineeringProposalSnapshot? proposalFor(ProjectAggregateRoot current) =>
      snapshot;
}

void main() {
  final project = P1010ServiceAnchorFixture().project;
  final proposal = EngineeringProposalDiff(
    sourceFingerprint: 'source-evidence-v1',
    boardGenerationKey: 'board-1',
    catalogSnapshotId: 'catalog-1',
    entries: [
      EngineeringProposalDiffEntry(
        generationKey: 'circuit-1',
        calculationCircuitId: 'calculation-1',
        status: EngineeringProposalStatus.unresolved,
      ),
    ],
    issues: [PowerEvidenceSelectionIssue.circuitBindingMissing],
  );

  P12EngineeringProposalSnapshot snapshot({
    String? projectId,
    String? projectVersion,
    String? engineeringFingerprint,
    String? selectionsFingerprint,
  }) =>
      P12EngineeringProposalSnapshot(
        projectId: projectId ?? project.id.value,
        projectVersion: projectVersion ?? project.version.toString(),
        engineeringStateFingerprint: engineeringFingerprint ??
            project.engineeringMetadata.engineeringState.fingerprint,
        powerSelectionsFingerprint: selectionsFingerprint ??
            project.engineeringMetadata.powerSelections.fingerprint,
        proposal: proposal,
      );

  test('absent production source never fabricates an EngineeringProposalDiff',
      () {
    expect(
      P12EngineeringProposalReadGate.read(current: project, source: null),
      isNull,
    );
    expect(
      P12EngineeringProposalReadGate.read(
        current: project,
        source: const _FixedP12ProposalSource(null),
      ),
      isNull,
    );
  });

  test('source-backed snapshot is project/version/fingerprint-bound', () {
    final valid = snapshot();
    expect(
      P12EngineeringProposalReadGate.read(
        current: project,
        source: _FixedP12ProposalSource(valid),
      ),
      same(valid),
    );
    expect(valid.readyToApply, isFalse);
    expect(valid.proposal.isFullySelected, isFalse);
  });

  test('foreign project, stale version and altered engineering state fail', () {
    for (final invalid in [
      snapshot(projectId: 'foreign-project'),
      snapshot(projectVersion: 'outdated-version'),
      snapshot(engineeringFingerprint: 'altered-engineering'),
      snapshot(selectionsFingerprint: 'altered-selections'),
    ]) {
      expect(
        () => P12EngineeringProposalReadGate.read(
          current: project,
          source: _FixedP12ProposalSource(invalid),
        ),
        throwsStateError,
      );
    }
  });
}
