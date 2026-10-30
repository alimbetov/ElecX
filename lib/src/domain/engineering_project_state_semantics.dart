import 'dart:convert';

import 'engineering_graph_semantics.dart';
import 'engineering_project_state.dart';

/// Deterministic semantic diff for the complete project-owned P11 state.
///
/// Graph entity changes reuse [EngineeringGraphDiff]. The remaining P11
/// abstractions are compared through the same canonical JSON that drives the
/// aggregate fingerprint, so loop order, supply roles, dependency relations,
/// extension/profile revisions and vocabulary changes cannot disappear from
/// impact qualification.
final class EngineeringProjectStateDiff {
  const EngineeringProjectStateDiff({
    required this.graph,
    required this.circuits,
    required this.loops,
    required this.groups,
    required this.sources,
    required this.circuitSupplies,
    required this.extensionContracts,
    required this.dependencyRelations,
    required this.compatibilityProfileChanged,
    required this.classificationVocabularyChanged,
  });

  final EngineeringGraphDiff graph;
  final EngineeringSemanticEntityDiff circuits;
  final EngineeringSemanticEntityDiff loops;
  final EngineeringSemanticEntityDiff groups;
  final EngineeringSemanticEntityDiff sources;
  final EngineeringSemanticEntityDiff circuitSupplies;
  final EngineeringSemanticEntityDiff extensionContracts;
  final EngineeringSemanticEntityDiff dependencyRelations;
  final bool compatibilityProfileChanged;
  final bool classificationVocabularyChanged;

  bool get isEmpty =>
      graph.isEmpty &&
      circuits.isEmpty &&
      loops.isEmpty &&
      groups.isEmpty &&
      sources.isEmpty &&
      circuitSupplies.isEmpty &&
      extensionContracts.isEmpty &&
      dependencyRelations.isEmpty &&
      !compatibilityProfileChanged &&
      !classificationVocabularyChanged;

  factory EngineeringProjectStateDiff.between(
    EngineeringProjectState before,
    EngineeringProjectState after,
  ) {
    final beforeJson = before.toCanonicalJson();
    final afterJson = after.toCanonicalJson();
    return EngineeringProjectStateDiff(
      graph: EngineeringGraphDiff.between(before.graph, after.graph),
      circuits: _entities(beforeJson, afterJson, 'circuits', 'id'),
      loops: _entities(beforeJson, afterJson, 'loops', 'id'),
      groups: _entities(beforeJson, afterJson, 'groups', 'id'),
      sources: _entities(beforeJson, afterJson, 'sources', 'id'),
      circuitSupplies:
          _entities(beforeJson, afterJson, 'circuitSupplies', 'circuitId'),
      extensionContracts:
          _entities(beforeJson, afterJson, 'extensionContracts', 'id'),
      dependencyRelations: _entities(
        beforeJson,
        afterJson,
        'dependencyRelations',
        'semanticTypeId',
      ),
      compatibilityProfileChanged: !_sameCanonical(
        beforeJson['compatibilityProfile'],
        afterJson['compatibilityProfile'],
      ),
      classificationVocabularyChanged:
          before.classificationVocabularyVersion !=
              after.classificationVocabularyVersion,
    );
  }
}

final class EngineeringSemanticEntityDiff {
  const EngineeringSemanticEntityDiff({
    required this.added,
    required this.removed,
    required this.changed,
  });

  final List<String> added;
  final List<String> removed;
  final List<String> changed;

  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;
}

EngineeringSemanticEntityDiff _entities(
  Map<String, Object?> before,
  Map<String, Object?> after,
  String collectionKey,
  String idKey,
) {
  final beforeById = _byId(before[collectionKey], idKey);
  final afterById = _byId(after[collectionKey], idKey);
  final added = afterById.keys.where((id) => !beforeById.containsKey(id)).toList()
    ..sort();
  final removed =
      beforeById.keys.where((id) => !afterById.containsKey(id)).toList()..sort();
  final changed = beforeById.keys
      .where(afterById.containsKey)
      .where((id) => !_sameCanonical(beforeById[id], afterById[id]))
      .toList()
    ..sort();
  return EngineeringSemanticEntityDiff(
    added: List.unmodifiable(added),
    removed: List.unmodifiable(removed),
    changed: List.unmodifiable(changed),
  );
}

Map<String, Object?> _byId(Object? raw, String idKey) {
  final values = raw as List<Object?>;
  final result = <String, Object?>{};
  for (final rawValue in values) {
    final value = rawValue as Map<String, Object?>;
    final id = value[idKey] as String;
    if (result.containsKey(id)) {
      throw StateError('Duplicate canonical engineering semantic id $id.');
    }
    result[id] = value;
  }
  return result;
}

bool _sameCanonical(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);
