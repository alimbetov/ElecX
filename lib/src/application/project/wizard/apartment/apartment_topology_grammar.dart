import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/project_space_semantics.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

final class ApartmentTopologyGrammarExpansionResult {
  ApartmentTopologyGrammarExpansionResult({
    required Iterable<ApartmentTopologyDraft> drafts,
    required Iterable<P9Failure> failures,
  })  : drafts = List.unmodifiable(drafts),
        failures = List.unmodifiable(failures);

  final List<ApartmentTopologyDraft> drafts;
  final List<P9Failure> failures;
}

abstract interface class ApartmentTopologyGrammar {
  ApartmentTopologyFamily get family;

  ApartmentTopologyGrammarExpansionResult expand({
    required NormalizedApartmentRequest request,
    required ApartmentTopologyTemplate template,
    required TopologyVariantSeed seed,
  });
}

/// Registry/engine for all P9 v1 semantic families.
final class ApartmentTopologyGrammarEngine {
  ApartmentTopologyGrammarEngine({Iterable<ApartmentTopologyGrammar>? grammars})
      : _grammars = {
          for (final grammar in grammars ?? _defaultGrammars())
            grammar.family: grammar,
        };

  static const int maxRawDraftsPerRequest = 64;

  final Map<ApartmentTopologyFamily, ApartmentTopologyGrammar> _grammars;

  ApartmentTopologyGrammarExpansionResult expand({
    required NormalizedApartmentRequest request,
    required Iterable<ApartmentTopologyTemplate> templates,
  }) {
    final failures = <P9Failure>[];
    final draftsBySemanticSignature = <String, ApartmentTopologyDraft>{};
    final orderedTemplates = templates.toList()..sort(_compareTemplateStable);

    for (final template in orderedTemplates) {
      final grammar = _grammars[template.family];
      if (grammar == null) {
        failures.add(
          _failure(
            'p9.grammar.unsupported-family',
            template,
            facts: {'family': template.family.code},
          ),
        );
        continue;
      }
      final seeds = template.variantSeeds.toList()
        ..sort((left, right) {
          final order = left.stableOrder.compareTo(right.stableOrder);
          return order != 0 ? order : left.seedId.compareTo(right.seedId);
        });
      if (seeds.length > 12) {
        failures.add(
          _failure(
            'p9.grammar.expansion-limit',
            template,
            facts: {'seedCount': seeds.length, 'max': 12},
          ),
        );
        continue;
      }

      for (final seed in seeds) {
        if (draftsBySemanticSignature.length >= maxRawDraftsPerRequest) {
          break;
        }
        final result = grammar.expand(
          request: request,
          template: template,
          seed: seed,
        );
        failures.addAll(result.failures);
        for (final draft in result.drafts) {
          if (draftsBySemanticSignature.length >= maxRawDraftsPerRequest) {
            break;
          }
          draftsBySemanticSignature.putIfAbsent(
            draft.semanticSignature,
            () => draft,
          );
        }
      }
    }

    return ApartmentTopologyGrammarExpansionResult(
      drafts: draftsBySemanticSignature.values,
      failures: failures,
    );
  }

  static Iterable<ApartmentTopologyGrammar> _defaultGrammars() sync* {
    yield const CompactApartmentTopologyGrammar();
    yield const LinearApartmentTopologyGrammar();
    yield const CornerApartmentTopologyGrammar();
    yield const CentralCorridorApartmentTopologyGrammar();
    yield const CorridorSpineApartmentTopologyGrammar();
    yield const EuroApartmentTopologyGrammar();
    yield const OpenPlanApartmentTopologyGrammar();
    yield const SplitDayNightApartmentTopologyGrammar();
  }
}

final class CompactApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const CompactApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.compact);

  @override
  int corridorCount(NormalizedApartmentRequest request) =>
      request.habitableRoomCount <= 2 ? 0 : 1;
}

final class LinearApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const LinearApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.linear);

  @override
  int corridorCount(NormalizedApartmentRequest request) =>
      request.habitableRoomCount <= 2 ? 0 : 1;
}

