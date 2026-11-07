import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/semantic_sha256.dart';

enum CanonicalPowerSelectionChangeKind { add, update, remove }

/// A typed before/after operation on already-canonical circuit identity.
/// This is a read-only diff and cannot perform a project mutation.
final class CanonicalPowerSelectionChange {
  CanonicalPowerSelectionChange({
    required this.circuitId,
    required this.kind,
    required this.before,
    required this.after,
  }) {
    if (before?.circuitId != null && before!.circuitId != circuitId) {
      throw ArgumentError('Before selection uses another circuit.');
    }
    if (after?.circuitId != null && after!.circuitId != circuitId) {
      throw ArgumentError('After selection uses another circuit.');
    }
    switch (kind) {
      case CanonicalPowerSelectionChangeKind.add:
        if (before != null || after == null) {
          throw ArgumentError('Add requires only after selection.');
        }
      case CanonicalPowerSelectionChangeKind.update:
        if (before == null || after == null) {
          throw ArgumentError('Update requires both selection versions.');
        }
      case CanonicalPowerSelectionChangeKind.remove:
        if (before == null || after != null) {
          throw ArgumentError('Remove requires only before selection.');
        }
    }
  }

  final CircuitId circuitId;
  final CanonicalPowerSelectionChangeKind kind;
  final CanonicalPowerCircuitSelection? before;
  final CanonicalPowerCircuitSelection? after;

  String get semanticKey => '${kind.name}|${circuitId.value}';
  bool get equipmentChanged =>
      before?.cableCatalogId != after?.cableCatalogId ||
      before?.protectionCatalogId != after?.protectionCatalogId ||
      before?.boardCatalogTypeId != after?.boardCatalogTypeId;
  bool get provenanceChanged =>
      jsonEncode(before?.sources.map((s) => s.toCanonicalJson()).toList()) !=
          jsonEncode(after?.sources.map((s) => s.toCanonicalJson()).toList()) ||
      before?.evidenceFingerprint != after?.evidenceFingerprint;
}

final class CanonicalPowerSelectionDiff {
  CanonicalPowerSelectionDiff(Iterable<CanonicalPowerSelectionChange> changes)
      : changes = List.unmodifiable(
          changes.toList()
            ..sort((a, b) => a.circuitId.value.compareTo(b.circuitId.value)),
        ) {
    if (this.changes.map((c) => c.circuitId).toSet().length !=
        this.changes.length) {
      throw ArgumentError('Duplicate canonical POWER diff circuit.');
    }
  }

  final List<CanonicalPowerSelectionChange> changes;
  bool get isEmpty => changes.isEmpty;
  bool get isNotEmpty => changes.isNotEmpty;

  String get fingerprint => semanticSha256Hex(jsonEncode([
        'p12a8.canonical-power-diff.v1',
        for (final change in changes)
          [
            change.circuitId.value,
            change.kind.name,
            change.before?.toCanonicalJson(),
            change.after?.toCanonicalJson(),
          ],
      ]));

  factory CanonicalPowerSelectionDiff.between(
    CanonicalPowerSelectionRegistry before,
    CanonicalPowerSelectionRegistry after,
  ) {
    final ids = <CircuitId>{
      ...before.byCircuit.keys,
      ...after.byCircuit.keys,
    }.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final changes = <CanonicalPowerSelectionChange>[];
    for (final id in ids) {
      final old = before.byCircuit[id];
      final next = after.byCircuit[id];
      if (old == null && next != null) {
        changes.add(CanonicalPowerSelectionChange(
          circuitId: id,
          kind: CanonicalPowerSelectionChangeKind.add,
          before: null,
          after: next,
        ));
      } else if (old != null && next == null) {
        changes.add(CanonicalPowerSelectionChange(
          circuitId: id,
          kind: CanonicalPowerSelectionChangeKind.remove,
          before: old,
          after: null,
        ));
      } else if (old != null &&
          next != null &&
          jsonEncode(old.toCanonicalJson()) !=
              jsonEncode(next.toCanonicalJson())) {
        changes.add(CanonicalPowerSelectionChange(
          circuitId: id,
          kind: CanonicalPowerSelectionChangeKind.update,
          before: old,
          after: next,
        ));
      }
    }
    return CanonicalPowerSelectionDiff(changes);
  }
}
