import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../../project/project_mutation.dart';
import '../../project/project_mutation_reservation.dart';
import 'canonical_power_selection_diff.dart';
import 'engineering_proposal_diff.dart';

/// P12A.8 preview-only canonical mapping of a fully selected P12A.7 proposal.
/// It uses the existing coordinator, version and P11 circuit identities.
/// No new entity IDs are allocated for selections of existing circuits.
final class EngineeringReservedProjectCommand
    implements ReservedProjectCommand, PreviewOnlyReservedProjectCommand {
  EngineeringReservedProjectCommand({
    required this.proposal,
    required CanonicalPowerSelectionRegistry requestedSelections,
    required Map<String, CircuitId> canonicalCircuitIdsByCalculationId,
    required this.expectedEngineeringStateFingerprint,
    required this.expectedPowerSelectionFingerprint,
  })  : canonicalCircuitIdsByCalculationId =
            Map.unmodifiable(canonicalCircuitIdsByCalculationId),
        requestedSelections = CanonicalPowerSelectionRegistry.fromCanonicalJson(
            jsonDecode(jsonEncode(requestedSelections.toCanonicalJson()))) {
    if (!proposal.isFullySelected) {
      throw ArgumentError(
          'Unresolved engineering proposal cannot enter canonical preview.');
    }
    if (expectedEngineeringStateFingerprint.trim().isEmpty ||
        expectedPowerSelectionFingerprint.trim().isEmpty) {
      throw ArgumentError('Canonical baseline fingerprints are required.');
    }
    final selectedByKey = {
      for (final entry in proposal.entries) entry.generationKey: entry,
    };
    final proposalCalculationIds = {
      for (final entry in proposal.entries) entry.calculationCircuitId,
    };
    if (this.canonicalCircuitIdsByCalculationId.keys.toSet().length !=
            proposalCalculationIds.length ||
        !this.canonicalCircuitIdsByCalculationId.keys.toSet().containsAll(
              proposalCalculationIds,
            ) ||
        this.canonicalCircuitIdsByCalculationId.values.toSet().length !=
            proposalCalculationIds.length) {
      throw ArgumentError(
          'Explicit calculation-to-canonical circuit mapping must be bijective.');
    }
    if (selectedByKey.length != this.requestedSelections.byCircuit.length) {
      throw ArgumentError('Selection count must equal proposal circuit count.');
    }
    for (final selection in this.requestedSelections.byCircuit.values) {
      final entry = selectedByKey[selection.generationKey];
      if (entry == null ||
          this.canonicalCircuitIdsByCalculationId[entry.calculationCircuitId] !=
              selection.circuitId ||
          entry.cableCatalogId != selection.cableCatalogId ||
          entry.protectionCatalogId != selection.protectionCatalogId ||
          selection.catalogSnapshotId != proposal.catalogSnapshotId) {
        throw ArgumentError(
            'Canonical selections do not match the frozen P12A.7 proposal.');
      }
    }
  }

  final EngineeringProposalDiff proposal;
  final CanonicalPowerSelectionRegistry requestedSelections;

  /// Explicit lineage: the calculator's transient circuit IDs cannot be
  /// silently treated as authoritative P11 CircuitIds.
  final Map<String, CircuitId> canonicalCircuitIdsByCalculationId;
  final String expectedEngineeringStateFingerprint;
  final String expectedPowerSelectionFingerprint;

  @override
  String get commandType => 'p12a8.power-selection.preview.v1';

  @override
  String get normalizedIntentKey => jsonEncode([
        commandType,
        proposal.fingerprint,
        requestedSelections.fingerprint,
        [
          for (final id
              in canonicalCircuitIdsByCalculationId.keys.toList()..sort())
            [id, canonicalCircuitIdsByCalculationId[id]!.value],
        ],
        expectedEngineeringStateFingerprint,
        expectedPowerSelectionFingerprint,
      ]);

  @override
  String get commitBlockReason =>
      'P12A.8 production Apply requires authenticated normative review, '
      'board/thermal/fault/selectivity/RCD qualification and transaction-'
      'bound source revalidation. Preview is read-only.';

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory);

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    if (current.engineeringMetadata.engineeringState.fingerprint !=
            expectedEngineeringStateFingerprint ||
        current.engineeringMetadata.powerSelections.fingerprint !=
            expectedPowerSelectionFingerprint) {
      throw StateError('Engineering preview baseline is stale.');
    }
    requestedSelections
        .validateAgainst(current.engineeringMetadata.engineeringState);
    final old = current.engineeringMetadata.powerSelections;
    for (final existing in old.byCircuit.entries) {
      if (!requestedSelections.byCircuit.containsKey(existing.key)) {
        throw StateError(
            'Engineering preview cannot silently delete selections.');
      }
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    validateReservation(current: current, reservation: reservation);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        stores: current.stores,
        engineeringMetadata: current.engineeringMetadata
            .withPowerSelections(requestedSelections),
      ),
    );
  }

  /// Existing P11 CircuitIds are the semantic owners of the changed selection
  /// snapshots. CanonicalPowerSelectionDiff carries the exact before/after
  /// engineering details for display, while the change set uses typed IDs.
  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    final diff = CanonicalPowerSelectionDiff.between(
      before.engineeringMetadata.powerSelections,
      candidate.engineeringMetadata.powerSelections,
    );
    for (final change in diff.changes) {
      yield UpdateEntityOperation(entityId: change.circuitId);
    }
  }
}
