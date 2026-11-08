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
    this.upstreamResidualComponentId,
    required this.downstreamProtectionCatalogId,
    required this.upstreamResidualCatalogId,
    required this.evidenceSourceId,
    required Iterable<CircuitId> protectedCircuitIds,
    Map<CircuitId, String> downstreamCatalogOverrides = const {},
  }) : protectedCircuitIds = List.unmodifiable(
          protectedCircuitIds.toList()
            ..sort((a, b) => a.value.compareTo(b.value)),
        ),
        downstreamCatalogOverrides =
            Map.unmodifiable(downstreamCatalogOverrides) {
    if (downstreamProtectionCatalogId.trim().isEmpty ||
        upstreamResidualCatalogId.trim().isEmpty ||
        evidenceSourceId.trim().isEmpty ||
        downstreamProtectionCatalogId == upstreamResidualCatalogId ||
        this.protectedCircuitIds.isEmpty ||
        this.protectedCircuitIds.toSet().length !=
            this.protectedCircuitIds.length) {
      throw ArgumentError('Explicit, unique RCD circuit coverage required.');
    }
    for (final entry in this.downstreamCatalogOverrides.entries) {
      if (!this.protectedCircuitIds.contains(entry.key) ||
          entry.value.trim().isEmpty) {
        throw ArgumentError('Invalid circuit-specific MCB catalog override.');
      }
    }
  }

  final ComponentId boardComponentId;
  final ComponentId? upstreamResidualComponentId;
  final String downstreamProtectionCatalogId;
  final String upstreamResidualCatalogId;
  final String evidenceSourceId;
  final List<CircuitId> protectedCircuitIds;
  final Map<CircuitId, String> downstreamCatalogOverrides;

  String get fingerprint => semanticSha256Hex(jsonEncode([
        'p12a8.upstream-rcd-assignment.v2',
        boardComponentId.value,
        upstreamResidualComponentId?.value,
        downstreamProtectionCatalogId,
        upstreamResidualCatalogId,
        evidenceSourceId,
        [for (final id in protectedCircuitIds) id.value],
        [
          for (final id in downstreamCatalogOverrides.keys.toList()
            ..sort((a, b) => a.value.compareTo(b.value)))
            [id.value, downstreamCatalogOverrides[id]],
        ],
      ]));

  bool matches(CanonicalPowerCircuitSelection selection) =>
      selection.boardComponentId == boardComponentId &&
      selection.protectionCatalogId ==
          (downstreamCatalogOverrides[selection.circuitId] ??
              downstreamProtectionCatalogId) &&
      protectedCircuitIds.contains(selection.circuitId);

  Map<String, Object?> toCanonicalJson() => {
        'boardComponentId': boardComponentId.value,
        'upstreamResidualComponentId': upstreamResidualComponentId?.value,
        'downstreamProtectionCatalogId': downstreamProtectionCatalogId,
        'upstreamResidualCatalogId': upstreamResidualCatalogId,
        'evidenceSourceId': evidenceSourceId,
        'protectedCircuitIds': [
          for (final circuit in protectedCircuitIds) circuit.value
        ],
        'downstreamCatalogOverrides': {
          for (final id in downstreamCatalogOverrides.keys.toList()
            ..sort((a, b) => a.value.compareTo(b.value)))
            id.value: downstreamCatalogOverrides[id],
        },
      };

  factory CanonicalResidualProtectionAssignment.fromCanonicalJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().length != 7 ||
        !raw.keys.toSet().containsAll(const {
          'boardComponentId',
          'upstreamResidualComponentId',
          'downstreamProtectionCatalogId',
          'upstreamResidualCatalogId',
          'evidenceSourceId',
          'protectedCircuitIds',
          'downstreamCatalogOverrides',
        })) {
      throw const FormatException('Invalid group RCD document shape.');
    }
    String requiredString(Object? value) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid group RCD string identity.');
      }
      return value;
    }

    final rawIds = raw['protectedCircuitIds'];
    if (rawIds is! List ||
        raw['downstreamCatalogOverrides'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid P11 circuit catalog mapping.');
    }
    final rawOverrides =
        raw['downstreamCatalogOverrides'] as Map<String, dynamic>;
    return CanonicalResidualProtectionAssignment(
      boardComponentId: ComponentId(requiredString(raw['boardComponentId'])),
      upstreamResidualComponentId:
          ComponentId(requiredString(raw['upstreamResidualComponentId'])),
      downstreamProtectionCatalogId:
          requiredString(raw['downstreamProtectionCatalogId']),
      upstreamResidualCatalogId:
          requiredString(raw['upstreamResidualCatalogId']),
      evidenceSourceId: requiredString(raw['evidenceSourceId']),
      protectedCircuitIds: rawIds.map((v) => CircuitId(requiredString(v))),
      downstreamCatalogOverrides: {
        for (final entry in rawOverrides.entries)
          CircuitId(requiredString(entry.key)): requiredString(entry.value),
      },
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
      final groupKey = assignment.upstreamResidualComponentId?.value ??
          jsonEncode([
            assignment.boardComponentId.value,
            assignment.upstreamResidualCatalogId,
            assignment.fingerprint,
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
      final deviceId = assignment.upstreamResidualComponentId;
      if (deviceId == null || deviceId == assignment.boardComponentId) {
        throw ArgumentError(
            'Durable group RCD needs a distinct P11 device ID.');
      }
      final devices = state.graph.components
          .where((component) => component.id == deviceId)
          .toList();
      if (devices.length != 1 ||
          devices.single.componentTypeId !=
              assignment.upstreamResidualCatalogId) {
        throw ArgumentError('RCD catalog does not match a P11 device entity.');
      }
      final boardFeedsRcd = state.graph.connections.any((connection) =>
          connection.fromComponentId == assignment.boardComponentId &&
          connection.toComponentId == deviceId);
      if (!boardFeedsRcd) {
        throw ArgumentError('Group RCD has no P11 board feed.');
      }
      for (final id in assignment.protectedCircuitIds) {
        final selected = selections.byCircuit[id];
        if (selected == null ||
            selected.protectionRatings.deviceKind.trim().toLowerCase() !=
                'mcb' ||
            !assignment.matches(selected)) {
          throw ArgumentError('Group RCD references unrelated P11 MCB.');
        }
        final pins = selected.sources.map((s) => s.sourceId).toSet();
        if (!pins.contains(assignment.evidenceSourceId)) {
          throw ArgumentError('Group RCD proof is not pinned by selection.');
        }
        final circuits = state.circuits.where((c) => c.id == id).toList();
        final boards = state.graph.components
            .where((c) => c.id == assignment.boardComponentId)
            .toList();
        if (circuits.length != 1 || boards.length != 1) {
          throw ArgumentError('Group RCD references missing P11 topology.');
        }
        final activeConnections = state.graph.connections.where(
          (connection) => circuits.single.connectionIds.contains(connection.id),
        ).toList();
        final downstream = activeConnections
            .where((connection) =>
                connection.fromComponentId == deviceId &&
                connection.toComponentId != assignment.boardComponentId)
            .map((connection) => connection.toComponentId)
            .toSet();
        // Traverse this circuit while deliberately excluding the RCD.
        // Every protected load must be unreachable from the board by any
        // alternative feed path, including indirect board->junction->load.
        final reachable = <ComponentId>{assignment.boardComponentId};
        var changed = true;
        while (changed) {
          changed = false;
          for (final connection in activeConnections) {
            if (connection.toComponentId == deviceId ||
                connection.fromComponentId == deviceId) {
              continue;
            }
            if (reachable.contains(connection.fromComponentId) &&
                reachable.add(connection.toComponentId)) {
              changed = true;
            }
          }
        }
        if (downstream.isEmpty || downstream.any(reachable.contains)) {
          throw ArgumentError('P11 circuit bypasses its assigned group RCD.');
        }
      }
    }
  }
}
