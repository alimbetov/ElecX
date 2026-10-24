import '../apartment_topology.dart';
import '../project_space_semantics.dart';
import 'apartment_topology_models.dart';

final class ApartmentTopologyCatalog {
  ApartmentTopologyCatalog({
    required this.catalogVersion,
    required Iterable<ApartmentTopologyTemplate> templates,
  }) : templates = List.unmodifiable(templates);

  final int catalogVersion;
  final List<ApartmentTopologyTemplate> templates;

  List<CatalogValidationIssue> validate() =>
      const ApartmentTopologyCatalogValidator().validate(this);

  void validateOrThrow() {
    final issues = validate();
    if (issues.isNotEmpty) {
      throw ApartmentTopologyCatalogValidationException(issues);
    }
  }
}

final class CatalogValidationIssue {
  CatalogValidationIssue({
    required this.code,
    required this.message,
    this.templateId,
    Map<String, Object?> facts = const {},
  }) : facts = Map.unmodifiable(facts);

  final String code;
  final String message;
  final String? templateId;
  final Map<String, Object?> facts;
}

final class ApartmentTopologyCatalogValidationException implements Exception {
  ApartmentTopologyCatalogValidationException(
    Iterable<CatalogValidationIssue> issues,
  ) : issues = List.unmodifiable(issues);

  final List<CatalogValidationIssue> issues;

  @override
  String toString() =>
      'ApartmentTopologyCatalogValidationException(${issues.length} issues)';
}

final class ApartmentTopologyCatalogValidator {
  const ApartmentTopologyCatalogValidator();

  static const int maxSeedsPerTemplate = 12;

  List<CatalogValidationIssue> validate(ApartmentTopologyCatalog catalog) {
    final issues = <CatalogValidationIssue>[];
    if (catalog.catalogVersion <= 0) {
      issues.add(
        CatalogValidationIssue(
          code: 'p9.catalog.invalid-catalog-version',
          message: 'catalogVersion must be positive.',
          facts: {'catalogVersion': catalog.catalogVersion},
        ),
      );
    }
    if (catalog.templates.isEmpty) {
      issues.add(
        CatalogValidationIssue(
          code: 'p9.catalog.empty-catalog',
          message: 'Catalog must contain at least one topology template.',
        ),
      );
    }

    final identities = <String>{};
    for (final template in catalog.templates) {
      final identity =
          '${template.templateId.value}@${template.templateVersion}';
      if (!identities.add(identity)) {
        issues.add(
          _issue(
            template,
            'p9.catalog.duplicate-template-identity',
            'templateId + templateVersion must be unique.',
          ),
        );
      }
      _validateTemplate(template, issues);
    }
    return List.unmodifiable(issues);
  }

  void _validateTemplate(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    if (template.templateVersion <= 0) {
      issues.add(
        _issue(
          template,
          'p9.catalog.invalid-template-version',
          'templateVersion must be positive.',
        ),
      );
    }
    if (template.stableOrder < 0) {
      issues.add(
        _issue(
          template,
          'p9.catalog.invalid-template-order',
          'stableOrder must be non-negative.',
        ),
      );
    }
    _validateConstraints(template, issues);
    _validateSpaces(template, issues);
    _validateAdjacency(template, issues);
    _validateSeeds(template, issues);
    _validateKitchenContracts(template, issues);
    _validateAreaFeasibility(template, issues);
  }

  void _validateConstraints(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    final constraints = template.constraints;
    if (constraints.supportedHabitableRoomCounts.isEmpty ||
        constraints.supportedBathroomCounts.isEmpty ||
        constraints.supportedSeparateWcCounts.isEmpty ||
        constraints.supportedBalconyCounts.isEmpty ||
        constraints.supportedBalconyKinds.isEmpty ||
        constraints.supportedKitchenModes.isEmpty ||
        constraints.supportedCorridorModes.isEmpty ||
        constraints.supportedExteriorExposurePreferences.isEmpty) {
      issues.add(
        _issue(
          template,
          'p9.catalog.empty-compatibility-set',
          'Every compatibility dimension must declare at least one value.',
        ),
      );
    }
    if (constraints.supportedHabitableRoomCounts
        .any((value) => value < 1 || value > 10)) {
      issues.add(
        _issue(
          template,
          'p9.catalog.invalid-room-count-range',
          'Supported habitable room counts must stay inside 1..10.',
        ),
      );
    }
    if (constraints.minInteriorAreaDm2 <= 0 ||
        constraints.minInteriorAreaDm2 > constraints.maxInteriorAreaDm2) {
      issues.add(
        _issue(
          template,
          'p9.catalog.invalid-area-envelope',
          'Template interior area envelope is invalid.',
        ),
      );
    }
    if (constraints.supportedBathroomCounts.any((value) => value < 1) ||
        constraints.supportedSeparateWcCounts.any((value) => value < 0) ||
        constraints.supportedBalconyCounts.any((value) => value < 0)) {
      issues.add(
        _issue(
          template,
          'p9.catalog.invalid-count-compatibility',
          'Bathroom/WC/balcony compatibility contains a negative value.',
        ),
      );
    }
  }

