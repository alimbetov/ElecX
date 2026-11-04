import 'dart:convert';

import '../domain/component_catalog_engineering_metadata.dart';
import '../domain/component_placement.dart';
import '../domain/engineering_graph.dart';
import '../domain/power_board_catalog_qualification.dart';
import '../domain/power_starter_generation.dart';
import '../domain/semantic_sha256.dart';

const String powerBoardCatalogQualificationVersion = 'p12.board-catalog.v1';

/// Qualifies an explicit board type against the pinned catalog snapshot.
///
/// The registry and its snapshot identifier must come from the same trusted
/// upstream catalog source. Merely passing a string identifier does not
/// constitute cryptographic snapshot attestation. Missing facts fail closed.
abstract final class PowerStarterBoardCatalogEngine {
  static PowerBoardCatalogQualification qualify({
    required PowerStarterCandidate candidate,
    required String catalogSnapshotId,
    required ComponentCatalogEngineeringRegistry registry,
    required String componentTypeId,
    required EngineeringConnectionType connectionType,
    required ComponentHostKind hostKind,
  }) {
    if (catalogSnapshotId.trim().isEmpty ||
        componentTypeId.trim().isEmpty) {
      throw ArgumentError(
        'Board catalog identity and snapshot must be non-empty.',
      );
    }

    final record = registry.find(componentTypeId);
    final status = _status(
      candidate: candidate,
      catalogSnapshotId: catalogSnapshotId,
      record: record,
      connectionType: connectionType,
      hostKind: hostKind,
    );
    final selected =
        status == PowerBoardCatalogStatus.qualifiedForPreview ? record : null;
    final source = selected?.metadata.source;
    final envelope = selected?.metadata.physicalEnvelope;
    final ports = selected?.entry.ports.toList()
      ?..sort((a, b) => a.id.compareTo(b.id));
    final fingerprint = semanticSha256Hex(jsonEncode([
      powerBoardCatalogQualificationVersion,
      candidate.fingerprint,
      candidate.catalogSnapshotId,
      catalogSnapshotId,
      componentTypeId,
      connectionType.name,
      hostKind.name,
      status.name,
      if (source != null)
        [
          source.manufacturer,
          source.model,
          source.revision,
          source.sourceUri,
          source.verifiedAtIso8601,
        ],
      if (envelope != null)
        [
          envelope.widthMm,
          envelope.heightMm,
          envelope.depthMm,
          envelope.massGrams,
        ],
      if (ports != null)
        [
          for (final port in ports)
            [
              port.id,
              port.direction.name,
              port.allowedConnections.map((type) => type.name).toList()
                ..sort(),
            ],
        ],
    ]));

    return PowerBoardCatalogQualification(
      candidate: candidate,
      status: status,
      fingerprint: fingerprint,
      requestedComponentTypeId: componentTypeId,
      record: selected,
    );
  }

  static PowerBoardCatalogStatus _status({
    required PowerStarterCandidate candidate,
    required String catalogSnapshotId,
    required ComponentCatalogEngineeringRecord? record,
    required EngineeringConnectionType connectionType,
    required ComponentHostKind hostKind,
  }) {
    if (candidate.catalogSnapshotId != catalogSnapshotId) {
      return PowerBoardCatalogStatus.snapshotMismatch;
    }
    if (record == null) return PowerBoardCatalogStatus.componentMissing;

    final entry = record.entry;
    if (entry.discipline != EngineeringDiscipline.power ||
        entry.systemClass != EngineeringSystemClass.powerAc ||
        !record.supports(
          systemClass: EngineeringSystemClass.powerAc,
          connectionType: connectionType,
          hostKind: hostKind,
          requireAutoConfigurationReady: false,
        )) {
      return PowerBoardCatalogStatus.incompatible;
    }

    // Not every POWER component is a distribution board: the exact catalog
    // type must expose both an AC supply input and a circuit-feeding output.
    final hasSupplyInput = entry.ports.any(
      (port) =>
          port.direction == EngineeringPortDirection.input &&
          port.accepts(connectionType),
    );
    final hasCircuitOutput = entry.ports.any(
      (port) =>
          port.direction == EngineeringPortDirection.output &&
          port.accepts(connectionType),
    );
    if (!hasSupplyInput || !hasCircuitOutput) {
      return PowerBoardCatalogStatus.incompatible;
    }

    if (!record.metadata.isAutoConfigurationReady) {
      return PowerBoardCatalogStatus.missingSourceFacts;
    }
    return PowerBoardCatalogStatus.qualifiedForPreview;
  }
}
