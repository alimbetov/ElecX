/// Source-pinned installation-method evidence for one exact ampacity section.
///
/// [ampacitySourceKey] binds the method evidence to the same section evidence
/// that governed D3 cable ampacity. This prevents proving one installation
/// method while calculating Iz from an unrelated table/profile.
final class CircuitInstallationSectionMethodEvidence {
  CircuitInstallationSectionMethodEvidence({
    required this.sectionId,
    required this.installationMethodId,
    required this.ampacitySourceKey,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (sectionId.trim().isEmpty ||
        installationMethodId.trim().isEmpty ||
        ampacitySourceKey.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Installation section identity/method/ampacity/source must be non-empty.',
      );
    }
  }

  final String sectionId;
  final String installationMethodId;
  final String ampacitySourceKey;
  final String sourceId;
  final String sourceRevision;
}

/// Exact installation-method closure policy for one D3-selected cable.
final class CircuitInstallationMethodPolicy {
  CircuitInstallationMethodPolicy({
    required this.circuitId,
    required this.cableId,
    required Iterable<CircuitInstallationSectionMethodEvidence> sections,
    required this.sourceId,
    required this.sourceRevision,
  }) : sections = List.unmodifiable(
          sections.toList()
            ..sort((left, right) => left.sectionId.compareTo(right.sectionId)),
        ) {
    if (circuitId.trim().isEmpty ||
        cableId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Installation policy circuit/cable/source must be non-empty.',
      );
    }
    if (this.sections.isEmpty) {
      throw ArgumentError(
        'Installation policy requires evidence for every ampacity section.',
      );
    }
    final ids = <String>{};
    for (final section in this.sections) {
      if (!ids.add(section.sectionId)) {
        throw ArgumentError(
          'Duplicate installation section ${section.sectionId}.',
        );
      }
    }
  }

  final String circuitId;
  final String cableId;
  final List<CircuitInstallationSectionMethodEvidence> sections;
  final String sourceId;
  final String sourceRevision;
}
