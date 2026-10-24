import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v1.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_draft.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.4 deterministic area fitting', () {
    const fitter = ApartmentAreaFitter();

    test('P9.4-AT-001 exact interior minimum request', () {
      final request = _request(1500);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'a', min: 1000, preferred: 1400, max: 2200),
            _spec(key: 'b', min: 500, preferred: 900, max: 1800),
          ],
        ),
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(_areas(result.fittedDraft!), {'a:1': 1000, 'b:1': 500});
      expect(result.fittedDraft!.allocatedInteriorAreaDm2, 1500);
      expect(result.fittedDraft!.interiorResidualDm2, 0);
    });

    test('P9.4-AT-002 exact interior maximum request', () {
      final request = _request(5000);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'a', min: 1000, preferred: 1500, max: 2500),
            _spec(key: 'b', min: 500, preferred: 1000, max: 2500),
          ],
        ),
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(_areas(result.fittedDraft!), {'a:1': 2500, 'b:1': 2500});
      expect(result.fittedDraft!.interiorResidualDm2, 0);
    });

    test('P9.4-AT-003 request below interior minimum is rejected', () {
      final request = _request(1500);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'a', min: 1000, preferred: 1400, max: 2000),
            _spec(key: 'b', min: 600, preferred: 900, max: 1800),
          ],
        ),
        request: request,
      );

      expect(result.fittedDraft, isNull);
      expect(
        result.failures.map((failure) => failure.code),
        contains('p9.area.request-below-minimum'),
      );
    });

    test('P9.4-AT-004 request above interior maximum is rejected', () {
      final request = _request(5000);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'a', min: 800, preferred: 1400, max: 2000),
            _spec(key: 'b', min: 700, preferred: 1200, max: 2000),
          ],
        ),
        request: request,
      );

      expect(result.fittedDraft, isNull);
      expect(
        result.failures.map((failure) => failure.code),
        contains('p9.area.request-above-maximum'),
      );
    });

    test('P9.4-AT-005 integer remainder distribution is deterministic', () {
      final request = _request(1503);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'a', min: 500, preferred: 1000, max: 2000),
            _spec(key: 'b', min: 500, preferred: 1000, max: 2000),
          ],
        ),
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(_areas(result.fittedDraft!), {'a:1': 752, 'b:1': 751});
    });

    test(
        'P9.4-AT-006 source-order permutation keeps allocation and fingerprint',
        () {
      final request = _request(3201);
      final a = _spec(
        key: 'a',
        min: 700,
        preferred: 1300,
        max: 2200,
        weight: 1200,
      );
      final b = _spec(
        key: 'b',
        min: 600,
        preferred: 1200,
        max: 2100,
        weight: 800,
      );
      final first = fitter.fit(
        draft: _draft(request, [a, b], fingerprint: 'same-draft'),
        request: request,
      );
      final second = fitter.fit(
        draft: _draft(request, [b, a], fingerprint: 'same-draft'),
        request: request,
      );

      expect(_areas(first.fittedDraft!), _areas(second.fittedDraft!));
      expect(
        first.fittedDraft!.areaFitFingerprint,
        second.fittedDraft!.areaFitFingerprint,
      );
    });

    test(
        'P9.4-AT-007 near-fixed bathroom stays at preferred while rooms expand',
        () {
      final request = _request(4000);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(
              key: 'bathroom',
              min: 400,
              preferred: 600,
              max: 1000,
              nearFixed: true,
              usage: SpaceUsage.bathroom,
            ),
            _spec(key: 'bedroom', min: 1000, preferred: 1500, max: 3000),
            _spec(key: 'living', min: 1000, preferred: 1500, max: 3000),
          ],
        ),
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(
        _areas(result.fittedDraft!),
        {'bathroom:1': 600, 'bedroom:1': 1700, 'living:1': 1700},
      );
    });

    test('P9.4-AT-008 appendage area is independent from interior request', () {
      final request = _request(
        2000,
        balconyCount: 1,
        balconyKind: ApartmentBalconyKind.balcony,
      );
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'living', min: 1000, preferred: 1500, max: 3000),
            _spec(
              key: 'balcony',
              min: 300,
              preferred: 500,
              max: 700,
              participation: SpaceAreaParticipation.exteriorAppendage,
              usage: SpaceUsage.balcony,
            ),
          ],
        ),
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(result.fittedDraft!.allocatedInteriorAreaDm2, 2000);
      expect(result.fittedDraft!.exteriorAppendageAreaDm2, 500);
      expect(_areas(result.fittedDraft!)['balcony:1'], 500);
    });

    test(
        'P9.4-AT-009 appendage target changes do not change interior allocation',
        () {
      final request = _request(
        2600,
        balconyCount: 1,
        balconyKind: ApartmentBalconyKind.balcony,
      );
      final interior = [
        _spec(key: 'a', min: 700, preferred: 1200, max: 2200),
        _spec(key: 'b', min: 600, preferred: 1100, max: 2100),
      ];
      final first = fitter.fit(
        draft: _draft(
          request,
          [
            ...interior,
            _spec(
              key: 'balcony',
              min: 300,
              preferred: 500,
              max: 800,
              participation: SpaceAreaParticipation.exteriorAppendage,
              usage: SpaceUsage.balcony,
            ),
          ],
          fingerprint: 'appendage-a',
        ),
        request: request,
      );
      final second = fitter.fit(
        draft: _draft(
          request,
          [
            ...interior,
            _spec(
              key: 'balcony',
              min: 300,
              preferred: 700,
              max: 800,
              participation: SpaceAreaParticipation.exteriorAppendage,
              usage: SpaceUsage.balcony,
            ),
          ],
          fingerprint: 'appendage-b',
        ),
        request: request,
      );

      expect(_interiorAreas(first.fittedDraft!),
          _interiorAreas(second.fittedDraft!));
      expect(first.fittedDraft!.exteriorAppendageAreaDm2, 500);
      expect(second.fittedDraft!.exteriorAppendageAreaDm2, 700);
    });

    test('P9.4-AT-010 same inputs repeated 10000 times keep fingerprint', () {
      final request = _request(3301);
      final draft = _draft(
        request,
        [
          _spec(key: 'a', min: 700, preferred: 1300, max: 2400),
          _spec(key: 'b', min: 600, preferred: 1200, max: 2300),
        ],
      );
      final expected = fitter.fit(draft: draft, request: request).fittedDraft!;

      for (var i = 0; i < 10000; i++) {
        final actual = fitter.fit(draft: draft, request: request).fittedDraft!;
        expect(actual.areaFitFingerprint, expected.areaFitFingerprint);
        expect(actual.allocatedInteriorAreaDm2, 3301);
      }
    });

    test('P9.4-AT-011 production 1..10-room corpus has zero residual', () {
      final catalog = P9ApartmentTopologyCatalogV1.create();
      const filter = ApartmentTopologyCatalogFilter();
      final grammar = ApartmentTopologyGrammarEngine();
      const areas = <int, int>{
        1: 3000,
        2: 5000,
        3: 7000,
        4: 9000,
        5: 11000,
        6: 14000,
        7: 17000,
        8: 20000,
        9: 23000,
        10: 26000,
      };

      for (var rooms = 1; rooms <= 10; rooms++) {
        final request = _request(areas[rooms]!, habitableRoomCount: rooms);
        final templates = filter.compatibleTemplates(catalog, request);
        expect(templates, isNotEmpty,
            reason: 'roomCount=$rooms catalog coverage');
        final expansion =
            grammar.expand(request: request, templates: templates);
        expect(expansion.drafts, isNotEmpty,
            reason: 'roomCount=$rooms grammar');

        for (final draft in expansion.drafts) {
          final result = fitter.fit(draft: draft, request: request);
          expect(
            result.isValid,
            isTrue,
            reason:
                'roomCount=$rooms family=${draft.family.code} failures=${result.failures.map((failure) => failure.code).toList()}',
          );
          expect(result.fittedDraft!.interiorResidualDm2, 0);
          expect(
            result.fittedDraft!.allocatedInteriorAreaDm2,
            request.interiorAreaDm2,
          );
        }
      }
    });

    test('P9.4-AT-012 authoritative allocation state remains integer-only', () {
      final request = _request(2501);
      final result = fitter.fit(
        draft: _draft(
          request,
          [
            _spec(key: 'a', min: 700, preferred: 1200, max: 2000),
            _spec(key: 'b', min: 600, preferred: 1100, max: 2000),
          ],
        ),
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(
        result.fittedDraft!.spaces.map((space) => space.areaDm2),
        everyElement(isA<int>()),
      );
      expect(result.fittedDraft!.areaFitFingerprint, hasLength(64));
    });

    test('duplicate expanded semantic key fails closed', () {
      final request = _request(2000);
      final duplicate = _spec(key: 'a', min: 500, preferred: 1000, max: 2000);
      final result = fitter.fit(
        draft: _draft(request, [duplicate, duplicate]),
        request: request,
      );

      expect(result.fittedDraft, isNull);
      expect(
        result.failures.map((failure) => failure.code),
        contains('p9.area.duplicate-space-key'),
      );
    });
  });
}

