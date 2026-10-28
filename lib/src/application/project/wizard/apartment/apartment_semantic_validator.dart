import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/project_space_semantics.dart';
import 'apartment_wizard_parameters.dart';

/// P9.5 semantic topology validator.
///
/// This stage validates adjacency, access/privacy, wet-core grouping and
/// exterior-exposure intent before geometry. It never allocates canonical IDs
/// and never infers semantics from localized names.
final class ApartmentSemanticValidator {
  const ApartmentSemanticValidator();

  static const int preferredAdjacencyPenaltyBp = 100;

  TopologySemanticValidation validate({
    required AreaFittedTopologyDraft fittedDraft,
    required NormalizedApartmentRequest request,
    required ApartmentTopologyTemplate template,
  }) {
    final draft = fittedDraft.draft;
    final spaces = draft.spaces.toList()..sort(_compareSpace);
    final byKey = <String, DraftSpace>{
      for (final space in spaces) space.semanticKey: space,
    };
    final blockers = <P9SemanticViolation>[];
    final preferenceMisses = <P9SemanticPreferenceMiss>[];

    _validateLineage(blockers, draft, request, template);
    _validateReferenceContract(blockers, draft, byKey);

    final accessGraph = _buildAccessGraph(draft, byKey);
    final distances = _distancesFromEntry(draft, accessGraph, byKey);
    final disconnected = <String>[];
    for (final space in spaces) {
      if (_isExteriorAppendage(space)) {
        continue;
      }
      if (!distances.containsKey(space.semanticKey)) {
        disconnected.add(space.semanticKey);
        blockers.add(
          _violation(
            code: 'p9.semantic.disconnected-space',
            ruleId: 'p9.semantic.entry-reachability',
            keys: [space.semanticKey],
          ),
        );
      }
    }

    final privateTransitCount = _validatePrivateTransit(
      blockers: blockers,
      draft: draft,
      spaces: spaces,
      accessGraph: accessGraph,
      initiallyReachable: distances.keys.toSet(),
    );
    _validateBathroomPrivacy(blockers, draft, byKey);
    _validateKitchenMode(blockers, draft, request, spaces);
    _validateAppendages(blockers, draft, byKey);
    _validateWetCore(blockers, draft, template, spaces, byKey);
    _validateExteriorExposure(blockers, draft, spaces);

    final ruleEvaluation = _evaluateTemplateRules(
      blockers: blockers,
      preferenceMisses: preferenceMisses,
      draft: draft,
      template: template,
      spaces: spaces,
    );

    final maxDepth = distances.values.fold<int>(
      0,
      (current, depth) => depth > current ? depth : current,
    );
    final metrics = TopologySemanticMetrics(
      entryReachableSpaceCount: distances.length,
      maxAccessDepth: maxDepth,
      privateTransitViolations: privateTransitCount,
      circulationNodeCount:
          spaces.where((space) => space.sourceSpec.circulationSpace).length,
      requiredRulePassCount: ruleEvaluation.requiredRulePassCount,
      preferredRuleMisses: preferenceMisses.length,
      wetCoreGroupCount: draft.wetCore.groups.length,
    );

    return TopologySemanticValidation(
      blockers: blockers,
      preferenceMisses: preferenceMisses,
      metrics: metrics,
      geometryHandoff: _geometryHandoff(draft, template, spaces),
    );
  }

  void _validateLineage(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    NormalizedApartmentRequest request,
    ApartmentTopologyTemplate template,
  ) {
    if (draft.intentFingerprint != request.intentFingerprint) {
      blockers.add(
        _violation(
          code: 'p9.semantic.rule-contract-invalid',
          ruleId: 'p9.semantic.lineage.intent',
          facts: {
            'draftIntentFingerprint': draft.intentFingerprint,
            'requestIntentFingerprint': request.intentFingerprint,
          },
        ),
      );
    }
    if (draft.templateId != template.templateId ||
        draft.templateVersion != template.templateVersion ||
        draft.family != template.family) {
      blockers.add(
        _violation(
          code: 'p9.semantic.rule-contract-invalid',
          ruleId: 'p9.semantic.lineage.template',
          facts: {
            'draftTemplateId': draft.templateId.value,
            'draftTemplateVersion': draft.templateVersion,
            'templateId': template.templateId.value,
            'templateVersion': template.templateVersion,
          },
        ),
      );
    }
  }

