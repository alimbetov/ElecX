import 'dart:convert';

import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../apartment/p9_sha256.dart';
import 'building_generation_parameters.dart';

/// Published architectural constraints/defaults, never live project entities.
final class BuildingTemplateDefinition {
  BuildingTemplateDefinition({
    required this.id,
    required this.version,
    required this.kind,
    required Iterable<ProjectLevelKind> allowedLevelKinds,
    required Map<ProjectLevelKind, int> defaultFloorToFloorHeightsMm,
    required this.minimumLevels,
    required this.maximumLevels,
    required this.commonCoreDefaults,
    required this.serviceAnchorDefaults,
    this.minimumStairCount = 0,
    this.minimumLiftCount = 0,
    Iterable<String> typicalFloorDefinitionKeys = const [],
  })  : allowedLevelKinds = Set.unmodifiable(allowedLevelKinds),
        defaultFloorToFloorHeightsMm = Map.unmodifiable(
          defaultFloorToFloorHeightsMm,
        ),
        typicalFloorDefinitionKeys = Set.unmodifiable(
          typicalFloorDefinitionKeys,
        ) {
    if (id.value != id.value.trim() ||
        version < 1 ||
        minimumLevels < 1 ||
        maximumLevels > 231 ||
        minimumLevels > maximumLevels ||
        minimumStairCount < 0 ||
        minimumLiftCount < 0 ||
        commonCoreDefaults.stairCount < minimumStairCount ||
        commonCoreDefaults.liftCount < minimumLiftCount ||
        this.allowedLevelKinds.contains(ProjectLevelKind.unknown) ||
        !this.allowedLevelKinds.contains(ProjectLevelKind.ground) ||
        this.defaultFloorToFloorHeightsMm.length !=
            this.allowedLevelKinds.length ||
        !this.allowedLevelKinds.containsAll(
              this.defaultFloorToFloorHeightsMm.keys,
            )) {
      throw ArgumentError(
        'Inconsistent building template constraints/defaults.',
      );
    }
    for (final height in this.defaultFloorToFloorHeightsMm.values) {
      if (height < 1 || height > 1000000) {
        throw ArgumentError(
          'Template storey heights must be supported mm values.',
        );
      }
    }
    for (final key in this.typicalFloorDefinitionKeys) {
      if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(key)) {
        throw ArgumentError('Typical-floor template keys must be canonical.');
      }
    }
  }

  final TemplateId id;
  final int version;
  final BuildingCompositionKind kind;
  final Set<ProjectLevelKind> allowedLevelKinds;
  final Map<ProjectLevelKind, int> defaultFloorToFloorHeightsMm;
  final int minimumLevels;
  final int maximumLevels;
  final CommonCoreParameters commonCoreDefaults;
  final ServiceAnchorParameters serviceAnchorDefaults;
  final int minimumStairCount;
  final int minimumLiftCount;
  final Set<String> typicalFloorDefinitionKeys;

  Map<String, Object?> toCanonicalJson() => {
        'id': id.value,
        'version': version,
        'kind': kind.name,
        'levelRoles': [
          for (final role in ProjectLevelKind.values)
            if (allowedLevelKinds.contains(role))
              {
                'kind': role.name,
                'defaultFloorToFloorHeightMm':
                    defaultFloorToFloorHeightsMm[role],
              },
        ],
        'minimumLevels': minimumLevels,
        'maximumLevels': maximumLevels,
        'commonCoreDefaults': commonCoreDefaults.toCanonicalJson(),
        'serviceAnchorDefaults': serviceAnchorDefaults.toCanonicalJson(),
        'minimumStairCount': minimumStairCount,
        'minimumLiftCount': minimumLiftCount,
        'typicalFloorDefinitionKeys': typicalFloorDefinitionKeys.toList()
          ..sort(),
      };

  String get fingerprint => p9Sha256Hex(jsonEncode(toCanonicalJson()));
}

/// Exact immutable template evidence to carry into a P10 candidate/provenance.
/// An existing binding never resolves against a later catalog implicitly.
final class BuildingTemplateBinding {
  const BuildingTemplateBinding._({
    required this.reference,
    required this.definition,
    required this.catalogFingerprint,
    required this.requestFingerprint,
  });

  final BuildingTemplateRef reference;
  final BuildingTemplateDefinition definition;
  final String catalogFingerprint;
  final String requestFingerprint;

  String get templateFingerprint => definition.fingerprint;
}

