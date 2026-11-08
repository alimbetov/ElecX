import '../../application/project/project_snapshot.dart';
import '../../domain/canonical_power_selection.dart';
import '../../domain/canonical_residual_protection_registry.dart';
import '../../domain/project_aggregate.dart';
import 'power_selection_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// P12A.8 v22: immutable group-RCD ownership, additive to v21 POWER state.
/// v1-v21 projects reopen with an empty residual registry.
final class ResidualProtectionAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const ResidualProtectionAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 22;
  static const _base = PowerSelectionAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final original = snapshot.aggregate;
    final registry = original.engineeringMetadata.residualProtection;
    // Older v21 codec must not inadvertently erase newly persisted RCD data:
    // project the older schema on an ephemeral, independently validated root.
    final projection = ProjectAggregateRoot(
      id: original.id,
      siteId: original.siteId,
      version: original.version,
      stores: original.stores,
      engineeringMetadata: original.engineeringMetadata.withResidualProtection(
        const CanonicalResidualProtectionRegistry.empty(),
      ),
    );
    final previous = _base.encode(snapshot.copyWith(aggregate: projection));
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: {
        ...previous.payload,
        'residualProtection': registry.toCanonicalJson(),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException('Unsupported group RCD schema version.');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('residualProtection')) {
        throw const FormatException('Group RCD requires schema v22.');
      }
      return _base.decode(document);
    }

    try {
      final registry = CanonicalResidualProtectionRegistry.fromCanonicalJson(
        document.payload['residualProtection'],
      );
      final prior = _base.decode(ProjectDocument(
        schemaVersion:
            PowerSelectionAwareCanonicalProjectDocumentCodec.schemaVersion,
        payload: Map<String, Object?>.of(document.payload)
          ..remove('residualProtection'),
      ));
      final aggregate = prior.aggregate;
      final rebuilt = ProjectAggregateRoot(
        id: aggregate.id,
        siteId: aggregate.siteId,
        version: aggregate.version,
        stores: aggregate.stores,
        engineeringMetadata:
            aggregate.engineeringMetadata.withResidualProtection(registry),
      );
      return prior.copyWith(aggregate: rebuilt);
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Invalid canonical group RCD ownership.');
    } on StateError {
      throw const FormatException('Invalid canonical group RCD state.');
    } on TypeError {
      throw const FormatException('Invalid group RCD document types.');
    }
  }
}