  void _validateReferenceContract(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    Map<String, DraftSpace> byKey,
  ) {
    void requireKey(String key, String ruleId) {
      if (!byKey.containsKey(key)) {
        blockers.add(
          _violation(
            code: 'p9.semantic.missing-space',
            ruleId: ruleId,
            keys: [key],
          ),
        );
      }
    }

    requireKey(draft.circulation.entrySpaceKey, 'p9.semantic.entry');
    for (final edge in draft.circulation.accessEdges) {
      requireKey(edge.fromSpaceKey, 'p9.semantic.access.endpoint');
      requireKey(edge.toSpaceKey, 'p9.semantic.access.endpoint');
    }
    for (final intent in draft.adjacency) {
      requireKey(intent.fromSpaceKey, 'p9.semantic.adjacency.endpoint');
      requireKey(intent.toSpaceKey, 'p9.semantic.adjacency.endpoint');
    }
    for (final group in draft.wetCore.groups) {
      for (final key in group) {
        requireKey(key, 'p9.semantic.wet-core.endpoint');
      }
    }
    for (final key in draft.exteriorExposure.assignments.keys) {
      requireKey(key, 'p9.semantic.exterior.endpoint');
    }
  }

  Map<String, Set<String>> _buildAccessGraph(
    ApartmentTopologyDraft draft,
    Map<String, DraftSpace> byKey,
  ) {
    final graph = <String, Set<String>>{
      for (final key in byKey.keys) key: <String>{},
    };
    for (final edge in draft.circulation.accessEdges) {
      if (!byKey.containsKey(edge.fromSpaceKey) ||
          !byKey.containsKey(edge.toSpaceKey)) {
        continue;
      }
      graph[edge.fromSpaceKey]!.add(edge.toSpaceKey);
      graph[edge.toSpaceKey]!.add(edge.fromSpaceKey);
    }
    return graph;
  }

  Map<String, int> _distancesFromEntry(
    ApartmentTopologyDraft draft,
    Map<String, Set<String>> graph,
    Map<String, DraftSpace> byKey, {
    String? removedKey,
  }) {
    final entry = draft.circulation.entrySpaceKey;
    if (entry.isEmpty ||
        entry == removedKey ||
        !byKey.containsKey(entry) ||
        !graph.containsKey(entry)) {
      return const {};
    }
    final distances = <String, int>{entry: 0};
    final queue = <String>[entry];
    var index = 0;
    while (index < queue.length) {
      final current = queue[index++];
      final nextKeys = (graph[current] ?? const <String>{}).toList()..sort();
      for (final next in nextKeys) {
        if (next == removedKey || distances.containsKey(next)) {
          continue;
        }
        distances[next] = distances[current]! + 1;
        queue.add(next);
      }
    }
    return distances;
  }

  int _validatePrivateTransit({
    required List<P9SemanticViolation> blockers,
    required ApartmentTopologyDraft draft,
    required List<DraftSpace> spaces,
    required Map<String, Set<String>> accessGraph,
    required Set<String> initiallyReachable,
  }) {
    var violations = 0;
    final byKey = {for (final space in spaces) space.semanticKey: space};
    for (final bedroom in spaces.where(
      (space) => space.usage == SpaceUsage.bedroom,
    )) {
      final withoutBedroom = _distancesFromEntry(
        draft,
        accessGraph,
        byKey,
        removedKey: bedroom.semanticKey,
      );
      final isolated = spaces
          .where(
            (space) =>
                space.semanticKey != bedroom.semanticKey &&
                !_isExteriorAppendage(space) &&
                initiallyReachable.contains(space.semanticKey) &&
                !withoutBedroom.containsKey(space.semanticKey),
          )
          .map((space) => space.semanticKey)
          .toList()
        ..sort();
      if (isolated.isEmpty) {
        continue;
      }
      violations++;
      blockers.add(
        _violation(
          code: 'p9.semantic.private-transit',
          ruleId: 'p9.semantic.private-room-transit',
          keys: [bedroom.semanticKey, ...isolated],
          facts: {'transitBedroom': bedroom.semanticKey},
        ),
      );
    }
    return violations;
  }

