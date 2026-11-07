import 'dart:convert';

import 'project_identity.dart';
import 'semantic_sha256.dart';

/// P12A.8 canonical selection schema. This data is design evidence, not a
/// declaration that equipment complies with a jurisdiction's safety rules.
const int canonicalPowerSelectionSchemaVersion = 1;

final class CanonicalEngineeringSourceReference {
  CanonicalEngineeringSourceReference({
    required this.sourceId,
    required this.revision,
    required this.sha256,
    required this.approvalId,
  }) {
    _required(sourceId, 'sourceId');
    _required(revision, 'revision');
    _required(approvalId, 'approvalId');
    _digest(sha256, 'sha256');
  }

  final String sourceId;
  final String revision;
  final String sha256;
  final String approvalId;

  Map<String, Object?> toCanonicalJson() => {
        'sourceId': sourceId,
        'revision': revision,
        'sha256': sha256,
        'approvalId': approvalId,
      };

  factory CanonicalEngineeringSourceReference.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {
      'sourceId', 'revision', 'sha256', 'approvalId',
    });
    return CanonicalEngineeringSourceReference(
      sourceId: _string(json['sourceId']),
      revision: _string(json['revision']),
      sha256: _string(json['sha256']),
      approvalId: _string(json['approvalId']),
    );
  }
}

/// All four ratings are factual catalog/manufacturer evidence, never defaults.
final class CanonicalBoardElectricalRatings {
  CanonicalBoardElectricalRatings({
    required this.ratedBusbarCurrentA,
    required this.shortCircuitWithstandKa,
    required this.ratedVoltageV,
    required this.ipRating,
    required this.manufacturerSourceId,
  }) {
    _positive(ratedBusbarCurrentA, 'ratedBusbarCurrentA');
    _positive(shortCircuitWithstandKa, 'shortCircuitWithstandKa');
    _positive(ratedVoltageV, 'ratedVoltageV');
    _required(ipRating, 'ipRating');
    _required(manufacturerSourceId, 'manufacturerSourceId');
  }

  final double ratedBusbarCurrentA;
  final double shortCircuitWithstandKa;
  final double ratedVoltageV;
  final String ipRating;
  final String manufacturerSourceId;

  Map<String, Object?> toCanonicalJson() => {
        'ratedBusbarCurrentA': ratedBusbarCurrentA,
        'shortCircuitWithstandKa': shortCircuitWithstandKa,
        'ratedVoltageV': ratedVoltageV,
        'ipRating': ipRating,
        'manufacturerSourceId': manufacturerSourceId,
      };

  factory CanonicalBoardElectricalRatings.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {
      'ratedBusbarCurrentA', 'shortCircuitWithstandKa', 'ratedVoltageV',
      'ipRating', 'manufacturerSourceId',
    });
    return CanonicalBoardElectricalRatings(
      ratedBusbarCurrentA: _number(json['ratedBusbarCurrentA']),
      shortCircuitWithstandKa: _number(json['shortCircuitWithstandKa']),
      ratedVoltageV: _number(json['ratedVoltageV']),
      ipRating: _string(json['ipRating']),
      manufacturerSourceId: _string(json['manufacturerSourceId']),
    );
  }
}

/// One complete, losslessly persisted POWER circuit selection, keyed by the
/// existing authoritative P11 CircuitId. Catalog keys do not replace IDs.
final class CanonicalPowerCircuitSelection {
  CanonicalPowerCircuitSelection({
    required this.circuitId,
    required this.generationKey,
    required this.boardComponentId,
    required this.boardCatalogTypeId,
    required this.boardRatings,
    required this.cableCatalogId,
    required this.cableSourceId,
    required this.protectionCatalogId,
    required this.protectionSourceId,
    required this.routeLengthMm,
    required this.evidenceFingerprint,
    required Iterable<CanonicalEngineeringSourceReference> sources,
  }) : sources = List.unmodifiable(
          sources.toList()..sort((a, b) => a.sourceId.compareTo(b.sourceId)),
        ) {
    for (final field in [
      generationKey, boardCatalogTypeId, cableCatalogId, cableSourceId,
      protectionCatalogId, protectionSourceId,
    ]) {
      _required(field, 'selection identity');
    }
    _positive(routeLengthMm, 'routeLengthMm');
    _digest(evidenceFingerprint, 'evidenceFingerprint');
    if (this.sources.isEmpty ||
        this.sources.map((s) => s.sourceId).toSet().length !=
            this.sources.length) {
      throw ArgumentError('Selection requires unique, pinned source records.');
    }
    final sourceIds = this.sources.map((s) => s.sourceId).toSet();
    if (!sourceIds.contains(cableSourceId) ||
        !sourceIds.contains(protectionSourceId) ||
        !sourceIds.contains(boardRatings.manufacturerSourceId)) {
      throw ArgumentError('Selected catalog records must have pinned sources.');
    }
  }