final class CornerApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const CornerApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.corner);

  @override
  int corridorCount(NormalizedApartmentRequest request) =>
      request.habitableRoomCount <= 2 ? 0 : 1;
}

final class CentralCorridorApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const CentralCorridorApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.centralCorridor);

  @override
  int corridorCount(NormalizedApartmentRequest request) => 1;

  @override
  DraftLayoutAxis get primaryAxis => DraftLayoutAxis.vertical;
}

final class CorridorSpineApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const CorridorSpineApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.corridorSpine);

  @override
  int corridorCount(NormalizedApartmentRequest request) => 1;
}

final class EuroApartmentTopologyGrammar extends _BaseApartmentTopologyGrammar {
  const EuroApartmentTopologyGrammar() : super(ApartmentTopologyFamily.euro);

  @override
  int corridorCount(NormalizedApartmentRequest request) =>
      request.habitableRoomCount <= 2 ? 0 : 1;
}

final class OpenPlanApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const OpenPlanApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.openPlan);

  @override
  int corridorCount(NormalizedApartmentRequest request) =>
      request.habitableRoomCount <= 2 ? 0 : 1;
}

final class SplitDayNightApartmentTopologyGrammar
    extends _BaseApartmentTopologyGrammar {
  const SplitDayNightApartmentTopologyGrammar()
      : super(ApartmentTopologyFamily.splitDayNight);

  @override
  int corridorCount(NormalizedApartmentRequest request) => 1;
}

