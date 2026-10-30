import 'dart:convert';

import 'canonical_engineering_graph.dart';
import 'engineering_circuit_topology.dart';
import 'engineering_extension.dart';
import 'engineering_graph_semantics.dart';
import 'engineering_graph_validation.dart';
import 'engineering_supply_topology.dart';
import 'project_identity.dart';
import 'semantic_sha256.dart';

/// One project-owned authoritative P11 engineering state.
///
/// The state owns canonical graph entities plus the logical circuit/loop/group
/// and supply declarations that cannot be reconstructed from the graph alone.
/// [CanonicalEngineeringTopology] and [CanonicalEngineeringSupplyTopology] are
/// validated views over this state and never become parallel project stores.
final class EngineeringProjectState {
  EngineeringProjectState({
    required this.graph,
    Iterable<EngineeringCircuit> circuits = const [],
    Iterable<EngineeringLoop> loops = const [],
    Iterable<EngineeringGroup> groups = const [],
    Iterable<EngineeringSupplySource> sources = const [],
    Iterable<EngineeringCircuitSupply> circuitSupplies = const [],
    Iterable<EngineeringExtensionContract> extensionContracts = const [],
    this.compatibilityProfile,
    this.classificationVocabularyVersion = 'p11.v1',
    Iterable<ServiceEntryId>? knownServiceEntryIds,
  })  : circuits = List.unmodifiable(
          circuits.toList()
            ..sort((left, right) => left.id.value.compareTo(right.id.value)),
        ),
        loops = List.unmodifiable(
          loops.toList()
            ..sort((left, right) => left.id.value.compareTo(right.id.value)),
        ),
        groups = List.unmodifiable(
          groups.toList()
            ..sort((left, right) => left.id.value.compareTo(right.id.value)),
        ),
        sources = List.unmodifiable(
          sources.toList()
            ..sort((left, right) => left.id.value.compareTo(right.id.value)),
        ),
        circuitSupplies = List.unmodifiable(
          circuitSupplies.toList()
            ..sort(
              (left, right) =>
                  left.circuitId.value.compareTo(right.circuitId.value),
            ),
        ),
        extensionContracts = List.unmodifiable(
          extensionContracts.toList()
            ..sort((left, right) {
              final byId = left.id.compareTo(right.id);
              if (byId != 0) return byId;
              return left.version.compareTo(right.version);
            }),
        ) {
    if (classificationVocabularyVersion.trim().isEmpty) {
      throw ArgumentError.value(
        classificationVocabularyVersion,
        'classificationVocabularyVersion',
        'Must be non-empty.',
      );
    }

    topology = CanonicalEngineeringTopology(
      graph: graph,
      circuits: this.circuits,
      loops: this.loops,
      groups: this.groups,
    );

    final extensionRegistry = EngineeringExtensionRegistry(
      this.extensionContracts,
    );
    extensionRegistry.validateGraph(graph).requireValid();

    EngineeringGraphInvariantValidator.validate(
      graph: graph,
      topology: topology,
      compatibilityProfile: compatibilityProfile,
      options: EngineeringGraphValidationOptions(
        requireCompatibilityRule: compatibilityProfile != null,
        requireResolvedCircuitIds: true,
      ),
    ).requireValid();

    final internalKnownEntries = knownServiceEntryIds ??
        this
            .sources
            .map((source) => source.serviceEntryId)
            .whereType<ServiceEntryId>();
    supplyTopology = CanonicalEngineeringSupplyTopology(
      topology: topology,
      sources: this.sources,
      circuitSupplies: this.circuitSupplies,
      knownServiceEntryIds: internalKnownEntries,
    );
  }

  factory EngineeringProjectState.empty() => EngineeringProjectState(
        graph: CanonicalEngineeringGraph(components: const []),
      );

  final CanonicalEngineeringGraph graph;
  final List<EngineeringCircuit> circuits;
  final List<EngineeringLoop> loops;
  final List<EngineeringGroup> groups;
  final List<EngineeringSupplySource> sources;
  final List<EngineeringCircuitSupply> circuitSupplies;
  final List<EngineeringExtensionContract> extensionContracts;
  final EngineeringCompatibilityProfile? compatibilityProfile;
  final String classificationVocabularyVersion;

  late final CanonicalEngineeringTopology topology;
  late final CanonicalEngineeringSupplyTopology supplyTopology;

  bool get isEmpty =>
      graph.components.isEmpty &&
      graph.connections.isEmpty &&
      circuits.isEmpty &&
      loops.isEmpty &&
      groups.isEmpty &&
      sources.isEmpty &&
      circuitSupplies.isEmpty &&
      extensionContracts.isEmpty &&
      compatibilityProfile == null;

