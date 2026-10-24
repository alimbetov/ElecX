import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v1.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_draft.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = P9ApartmentTopologyCatalogV1.create();
  const normalizer = ApartmentRequestNormalizer();
  const filter = ApartmentTopologyCatalogFilter();

  group('P9.3 family grammars', () {
    test('P9.3-AT-001 all eight families emit stable unique semantic keys', () {
      final cases = <String, ApartmentRequestInput>{
        'p9-compact-separate': _request(2, 5500),
        'p9-linear-separate': _request(3, 7800),
        'p9-corner-separate': _request(3, 7800),
        'p9-central-corridor-separate': _request(4, 10000),
        'p9-corridor-spine-separate': _request(7, 19000),
        'p9-euro-kitchen-living': _request(
          3,
          7800,
          kitchenMode: ApartmentKitchenMode.kitchenLiving,
        ),
        'p9-open-plan': _request(
          2,
          6000,
          kitchenMode: ApartmentKitchenMode.openPlan,
        ),
        'p9-split-day-night-separate': _request(
          5,
          13000,
          preferDayNightSeparation: true,
        ),
      };
      final families = <ApartmentTopologyFamily>{};

      for (final entry in cases.entries) {
        final draft =
            _expandSingle(catalog, entry.key, entry.value).drafts.first;
        final keys = draft.spaces.map((space) => space.semanticKey).toList();
        families.add(draft.family);

        expect(keys.toSet(), hasLength(keys.length));
        expect(keys.every((key) => key.contains(':')), isTrue);
      }

      expect(families, equals(ApartmentTopologyFamily.values.toSet()));
    });

    test('P9.3-AT-002 compact 2-room draft minimizes circulation roles', () {
      final draft = _expandSingle(
        catalog,
        'p9-compact-separate',
        _request(2, 5500),
      ).drafts.first;

      expect(
        draft.spaces.where((space) => space.usage == SpaceUsage.corridor),
        isEmpty,
      );
      expect(draft.circulation.entrySpaceKey, 'entranceHall:1');
    });

    test('P9.3-AT-003 euro request emits kitchenLiving day anchor', () {
      final draft = _expandSingle(
        catalog,
        'p9-euro-kitchen-living',
        _request(
          3,
          7800,
          kitchenMode: ApartmentKitchenMode.kitchenLiving,
        ),
      ).drafts.first;

      expect(
        draft.spaces.where((space) => space.usage == SpaceUsage.kitchenLiving),
        hasLength(1),
      );
      expect(
        draft.layoutSkeleton.dayZoneKeys,
        contains('kitchenLiving:1'),
      );
    });

    test('P9.3-AT-004 splitDayNight creates distinct public/private groups',
        () {
      final draft = _expandSingle(
        catalog,
        'p9-split-day-night-separate',
        _request(
          5,
          13000,
          preferDayNightSeparation: true,
        ),
      ).drafts.first;

      expect(draft.layoutSkeleton.dayZoneKeys, isNotEmpty);
      expect(draft.layoutSkeleton.nightZoneKeys, isNotEmpty);
      expect(
        draft.layoutSkeleton.dayZoneKeys.toSet().intersection(
              draft.layoutSkeleton.nightZoneKeys.toSet(),
            ),
        isEmpty,
      );
      expect(
        draft.spaces.where((space) => space.usage == SpaceUsage.bedroom).every(
              (space) => draft.layoutSkeleton.nightZoneKeys
                  .contains(space.semanticKey),
            ),
        isTrue,
      );
    });

    test('P9.3-AT-005 corridorSpine supports a qualified 10-room fixture', () {
      final result = _expandSingle(
        catalog,
        'p9-corridor-spine-separate',
        _request(10, 28000),
      );
      final draft = result.drafts.first;
      final habitable = draft.spaces.where(
        (space) =>
            space.usage == SpaceUsage.livingRoom ||
            space.usage == SpaceUsage.bedroom ||
            space.usage == SpaceUsage.kitchenLiving,
      );

      expect(result.failures, isEmpty);
      expect(habitable, hasLength(10));
      expect(
        draft.spaces.where((space) => space.usage == SpaceUsage.bedroom),
        hasLength(9),
      );
    });

    test('P9.3-AT-006 same request/template/seed yields same fingerprint', () {
      final input = _request(3, 7800);
      final first = _expandSingle(catalog, 'p9-linear-separate', input);
      final second = _expandSingle(catalog, 'p9-linear-separate', input);

      expect(
        second.drafts.map((draft) => draft.draftFingerprint),
        first.drafts.map((draft) => draft.draftFingerprint),
      );
    });

    test('P9.3-AT-007 semantically duplicate seeds are suppressed', () {
      final source = catalog.templates.firstWhere(
        (template) => template.templateId.value == 'p9-compact-separate',
      );
      final firstSeed = source.variantSeeds.first;
      final duplicateSeed = TopologyVariantSeed(
        seedId: 'same-semantics-different-id',
        entrySide: firstSeed.entrySide,
        mirrored: firstSeed.mirrored,
        dayNightOrientation: firstSeed.dayNightOrientation,
        balconyStrategy: firstSeed.balconyStrategy,
        stableOrder: firstSeed.stableOrder + 1,
      );
      final duplicateTemplate = ApartmentTopologyTemplate(
        templateId: source.templateId,
        templateVersion: source.templateVersion,
        family: source.family,
        stableOrder: source.stableOrder,
        constraints: source.constraints,
        spaces: source.spaces,
        adjacencyRules: source.adjacencyRules,
        areaProfile: source.areaProfile,
        circulationPolicy: source.circulationPolicy,
        wetCorePolicy: source.wetCorePolicy,
        variantSeeds: [firstSeed, duplicateSeed],
      );
      final request = normalizer.normalize(_request(2, 5500)).request!;
      final result = ApartmentTopologyGrammarEngine().expand(
        request: request,
        templates: [duplicateTemplate],
      );

      expect(result.drafts, hasLength(1));
    });

    test('P9.3-AT-008 expansion hard cap 64 is enforced', () {
      final source = catalog.templates.firstWhere(
        (template) => template.templateId.value == 'p9-compact-separate',
      );
      final request = normalizer.normalize(_request(2, 5500)).request!;
      final engine = ApartmentTopologyGrammarEngine(
        grammars: [_BurstGrammar(source.family, count: 100)],
      );
      final result = engine.expand(request: request, templates: [source]);

      expect(result.drafts, hasLength(64));
    });

    test('P9.3-AT-009 source template order does not change draft order', () {
      final request = normalizer.normalize(_request(4, 10000)).request!;
      final compatible = filter.compatibleTemplates(catalog, request);
      final normal = ApartmentTopologyGrammarEngine().expand(
        request: request,
        templates: compatible,
      );
      final reversed = ApartmentTopologyGrammarEngine().expand(
        request: request,
        templates: compatible.reversed,
      );

      expect(
        reversed.drafts.map((draft) => draft.draftFingerprint),
        normal.drafts.map((draft) => draft.draftFingerprint),
      );
    });

    test('P9.3-AT-010 every adjacency endpoint exists in the draft', () {
      final request = normalizer.normalize(_request(5, 13000)).request!;
      final compatible = filter.compatibleTemplates(catalog, request);
      final result = ApartmentTopologyGrammarEngine().expand(
        request: request,
        templates: compatible,
      );

      expect(result.drafts, isNotEmpty);
      for (final draft in result.drafts) {
        final keys = draft.spaces.map((space) => space.semanticKey).toSet();
        for (final intent in draft.adjacency) {
          expect(keys, contains(intent.fromSpaceKey));
          expect(keys, contains(intent.toSpaceKey));
        }
      }
    });

    test('openPlan preserves distinct spaces plus required open connection',
        () {
      final draft = _expandSingle(
        catalog,
        'p9-open-plan',
        _request(
          2,
          6000,
          kitchenMode: ApartmentKitchenMode.openPlan,
        ),
      ).drafts.first;

      expect(
        draft.spaces.where((space) => space.usage == SpaceUsage.kitchen),
        hasLength(1),
      );
      expect(
        draft.spaces.where((space) => space.usage == SpaceUsage.livingRoom),
        hasLength(1),
      );
      expect(
        draft.adjacency.any(
          (intent) =>
              intent.kind == TopologyAdjacencyKind.openConnection &&
              intent.requirement == TopologyAdjacencyRequirement.required,
        ),
        isTrue,
      );
    });
  });
}

