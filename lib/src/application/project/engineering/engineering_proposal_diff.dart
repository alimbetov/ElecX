import 'dart:convert';

import '../../../domain/semantic_sha256.dart';
import '../../../engine/electrical_circuit_closure_engine.dart';
import '../../../engine/power_evidence_selection_engine.dart';

/// A proposed engineering change, not a durable canonical entity mutation.
enum EngineeringProposalStatus { selected, unresolved }

final class EngineeringProposalDiffEntry {
  EngineeringProposalDiffEntry({
    required this.generationKey,
    required this.calculationCircuitId,
    required this.status,
    this.cableCatalogId,
    this.protectionCatalogId,
  }) {
    if (generationKey.trim().isEmpty || calculationCircuitId.trim().isEmpty) {
      throw ArgumentError('Engineering proposal identity is required.');
    }
    if (status == EngineeringProposalStatus.selected &&
        ((cableCatalogId?.trim().isNotEmpty != true) ||
            (protectionCatalogId?.trim().isNotEmpty != true))) {
      throw ArgumentError('Selected circuit requires cable and protection.');
    }
    if (status == EngineeringProposalStatus.unresolved &&
        (cableCatalogId != null || protectionCatalogId != null)) {
      throw ArgumentError('Unresolved proposals cannot claim a selected pair.');
    }
  }

  /// Semantic generation key, never a substitute for a canonical CircuitId.
  final String generationKey;
  final String calculationCircuitId;
  final EngineeringProposalStatus status;
  final String? cableCatalogId;
  final String? protectionCatalogId;
}

/// Stable, typed, ID-free engineering proposal intended for eventual mapping
/// into ReservedProjectCommand and its canonical ProjectSemanticChangeSet.
/// This DTO deliberately cannot be committed or persisted as project state.
final class EngineeringProposalDiff {
  EngineeringProposalDiff({
    required this.sourceFingerprint,
    required this.boardGenerationKey,
    required this.catalogSnapshotId,
    required Iterable<EngineeringProposalDiffEntry> entries,
    required Iterable<PowerEvidenceSelectionIssue> issues,
  })  : entries = List.unmodifiable(
          entries.toList()
            ..sort((a, b) => a.generationKey.compareTo(b.generationKey)),
        ),
        issues = List.unmodifiable(
          issues.toSet().toList()..sort((a, b) => a.index.compareTo(b.index)),
        ) {
    if (sourceFingerprint.trim().isEmpty ||
        boardGenerationKey.trim().isEmpty ||
        catalogSnapshotId.trim().isEmpty) {
      throw ArgumentError('Pinned engineering proposal identity is required.');
    }
    if (this.entries.isEmpty) {
      throw ArgumentError('Engineering proposal requires circuits.');
    }
    final generationKeys = <String>{};
    final calculationIds = <String>{};
    for (final entry in this.entries) {
      if (!generationKeys.add(entry.generationKey) ||
          !calculationIds.add(entry.calculationCircuitId)) {
        throw ArgumentError('Duplicate circuit proposal identity.');
      }
    }
  }

  final String sourceFingerprint;
  final String boardGenerationKey;
  final String catalogSnapshotId;
  final List<EngineeringProposalDiffEntry> entries;
  final List<PowerEvidenceSelectionIssue> issues;

  /// Detects a changed proposal, catalog, source or selected equipment pair.
  String get fingerprint => semanticSha256Hex(jsonEncode([
        'p12a8.engineering-proposal-diff.v1',
        sourceFingerprint,
        boardGenerationKey,
        catalogSnapshotId,
        for (final entry in entries)
          [
            entry.generationKey,
            entry.calculationCircuitId,
            entry.status.name,
            entry.cableCatalogId,
            entry.protectionCatalogId,
          ],
        for (final issue in issues) issue.name,
      ]));

  bool get isFullySelected =>
      issues.isEmpty &&
      entries
          .every((entry) => entry.status == EngineeringProposalStatus.selected);

  /// P12A.8 still lacks trusted external reviews, board ratings and canonical
  /// persistence integration. Selection success cannot enable Apply.
  bool get readyToApply => false;
}

/// Read-only projection of P12A.7 results. Does not create canonical IDs,
/// route changes or a second ProjectMutationSession.
abstract final class EngineeringProposalDiffProjector {
  static EngineeringProposalDiff project(PowerEvidenceSelectionPreview source) {
    final candidate = source.board.candidate;
    final outcomes = <String, ElectricalCircuitClosureOutcome>{
      if (source.closure != null)
        for (final outcome in source.closure!.outcomes)
          outcome.circuitId: outcome,
    };
    final expected =
        candidate.circuits.map((item) => item.calculated.id).toSet();
    if (outcomes.keys.toSet().difference(expected).isNotEmpty ||
        (source.closure != null && outcomes.length != expected.length)) {
      throw StateError('Closure outcomes do not match generated circuit set.');
    }
    return EngineeringProposalDiff(
      sourceFingerprint: source.fingerprint,
      boardGenerationKey: candidate.boardGenerationKey,
      catalogSnapshotId: candidate.catalogSnapshotId,
      entries: [
        for (final circuit in candidate.circuits)
          _entry(
            circuit.generationKey,
            circuit.calculated.id,
            outcomes[circuit.calculated.id],
          ),
      ],
      issues: source.issues,
    );
  }

  static EngineeringProposalDiffEntry _entry(
    String key,
    String circuitId,
    ElectricalCircuitClosureOutcome? outcome,
  ) {
    if (outcome?.status == ElectricalCircuitClosureStatus.closed) {
      final cable = outcome!.selectedCable?.cable.id;
      final protection = outcome.selectedProtection?.id;
      if (cable == null || protection == null) {
        throw StateError(
            'Closed circuit lacks a selected cable/protection pair.');
      }
      return EngineeringProposalDiffEntry(
        generationKey: key,
        calculationCircuitId: circuitId,
        status: EngineeringProposalStatus.selected,
        cableCatalogId: cable,
        protectionCatalogId: protection,
      );
    }
    return EngineeringProposalDiffEntry(
      generationKey: key,
      calculationCircuitId: circuitId,
      status: EngineeringProposalStatus.unresolved,
    );
  }
}
