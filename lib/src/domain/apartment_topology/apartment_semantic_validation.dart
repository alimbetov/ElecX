import 'apartment_topology_draft.dart';

final class SemanticSpacePair {
  SemanticSpacePair(String leftKey, String rightKey)
      : leftKey = leftKey.compareTo(rightKey) <= 0 ? leftKey : rightKey,
        rightKey = leftKey.compareTo(rightKey) <= 0 ? rightKey : leftKey;

  final String leftKey;
  final String rightKey;

  String get stableKey => '$leftKey|$rightKey';
}

final class P9SemanticViolation {
  P9SemanticViolation({
    required this.code,
    required this.ruleId,
    Iterable<String> affectedKeys = const [],
    Map<String, Object?> facts = const {},
  })  : affectedKeys = List.unmodifiable(affectedKeys.toList()..sort()),
        facts = Map.unmodifiable(facts);

  final String code;
  final String ruleId;
  final List<String> affectedKeys;
  final Map<String, Object?> facts;

  String get stableKey => '$code|$ruleId|${affectedKeys.join(',')}';
}

final class P9SemanticPreferenceMiss {
  P9SemanticPreferenceMiss({
    required this.ruleId,
    required this.penaltyBp,
    Iterable<String> affectedKeys = const [],
  }) : affectedKeys = List.unmodifiable(affectedKeys.toList()..sort());

  final String ruleId;
  final int penaltyBp;
  final List<String> affectedKeys;

  String get stableKey => '$ruleId|${affectedKeys.join(',')}';
}

final class TopologySemanticMetrics {
  const TopologySemanticMetrics({
    required this.entryReachableSpaceCount,
    required this.maxAccessDepth,
    required this.privateTransitViolations,
    required this.circulationNodeCount,
    required this.requiredRulePassCount,
    required this.preferredRuleMisses,
    required this.wetCoreGroupCount,
  });

  final int entryReachableSpaceCount;
  final int maxAccessDepth;
  final int privateTransitViolations;
  final int circulationNodeCount;
  final int requiredRulePassCount;
  final int preferredRuleMisses;
  final int wetCoreGroupCount;
}

final class SemanticAccessIntent {
  SemanticAccessIntent({
    required String fromSpaceKey,
    required String toSpaceKey,
    required this.kind,
  }) : pair = SemanticSpacePair(fromSpaceKey, toSpaceKey);

  final SemanticSpacePair pair;
  final DraftAccessKind kind;
}

/// Typed semantic constraints handed to P9.6. Geometry must realize this
/// contract instead of inferring topology from labels or presentation state.
final class TopologyGeometryHandoff {
  TopologyGeometryHandoff({
    Iterable<SemanticSpacePair> requiredSharedBoundaryPairs = const [],
    Iterable<SemanticSpacePair> forbiddenSharedBoundaryPairs = const [],
    Iterable<String> requiredExteriorSpaceKeys = const [],
    Iterable<Iterable<String>> wetCoreGroups = const [],
    Iterable<SemanticAccessIntent> accessIntents = const [],
    Iterable<String> circulationAnchorKeys = const [],
  })  : requiredSharedBoundaryPairs = List.unmodifiable(
          requiredSharedBoundaryPairs.toList()
            ..sort((a, b) => a.stableKey.compareTo(b.stableKey)),
        ),
        forbiddenSharedBoundaryPairs = List.unmodifiable(
          forbiddenSharedBoundaryPairs.toList()
            ..sort((a, b) => a.stableKey.compareTo(b.stableKey)),
        ),
        requiredExteriorSpaceKeys = List.unmodifiable(
          requiredExteriorSpaceKeys.toSet().toList()..sort(),
        ),
        wetCoreGroups = List.unmodifiable(
          wetCoreGroups
              .map((group) => List<String>.unmodifiable(group.toList()..sort()))
              .toList()
            ..sort((a, b) => a.join('|').compareTo(b.join('|'))),
        ),
        accessIntents = List.unmodifiable(
          accessIntents.toList()
            ..sort((a, b) {
              final pair = a.pair.stableKey.compareTo(b.pair.stableKey);
              return pair != 0 ? pair : a.kind.name.compareTo(b.kind.name);
            }),
        ),
        circulationAnchorKeys = List.unmodifiable(
          circulationAnchorKeys.toSet().toList()..sort(),
        );

  final List<SemanticSpacePair> requiredSharedBoundaryPairs;
  final List<SemanticSpacePair> forbiddenSharedBoundaryPairs;
  final List<String> requiredExteriorSpaceKeys;
  final List<List<String>> wetCoreGroups;
  final List<SemanticAccessIntent> accessIntents;
  final List<String> circulationAnchorKeys;
}

final class TopologySemanticValidation {
  TopologySemanticValidation({
    required Iterable<P9SemanticViolation> blockers,
    required Iterable<P9SemanticPreferenceMiss> preferenceMisses,
    required this.metrics,
    required this.geometryHandoff,
  })  : blockers = List.unmodifiable(
          blockers.toList()..sort((a, b) => a.stableKey.compareTo(b.stableKey)),
        ),
        preferenceMisses = List.unmodifiable(
          preferenceMisses.toList()
            ..sort((a, b) => a.stableKey.compareTo(b.stableKey)),
        );

  final List<P9SemanticViolation> blockers;
  final List<P9SemanticPreferenceMiss> preferenceMisses;
  final TopologySemanticMetrics metrics;
  final TopologyGeometryHandoff geometryHandoff;

  bool get accepted => blockers.isEmpty;
}