Map<String, int> _areas(dynamic fitted) => {
      for (final space in fitted.spaces as Iterable)
        space.semanticKey as String: space.areaDm2 as int,
    };

Map<String, int> _interiorAreas(dynamic fitted) => {
      for (final space in fitted.spaces as Iterable)
        if (space.participation == SpaceAreaParticipation.requestedInteriorArea)
          space.semanticKey as String: space.areaDm2 as int,
    };

NormalizedApartmentRequest _request(
  int areaDm2, {
  int habitableRoomCount = 2,
  int balconyCount = 0,
  ApartmentBalconyKind balconyKind = ApartmentBalconyKind.none,
}) {
  const normalizer = ApartmentRequestNormalizer();
  return normalizer
      .normalize(
        ApartmentRequestInput(
          habitableRoomCount: habitableRoomCount,
          approximateAreaDm2: areaDm2,
          bathroomCount: 1,
          separateWcCount: 0,
          balconyCount: balconyCount,
          balconyKind: balconyKind,
          kitchenMode: ApartmentKitchenMode.separate,
          corridorMode: ApartmentCorridorMode.auto,
          exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
        ),
      )
      .request!;
}

ApartmentTopologyDraft _draft(
  NormalizedApartmentRequest request,
  List<TopologySpaceSpec> specs, {
  String fingerprint = 'fixture-draft',
}) {
  final spaces = <DraftSpace>[
    for (final spec in specs)
      DraftSpace(
        semanticKey: '${spec.semanticKey}:1',
        baseSemanticKey: spec.semanticKey,
        ordinal: 1,
        usage: spec.usage,
        type: spec.type,
        areaParticipation: spec.areaParticipation,
        sourceSpec: spec,
      ),
  ];
  final keys = spaces.map((space) => space.semanticKey).toList();
  return ApartmentTopologyDraft(
    templateId: TemplateId('p9-area-fixture'),
    templateVersion: 1,
    family: ApartmentTopologyFamily.compact,
    variantSeedId: 'fixture-seed',
    intentFingerprint: request.intentFingerprint,
    spaces: spaces,
    adjacency: const [],
    circulation: DraftCirculationGraph(
      entrySpaceKey: keys.first,
      accessEdges: const [],
    ),
    exteriorExposure: DraftExteriorExposure(const {}),
    wetCore: DraftWetCoreGrouping(const []),
    layoutSkeleton: DraftLayoutSkeleton(
      primaryAxis: DraftLayoutAxis.horizontal,
      mirrored: false,
      entrySide: TopologyEntrySide.west,
      stableRoleOrder: keys,
      dayZoneKeys: const [],
      nightZoneKeys: const [],
    ),
    semanticSignature: 'fixture-semantic',
    draftFingerprint: fingerprint,
  );
}

TopologySpaceSpec _spec({
  required String key,
  required int min,
  required int preferred,
  required int max,
  int weight = 1000,
  bool nearFixed = false,
  SpaceAreaParticipation participation =
      SpaceAreaParticipation.requestedInteriorArea,
  SpaceUsage usage = SpaceUsage.livingRoom,
}) =>
    TopologySpaceSpec(
      semanticKey: key,
      usage: usage,
      type: participation == SpaceAreaParticipation.exteriorAppendage
          ? ProjectSpaceType.outdoorArea
          : ProjectSpaceType.room,
      multiplicityMin: 1,
      multiplicityMax: 1,
      areaParticipation: participation,
      minAreaDm2: min,
      preferredAreaDm2: preferred,
      maxAreaDm2: max,
      areaWeightBp: weight,
      nearFixedArea: nearFixed,
      requiresExteriorExposure: false,
      wetSpace: usage == SpaceUsage.bathroom || usage == SpaceUsage.wc,
      circulationSpace: false,
      geometry: const TopologySpaceGeometryConstraints(
        minShortSideMm: 1000,
        minAspectBp: 5000,
        maxAspectBp: 20000,
        maxVertices: 4,
      ),
    );