  void _validateSpaces(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    if (template.spaces.isEmpty) {
      issues.add(
        _issue(
          template,
          'p9.catalog.empty-space-recipe',
          'Template must declare semantic spaces.',
        ),
      );
      return;
    }

    final keys = <String>{};
    for (final space in template.spaces) {
      if (space.semanticKey.trim().isEmpty || !keys.add(space.semanticKey)) {
        issues.add(
          _issue(
            template,
            'p9.catalog.duplicate-semantic-key',
            'Semantic space keys must be non-empty and unique.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      if (space.multiplicityMin < 0 ||
          space.multiplicityMax < 1 ||
          space.multiplicityMin > space.multiplicityMax) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-multiplicity',
            'Space multiplicity range is invalid.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      if (space.minAreaDm2 <= 0 ||
          space.minAreaDm2 > space.preferredAreaDm2 ||
          space.preferredAreaDm2 > space.maxAreaDm2) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-space-area-range',
            'Space min/preferred/max area must be positive and ordered.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      if (space.areaWeightBp <= 0) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-area-weight',
            'Space areaWeightBp must be positive.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      final geometry = space.geometry;
      if (geometry.minShortSideMm <= 0 ||
          (geometry.minLongSideMm != null && geometry.minLongSideMm! <= 0) ||
          geometry.minAspectBp <= 0 ||
          geometry.minAspectBp > geometry.maxAspectBp ||
          geometry.maxVertices < 4) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-geometry-constraints',
            'Space geometry constraints are invalid.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      if (space.requiresExteriorExposure &&
          (geometry.minExteriorExposureMm == null ||
              geometry.minExteriorExposureMm! <= 0)) {
        issues.add(
          _issue(
            template,
            'p9.catalog.missing-exterior-exposure-minimum',
            'Exterior-exposed spaces require a positive exposure minimum.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
      if (_isExteriorAppendage(space.usage) &&
          space.areaParticipation != SpaceAreaParticipation.exteriorAppendage) {
        issues.add(
          _issue(
            template,
            'p9.catalog.appendage-counted-as-interior',
            'Balcony/loggia/terrace cannot consume requested interior area.',
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
    }

    final supportsAppendage =
        template.constraints.supportedBalconyCounts.any((count) => count > 0);
    final hasAppendageRecipe = template.spaces.any(
      (space) =>
          space.areaParticipation == SpaceAreaParticipation.exteriorAppendage,
    );
    if (supportsAppendage && !hasAppendageRecipe) {
      issues.add(
        _issue(
          template,
          'p9.catalog.missing-appendage-recipe',
          'Template supports balconies but declares no appendage space recipe.',
        ),
      );
    }
  }

  void _validateAdjacency(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    final keys = template.spaces.map((space) => space.semanticKey).toSet();
    final requiredPairs = <String>{};
    final forbiddenPairs = <String>{};

    for (final rule in template.adjacencyRules) {
      if (!keys.contains(rule.fromKey) || !keys.contains(rule.toKey)) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-adjacency-reference',
            'Adjacency rule references an undeclared semantic key.',
            facts: {'fromKey': rule.fromKey, 'toKey': rule.toKey},
          ),
        );
      }
      if (rule.fromKey == rule.toKey) {
        issues.add(
          _issue(
            template,
            'p9.catalog.self-adjacency',
            'Adjacency rule cannot reference the same semantic key twice.',
            facts: {'semanticKey': rule.fromKey},
          ),
        );
      }
      if (rule.minSharedBoundaryMm != null && rule.minSharedBoundaryMm! <= 0) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-adjacency-length',
            'minSharedBoundaryMm must be positive when declared.',
          ),
        );
      }

      final key = '${rule.normalizedPairKey}|${rule.kind.name}';
      if (rule.requirement == TopologyAdjacencyRequirement.required) {
        requiredPairs.add(key);
      } else if (rule.requirement == TopologyAdjacencyRequirement.forbidden) {
        forbiddenPairs.add(key);
      }
    }

    final contradictions = requiredPairs.intersection(forbiddenPairs);
    for (final contradiction in contradictions) {
      issues.add(
        _issue(
          template,
          'p9.catalog.contradictory-adjacency',
          'The same adjacency is both required and forbidden.',
          facts: {'adjacency': contradiction},
        ),
      );
    }
  }

