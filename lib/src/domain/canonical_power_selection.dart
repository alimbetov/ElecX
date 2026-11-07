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

final class CanonicalCableElectricalRatings {
  CanonicalCableElectricalRatings({
    required this.conductorCrossSectionMm2,
    required this.conductorCount,
    required this.ratedVoltageV,
    required this.governingAmpacityA,
    required this.calculatedVoltageDropRatio,
  }) {
    _positive(conductorCrossSectionMm2, 'conductorCrossSectionMm2');
    if (conductorCount <= 0) {
      throw ArgumentError.value(conductorCount, 'conductorCount');
    }
    _positive(ratedVoltageV, 'ratedVoltageV');
    _positive(governingAmpacityA, 'governingAmpacityA');
    if (!calculatedVoltageDropRatio.isFinite ||
        calculatedVoltageDropRatio < 0 ||
        calculatedVoltageDropRatio >= 1) {
      throw ArgumentError.value(
          calculatedVoltageDropRatio, 'calculatedVoltageDropRatio');
    }
  }

  final double conductorCrossSectionMm2;
  final int conductorCount;
  final double ratedVoltageV;
  final double governingAmpacityA;
  final double calculatedVoltageDropRatio;

  Map<String, Object?> toCanonicalJson() => {
        'conductorCrossSectionMm2': conductorCrossSectionMm2,
        'conductorCount': conductorCount,
        'ratedVoltageV': ratedVoltageV,
        'governingAmpacityA': governingAmpacityA,
        'calculatedVoltageDropRatio': calculatedVoltageDropRatio,
      };

  factory CanonicalCableElectricalRatings.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {
      'conductorCrossSectionMm2', 'conductorCount', 'ratedVoltageV',
      'governingAmpacityA', 'calculatedVoltageDropRatio',
    });
    final count = json['conductorCount'];
    if (count is! int) {
      throw const FormatException('Invalid cable conductor count.');
    }
    return CanonicalCableElectricalRatings(
      conductorCrossSectionMm2: _number(json['conductorCrossSectionMm2']),
      conductorCount: count,
      ratedVoltageV: _number(json['ratedVoltageV']),
      governingAmpacityA: _number(json['governingAmpacityA']),
      calculatedVoltageDropRatio:
          _number(json['calculatedVoltageDropRatio']),
    );
  }
}

final class CanonicalProtectionElectricalRatings {
  CanonicalProtectionElectricalRatings({
    required this.ratedCurrentA,
    required this.breakingCapacityKa,
    required this.poleCount,
    required this.deviceKind,
    required this.tripCharacteristic,
  }) {
    _positive(ratedCurrentA, 'ratedCurrentA');
    _positive(breakingCapacityKa, 'breakingCapacityKa');
    if (poleCount <= 0) {
      throw ArgumentError.value(poleCount, 'poleCount');
    }
    _required(deviceKind, 'deviceKind');
    _required(tripCharacteristic, 'tripCharacteristic');
  }

  final double ratedCurrentA;
  final double breakingCapacityKa;
  final int poleCount;
  final String deviceKind;
  final String tripCharacteristic;

  Map<String, Object?> toCanonicalJson() => {
        'ratedCurrentA': ratedCurrentA,
        'breakingCapacityKa': breakingCapacityKa,
        'poleCount': poleCount,
        'deviceKind': deviceKind,
        'tripCharacteristic': tripCharacteristic,
      };

  factory CanonicalProtectionElectricalRatings.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {
      'ratedCurrentA', 'breakingCapacityKa', 'poleCount',
      'deviceKind', 'tripCharacteristic',
    });
    final poles = json['poleCount'];
    if (poles is! int) {
      throw const FormatException('Invalid protection pole count.');
    }
    return CanonicalProtectionElectricalRatings(
      ratedCurrentA: _number(json['ratedCurrentA']),
      breakingCapacityKa: _number(json['breakingCapacityKa']),
      poleCount: poles,
      deviceKind: _string(json['deviceKind']),
      tripCharacteristic: _string(json['tripCharacteristic']),
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
    required this.catalogSnapshotId,
    required this.boardRatings,
    required this.cableCatalogId,
    required this.cableRatings,
    required this.cableSourceId,
    required this.protectionCatalogId,
    required this.protectionRatings,
    required this.protectionSourceId,
    required this.routeLengthMm,
    required this.evidenceFingerprint,
    required Iterable<CanonicalEngineeringSourceReference> sources,
  }) : sources = List.unmodifiable(
          sources.toList()..sort((a, b) => a.sourceId.compareTo(b.sourceId)),
        ) {
    for (final field in [
      generationKey, boardCatalogTypeId, catalogSnapshotId,
      cableCatalogId, cableSourceId,
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
  final String catalogSnapshotId;
  final CanonicalBoardElectricalRatings boardRatings;
  final String cableCatalogId;
  final CanonicalCableElectricalRatings cableRatings;
  final String cableSourceId;
  final String protectionCatalogId;
  final CanonicalProtectionElectricalRatings protectionRatings;
  final String protectionSourceId;
  final double routeLengthMm;
  final String evidenceFingerprint;
  final List<CanonicalEngineeringSourceReference> sources;

  Map<String, Object?> toCanonicalJson() => {
        'circuitId': circuitId.value,
        'generationKey': generationKey,
        'boardComponentId': boardComponentId.value,
        'boardCatalogTypeId': boardCatalogTypeId,
        'catalogSnapshotId': catalogSnapshotId,
        'boardRatings': boardRatings.toCanonicalJson(),
        'cableCatalogId': cableCatalogId,
        'cableRatings': cableRatings.toCanonicalJson(),
        'cableSourceId': cableSourceId,
        'protectionCatalogId': protectionCatalogId,
        'protectionRatings': protectionRatings.toCanonicalJson(),
        'protectionSourceId': protectionSourceId,
        'routeLengthMm': routeLengthMm,
        'evidenceFingerprint': evidenceFingerprint,
        'sources': [for (final source in sources) source.toCanonicalJson()],
      };

  factory CanonicalPowerCircuitSelection.fromCanonicalJson(Object? raw) {
    final json = _map(raw, const {
      'circuitId', 'generationKey', 'boardComponentId', 'boardCatalogTypeId',
      'catalogSnapshotId', 'boardRatings', 'cableCatalogId',
      'cableRatings', 'cableSourceId',
      'protectionCatalogId', 'protectionRatings', 'protectionSourceId', 'routeLengthMm',
      'evidenceFingerprint', 'sources',
    });
    return CanonicalPowerCircuitSelection(
      circuitId: CircuitId(_string(json['circuitId'])),
      generationKey: _string(json['generationKey']),
      boardComponentId: ComponentId(_string(json['boardComponentId'])),
      boardCatalogTypeId: _string(json['boardCatalogTypeId']),
      catalogSnapshotId: _string(json['catalogSnapshotId']),
      boardRatings:
          CanonicalBoardElectricalRatings.fromCanonicalJson(json['boardRatings']),
      cableCatalogId: _string(json['cableCatalogId']),
      cableRatings:
          CanonicalCableElectricalRatings.fromCanonicalJson(json['cableRatings']),
      cableSourceId: _string(json['cableSourceId']),
      protectionCatalogId: _string(json['protectionCatalogId']),
      protectionRatings: CanonicalProtectionElectricalRatings.fromCanonicalJson(
          json['protectionRatings']),
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
