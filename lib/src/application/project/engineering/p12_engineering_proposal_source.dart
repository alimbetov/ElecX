import '../../../domain/project_aggregate.dart';
import 'engineering_proposal_diff.dart';

/// Frozen, externally produced P12A.7 selection projection.
/// An ordinary editor form is never allowed to create or approve this record.
final class P12EngineeringProposalSnapshot {
  P12EngineeringProposalSnapshot({
    required this.projectId,
    required this.projectVersion,
    required this.engineeringStateFingerprint,
    required this.powerSelectionsFingerprint,
    required this.proposal,
  }) {
    if (projectId.trim().isEmpty ||
        projectVersion.trim().isEmpty ||
        engineeringStateFingerprint.trim().isEmpty ||
        powerSelectionsFingerprint.trim().isEmpty) {
      throw ArgumentError('Pinned P12 project baseline is required.');
    }
  }

  final String projectId;
  final String projectVersion;
  final String engineeringStateFingerprint;
  final String powerSelectionsFingerprint;
  final EngineeringProposalDiff proposal;

  /// A source-backed proposal is still only a preview, never Apply authority.
  bool get readyToApply => false;

  bool matches(ProjectAggregateRoot current) =>
      projectId == current.id.value &&
      projectVersion == current.version.toString() &&
      engineeringStateFingerprint ==
          current.engineeringMetadata.engineeringState.fingerprint &&
      powerSelectionsFingerprint ==
          current.engineeringMetadata.powerSelections.fingerprint;
}

/// The production composition root must supply this capability from its
/// independently reviewed P12 calculation/evidence pipeline. Null means
/// there is no verified proposal for the exact requested project baseline.
abstract interface class P12EngineeringProposalSource {
  P12EngineeringProposalSnapshot? proposalFor(ProjectAggregateRoot current);
}

/// Fail-closed read boundary: a foreign/stale proposal cannot appear as the
/// review of the current project, even if an adapter accidentally returns it.
abstract final class P12EngineeringProposalReadGate {
  static P12EngineeringProposalSnapshot? read({
    required ProjectAggregateRoot current,
    required P12EngineeringProposalSource? source,
  }) {
    if (source == null) return null;
    final result = source.proposalFor(current);
    if (result == null) return null;
    if (!result.matches(current)) {
      throw StateError('P12 proposal does not match current project baseline.');
    }
    return result;
  }
}