  void _validateSeeds(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    if (template.variantSeeds.isEmpty ||
        template.variantSeeds.length > maxSeedsPerTemplate) {
      issues.add(
        _issue(
          template,
          'p9.catalog.invalid-seed-count',
          'Template seed count must be between 1 and $maxSeedsPerTemplate.',
          facts: {'seedCount': template.variantSeeds.length},
        ),
      );
    }

    final seedIds = <String>{};
    final stableOrders = <int>{};
    for (final seed in template.variantSeeds) {
      if (seed.seedId.trim().isEmpty || !seedIds.add(seed.seedId)) {
        issues.add(
          _issue(
            template,
            'p9.catalog.duplicate-seed-identity',
            'Variant seed IDs must be non-empty and unique.',
            facts: {'seedId': seed.seedId},
          ),
        );
      }
      if (seed.stableOrder < 0 || !stableOrders.add(seed.stableOrder)) {
        issues.add(
          _issue(
            template,
            'p9.catalog.invalid-seed-order',
            'Seed stableOrder values must be unique and non-negative.',
            facts: {'stableOrder': seed.stableOrder},
          ),
        );
      }
    }
  }

  void _validateKitchenContracts(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    final modes = template.constraints.supportedKitchenModes;
    if (modes.contains(ApartmentKitchenMode.kitchenLiving) &&
        !template.spaces
            .any((space) => space.usage == SpaceUsage.kitchenLiving)) {
      issues.add(
        _issue(
          template,
          'p9.catalog.kitchen-living-contract-missing',
          'kitchenLiving compatibility requires SpaceUsage.kitchenLiving.',
        ),
      );
    }

    if (modes.contains(ApartmentKitchenMode.openPlan)) {
      final hasKitchen =
          template.spaces.any((space) => space.usage == SpaceUsage.kitchen);
      final hasDaySpace =
          template.spaces.any((space) => space.usage == SpaceUsage.livingRoom);
      final hasOpenConnection = template.adjacencyRules.any(
        (rule) =>
            rule.kind == TopologyAdjacencyKind.openConnection &&
            rule.requirement == TopologyAdjacencyRequirement.required,
      );
      if (!hasKitchen || !hasDaySpace || !hasOpenConnection) {
        issues.add(
          _issue(
            template,
            'p9.catalog.open-plan-contract-missing',
            'openPlan requires distinct kitchen/day roles and required open connection.',
          ),
        );
      }
    }
  }

  void _validateAreaFeasibility(
    ApartmentTopologyTemplate template,
    List<CatalogValidationIssue> issues,
  ) {
    var minimumInteriorDm2 = 0;
    var maximumInteriorDm2 = 0;
    for (final space in template.spaces) {
      if (space.areaParticipation !=
          SpaceAreaParticipation.requestedInteriorArea) {
        continue;
      }
      minimumInteriorDm2 += space.minAreaDm2 * space.multiplicityMin;
      maximumInteriorDm2 += space.maxAreaDm2 * space.multiplicityMax;
    }

    if (minimumInteriorDm2 > template.constraints.maxInteriorAreaDm2 ||
        maximumInteriorDm2 < template.constraints.minInteriorAreaDm2) {
      issues.add(
        _issue(
          template,
          'p9.catalog.infeasible-area-envelope',
          'Space recipe cannot realize the advertised template area envelope.',
          facts: {
            'minimumRecipeAreaDm2': minimumInteriorDm2,
            'maximumRecipeAreaDm2': maximumInteriorDm2,
          },
        ),
      );
    }
  }

  CatalogValidationIssue _issue(
    ApartmentTopologyTemplate template,
    String code,
    String message, {
    Map<String, Object?> facts = const {},
  }) =>
      CatalogValidationIssue(
        code: code,
        message: message,
        templateId: template.templateId.value,
        facts: facts,
      );

  bool _isExteriorAppendage(SpaceUsage usage) =>
      usage == SpaceUsage.balcony ||
      usage == SpaceUsage.loggia ||
      usage == SpaceUsage.terrace;
}
