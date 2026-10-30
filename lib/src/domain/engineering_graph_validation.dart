import 'canonical_engineering_graph.dart';
import 'engineering_circuit_topology.dart';
import 'engineering_classification.dart';
import 'engineering_graph.dart';
import 'project_identity.dart';

/// One explicit compatibility contract for a directed logical connection.
///
/// Rules are exact and deterministic. They do not infer compatibility from
/// display names, discipline labels, preferred-connection hints or physical
/// routing. Extensible classification/media keep custom systems outside closed
/// enums while legacy families remain part of the compatibility bridge.
final class EngineeringConnectionCompatibilityRule {
  EngineeringConnectionCompatibilityRule({
    required this.id,
    required this.fromSystemClass,
    required this.toSystemClass,
    required this.connectionSystemClass,
    required this.connectionType,
    EngineeringSystemKey? fromSystemKey,
    EngineeringSystemKey? toSystemKey,
    EngineeringSystemKey? connectionSystemKey,
    this.media,
    this.allowUnspecifiedMedia = false,
  })  : fromSystemKey =
            fromSystemKey ?? EngineeringSystemKey.fromLegacy(fromSystemClass),
        toSystemKey =
            toSystemKey ?? EngineeringSystemKey.fromLegacy(toSystemClass),
        connectionSystemKey = connectionSystemKey ??
            EngineeringSystemKey.fromLegacy(connectionSystemClass) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must be non-empty.');
    }
    if (allowUnspecifiedMedia && media == null) {
      throw ArgumentError(
        'allowUnspecifiedMedia requires an explicit rule medium.',
      );
    }
  }

  final String id;
  final EngineeringSystemClass fromSystemClass;
  final EngineeringSystemKey fromSystemKey;
  final EngineeringSystemClass toSystemClass;
  final EngineeringSystemKey toSystemKey;
  final EngineeringSystemClass connectionSystemClass;
  final EngineeringSystemKey connectionSystemKey;
  final EngineeringConnectionType connectionType;
  final EngineeringMedia? media;

  /// Transitional allowance for a legacy edge that has not yet persisted its
  /// medium. It never permits a different explicit medium.
  final bool allowUnspecifiedMedia;

  bool matches({
    required EngineeringGraphComponent from,
    required EngineeringGraphComponent to,
    required EngineeringGraphConnection connection,
  }) {
    if (from.systemClass != fromSystemClass ||
        from.systemKey != fromSystemKey ||
        to.systemClass != toSystemClass ||
        to.systemKey != toSystemKey ||
        connection.systemClass != connectionSystemClass ||
        connection.systemKey != connectionSystemKey ||
        connection.connectionType != connectionType) {
      return false;
    }

    final expectedMedia = media;
    if (expectedMedia == null) {
      return connection.media == null;
    }
    return connection.media == expectedMedia ||
        (connection.media == null && allowUnspecifiedMedia);
  }

  /// Signature for explicit-media matching. `allowUnspecifiedMedia` is not part
  /// of this key because it does not change matching of an explicit medium.
  String get compatibilityKey => <String>[
        fromSystemClass.name,
        fromSystemKey.id,
        toSystemClass.name,
        toSystemKey.id,
        connectionSystemClass.name,
        connectionSystemKey.id,
        connectionType.name,
        media?.id ?? '<unspecified>',
      ].join('\u0000');

  bool get matchesUnspecifiedMedia => media == null || allowUnspecifiedMedia;

  /// Signature for rules that can match a legacy connection with null media.
  String get unspecifiedMediaCompatibilityKey => <String>[
        fromSystemClass.name,
        fromSystemKey.id,
        toSystemClass.name,
        toSystemKey.id,
        connectionSystemClass.name,
        connectionSystemKey.id,
        connectionType.name,
      ].join('\u0000');
}

/// Versioned explicit compatibility policy supplied by project/catalog/profile
/// configuration. The graph foundation contains no hidden normative defaults.
final class EngineeringCompatibilityProfile {
  EngineeringCompatibilityProfile({
    required this.id,
    required this.revision,
    required Iterable<EngineeringConnectionCompatibilityRule> rules,
  }) : rules = List.unmodifiable(
          rules.toList()..sort((left, right) => left.id.compareTo(right.id)),
        ) {
    if (id.trim().isEmpty || revision.trim().isEmpty) {
      throw ArgumentError(
          'Compatibility profile id/revision must be non-empty.');
    }

    final ids = <String>{};
    final signatures = <String>{};
    final unspecifiedMediaSignatures = <String>{};
    for (final rule in this.rules) {
      if (!ids.add(rule.id)) {
        throw ArgumentError('Duplicate compatibility rule id ${rule.id}.');
      }
      if (!signatures.add(rule.compatibilityKey)) {
        throw ArgumentError(
          'Duplicate compatibility contract for rule ${rule.id}.',
        );
      }
      if (rule.matchesUnspecifiedMedia &&
          !unspecifiedMediaSignatures.add(
            rule.unspecifiedMediaCompatibilityKey,
          )) {
        throw ArgumentError(
          'Ambiguous unspecified-media compatibility for rule ${rule.id}.',
        );
      }
    }
  }

