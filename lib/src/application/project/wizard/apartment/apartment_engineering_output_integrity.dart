import '../../../../engine/phase_assignment_engine.dart';
import 'p9_canonical_serialization.dart';
import 'p9_sha256.dart';

/// Computes the canonical D8 integrity fingerprint from the persisted semantic
/// payload. Callers must never treat a stored fingerprint as authoritative.
String computeApartmentEngineeringOutputFingerprint({
  required String outputProjectionVersion,
  required String requirementsFingerprint,
  required Iterable<String> loadScheduleRows,
  required Iterable<String> circuitScheduleRows,
  required String panelSummary,
  required Iterable<String> sldNodes,
  required Iterable<String> sldEdges,
  required Iterable<String> explanations,
}) {
  final serialization = p9CanonicalSerializeFields([
    MapEntry('version', outputProjectionVersion),
    MapEntry('requirementsFingerprint', requirementsFingerprint),
    const MapEntry(
      'phaseAssignmentVersion',
      electricalPhaseAssignmentVersion,
    ),
    for (final row in loadScheduleRows) MapEntry('loadScheduleRow', row),
    for (final row in circuitScheduleRows) MapEntry('circuitScheduleRow', row),
    MapEntry('panelSummary', panelSummary),
    for (final node in sldNodes) MapEntry('sldNode', node),
    for (final edge in sldEdges) MapEntry('sldEdge', edge),
    for (final explanation in explanations)
      MapEntry('explanation', explanation),
  ]);
  return p9Sha256Hex(serialization);
}

void requireApartmentEngineeringOutputFingerprint({
  required String persistedFingerprint,
  required String outputProjectionVersion,
  required String requirementsFingerprint,
  required Iterable<String> loadScheduleRows,
  required Iterable<String> circuitScheduleRows,
  required String panelSummary,
  required Iterable<String> sldNodes,
  required Iterable<String> sldEdges,
  required Iterable<String> explanations,
}) {
  final expected = computeApartmentEngineeringOutputFingerprint(
    outputProjectionVersion: outputProjectionVersion,
    requirementsFingerprint: requirementsFingerprint,
    loadScheduleRows: loadScheduleRows,
    circuitScheduleRows: circuitScheduleRows,
    panelSummary: panelSummary,
    sldNodes: sldNodes,
    sldEdges: sldEdges,
    explanations: explanations,
  );
  if (persistedFingerprint.toLowerCase() != expected) {
    throw const FormatException(
      'Applied engineering output fingerprint does not match the D8 payload.',
    );
  }
}
