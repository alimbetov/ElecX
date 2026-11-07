import '../../application/project/project_snapshot.dart';
import '../../domain/canonical_power_selection.dart';
import '../../domain/project_aggregate.dart';
import 'engineering_state_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// P12A.8 additive canonical schema v21; v1-v20 remain readable.
/// POWER selections are owned by the same ProjectEngineeringMetadata and
/// project repository, never a parallel database or engineering graph.
final class PowerSelectionAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const PowerSelectionAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 21;
  static const _base = EngineeringStateAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final metadata = snapshot.aggregate.engineeringMetadata;
    _validateReferences(snapshot.aggregate);
    // The v20 codec rejects writes that would discard v21-only data. Build an
    // ephemeral projection for its older envelope; the original snapshot and
    // canonical selection registry remain untouched.
    final original = snapshot.aggregate;
    final legacyAggregate = ProjectAggregateRoot(
      id: original.id,
      siteId: original.siteId,
      version: original.version,
      stores: original.stores,
      engineeringMetadata: metadata.withPowerSelections(
        const CanonicalPowerSelectionRegistry.empty(),
      ),
    );
    final base = _base.encode(snapshot.copyWith(aggregate: legacyAggregate));
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...base.payload,
        'powerSelections': metadata.powerSelections.toCanonicalJson(),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException(
          'Unsupported canonical POWER document schema.');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('powerSelections')) {
        throw const FormatException(
          'POWER selections require canonical project schema v21.',
        );
      }
      return _base.decode(document);
    }

    try {
      final selections = CanonicalPowerSelectionRegistry.fromCanonicalJson(
        document.payload['powerSelections'],
      );
      final base = _base.decode(ProjectDocument(
        schemaVersion:
            EngineeringStateAwareCanonicalProjectDocumentCodec.schemaVersion,
        payload: Map<String, Object?>.of(document.payload)
          ..remove('powerSelections'),
      ));
      final aggregate = base.aggregate;
      final rebuilt = ProjectAggregateRoot(
        id: aggregate.id,
        siteId: aggregate.siteId,
        version: aggregate.version,
        stores: aggregate.stores,
        engineeringMetadata:
            aggregate.engineeringMetadata.withPowerSelections(selections),
      );
      _validateReferences(rebuilt);
      return base.copyWith(aggregate: rebuilt);
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Invalid canonical POWER selections.');
    } on StateError {
      throw const FormatException(
          'Invalid canonical POWER selection references.');
    } on TypeError {
      throw const FormatException('Invalid canonical POWER selection types.');
    }
  }

  static void _validateReferences(ProjectAggregateRoot project) {
    final engineering = project.engineeringMetadata.engineeringState;
    final circuits = engineering.circuits.map((c) => c.id).toSet();
    final components =
        engineering.graph.components.map((component) => component.id).toSet();
    for (final selection
        in project.engineeringMetadata.powerSelections.byCircuit.values) {
      if (!circuits.contains(selection.circuitId) ||
          !components.contains(selection.boardComponentId)) {
        throw const FormatException(
          'POWER selection references missing canonical P11 entities.',
        );
      }
    }
  }
}