  void _validateBathroomPrivacy(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    Map<String, DraftSpace> byKey,
  ) {
    for (final edge in draft.circulation.accessEdges) {
      final left = byKey[edge.fromSpaceKey];
      final right = byKey[edge.toSpaceKey];
      if (left == null || right == null) {
        continue;
      }
      final bedroomBathroom = (left.usage == SpaceUsage.bedroom &&
              _isBathroomLike(right.usage)) ||
          (right.usage == SpaceUsage.bedroom && _isBathroomLike(left.usage));
      if (!bedroomBathroom) {
        continue;
      }
      blockers.add(
        _violation(
          code: 'p9.semantic.private-transit',
          ruleId: 'p9.semantic.bathroom-privacy.v1-no-ensuite',
          keys: [left.semanticKey, right.semanticKey],
          facts: {'reason': 'ensuiteNotDeclaredByTemplateContract'},
        ),
      );
    }
  }

  void _validateKitchenMode(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    NormalizedApartmentRequest request,
    List<DraftSpace> spaces,
  ) {
    final kitchens = spaces.where((space) => space.usage == SpaceUsage.kitchen);
    final kitchenLiving =
        spaces.where((space) => space.usage == SpaceUsage.kitchenLiving);
    final living =
        spaces.where((space) => space.usage == SpaceUsage.livingRoom);
    var valid = false;
    switch (request.kitchenMode) {
      case ApartmentKitchenMode.separate:
        valid = kitchens.length == 1 && kitchenLiving.isEmpty;
      case ApartmentKitchenMode.kitchenLiving:
        valid = kitchenLiving.length == 1 && kitchens.isEmpty;
      case ApartmentKitchenMode.openPlan:
        final kitchenKeys = kitchens.map((space) => space.semanticKey).toSet();
        final livingKeys = living.map((space) => space.semanticKey).toSet();
        final hasOpenConnection = draft.adjacency.any(
          (intent) =>
              intent.kind == TopologyAdjacencyKind.openConnection &&
              intent.requirement != TopologyAdjacencyRequirement.forbidden &&
              ((kitchenKeys.contains(intent.fromSpaceKey) &&
                      livingKeys.contains(intent.toSpaceKey)) ||
                  (kitchenKeys.contains(intent.toSpaceKey) &&
                      livingKeys.contains(intent.fromSpaceKey))),
        );
        valid = kitchens.length == 1 &&
            living.isNotEmpty &&
            kitchenLiving.isEmpty &&
            hasOpenConnection;
    }
    if (!valid) {
      blockers.add(
        _violation(
          code: 'p9.semantic.kitchen-mode-mismatch',
          ruleId: 'p9.semantic.kitchen-mode.${request.kitchenMode.code}',
          keys: [
            ...kitchens.map((space) => space.semanticKey),
            ...kitchenLiving.map((space) => space.semanticKey),
            ...living.map((space) => space.semanticKey),
          ],
        ),
      );
    }
  }

  void _validateAppendages(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    Map<String, DraftSpace> byKey,
  ) {
    for (final appendage in byKey.values.where(_isExteriorAppendage)) {
      final touching = draft.circulation.accessEdges.where(
        (edge) =>
            edge.fromSpaceKey == appendage.semanticKey ||
            edge.toSpaceKey == appendage.semanticKey,
      );
      final hosts = <DraftSpace>[];
      for (final edge in touching) {
        final otherKey = edge.fromSpaceKey == appendage.semanticKey
            ? edge.toSpaceKey
            : edge.fromSpaceKey;
        final host = byKey[otherKey];
        if (host != null) {
          hosts.add(host);
        }
      }
      final validHosts = hosts
          .where(
            (host) =>
                _isHabitableAppendageHost(host.usage) &&
                draft.exteriorExposure.assignments
                    .containsKey(host.semanticKey),
          )
          .toList();
      if (hosts.length != 1 || validHosts.length != 1) {
        blockers.add(
          _violation(
            code: 'p9.semantic.invalid-balcony-attachment',
            ruleId: 'p9.semantic.appendage-primary-attachment',
            keys: [
              appendage.semanticKey,
              ...hosts.map((host) => host.semanticKey),
            ],
            facts: {
              'attachmentCount': hosts.length,
              'validHostCount': validHosts.length,
            },
          ),
        );
      }
    }
  }

