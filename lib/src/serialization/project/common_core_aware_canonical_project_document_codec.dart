import '../../application/project/project_snapshot.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/vertical_core.dart';
import '../../domain/vertical_core_project_validation.dart';
import 'level_composition_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// Schema v16 persists P10.6 architectural vertical-core semantics without
/// changing the older P7 physical VerticalCore persistence contract.
///
/// The v15 payload still owns the canonical core identity, building, physical
/// kind, served LevelIds and footprint. This additive layer stores only the P10
/// usage plus LevelId -> host SpaceId bindings and reconstructs one canonical
/// [ProjectVerticalCore] on load.
final class CommonCoreAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const CommonCoreAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 16;
  static const int _baseSchemaVersion = 15;
  static const LevelCompositionAwareCanonicalProjectDocumentCodec _base =
      LevelCompositionAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    _validateCoreHosts(snapshot.aggregate);

    final base = _base.encode(_withoutBuildingCoreSemantics(snapshot));
    final cores = snapshot.aggregate.stores.verticalCores.values
        .where(_hasBuildingCoreSemantics)
        .toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));

    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...base.payload,
        'buildingCoreSemantics': <String, Object?>{
          'schemaVersion': 1,
          'cores': <Object?>[
            for (final core in cores)
              <String, Object?>{
                'verticalCoreId': core.id.value,
                'usage': core.usage.name,
                'hosts': <String, Object?>{
                  for (final entry
                      in (core.hostSpaceIdsByLevel.entries.toList()
                        ..sort((a, b) => a.key.value.compareTo(b.key.value))))
                    entry.key.value: entry.value.value,
                },
              },
          ],
        },
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw FormatException(
        'Unsupported canonical ElecX project schema ${document.schemaVersion}; '
        'supported versions are 1..$schemaVersion.',
      );
    }

    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('buildingCoreSemantics')) {
        throw const FormatException(
          'Building core semantics require project schema v16.',
        );
      }
      return _base.decode(document);
    }

    try {
      final semantics = _map(
        document.payload['buildingCoreSemantics'],
        const {'schemaVersion', 'cores'},
      );
      if (_int(semantics['schemaVersion'],
              'buildingCoreSemantics.schemaVersion') !=
          1) {
        throw const FormatException(
          'Unsupported building core semantics schema version.',
        );
      }

      final payload = Map<String, Object?>.of(document.payload)
        ..remove('buildingCoreSemantics');
      final base = _base.decode(
        ProjectDocument(
          schemaVersion: _baseSchemaVersion,
          payload: payload,
        ),
      );

      final overrides = <VerticalCoreId, _CoreSemantics>{};
      for (final raw
          in _list(semantics['cores'], 'buildingCoreSemantics.cores')) {
        final json = _map(
          raw,
          const {'verticalCoreId', 'usage', 'hosts'},
        );
        final coreId = VerticalCoreId(
          _string(
              json['verticalCoreId'], 'buildingCoreSemantics.verticalCoreId'),
        );
        if (overrides.containsKey(coreId)) {
          throw FormatException(
              'Duplicate building core semantics for $coreId.');
        }
        if (!base.aggregate.stores.verticalCores.containsKey(coreId)) {
          throw FormatException(
            'Building core semantics reference missing vertical core $coreId.',
          );
        }
        final hostsJson = _map(json['hosts']);
        final hosts = <LevelId, SpaceId>{};
        for (final entry in hostsJson.entries) {
          final levelId =
              LevelId(_string(entry.key, 'buildingCoreSemantics.host.levelId'));
          if (hosts.containsKey(levelId)) {
            throw FormatException('Duplicate host LevelId $levelId.');
          }
          hosts[levelId] = SpaceId(
              _string(entry.value, 'buildingCoreSemantics.host.spaceId'));
        }
        overrides[coreId] = _CoreSemantics(
          usage: _enumByName(
            VerticalCoreUsage.values,
            json['usage'],
            'buildingCoreSemantics.usage',
          ),
          hosts: hosts,
        );
      }

      final rebuiltCores = <VerticalCoreId, ProjectVerticalCore>{};
      for (final entry in base.aggregate.stores.verticalCores.entries) {
        final core = entry.value;
        final semantics = overrides[entry.key];
        rebuiltCores[entry.key] = ProjectVerticalCore(
          id: core.id,
          buildingId: core.buildingId,
          kind: core.kind,
          levelIds: core.levelIds,
          footprint: core.footprint,
          name: core.name,
          usage: semantics?.usage ?? VerticalCoreUsage.unspecified,
          hostSpaceIdsByLevel: semantics?.hosts ?? const {},
        );
      }

      final source = base.aggregate;
      final aggregate = ProjectAggregateRoot(
        id: source.id,
        siteId: source.siteId,
        version: source.version,
        engineeringMetadata: source.engineeringMetadata,
        stores: source.stores.copyWith(verticalCores: rebuiltCores),
      );
      _validateCoreHosts(aggregate);
      return base.copyWith(aggregate: aggregate);
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Malformed building core semantics: $error');
    } on VerticalCoreProjectValidationException catch (error) {
      throw FormatException('Invalid building core host graph: $error');
    } on VerticalCoreTopologyValidationException catch (error) {
      throw FormatException('Invalid building core topology: $error');
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical project graph: $error');
    }
  }

  static bool _hasBuildingCoreSemantics(ProjectVerticalCore core) =>
      core.usage != VerticalCoreUsage.unspecified ||
      core.hostSpaceIdsByLevel.isNotEmpty;

  static ProjectSnapshot _withoutBuildingCoreSemantics(
    ProjectSnapshot snapshot,
  ) {
    if (!snapshot.aggregate.stores.verticalCores.values
        .any(_hasBuildingCoreSemantics)) {
      return snapshot;
    }
    final project = snapshot.aggregate;
    final cores = <VerticalCoreId, ProjectVerticalCore>{
      for (final entry in project.stores.verticalCores.entries)
        entry.key: ProjectVerticalCore(
          id: entry.value.id,
          buildingId: entry.value.buildingId,
          kind: entry.value.kind,
          levelIds: entry.value.levelIds,
          footprint: entry.value.footprint,
          name: entry.value.name,
        ),
    };
    return snapshot.copyWith(
      aggregate: ProjectAggregateRoot(
        id: project.id,
        siteId: project.siteId,
        version: project.version,
        engineeringMetadata: project.engineeringMetadata,
        stores: project.stores.copyWith(verticalCores: cores),
      ),
    );
  }

  static void _validateCoreHosts(ProjectAggregateRoot project) {
    VerticalCoreProjectValidator.validateOrThrow(
      verticalCores: project.stores.verticalCores,
      buildingExists: project.stores.buildings.containsKey,
      levelBuildingResolver: (levelId) =>
          project.stores.levels[levelId]?.buildingId,
      spaceLevelResolver: (spaceId) => project.stores.spaces[spaceId]?.levelId,
    );
  }
}

final class _CoreSemantics {
  const _CoreSemantics({required this.usage, required this.hosts});

  final VerticalCoreUsage usage;
  final Map<LevelId, SpaceId> hosts;
}

Map<String, Object?> _map(Object? value, [Set<String>? expected]) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected an object with string keys.');
  }
  final json = Map<String, Object?>.from(value);
  if (expected != null &&
      (json.length != expected.length || !expected.containsAll(json.keys))) {
    throw const FormatException('Unknown or missing building core field.');
  }
  return json;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array.');
  return List<Object?>.from(value);
}

String _string(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _int(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  final raw = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == raw) return candidate;
  }
  throw FormatException('$field contains unsupported value $raw.');
}
