import 'dart:convert';

import 'canonical_power_selection.dart';
import 'engineering_project_state.dart';
import 'project_identity.dart';
import 'semantic_sha256.dart';

/// Durable P12A group-RCD relationship attached to canonical P11 identities.
/// It never creates an independent engineering graph or mutable sidecar store.
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

  bool matches(CanonicalPowerCircuitSelection selection) =>
      selection.boardComponentId == boardComponentId &&
      selection.protectionCatalogId == downstreamProtectionCatalogId &&
      protectedCircuitIds.contains(selection.circuitId);

  Map<String, Object?> toCanonicalJson() => {
        'boardComponentId': boardComponentId.value,
        'downstreamProtectionCatalogId': downstreamProtectionCatalogId,
        'upstreamResidualCatalogId': upstreamResidualCatalogId,
        'evidenceSourceId': evidenceSourceId,
        'protectedCircuitIds': [
          for (final circuit in protectedCircuitIds) circuit.value
        ],
      };

  factory CanonicalResidualProtectionAssignment.fromCanonicalJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference(const {
          'boardComponentId',
          'downstreamProtectionCatalogId',
          'upstreamResidualCatalogId',
          'evidenceSourceId',
          'protectedCircuitIds',
        }).isEmpty == false ||
        raw.keys.length != 5) {
      throw const FormatException('Invalid group RCD document shape.');
    }
    String requiredString(Object? value) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid group RCD string identity.');
      }
      return value;
    }

    final rawIds = raw['protectedCircuitIds'];
    if (rawIds is! List) {
      throw const FormatException('Invalid protected P11 circuit list.');
    }
    return CanonicalResidualProtectionAssignment(
      boardComponentId: ComponentId(requiredString(raw['boardComponentId'])),
      downstreamProtectionCatalogId:
          requiredString(raw['downstreamProtectionCatalogId']),
      upstreamResidualCatalogId: requiredString(raw['upstreamResidualCatalogId']),
      evidenceSourceId: requiredString(raw['evidenceSourceId']),
      protectedCircuitIds: rawIds.map((v) => CircuitId(requiredString(v))),
    );
  }
}

/// Single project-owned immutable ledger of assignments, never a second P11
/// graph. Full cross-reference validation runs on every aggregate rebuild.
final class CanonicalResidualProtectionRegistry {
  const CanonicalResidualProtectionRegistry.empty()
      : assignments = const [];

  CanonicalResidualProtectionRegistry({
    required Iterable<CanonicalResidualProtectionAssignment> assignments,
  }) : assignments = List.unmodifiable(
          assignments.toList()
            ..sort((a, b) => a.fingerprint.compareTo(b.fingerprint)),
        ) {
    final covered = <CircuitId>{};
    final keys = <String>{};
    for (final assignment in this.assignments) {
      final groupKey = jsonEncode([
        assignment.boardComponentId.value,
        assignment.upstreamResidualCatalogId,
      ]);
      if (!keys.add(groupKey)) {
        throw ArgumentError('Duplicate upstream RCD group identity.');
      }
      for (final id in assignment.protectedCircuitIds) {
        if (!covered.add(id)) {
          throw ArgumentError('P11 circuit covered by multiple group RCDs.');
        }
      }
    }
  }

  final List<CanonicalResidualProtectionAssignment> assignments;

  bool get isEmpty => assignments.isEmpty;

  String get fingerprint =>
      semanticSha256Hex(jsonEncode(toCanonicalJson()));

  Map<String, Object?> toCanonicalJson() => {
        'assignments': [
          for (final assignment in assignments) assignment.toCanonicalJson()
        ],
      };

  factory CanonicalResidualProtectionRegistry.fromCanonicalJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw.length != 1 ||
        !raw.containsKey('assignments') ||
        raw['assignments'] is! List) {
      throw const FormatException('Invalid group RCD registry document.');
    }
    return CanonicalResidualProtectionRegistry(
      assignments: (raw['assignments'] as List)
          .map(CanonicalResidualProtectionAssignment.fromCanonicalJson),
    );
  }

  bool sameAs(CanonicalResidualProtectionRegistry other) =>
      fingerprint == other.fingerprint;

  void validateAgainst(
    EngineeringProjectState state,
    CanonicalPowerSelectionRegistry selections,
  ) {
    for (final assignment in assignments) {
      for (final id in assignment.protectedCircuitIds) {
        final selected = selections.byCircuit[id];
        if (selected == null ||
            selected.protectionRatings.deviceKind.trim().toLowerCase() !=
                'mcb' ||
            !assignment.matches(selected)) {
          throw ArgumentError(
              'Group RCD references an unselected or unrelated P11 MCB circuit.');
        }
        final pins = selected.sources.map((s) => s.sourceId).toSet();
        if (!pins.contains(assignment.evidenceSourceId)) {
          throw ArgumentError('Group RCD proof is not pinned by selection.');
        }
        if (state.circuits.where((c) => c.id == id).length != 1 ||
            state.graph.components
                .where((c) => c.id == assignment.boardComponentId)
                .length != 1) {
          throw ArgumentError('Group RCD references missing P11 topology.');
        }
      }
    }
  }
}
