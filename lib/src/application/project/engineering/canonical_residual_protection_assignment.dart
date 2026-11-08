import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/semantic_sha256.dart';

/// Frozen proposal-side mapping of one upstream RCD to explicitly protected
/// canonical P11 circuits. This is NOT an alternative project database.
/// Production Apply requires promotion to validated project-owned topology.
final class CanonicalResidualProtectionAssignment {
  CanonicalResidualProtectionAssignment({
    required this.boardComponentId,
    required this.downstreamProtectionCatalogId,
    required this.upstreamResidualCatalogId,
    required this.evidenceSourceId,
    required Iterable<CircuitId> protectedCircuitIds,
  }) : protectedCircuitIds = List.unmodifiable(
          protectedCircuitIds.toList()
            ..sort((a, b) => a.value.compareTo(b.value)),
        ) {
    if (downstreamProtectionCatalogId.trim().isEmpty ||
        upstreamResidualCatalogId.trim().isEmpty ||
        evidenceSourceId.trim().isEmpty ||
        downstreamProtectionCatalogId == upstreamResidualCatalogId ||
        this.protectedCircuitIds.isEmpty ||
        this.protectedCircuitIds.toSet().length !=
            this.protectedCircuitIds.length) {
      throw ArgumentError('Explicit, unique RCD circuit coverage required.');
    }
  }

  final ComponentId boardComponentId;
  final String downstreamProtectionCatalogId;
  final String upstreamResidualCatalogId;
  final String evidenceSourceId;
  final List<CircuitId> protectedCircuitIds;

  String get fingerprint => semanticSha256Hex(jsonEncode([
        'p12a8.upstream-rcd-assignment.v1',
        boardComponentId.value,
        downstreamProtectionCatalogId,
        upstreamResidualCatalogId,
        evidenceSourceId,
        [for (final id in protectedCircuitIds) id.value],
      ]));

  /// Caller-owned proposal is insufficient for certification without a
  /// matching independent, authenticated topology attestation.
  bool matches(CanonicalPowerCircuitSelection selection) =>
      selection.boardComponentId == boardComponentId &&
      selection.protectionCatalogId == downstreamProtectionCatalogId &&
      protectedCircuitIds.contains(selection.circuitId);
}