abstract class _BaseApartmentTopologyGrammar
    implements ApartmentTopologyGrammar {
  const _BaseApartmentTopologyGrammar(this.family);

  @override
  final ApartmentTopologyFamily family;

  int corridorCount(NormalizedApartmentRequest request);

  DraftLayoutAxis get primaryAxis => DraftLayoutAxis.horizontal;

  @override
  ApartmentTopologyGrammarExpansionResult expand({
    required NormalizedApartmentRequest request,
    required ApartmentTopologyTemplate template,
    required TopologyVariantSeed seed,
  }) {
    if (template.family != family ||
        !template.constraints.supportedHabitableRoomCounts
            .contains(request.habitableRoomCount) ||
        !template.constraints.supportedKitchenModes
            .contains(request.kitchenMode)) {
      return ApartmentTopologyGrammarExpansionResult(
        drafts: const [],
        failures: [
          _failure(
            'p9.grammar.request-template-mismatch',
            template,
            facts: {
              'family': family.code,
              'rooms': request.habitableRoomCount,
              'kitchenMode': request.kitchenMode.code,
            },
          ),
        ],
      );
    }

    final failures = <P9Failure>[];
    final spaces = _expandSpaces(request, template, seed, failures);
    if (failures.isNotEmpty) {
      return ApartmentTopologyGrammarExpansionResult(
        drafts: const [],
        failures: failures,
      );
    }

    final byBaseKey = <String, List<DraftSpace>>{};
    for (final space in spaces) {
      byBaseKey.putIfAbsent(space.baseSemanticKey, () => []).add(space);
    }

    final adjacency = _expandTemplateAdjacency(
      template,
      byBaseKey,
      failures,
    );
    if (failures.isNotEmpty) {
      return ApartmentTopologyGrammarExpansionResult(
        drafts: const [],
        failures: failures,
      );
    }

    _addRequiredAccessAdjacency(request, seed, spaces, adjacency);
    final dedupedAdjacency = _dedupeAdjacency(adjacency);
    final circulation = _circulation(spaces, dedupedAdjacency);
    if (!_isReachableFromEntry(spaces, circulation)) {
      return ApartmentTopologyGrammarExpansionResult(
        drafts: const [],
        failures: [
          _failure(
            'p9.grammar.invalid-circulation-graph',
            template,
            facts: {'seedId': seed.seedId},
          ),
        ],
      );
    }

    final exterior = DraftExteriorExposure(
      _assignExposure(request, seed, spaces),
    );
    final wetCore = DraftWetCoreGrouping(_wetCoreGroups(spaces));
    final layout = _layoutSkeleton(seed, spaces);
    final semanticSignature = _semanticSignature(
      request: request,
      spaces: spaces,
      adjacency: dedupedAdjacency,
      circulation: circulation,
      exterior: exterior,
      wetCore: wetCore,
      layout: layout,
    );
    final fingerprint = p9Sha256Hex(
      <String>[
        'p9.apartment.draft',
        'intent=${request.intentFingerprint}',
        'template=${template.templateId.value}@${template.templateVersion}',
        'family=${family.code}',
        'seed=${seed.seedId}',
        'semantic=$semanticSignature',
      ].join('\n'),
    );

    return ApartmentTopologyGrammarExpansionResult(
      drafts: [
        ApartmentTopologyDraft(
          templateId: template.templateId,
          templateVersion: template.templateVersion,
          family: family,
          variantSeedId: seed.seedId,
          intentFingerprint: request.intentFingerprint,
          spaces: spaces,
          adjacency: dedupedAdjacency,
          circulation: circulation,
          exteriorExposure: exterior,
          wetCore: wetCore,
          layoutSkeleton: layout,
          semanticSignature: semanticSignature,
          draftFingerprint: fingerprint,
        ),
      ],
      failures: const [],
    );
  }

  List<DraftSpace> _expandSpaces(
    NormalizedApartmentRequest request,
    ApartmentTopologyTemplate template,
    TopologyVariantSeed seed,
    List<P9Failure> failures,
  ) {
    final spaces = <DraftSpace>[];
    final specs = template.spaces.toList()
      ..sort(
        (left, right) =>
            _baseSpaceOrder(left).compareTo(_baseSpaceOrder(right)),
      );

    for (final spec in specs) {
      final count = _multiplicity(request, seed, spec);
      if (count < spec.multiplicityMin || count > spec.multiplicityMax) {
        failures.add(
          _failure(
            'p9.grammar.invalid-template-contract',
            template,
            facts: {
              'semanticKey': spec.semanticKey,
              'requestedMultiplicity': count,
              'min': spec.multiplicityMin,
              'max': spec.multiplicityMax,
            },
          ),
        );
        continue;
      }
      for (var ordinal = 1; ordinal <= count; ordinal++) {
        spaces.add(
          DraftSpace(
            semanticKey: '${spec.semanticKey}:$ordinal',
            baseSemanticKey: spec.semanticKey,
            ordinal: ordinal,
            usage: spec.usage,
            type: spec.type,
            areaParticipation: spec.areaParticipation,
            sourceSpec: spec,
          ),
        );
      }
    }
    spaces.sort(_compareDraftSpace);
    final keys = <String>{};
    for (final space in spaces) {
      if (!keys.add(space.semanticKey)) {
        failures.add(
          _failure(
            'p9.grammar.duplicate-semantic-key',
            template,
            facts: {'semanticKey': space.semanticKey},
          ),
        );
      }
    }
    return spaces;
  }

  int _multiplicity(
    NormalizedApartmentRequest request,
    TopologyVariantSeed seed,
    TopologySpaceSpec spec,
  ) {
    switch (spec.usage) {
      case SpaceUsage.livingRoom:
      case SpaceUsage.kitchenLiving:
      case SpaceUsage.kitchen:
      case SpaceUsage.entranceHall:
        return 1;
      case SpaceUsage.bedroom:
        return request.habitableRoomCount - 1;
      case SpaceUsage.bathroom:
        return request.bathroomCount;
      case SpaceUsage.wc:
        return request.separateWcCount;
      case SpaceUsage.corridor:
        return corridorCount(request);
      case SpaceUsage.balcony:
        if (request.balconyCount == 0 ||
            request.balconyKind == ApartmentBalconyKind.loggia) {
          return 0;
        }
        if (request.balconyKind == ApartmentBalconyKind.either &&
            seed.stableOrder.isOdd) {
          return 0;
        }
        return request.balconyCount;
      case SpaceUsage.loggia:
        if (request.balconyCount == 0 ||
            request.balconyKind == ApartmentBalconyKind.balcony) {
          return 0;
        }
        if (request.balconyKind == ApartmentBalconyKind.either &&
            seed.stableOrder.isEven) {
          return 0;
        }
        return request.balconyCount;
      default:
        return spec.multiplicityMin;
    }
  }

  List<DraftAdjacencyIntent> _expandTemplateAdjacency(
    ApartmentTopologyTemplate template,
    Map<String, List<DraftSpace>> byBaseKey,
    List<P9Failure> failures,
  ) {
    final result = <DraftAdjacencyIntent>[];
    for (final rule in template.adjacencyRules) {
      final from = byBaseKey[rule.fromKey] ?? const <DraftSpace>[];
      final to = byBaseKey[rule.toKey] ?? const <DraftSpace>[];
      if (from.isEmpty || to.isEmpty) {
        if (rule.requirement == TopologyAdjacencyRequirement.required) {
          failures.add(
            _failure(
              'p9.grammar.missing-required-role',
              template,
              facts: {'fromKey': rule.fromKey, 'toKey': rule.toKey},
            ),
          );
        }
        continue;
      }

      if (from.length == 1) {
        for (final target in to) {
          result
              .add(_intent(rule, from.single.semanticKey, target.semanticKey));
        }
      } else if (to.length == 1) {
        for (final source in from) {
          result.add(_intent(rule, source.semanticKey, to.single.semanticKey));
        }
      } else {
        final count = from.length > to.length ? from.length : to.length;
        for (var index = 0; index < count; index++) {
          result.add(
            _intent(
              rule,
              from[index % from.length].semanticKey,
              to[index % to.length].semanticKey,
            ),
          );
        }
      }
    }
    return result;
  }

  DraftAdjacencyIntent _intent(
    TopologyAdjacencyRule rule,
    String from,
    String to,
  ) =>
      DraftAdjacencyIntent(
        fromSpaceKey: from,
        toSpaceKey: to,
        requirement: rule.requirement,
        kind: rule.kind,
        minSharedBoundaryMm: rule.minSharedBoundaryMm,
      );

  void _addRequiredAccessAdjacency(
    NormalizedApartmentRequest request,
    TopologyVariantSeed seed,
    List<DraftSpace> spaces,
    List<DraftAdjacencyIntent> adjacency,
  ) {
    final entry = _firstUsage(spaces, SpaceUsage.entranceHall);
    final corridor = _firstUsage(spaces, SpaceUsage.corridor);
    final distribution = corridor ?? entry;
    final day = _firstUsage(spaces, SpaceUsage.kitchenLiving) ??
        _firstUsage(spaces, SpaceUsage.livingRoom);
    if (entry == null || day == null) {
      return;
    }

    if (distribution != null && distribution.semanticKey != entry.semanticKey) {
      adjacency
          .add(_requiredAccess(entry.semanticKey, distribution.semanticKey));
    }
    if (distribution != null && distribution.semanticKey != day.semanticKey) {
      adjacency.add(_requiredAccess(distribution.semanticKey, day.semanticKey));
    }

    for (final space in spaces) {
      if (distribution == null ||
          space.semanticKey == distribution.semanticKey) {
        continue;
      }
      if (space.usage == SpaceUsage.bedroom ||
          space.usage == SpaceUsage.bathroom ||
          space.usage == SpaceUsage.wc) {
        adjacency
            .add(_requiredAccess(distribution.semanticKey, space.semanticKey));
      }
    }

    final kitchen = _firstUsage(spaces, SpaceUsage.kitchen);
    if (kitchen != null &&
        request.kitchenMode == ApartmentKitchenMode.separate) {
      adjacency.add(
        _requiredAccess((distribution ?? day).semanticKey, kitchen.semanticKey),
      );
    }

    final appendages = spaces
        .where(
          (space) =>
              space.usage == SpaceUsage.balcony ||
              space.usage == SpaceUsage.loggia,
        )
        .toList();
    final bedrooms =
        spaces.where((space) => space.usage == SpaceUsage.bedroom).toList();
    for (final appendage in appendages) {
      final host = seed.balconyStrategy == BalconyAttachmentStrategy.bedroom &&
              bedrooms.isNotEmpty
          ? bedrooms.first
          : day;
      adjacency.add(_requiredAccess(host.semanticKey, appendage.semanticKey));
    }

    if (request.kitchenMode == ApartmentKitchenMode.openPlan &&
        kitchen != null) {
      adjacency.add(
        DraftAdjacencyIntent(
          fromSpaceKey: day.semanticKey,
          toSpaceKey: kitchen.semanticKey,
          requirement: TopologyAdjacencyRequirement.required,
          kind: TopologyAdjacencyKind.openConnection,
          minSharedBoundaryMm: 1200,
        ),
      );
    }
  }

  DraftAdjacencyIntent _requiredAccess(String from, String to) =>
      DraftAdjacencyIntent(
        fromSpaceKey: from,
        toSpaceKey: to,
        requirement: TopologyAdjacencyRequirement.required,
        kind: TopologyAdjacencyKind.access,
      );

  List<DraftAdjacencyIntent> _dedupeAdjacency(
    Iterable<DraftAdjacencyIntent> values,
  ) {
    final byKey = <String, DraftAdjacencyIntent>{};
    final sorted = values.toList()
      ..sort(
          (left, right) => _adjacencyKey(left).compareTo(_adjacencyKey(right)));
    for (final value in sorted) {
      byKey.putIfAbsent(_adjacencyKey(value), () => value);
    }
    return List.unmodifiable(byKey.values);
  }

  String _adjacencyKey(DraftAdjacencyIntent value) =>
      '${value.normalizedPairKey}|${value.kind.name}|${value.requirement.name}';

  DraftCirculationGraph _circulation(
    List<DraftSpace> spaces,
    List<DraftAdjacencyIntent> adjacency,
  ) {
    final entry = _firstUsage(spaces, SpaceUsage.entranceHall);
    final edges = <DraftAccessEdge>[];
    for (final intent in adjacency) {
      if (intent.requirement != TopologyAdjacencyRequirement.required) {
        continue;
      }
      if (intent.kind == TopologyAdjacencyKind.access ||
          intent.kind == TopologyAdjacencyKind.openConnection) {
        edges.add(
          DraftAccessEdge(
            fromSpaceKey: intent.fromSpaceKey,
            toSpaceKey: intent.toSpaceKey,
            kind: intent.kind == TopologyAdjacencyKind.openConnection
                ? DraftAccessKind.openPassage
                : DraftAccessKind.door,
          ),
        );
      }
    }
    edges.sort((left, right) {
      final pair = left.normalizedPairKey.compareTo(right.normalizedPairKey);
      return pair != 0 ? pair : left.kind.name.compareTo(right.kind.name);
    });
    return DraftCirculationGraph(
      entrySpaceKey: entry?.semanticKey ?? '',
      accessEdges: edges,
    );
  }

  bool _isReachableFromEntry(
    List<DraftSpace> spaces,
    DraftCirculationGraph graph,
  ) {
    if (graph.entrySpaceKey.isEmpty) {
      return false;
    }
    final neighbors = <String, Set<String>>{};
    for (final edge in graph.accessEdges) {
      neighbors.putIfAbsent(edge.fromSpaceKey, () => {}).add(edge.toSpaceKey);
      neighbors.putIfAbsent(edge.toSpaceKey, () => {}).add(edge.fromSpaceKey);
    }
    final visited = <String>{graph.entrySpaceKey};
    final queue = <String>[graph.entrySpaceKey];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final next in neighbors[current] ?? const <String>{}) {
        if (visited.add(next)) {
          queue.add(next);
        }
      }
    }
    return spaces.every((space) => visited.contains(space.semanticKey));
  }

  Map<String, DraftExteriorSide> _assignExposure(
    NormalizedApartmentRequest request,
    TopologyVariantSeed seed,
    List<DraftSpace> spaces,
  ) {
    final exposed = spaces
        .where(
          (space) =>
              space.sourceSpec.requiresExteriorExposure ||
              space.areaParticipation ==
                  SpaceAreaParticipation.exteriorAppendage,
        )
        .toList();
    final sides = _exposureSides(request, seed);
    final result = <String, DraftExteriorSide>{};
    for (var index = 0; index < exposed.length; index++) {
      result[exposed[index].semanticKey] = sides[index % sides.length];
    }
    return result;
  }

  List<DraftExteriorSide> _exposureSides(
    NormalizedApartmentRequest request,
    TopologyVariantSeed seed,
  ) {
    final west =
        seed.mirrored ? DraftExteriorSide.east : DraftExteriorSide.west;
    final east =
        seed.mirrored ? DraftExteriorSide.west : DraftExteriorSide.east;
    if (request.exteriorExposurePreference ==
        ApartmentExteriorExposurePreference.oneSide) {
      return [west];
    }
    if (request.exteriorExposurePreference ==
        ApartmentExteriorExposurePreference.corner) {
      return [west, DraftExteriorSide.north];
    }
    if (request.exteriorExposurePreference ==
        ApartmentExteriorExposurePreference.oppositeSides) {
      return [west, east];
    }
    if (family == ApartmentTopologyFamily.corner) {
      return [west, DraftExteriorSide.north];
    }
    if (family == ApartmentTopologyFamily.linear ||
        family == ApartmentTopologyFamily.corridorSpine) {
      return [west, east];
    }
    return [west];
  }

  List<List<String>> _wetCoreGroups(List<DraftSpace> spaces) {
    final wetKeys = spaces
        .where(
          (space) =>
              space.sourceSpec.wetSpace ||
              space.usage == SpaceUsage.kitchen ||
              space.usage == SpaceUsage.kitchenLiving,
        )
        .map((space) => space.semanticKey)
        .toList()
      ..sort();
    return wetKeys.isEmpty ? const [] : [wetKeys];
  }

  DraftLayoutSkeleton _layoutSkeleton(
    TopologyVariantSeed seed,
    List<DraftSpace> spaces,
  ) {
    final day = spaces
        .where(
          (space) =>
              space.usage == SpaceUsage.livingRoom ||
              space.usage == SpaceUsage.kitchen ||
              space.usage == SpaceUsage.kitchenLiving,
        )
        .map((space) => space.semanticKey)
        .toList();
    final night = spaces
        .where(
          (space) =>
              space.usage == SpaceUsage.bedroom ||
              (family == ApartmentTopologyFamily.splitDayNight &&
                  (space.usage == SpaceUsage.bathroom ||
                      space.usage == SpaceUsage.wc)),
        )
        .map((space) => space.semanticKey)
        .toList();
    final roleOrder = spaces.map((space) => space.semanticKey).toList();
    if (seed.dayNightOrientation == DayNightOrientation.nightFirst) {
      roleOrder.sort((left, right) {
        final leftNight = night.contains(left) ? 0 : 1;
        final rightNight = night.contains(right) ? 0 : 1;
        final group = leftNight.compareTo(rightNight);
        return group != 0 ? group : left.compareTo(right);
      });
    }
    return DraftLayoutSkeleton(
      primaryAxis: primaryAxis,
      mirrored: seed.mirrored,
      entrySide: seed.entrySide,
      stableRoleOrder: roleOrder,
      dayZoneKeys: day,
      nightZoneKeys: night,
    );
  }

  String _semanticSignature({
    required NormalizedApartmentRequest request,
    required List<DraftSpace> spaces,
    required List<DraftAdjacencyIntent> adjacency,
    required DraftCirculationGraph circulation,
    required DraftExteriorExposure exterior,
    required DraftWetCoreGrouping wetCore,
    required DraftLayoutSkeleton layout,
  }) {
    final lines = <String>[
      'p9.apartment.draft.semantic',
      'intent=${request.intentFingerprint}',
      'family=${family.code}',
      for (final space in spaces)
        'space=${space.semanticKey}|${space.usage.name}|${space.type.name}|${space.areaParticipation.name}',
      for (final intent in adjacency)
        'adj=${intent.normalizedPairKey}|${intent.kind.name}|${intent.requirement.name}|${intent.minSharedBoundaryMm ?? '-'}',
      'entry=${circulation.entrySpaceKey}',
      for (final edge in circulation.accessEdges)
        'access=${edge.normalizedPairKey}|${edge.kind.name}',
      for (final key in exterior.assignments.keys.toList()..sort())
        'exposure=$key|${exterior.assignments[key]!.name}',
      for (var index = 0; index < wetCore.groups.length; index++)
        'wet=$index|${(wetCore.groups[index].toList()..sort()).join(',')}',
      'layout=${layout.primaryAxis.name}|${layout.entrySide.name}|${layout.mirrored}',
      'roles=${layout.stableRoleOrder.join(',')}',
      'day=${layout.dayZoneKeys.join(',')}',
      'night=${layout.nightZoneKeys.join(',')}',
    ];
    return p9Sha256Hex(lines.join('\n'));
  }

  DraftSpace? _firstUsage(List<DraftSpace> spaces, SpaceUsage usage) {
    for (final space in spaces) {
      if (space.usage == usage) {
        return space;
      }
    }
    return null;
  }

  int _baseSpaceOrder(TopologySpaceSpec spec) {
    if (spec.usage == SpaceUsage.entranceHall) {
      return 0;
    }
    if (spec.usage == SpaceUsage.livingRoom ||
        spec.usage == SpaceUsage.kitchenLiving) {
      return 10;
    }
    if (spec.usage == SpaceUsage.kitchen) {
      return 20;
    }
    if (spec.usage == SpaceUsage.corridor) {
      return 30;
    }
    if (spec.usage == SpaceUsage.bedroom) {
      return 40;
    }
    if (spec.usage == SpaceUsage.bathroom) {
      return 50;
    }
    if (spec.usage == SpaceUsage.wc) {
      return 60;
    }
    if (spec.usage == SpaceUsage.balcony ||
        spec.usage == SpaceUsage.loggia ||
        spec.usage == SpaceUsage.terrace) {
      return 90;
    }
    return 80;
  }

  int _compareDraftSpace(DraftSpace left, DraftSpace right) {
    final role = _baseSpaceOrder(left.sourceSpec)
        .compareTo(_baseSpaceOrder(right.sourceSpec));
    if (role != 0) {
      return role;
    }
    final key = left.baseSemanticKey.compareTo(right.baseSemanticKey);
    return key != 0 ? key : left.ordinal.compareTo(right.ordinal);
  }
}