  void _validateWetCore(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    ApartmentTopologyTemplate template,
    List<DraftSpace> spaces,
    Map<String, DraftSpace> byKey,
  ) {
    final wetKeys = spaces.where(_isWetSpace).map((space) => space.semanticKey);
    final expected = wetKeys.toSet();
    final counts = <String, int>{};
    var invalidReference = false;
    for (final group in draft.wetCore.groups) {
      if (group.isEmpty) {
        invalidReference = true;
      }
      for (final key in group) {
        final space = byKey[key];
        if (space == null || !_isWetSpace(space)) {
          invalidReference = true;
          continue;
        }
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final missing = expected.where((key) => (counts[key] ?? 0) != 1).toList()
      ..sort();
    if (draft.wetCore.groups.length >
            template.wetCorePolicy.maxWetCoreGroupCount ||
        invalidReference ||
        missing.isNotEmpty) {
      blockers.add(
        _violation(
          code: 'p9.semantic.invalid-wet-core',
          ruleId: 'p9.semantic.wet-core-membership',
          keys: missing,
          facts: {
            'groupCount': draft.wetCore.groups.length,
            'maxGroupCount': template.wetCorePolicy.maxWetCoreGroupCount,
            'invalidReference': invalidReference,
          },
        ),
      );
    }
  }

  void _validateExteriorExposure(
    List<P9SemanticViolation> blockers,
    ApartmentTopologyDraft draft,
    List<DraftSpace> spaces,
  ) {
    for (final space in spaces) {
      if (!space.sourceSpec.requiresExteriorExposure) {
        continue;
      }
      if (!draft.exteriorExposure.assignments.containsKey(space.semanticKey)) {
        blockers.add(
          _violation(
            code: 'p9.semantic.exterior-exposure-unavailable',
            ruleId: 'p9.semantic.required-exterior-exposure',
            keys: [space.semanticKey],
          ),
        );
      }
    }
  }

  _RuleEvaluation _evaluateTemplateRules({
    required List<P9SemanticViolation> blockers,
    required List<P9SemanticPreferenceMiss> preferenceMisses,
    required ApartmentTopologyDraft draft,
    required ApartmentTopologyTemplate template,
    required List<DraftSpace> spaces,
  }) {
    var requiredPasses = 0;
    final byBase = <String, List<DraftSpace>>{};
    for (final space in spaces) {
      byBase.putIfAbsent(space.baseSemanticKey, () => []).add(space);
    }
    for (final values in byBase.values) {
      values.sort(_compareSpace);
    }
    final positiveIntents = draft.adjacency
        .where(
          (intent) =>
              intent.requirement != TopologyAdjacencyRequirement.forbidden,
        )
        .toList();

    for (var index = 0; index < template.adjacencyRules.length; index++) {
      final rule = template.adjacencyRules[index];
      final from = byBase[rule.fromKey] ?? const <DraftSpace>[];
      final to = byBase[rule.toKey] ?? const <DraftSpace>[];
      if (from.isEmpty || to.isEmpty) {
        continue;
      }
      final pairs = _expandPairs(from, to);
      for (final pair in pairs) {
        final ruleId =
            'template:${template.templateId.value}@${template.templateVersion}:adjacency:$index:${pair.stableKey}:${rule.kind.name}';
        final present = positiveIntents.any(
          (intent) =>
              intent.kind == rule.kind &&
              intent.normalizedPairKey == pair.stableKey,
        );
        switch (rule.requirement) {
          case TopologyAdjacencyRequirement.required:
            if (present) {
              requiredPasses++;
            } else {
              blockers.add(
                _violation(
                  code: 'p9.semantic.required-adjacency-missing',
                  ruleId: ruleId,
                  keys: [pair.leftKey, pair.rightKey],
                ),
              );
            }
          case TopologyAdjacencyRequirement.preferred:
            if (!present) {
              preferenceMisses.add(
                P9SemanticPreferenceMiss(
                  ruleId: ruleId,
                  penaltyBp: preferredAdjacencyPenaltyBp,
                  affectedKeys: [pair.leftKey, pair.rightKey],
                ),
              );
            }
          case TopologyAdjacencyRequirement.forbidden:
            if (present) {
              blockers.add(
                _violation(
                  code: 'p9.semantic.forbidden-adjacency-present',
                  ruleId: ruleId,
                  keys: [pair.leftKey, pair.rightKey],
                ),
              );
            }
        }
      }
    }
    return _RuleEvaluation(requiredRulePassCount: requiredPasses);
  }

  List<SemanticSpacePair> _expandPairs(
    List<DraftSpace> from,
    List<DraftSpace> to,
  ) {
    if (from.length == 1) {
      return [
        for (final target in to)
          SemanticSpacePair(from.single.semanticKey, target.semanticKey),
      ];
    }
    if (to.length == 1) {
      return [
        for (final source in from)
          SemanticSpacePair(source.semanticKey, to.single.semanticKey),
      ];
    }
    final count = from.length > to.length ? from.length : to.length;
    return [
      for (var index = 0; index < count; index++)
        SemanticSpacePair(
          from[index % from.length].semanticKey,
          to[index % to.length].semanticKey,
        ),
    ];
  }

  TopologyGeometryHandoff _geometryHandoff(
    ApartmentTopologyDraft draft,
    ApartmentTopologyTemplate template,
    List<DraftSpace> spaces,
  ) {
    final requiredShared = <SemanticSpacePair>[];
    final forbiddenShared = <SemanticSpacePair>[];
    for (final intent in draft.adjacency) {
      if (intent.kind != TopologyAdjacencyKind.directBoundary &&
          intent.kind != TopologyAdjacencyKind.openConnection) {
        continue;
      }
      final pair = SemanticSpacePair(intent.fromSpaceKey, intent.toSpaceKey);
      if (intent.requirement == TopologyAdjacencyRequirement.required) {
        requiredShared.add(pair);
      } else if (intent.requirement == TopologyAdjacencyRequirement.forbidden) {
        forbiddenShared.add(pair);
      }
    }

    final requiredExterior = <String>[
      for (final space in spaces)
        if (space.sourceSpec.requiresExteriorExposure ||
            _isExteriorAppendage(space))
          space.semanticKey,
    ];
    final anchors = <String>[
      draft.circulation.entrySpaceKey,
      for (final space in spaces)
        if (space.sourceSpec.circulationSpace) space.semanticKey,
    ];
    return TopologyGeometryHandoff(
      requiredSharedBoundaryPairs: requiredShared,
      forbiddenSharedBoundaryPairs: forbiddenShared,
      requiredExteriorSpaceKeys: requiredExterior,
      wetCoreGroups: draft.wetCore.groups,
      accessIntents: [
        for (final edge in draft.circulation.accessEdges)
          SemanticAccessIntent(
            fromSpaceKey: edge.fromSpaceKey,
            toSpaceKey: edge.toSpaceKey,
            kind: edge.kind,
          ),
      ],
      circulationAnchorKeys: anchors,
    );
  }
}

final class _RuleEvaluation {
  const _RuleEvaluation({required this.requiredRulePassCount});

  final int requiredRulePassCount;
}

P9SemanticViolation _violation({
  required String code,
  required String ruleId,
  Iterable<String> keys = const [],
  Map<String, Object?> facts = const {},
}) =>
    P9SemanticViolation(
      code: code,
      ruleId: ruleId,
      affectedKeys: keys,
      facts: facts,
    );

bool _isExteriorAppendage(DraftSpace space) =>
    space.areaParticipation == SpaceAreaParticipation.exteriorAppendage ||
    space.usage == SpaceUsage.balcony ||
    space.usage == SpaceUsage.loggia ||
    space.usage == SpaceUsage.terrace;

bool _isBathroomLike(SpaceUsage usage) =>
    usage == SpaceUsage.bathroom ||
    usage == SpaceUsage.wc ||
    usage == SpaceUsage.showerRoom;

bool _isHabitableAppendageHost(SpaceUsage usage) =>
    usage == SpaceUsage.livingRoom ||
    usage == SpaceUsage.kitchenLiving ||
    usage == SpaceUsage.bedroom;

bool _isWetSpace(DraftSpace space) =>
    space.sourceSpec.wetSpace ||
    space.usage == SpaceUsage.kitchen ||
    space.usage == SpaceUsage.kitchenLiving ||
    space.usage == SpaceUsage.bathroom ||
    space.usage == SpaceUsage.wc ||
    space.usage == SpaceUsage.showerRoom ||
    space.usage == SpaceUsage.laundry;

int _compareSpace(DraftSpace left, DraftSpace right) =>
    left.semanticKey.compareTo(right.semanticKey);