final class BuildingTemplateCatalog {
  BuildingTemplateCatalog({
    required this.version,
    required Iterable<BuildingTemplateDefinition> templates,
  }) : templates = List.unmodifiable(
          List<BuildingTemplateDefinition>.of(templates)
            ..sort((a, b) {
              final byId = a.id.value.compareTo(b.id.value);
              return byId == 0 ? a.version.compareTo(b.version) : byId;
            }),
        ) {
    if (version < 1 || this.templates.isEmpty) {
      throw ArgumentError(
        'A versioned building catalog must contain templates.',
      );
    }
    final identities = <(TemplateId, int)>{};
    for (final template in this.templates) {
      if (!identities.add((template.id, template.version))) {
        throw ArgumentError('Duplicate published template identity/version.');
      }
    }
  }

  final int version;
  final List<BuildingTemplateDefinition> templates;

  String get fingerprint => p9Sha256Hex(
        jsonEncode({
          'schema': 'p10.building-template-catalog.v1',
          'version': version,
          'templates': [
            for (final template in templates) template.toCanonicalJson(),
          ],
        }),
      );

  BuildingTemplateBinding bind(BuildingGenerationParameters request) {
    final reference = request.template;
    if (reference == null || reference.catalogVersion != version) {
      throw ArgumentError('An exact supported catalog version is required.');
    }
    final matching = templates.where(
      (template) =>
          template.id == reference.id &&
          template.version == reference.templateVersion,
    );
    if (matching.isEmpty) {
      throw ArgumentError('Unsupported building template identity/version.');
    }
    final definition = matching.single;
    if (request.kind != definition.kind ||
        request.levelStack.levels.length < definition.minimumLevels ||
        request.levelStack.levels.length > definition.maximumLevels ||
        request.commonCore.stairCount < definition.minimumStairCount ||
        request.commonCore.liftCount < definition.minimumLiftCount ||
        request.levelStack.levels.any(
          (level) => !definition.allowedLevelKinds.contains(level.kind),
        ) ||
        (request.typicalFloor != null &&
            !definition.typicalFloorDefinitionKeys.contains(
              request.typicalFloor!.definitionKey,
            ))) {
      throw ArgumentError(
        'Request is incompatible with the selected template.',
      );
    }
    return BuildingTemplateBinding._(
      reference: reference,
      definition: definition,
      catalogFingerprint: fingerprint,
      requestFingerprint: request.requestFingerprint,
    );
  }

  /// Explicit v1 defaults for the first single-building production families.
  /// Site/complex templates will be introduced with P10.9, without fallback.
  factory BuildingTemplateCatalog.residentialV1() => BuildingTemplateCatalog(
        version: 1,
        templates: [
          _residentialTemplate(
            'p10.cottage',
            BuildingCompositionKind.detachedHouse,
            maximumLevels: 8,
            lifts: 0,
          ),
          _residentialTemplate(
            'p10.tower',
            BuildingCompositionKind.residentialTower,
            maximumLevels: 231,
            lifts: 1,
          ),
          _residentialTemplate(
            'p10.residential-building',
            BuildingCompositionKind.multiStoreyResidentialBuilding,
            maximumLevels: 231,
            lifts: 0,
          ),
        ],
      );
}

BuildingTemplateDefinition _residentialTemplate(
  String id,
  BuildingCompositionKind kind, {
  required int maximumLevels,
  required int lifts,
}) =>
    BuildingTemplateDefinition(
      id: TemplateId(id),
      version: 1,
      kind: kind,
      allowedLevelKinds: ProjectLevelKind.values.where(
        (role) => role != ProjectLevelKind.unknown,
      ),
      defaultFloorToFloorHeightsMm: {
        for (final role in ProjectLevelKind.values)
          if (role != ProjectLevelKind.unknown) role: 3000,
      },
      minimumLevels: kind == BuildingCompositionKind.detachedHouse ? 1 : 2,
      maximumLevels: maximumLevels,
      commonCoreDefaults: CommonCoreParameters(
        stairCount: 1,
        liftCount: lifts,
        serviceShaftCount: 1,
        corridorWidthMm: 1800,
      ),
      serviceAnchorDefaults: ServiceAnchorParameters(
        kinds: const [
          BuildingServiceAnchorKind.electricalEntry,
          BuildingServiceAnchorKind.telecomEntry,
        ],
      ),
      minimumStairCount: kind == BuildingCompositionKind.detachedHouse ? 0 : 1,
      minimumLiftCount: lifts,
      typicalFloorDefinitionKeys: const ['residential.standard'],
    );