  /// Validates non-owning links from P11 supply sources to P10 service entries.
  ///
  /// The project aggregate supplies the authoritative P10 ids. They are never
  /// copied into this state as owned entities.
  void requireKnownServiceEntries(
      Iterable<ServiceEntryId> knownServiceEntryIds) {
    final known = knownServiceEntryIds.toSet();
    for (final source in sources) {
      final serviceEntryId = source.serviceEntryId;
      if (serviceEntryId != null && !known.contains(serviceEntryId)) {
        throw ArgumentError(
          'Supply source ${source.id} references unknown project service entry '
          '$serviceEntryId.',
        );
      }
    }
  }

  Map<String, Object?> toCanonicalJson() => {
        'schemaVersion': 1,
        'classificationVocabularyVersion': classificationVocabularyVersion,
        'graph': engineeringGraphCanonicalJson(graph),
        'circuits': [for (final circuit in circuits) _circuitJson(circuit)],
        'loops': [for (final loop in loops) _loopJson(loop)],
        'groups': [for (final group in groups) _groupJson(group)],
        'sources': [for (final source in sources) _sourceJson(source)],
        'circuitSupplies': [
          for (final supply in circuitSupplies) _circuitSupplyJson(supply),
        ],
        'extensionContracts': [
          for (final contract in extensionContracts) _extensionJson(contract),
        ],
        'compatibilityProfile': compatibilityProfile == null
            ? null
            : _compatibilityJson(compatibilityProfile!),
      };

  String get fingerprint => semanticSha256Hex(jsonEncode(toCanonicalJson()));

  bool sameAs(EngineeringProjectState other) =>
      fingerprint == other.fingerprint;
}

Map<String, Object?> _circuitJson(EngineeringCircuit circuit) => {
      'id': circuit.id.value,
      'systemClass': circuit.systemClass.name,
      'systemKey': circuit.systemKey.id,
      'media': circuit.media?.id,
      'connectionIds': circuit.connectionIds.map((id) => id.value).toList()
        ..sort(),
    };

Map<String, Object?> _loopJson(EngineeringLoop loop) => {
      'id': loop.id.value,
      'systemClass': loop.systemClass.name,
      'systemKey': loop.systemKey.id,
      'media': loop.media?.id,
      'circuitId': loop.circuitId?.value,
      // Loop order is canonical engineering semantics and must not be sorted.
      'connectionIds': loop.connectionIds.map((id) => id.value).toList(),
    };

Map<String, Object?> _groupJson(EngineeringGroup group) => {
      'id': group.id.value,
      'semanticTypeId': group.semanticTypeId,
      'componentIds': group.componentIds.map((id) => id.value).toList()..sort(),
      'connectionIds': group.connectionIds.map((id) => id.value).toList()
        ..sort(),
      'circuitIds': group.circuitIds.map((id) => id.value).toList()..sort(),
      'loopIds': group.loopIds.map((id) => id.value).toList()..sort(),
    };

Map<String, Object?> _sourceJson(EngineeringSupplySource source) => {
      'id': source.id.value,
      'componentId': source.endpoint.componentId.value,
      'portId': source.endpoint.portId.value,
      'systemClass': source.systemClass.name,
      'systemKey': source.systemKey.id,
      'role': source.role.id,
      'media': source.media?.id,
      'serviceEntryId': source.serviceEntryId?.value,
    };

Map<String, Object?> _circuitSupplyJson(EngineeringCircuitSupply supply) => {
      'circuitId': supply.circuitId.value,
      'sourceIds': supply.sourceIds.map((id) => id.value).toList()..sort(),
    };

Map<String, Object?> _extensionJson(EngineeringExtensionContract contract) => {
      'id': contract.id,
      'version': contract.version,
      'disciplines': [
        for (final definition
            in contract.disciplines.toList()
              ..sort((left, right) => left.key.id.compareTo(right.key.id)))
          {
            'key': definition.key.id,
            'legacyFamily': definition.legacyFamily.name,
          },
      ],
      'systems': [
        for (final definition
            in contract.systems.toList()
              ..sort((left, right) => left.key.id.compareTo(right.key.id)))
          {
            'key': definition.key.id,
            'disciplineKey': definition.disciplineKey.id,
            'legacySystemFamily': definition.legacySystemFamily.name,
            'media': definition.media.map((value) => value.id).toList()..sort(),
            'portCapabilities':
                definition.portCapabilities.map((value) => value.id).toList()
                  ..sort(),
          },
      ],
    };

Map<String, Object?> _compatibilityJson(
  EngineeringCompatibilityProfile profile,
) =>
    {
      'id': profile.id,
      'revision': profile.revision,
      'rules': [
        for (final rule in profile.rules)
          {
            'id': rule.id,
            'fromSystemClass': rule.fromSystemClass.name,
            'fromSystemKey': rule.fromSystemKey.id,
            'toSystemClass': rule.toSystemClass.name,
            'toSystemKey': rule.toSystemKey.id,
            'connectionSystemClass': rule.connectionSystemClass.name,
            'connectionSystemKey': rule.connectionSystemKey.id,
            'connectionType': rule.connectionType.name,
            'media': rule.media?.id,
            'allowUnspecifiedMedia': rule.allowUnspecifiedMedia,
          },
      ],
    };