  final String id;
  final String revision;
  final List<EngineeringConnectionCompatibilityRule> rules;

  EngineeringConnectionCompatibilityRule? matchingRule({
    required EngineeringGraphComponent from,
    required EngineeringGraphComponent to,
    required EngineeringGraphConnection connection,
  }) {
    for (final rule in rules) {
      if (rule.matches(from: from, to: to, connection: connection)) {
        return rule;
      }
    }
    return null;
  }
}

/// Controls migration strictness without weakening graph construction itself.
///
/// Defaults preserve pre-P11 persisted projects. Production flows can turn on
/// stricter gates as their persistence/catalog lifecycle becomes authoritative.
final class EngineeringGraphValidationOptions {
  const EngineeringGraphValidationOptions({
    this.requireCompatibilityRule = false,
    this.requireExplicitMedia = false,
    this.requireResolvedCircuitIds = false,
  });

  final bool requireCompatibilityRule;
  final bool requireExplicitMedia;
  final bool requireResolvedCircuitIds;
}

enum EngineeringGraphValidationIssueCode {
  topologyGraphMismatch,
  explicitMediaRequired,
  compatibilityRuleMissing,
  unresolvedCircuit,
}

final class EngineeringGraphValidationIssue {
  const EngineeringGraphValidationIssue({
    required this.code,
    required this.message,
    this.connectionId,
  });

  final EngineeringGraphValidationIssueCode code;
  final String message;
  final EngineeringConnectionId? connectionId;
}

final class EngineeringGraphValidationReport {
  EngineeringGraphValidationReport({
    required Iterable<EngineeringGraphValidationIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<EngineeringGraphValidationIssue> issues;

  bool get isValid => issues.isEmpty;

  void requireValid() {
    if (isValid) return;
    throw StateError(
      issues.map((issue) => '${issue.code.name}: ${issue.message}').join('\n'),
    );
  }
}

/// Cross-object P11 invariant validation layered over the canonical graph.
///
/// Base endpoint existence, direction, legacy connection-type and explicit
/// endpoint-media compatibility already fail during [CanonicalEngineeringGraph]
/// construction. This validator adds policy/system/topology invariants without
/// creating another graph owner.
abstract final class EngineeringGraphInvariantValidator {
  static EngineeringGraphValidationReport validate({
    required CanonicalEngineeringGraph graph,
    EngineeringCompatibilityProfile? compatibilityProfile,
    CanonicalEngineeringTopology? topology,
    EngineeringGraphValidationOptions options =
        const EngineeringGraphValidationOptions(),
  }) {
    final issues = <EngineeringGraphValidationIssue>[];

    if (topology != null && !identical(topology.graph, graph)) {
      issues.add(
        const EngineeringGraphValidationIssue(
          code: EngineeringGraphValidationIssueCode.topologyGraphMismatch,
          message:
              'Topology must be validated against its authoritative graph.',
        ),
      );
    }

    for (final connection in graph.connections) {
      final from = graph.requireComponent(connection.fromComponentId);
      final to = graph.requireComponent(connection.toComponentId);

      if (options.requireExplicitMedia && connection.media == null) {
        issues.add(
          EngineeringGraphValidationIssue(
            code: EngineeringGraphValidationIssueCode.explicitMediaRequired,
            connectionId: connection.id,
            message: 'Connection ${connection.id} has no explicit medium.',
          ),
        );
      }

      if (options.requireCompatibilityRule) {
        final rule = compatibilityProfile?.matchingRule(
          from: from,
          to: to,
          connection: connection,
        );
        if (rule == null) {
          issues.add(
            EngineeringGraphValidationIssue(
              code:
                  EngineeringGraphValidationIssueCode.compatibilityRuleMissing,
              connectionId: connection.id,
              message: 'Connection ${connection.id} is not allowed by the '
                  'active compatibility profile.',
            ),
          );
        }
      }

      if (options.requireResolvedCircuitIds && connection.circuitId != null) {
        final resolved = topology?.circuit(connection.circuitId!);
        if (resolved == null ||
            !resolved.connectionIds.contains(connection.id)) {
          issues.add(
            EngineeringGraphValidationIssue(
              code: EngineeringGraphValidationIssueCode.unresolvedCircuit,
              connectionId: connection.id,
              message: 'Connection ${connection.id} references unresolved '
                  'circuit ${connection.circuitId}.',
            ),
          );
        }
      }
    }

    return EngineeringGraphValidationReport(issues: issues);
  }
}