int _compareTemplateStable(
  ApartmentTopologyTemplate left,
  ApartmentTopologyTemplate right,
) {
  final family =
      _familyOrder(left.family).compareTo(_familyOrder(right.family));
  if (family != 0) {
    return family;
  }
  final stable = left.stableOrder.compareTo(right.stableOrder);
  if (stable != 0) {
    return stable;
  }
  final id = left.templateId.value.compareTo(right.templateId.value);
  return id != 0 ? id : left.templateVersion.compareTo(right.templateVersion);
}

int _familyOrder(ApartmentTopologyFamily family) => switch (family) {
      ApartmentTopologyFamily.compact => 0,
      ApartmentTopologyFamily.linear => 1,
      ApartmentTopologyFamily.corner => 2,
      ApartmentTopologyFamily.centralCorridor => 3,
      ApartmentTopologyFamily.corridorSpine => 4,
      ApartmentTopologyFamily.euro => 5,
      ApartmentTopologyFamily.openPlan => 6,
      ApartmentTopologyFamily.splitDayNight => 7,
    };

P9Failure _failure(
  String code,
  ApartmentTopologyTemplate template, {
  Map<String, Object?> facts = const {},
}) =>
    P9Failure(
      code: code,
      stage: P9FailureStage.grammar,
      severity: P9FailureSeverity.blocker,
      facts: {
        'templateId': template.templateId.value,
        'templateVersion': template.templateVersion,
        ...facts,
      },
    );