ApartmentTopologyGrammarExpansionResult _expandSingle(
  ApartmentTopologyCatalog catalog,
  String templateId,
  ApartmentRequestInput input,
) {
  const normalizer = ApartmentRequestNormalizer();
  final request = normalizer.normalize(input).request!;
  final template = catalog.templates.firstWhere(
    (item) => item.templateId.value == templateId,
  );
  return ApartmentTopologyGrammarEngine().expand(
    request: request,
    templates: [template],
  );
}

ApartmentRequestInput _request(
  int rooms,
  int areaDm2, {
  ApartmentKitchenMode kitchenMode = ApartmentKitchenMode.separate,
  bool preferDayNightSeparation = false,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: rooms,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: kitchenMode,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
      preferDayNightSeparation: preferDayNightSeparation,
    );

final class _BurstGrammar implements ApartmentTopologyGrammar {
  const _BurstGrammar(this.family, {required this.count});

  @override
  final ApartmentTopologyFamily family;
  final int count;

  @override
  ApartmentTopologyGrammarExpansionResult expand({
    required NormalizedApartmentRequest request,
    required ApartmentTopologyTemplate template,
    required TopologyVariantSeed seed,
  }) =>
      ApartmentTopologyGrammarExpansionResult(
        drafts: [
          for (var index = 0; index < count; index++)
            ApartmentTopologyDraft(
              templateId: template.templateId,
              templateVersion: template.templateVersion,
              family: family,
              variantSeedId: seed.seedId,
              intentFingerprint: request.intentFingerprint,
              spaces: const [],
              adjacency: const [],
              circulation: DraftCirculationGraph(
                entrySpaceKey: 'entry:$index',
                accessEdges: const [],
              ),
              exteriorExposure: DraftExteriorExposure(const {}),
              wetCore: DraftWetCoreGrouping(const []),
              layoutSkeleton: DraftLayoutSkeleton(
                primaryAxis: DraftLayoutAxis.horizontal,
                mirrored: false,
                entrySide: TopologyEntrySide.west,
                stableRoleOrder: ['role:$index'],
                dayZoneKeys: const [],
                nightZoneKeys: const [],
              ),
              semanticSignature: 'semantic-$index',
              draftFingerprint: 'draft-$index',
            ),
        ],
        failures: const [],
      );
}