  final CircuitId circuitId;
  final String generationKey;
  final ComponentId boardComponentId;
  final String boardCatalogTypeId;
  final CanonicalBoardElectricalRatings boardRatings;
  final String cableCatalogId;
  final String cableSourceId;
  final String protectionCatalogId;
  final String protectionSourceId;
  final double routeLengthMm;
  final String evidenceFingerprint;
  final List<CanonicalEngineeringSourceReference> sources;

  Map<String, Object?> toCanonicalJson() => {
        'circuitId': circuitId.value,
        'generationKey': generationKey,
        'boardComponentId': boardComponentId.value,
        'boardCatalogTypeId': boardCatalogTypeId,
        'boardRatings': boardRatings.toCanonicalJson(),
        'cableCatalogId': cableCatalogId,
        'cableSourceId': cableSourceId,
        'protectionCatalogId': protectionCatalogId,
        'protectionSourceId': protectionSourceId,
        'routeLengthMm': routeLengthMm,
        'evidenceFingerprint': evidenceFingerprint,
        'sources': [for (final source in sources) source.toCanonicalJson()],
      };

  factory CanonicalPowerCircuitSelection.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {
      'circuitId', 'generationKey', 'boardComponentId', 'boardCatalogTypeId',
      'boardRatings', 'cableCatalogId', 'cableSourceId',
      'protectionCatalogId', 'protectionSourceId', 'routeLengthMm',
      'evidenceFingerprint', 'sources',
    });
    return CanonicalPowerCircuitSelection(
      circuitId: CircuitId(_string(json['circuitId'])),
      generationKey: _string(json['generationKey']),
      boardComponentId: ComponentId(_string(json['boardComponentId'])),
      boardCatalogTypeId: _string(json['boardCatalogTypeId']),
      boardRatings:
          CanonicalBoardElectricalRatings.fromCanonicalJson(json['boardRatings']),
      cableCatalogId: _string(json['cableCatalogId']),
      cableSourceId: _string(json['cableSourceId']),
      protectionCatalogId: _string(json['protectionCatalogId']),
      protectionSourceId: _string(json['protectionSourceId']),
      routeLengthMm: _number(json['routeLengthMm']),
      evidenceFingerprint: _string(json['evidenceFingerprint']),
      sources: _list(json['sources'])
          .map(CanonicalEngineeringSourceReference.fromCanonicalJson),
    );
  }
}

/// Project-owned canonical selection data. No independently persisted project
/// or graph; each key references a CircuitId in the P11 engineering state.
final class CanonicalPowerSelectionRegistry {
  const CanonicalPowerSelectionRegistry.empty() : byCircuit = const {};

  CanonicalPowerSelectionRegistry({
    required Iterable<CanonicalPowerCircuitSelection> selections,
  }) : byCircuit = Map.unmodifiable({
          for (final selection in selections) selection.circuitId: selection,
        }) {
    if (byCircuit.length != selections.length) {
      throw ArgumentError('Duplicate canonical POWER circuit selection.');
    }
    final keys = <String>{};
    for (final selection in byCircuit.values) {
      if (!keys.add(selection.generationKey)) {
        throw ArgumentError('Duplicate POWER generation key.');
      }
    }
  }

  final Map<CircuitId, CanonicalPowerCircuitSelection> byCircuit;

  bool get isEmpty => byCircuit.isEmpty;
  String get fingerprint => semanticSha256Hex(jsonEncode(toCanonicalJson()));
  bool sameAs(CanonicalPowerSelectionRegistry other) =>
      fingerprint == other.fingerprint;

  Map<String, Object?> toCanonicalJson() => {
        'schemaVersion': canonicalPowerSelectionSchemaVersion,
        'selections': [
          for (final selection in (byCircuit.values.toList()
            ..sort((a, b) => a.circuitId.value.compareTo(b.circuitId.value))))
            selection.toCanonicalJson(),
        ],
      };

  factory CanonicalPowerSelectionRegistry.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {'schemaVersion', 'selections'});
    if (json['schemaVersion'] != canonicalPowerSelectionSchemaVersion) {
      throw const FormatException('Unsupported POWER selection schema.');
    }
    return CanonicalPowerSelectionRegistry(
      selections: _list(json['selections'])
          .map(CanonicalPowerCircuitSelection.fromCanonicalJson)
          .toList(),
    );
  }
}

Map<String, Object?> _map(Object? raw, Set<String> keys) {
  if (raw is! Map<String, dynamic> ||
      raw.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(raw.keys.toSet()).isNotEmpty) {
    throw const FormatException('Invalid canonical POWER selection object.');
  }
  return Map<String, Object?>.of(raw);
}

List<Object?> _list(Object? raw) {
  if (raw is! List) {
    throw const FormatException('Expected canonical POWER selection list.');
  }
  return List<Object?>.of(raw);
}

String _string(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('Expected non-empty canonical string.');
  }
  return raw;
}

void _required(String value, String key) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, key, 'Must be non-empty.');
  }
}

void _positive(double value, String key) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, key, 'Must be finite and positive.');
  }
}

void _digest(String value, String key) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, key, 'Must be lowercase SHA-256.');
  }
}

double _number(Object? raw) {
  if (raw is! num) {
    throw const FormatException('Expected numeric POWER selection value.');
  }
  return raw.toDouble();
}
