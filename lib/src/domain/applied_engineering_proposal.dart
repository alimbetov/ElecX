import 'project_identity.dart';

/// Canonical, application-independent snapshot of the exact engineering
/// proposal that was frozen in Wizard Preview and committed by Apply.
///
/// The domain intentionally stores the D8 projection as canonical serialized
/// rows rather than depending on apartment-wizard application types. This keeps
/// persistence/Undo/Redo independent from the UI while preserving the exact
/// values that produced [outputFingerprint].
final class AppliedEngineeringProposalSnapshot {
  AppliedEngineeringProposalSnapshot({
    required this.levelId,
    required String proposalVersion,
    required String outputProjectionVersion,
    required String candidateSetFingerprint,
    required String candidateFingerprint,
    required String intentFingerprint,
    required String d1RequirementsFingerprint,
    required String requirementsFingerprint,
    required String outputFingerprint,
    required String proposalFingerprint,
    required Iterable<String> loadScheduleRows,
    required Iterable<String> circuitScheduleRows,
    required String panelSummary,
    required Iterable<String> sldNodes,
    required Iterable<String> sldEdges,
    required Iterable<String> explanations,
  })  : proposalVersion = _nonEmpty(proposalVersion, 'proposalVersion'),
        outputProjectionVersion =
            _nonEmpty(outputProjectionVersion, 'outputProjectionVersion'),
        candidateSetFingerprint =
            _fingerprint(candidateSetFingerprint, 'candidateSetFingerprint'),
        candidateFingerprint =
            _fingerprint(candidateFingerprint, 'candidateFingerprint'),
        intentFingerprint = _fingerprint(intentFingerprint, 'intentFingerprint'),
        d1RequirementsFingerprint = _fingerprint(
          d1RequirementsFingerprint,
          'd1RequirementsFingerprint',
        ),
        requirementsFingerprint =
            _fingerprint(requirementsFingerprint, 'requirementsFingerprint'),
        outputFingerprint = _fingerprint(outputFingerprint, 'outputFingerprint'),
        proposalFingerprint =
            _fingerprint(proposalFingerprint, 'proposalFingerprint'),
        loadScheduleRows = _rows(loadScheduleRows, 'loadScheduleRows'),
        circuitScheduleRows = _rows(circuitScheduleRows, 'circuitScheduleRows'),
        panelSummary = _nonEmpty(panelSummary, 'panelSummary'),
        sldNodes = _rows(sldNodes, 'sldNodes'),
        sldEdges = _rows(sldEdges, 'sldEdges'),
        explanations = _rows(explanations, 'explanations');

  final LevelId levelId;
  final String proposalVersion;
  final String outputProjectionVersion;
  final String candidateSetFingerprint;
  final String candidateFingerprint;
  final String intentFingerprint;
  final String d1RequirementsFingerprint;
  final String requirementsFingerprint;
  final String outputFingerprint;
  final String proposalFingerprint;
  final List<String> loadScheduleRows;
  final List<String> circuitScheduleRows;
  final String panelSummary;
  final List<String> sldNodes;
  final List<String> sldEdges;
  final List<String> explanations;

  bool sameAs(AppliedEngineeringProposalSnapshot other) =>
      levelId == other.levelId &&
      proposalVersion == other.proposalVersion &&
      outputProjectionVersion == other.outputProjectionVersion &&
      candidateSetFingerprint == other.candidateSetFingerprint &&
      candidateFingerprint == other.candidateFingerprint &&
      intentFingerprint == other.intentFingerprint &&
      d1RequirementsFingerprint == other.d1RequirementsFingerprint &&
      requirementsFingerprint == other.requirementsFingerprint &&
      outputFingerprint == other.outputFingerprint &&
      proposalFingerprint == other.proposalFingerprint &&
      _listEquals(loadScheduleRows, other.loadScheduleRows) &&
      _listEquals(circuitScheduleRows, other.circuitScheduleRows) &&
      panelSummary == other.panelSummary &&
      _listEquals(sldNodes, other.sldNodes) &&
      _listEquals(sldEdges, other.sldEdges) &&
      _listEquals(explanations, other.explanations);
}

/// Root-level immutable registry keyed by the canonical target level.
final class AppliedEngineeringProposalRegistry {
  const AppliedEngineeringProposalRegistry.empty() : byLevel = const {};

  AppliedEngineeringProposalRegistry({
    Map<LevelId, AppliedEngineeringProposalSnapshot> byLevel = const {},
  }) : byLevel = Map.unmodifiable(byLevel) {
    for (final entry in this.byLevel.entries) {
      if (entry.key != entry.value.levelId) {
        throw ArgumentError(
          'Applied engineering proposal map key must match snapshot levelId.',
        );
      }
    }
  }

  final Map<LevelId, AppliedEngineeringProposalSnapshot> byLevel;

  AppliedEngineeringProposalSnapshot? forLevel(LevelId levelId) =>
      byLevel[levelId];

  AppliedEngineeringProposalRegistry replace(
    AppliedEngineeringProposalSnapshot snapshot,
  ) =>
      AppliedEngineeringProposalRegistry(
        byLevel: {...byLevel, snapshot.levelId: snapshot},
      );

  bool sameAs(AppliedEngineeringProposalRegistry other) {
    if (identical(this, other)) return true;
    if (byLevel.length != other.byLevel.length) return false;
    for (final entry in byLevel.entries) {
      final right = other.byLevel[entry.key];
      if (right == null || !entry.value.sameAs(right)) return false;
    }
    return true;
  }
}

String _nonEmpty(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return normalized;
}

String _fingerprint(String value, String name) {
  final normalized = _nonEmpty(value, name).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, name, 'Must be a SHA-256 hex digest.');
  }
  return normalized;
}

List<String> _rows(Iterable<String> values, String name) => List.unmodifiable(
      values.map((value) => _nonEmpty(value, name)),
    );

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
