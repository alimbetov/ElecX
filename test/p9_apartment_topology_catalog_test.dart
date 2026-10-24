import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v1.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.2 production catalog', () {
    final catalog = P9ApartmentTopologyCatalogV1.create();
    const normalizer = ApartmentRequestNormalizer();
    const filter = ApartmentTopologyCatalogFilter();

    test('production v1 catalog passes complete integrity validation', () {
      expect(catalog.catalogVersion, 1);
      expect(catalog.validate(), isEmpty);
      expect(catalog.templates, isNotEmpty);
    });

    test('P9.2-AT-008 3-room 78m2 request returns stable compatible set', () {
      final request = normalizer.normalize(
        _request(roomCount: 3, areaDm2: 7800),
      ).request!;
      final first = filter.compatibleTemplates(catalog, request);
      final second = filter.compatibleTemplates(catalog, request);

      expect(first, isNotEmpty);
      expect(
        first.map((template) => template.templateId.value),
        second.map((template) => template.templateId.value),
      );
      expect(
        first.map((template) => template.family).toSet().length,
        greaterThanOrEqualTo(3),
      );
    });

    test('P9.2-AT-009 incompatible template exposes kitchen-mode reason', () {
      final request = normalizer.normalize(
        _request(
          roomCount: 3,
          areaDm2: 7800,
          kitchenMode: ApartmentKitchenMode.openPlan,
        ),
      ).request!;
      final evaluated = filter.evaluate(catalog, request);
      final separateTemplate = evaluated.firstWhere(
        (item) => item.template.templateId.value == 'p9-compact-separate',
      );

      expect(separateTemplate.compatible, isFalse);
      expect(
        separateTemplate.reasons.map((reason) => reason.code),
        contains('p9.catalog.kitchen-mode'),
      );
    });

    test('P9.2-AT-010 preferred family changes order only among valid paths', () {
      final base = normalizer.normalize(
        _request(roomCount: 4, areaDm2: 10000),
      ).request!;
      final preferred = normalizer.normalize(
        _request(
          roomCount: 4,
          areaDm2: 10000,
          preferredFamily: ApartmentTopologyFamily.corner,
        ),
      ).request!;

      final baseIds = filter
          .compatibleTemplates(catalog, base)
          .map((template) => template.templateId.value)
          .toSet();
      final preferredTemplates = filter.compatibleTemplates(catalog, preferred);
      final preferredIds =
          preferredTemplates.map((template) => template.templateId.value).toSet();

      expect(preferredIds, baseIds);
      expect(preferredTemplates.first.family, ApartmentTopologyFamily.corner);
    });

    test('P9.2-AT-011 source order cannot change filtered order', () {
      final request = normalizer.normalize(
        _request(roomCount: 4, areaDm2: 10000),
      ).request!;
      final reversed = ApartmentTopologyCatalog(
        catalogVersion: catalog.catalogVersion,
        templates: catalog.templates.reversed,
      );

      final normalIds = filter
          .compatibleTemplates(catalog, request)
          .map((template) => template.templateId.value)
          .toList();
      final reversedIds = filter
          .compatibleTemplates(reversed, request)
          .map((template) => template.templateId.value)
          .toList();

      expect(reversedIds, normalIds);
    });

    test('P9.2-AT-013 every room count 1..10 has a qualified separate path', () {
      for (var rooms = 1; rooms <= 10; rooms++) {
        final request = normalizer.normalize(
          _request(roomCount: rooms, areaDm2: _representativeArea(rooms)),
        ).request!;
        final compatible = filter.compatibleTemplates(catalog, request);

        expect(
          compatible,
          isNotEmpty,
          reason: 'room count $rooms must have a production catalog path',
        );
      }
    });

    test('minimum catalog diversity targets hold for 1..5 room separate flow', () {
      final minimumSeeds = {1: 3, 2: 4, 3: 5, 4: 5, 5: 3};
      final minimumFamilies = {1: 2, 2: 3, 3: 3, 4: 3, 5: 2};

      for (var rooms = 1; rooms <= 5; rooms++) {
        final request = normalizer.normalize(
          _request(roomCount: rooms, areaDm2: _representativeArea(rooms)),
        ).request!;
        final compatible = filter.compatibleTemplates(catalog, request);
        final seedCount = compatible.fold<int>(
          0,
          (sum, template) => sum + template.variantSeeds.length,
        );
        final familyCount = compatible.map((template) => template.family).toSet().length;

        expect(seedCount, greaterThanOrEqualTo(minimumSeeds[rooms]!));
        expect(familyCount, greaterThanOrEqualTo(minimumFamilies[rooms]!));
      }
    });
  });

  group('P9.2 integrity failures', () {
    test('P9.2-AT-001 duplicate template identity rejected', () {
      final template = _fixtureTemplate();
      final catalog = ApartmentTopologyCatalog(
        catalogVersion: 1,
        templates: [template, template],
      );

      expect(
        catalog.validate().map((issue) => issue.code),
        contains('p9.catalog.duplicate-template-identity'),
      );
    });

    test('P9.2-AT-002 duplicate seed identity rejected', () {
      final template = _fixtureTemplate(
        seeds: const [
          TopologyVariantSeed(
            seedId: 'duplicate',
            entrySide: TopologyEntrySide.west,
            mirrored: false,
            dayNightOrientation: DayNightOrientation.none,
            balconyStrategy: BalconyAttachmentStrategy.daySpace,
            stableOrder: 0,
          ),
          TopologyVariantSeed(
            seedId: 'duplicate',
            entrySide: TopologyEntrySide.east,
            mirrored: true,
            dayNightOrientation: DayNightOrientation.none,
            balconyStrategy: BalconyAttachmentStrategy.daySpace,
            stableOrder: 1,
          ),
        ],
      );

      expect(
        _catalog(template).validate().map((issue) => issue.code),
        contains('p9.catalog.duplicate-seed-identity'),
      );
    });

    test('P9.2-AT-003 impossible min/preferred/max rejected', () {
      final spaces = _fixtureSpaces();
      final invalid = TopologySpaceSpec(
        semanticKey: 'livingRoom',
        usage: SpaceUsage.livingRoom,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 1200,
        preferredAreaDm2: 1000,
        maxAreaDm2: 900,
        areaWeightBp: 1000,
        nearFixedArea: false,
        requiresExteriorExposure: true,
        wetSpace: false,
        circulationSpace: false,
        geometry: _roomGeometry,
      );
      spaces[0] = invalid;

      expect(
        _catalog(_fixtureTemplate(spaces: spaces))
            .validate()
            .map((issue) => issue.code),
        contains('p9.catalog.invalid-space-area-range'),
      );
    });

    test('P9.2-AT-004 invalid adjacency reference rejected', () {
      final template = _fixtureTemplate(
        adjacency: const [
          TopologyAdjacencyRule(
            fromKey: 'livingRoom',
            toKey: 'missing',
            requirement: TopologyAdjacencyRequirement.required,
            kind: TopologyAdjacencyKind.access,
          ),
        ],
      );

      expect(
        _catalog(template).validate().map((issue) => issue.code),
        contains('p9.catalog.invalid-adjacency-reference'),
      );
    });

    test('P9.2-AT-005 balcony counted as interior rejected', () {
      final spaces = _fixtureSpaces();
      spaces.add(
        TopologySpaceSpec(
          semanticKey: 'balcony',
          usage: SpaceUsage.balcony,
          type: ProjectSpaceType.room,
          multiplicityMin: 0,
          multiplicityMax: 1,
          areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
          minAreaDm2: 150,
          preferredAreaDm2: 250,
          maxAreaDm2: 500,
          areaWeightBp: 200,
          nearFixedArea: true,
          requiresExteriorExposure: false,
          wetSpace: false,
          circulationSpace: false,
          geometry: _appendageGeometry,
        ),
      );

      expect(
        _catalog(_fixtureTemplate(spaces: spaces))
            .validate()
            .map((issue) => issue.code),
        contains('p9.catalog.appendage-counted-as-interior'),
      );
    });

    test('P9.2-AT-006 invalid short-side/aspect constraints rejected', () {
      final spaces = _fixtureSpaces();
      spaces[0] = TopologySpaceSpec(
        semanticKey: 'livingRoom',
        usage: SpaceUsage.livingRoom,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 800,
        preferredAreaDm2: 1200,
        maxAreaDm2: 2500,
        areaWeightBp: 1000,
        nearFixedArea: false,
        requiresExteriorExposure: false,
        wetSpace: false,
        circulationSpace: false,
        geometry: const TopologySpaceGeometryConstraints(
          minShortSideMm: 0,
          minAspectBp: 20000,
          maxAspectBp: 10000,
          maxVertices: 3,
        ),
      );

      expect(
        _catalog(_fixtureTemplate(spaces: spaces))
            .validate()
            .map((issue) => issue.code),
        contains('p9.catalog.invalid-geometry-constraints'),
      );
    });

    test('P9.2-AT-007 openPlan without explicit open connection rejected', () {
      final template = _fixtureTemplate(
        kitchenModes: const {ApartmentKitchenMode.openPlan},
      );

      expect(
        _catalog(template).validate().map((issue) => issue.code),
        contains('p9.catalog.open-plan-contract-missing'),
      );
    });
  });
}

const _roomGeometry = TopologySpaceGeometryConstraints(
  minShortSideMm: 1600,
  minLongSideMm: 2200,
  minAspectBp: 3500,
  maxAspectBp: 28000,
  minExteriorExposureMm: 1600,
  maxVertices: 8,
);

const _serviceGeometry = TopologySpaceGeometryConstraints(
  minShortSideMm: 900,
  minLongSideMm: 1200,
  minAspectBp: 3000,
  maxAspectBp: 35000,
  maxVertices: 8,
);

const _appendageGeometry = TopologySpaceGeometryConstraints(
  minShortSideMm: 800,
  minLongSideMm: 1200,
  minAspectBp: 2500,
  maxAspectBp: 50000,
  maxVertices: 8,
);

ApartmentRequestInput _request({
  required int roomCount,
  required int areaDm2,
  ApartmentKitchenMode kitchenMode = ApartmentKitchenMode.separate,
  ApartmentTopologyFamily? preferredFamily,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: kitchenMode,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
      preferredFamily: preferredFamily,
    );

int _representativeArea(int roomCount) => switch (roomCount) {
      1 => 4000,
      2 => 5500,
      3 => 7800,
      4 => 10000,
      5 => 13000,
      6 => 16000,
      7 => 19000,
      8 => 22000,
      9 => 25000,
      10 => 28000,
      _ => throw RangeError.range(roomCount, 1, 10),
    };

ApartmentTopologyCatalog _catalog(ApartmentTopologyTemplate template) =>
    ApartmentTopologyCatalog(catalogVersion: 1, templates: [template]);

ApartmentTopologyTemplate _fixtureTemplate({
  List<TopologySpaceSpec>? spaces,
  List<TopologyAdjacencyRule>? adjacency,
  List<TopologyVariantSeed>? seeds,
  Set<ApartmentKitchenMode> kitchenModes = const {ApartmentKitchenMode.separate},
}) =>
    ApartmentTopologyTemplate(
      templateId: TemplateId('fixture-template'),
      templateVersion: 1,
      family: ApartmentTopologyFamily.compact,
      stableOrder: 0,
      constraints: ApartmentTemplateConstraints(
        supportedHabitableRoomCounts: const {2},
        minInteriorAreaDm2: 2500,
        maxInteriorAreaDm2: 10000,
        supportedBathroomCounts: const {1},
        supportedSeparateWcCounts: const {0},
        supportedBalconyCounts: const {0},
        supportedBalconyKinds: const {ApartmentBalconyKind.none},
        supportedKitchenModes: kitchenModes,
        supportedCorridorModes: const {ApartmentCorridorMode.compact},
        supportedExteriorExposurePreferences: const {
          ApartmentExteriorExposurePreference.oneSide,
        },
        supportsDayNightSeparation: false,
      ),
      spaces: spaces ?? _fixtureSpaces(),
      adjacencyRules: adjacency ??
          const [
            TopologyAdjacencyRule(
              fromKey: 'entranceHall',
              toKey: 'livingRoom',
              requirement: TopologyAdjacencyRequirement.required,
              kind: TopologyAdjacencyKind.access,
            ),
          ],
      areaProfile: const TopologyAreaProfile(
        maxCirculationAreaBp: 1800,
        serviceAreaWeightBp: 2500,
        habitableAreaWeightBp: 7500,
      ),
      circulationPolicy: const CirculationPolicy(
        maxCirculationSpaceCount: 2,
        requireEntryDistribution: true,
      ),
      wetCorePolicy: const WetCorePolicy(
        maxWetCoreGroupCount: 1,
        maxGroupSeparationMm: 3000,
        preferSharedServiceBoundary: true,
      ),
      variantSeeds: seeds ??
          const [
            TopologyVariantSeed(
              seedId: 'fixture-a',
              entrySide: TopologyEntrySide.west,
              mirrored: false,
              dayNightOrientation: DayNightOrientation.none,
              balconyStrategy: BalconyAttachmentStrategy.daySpace,
              stableOrder: 0,
            ),
          ],
    );

List<TopologySpaceSpec> _fixtureSpaces() => [
      const TopologySpaceSpec(
        semanticKey: 'livingRoom',
        usage: SpaceUsage.livingRoom,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 800,
        preferredAreaDm2: 1200,
        maxAreaDm2: 2500,
        areaWeightBp: 1000,
        nearFixedArea: false,
        requiresExteriorExposure: true,
        wetSpace: false,
        circulationSpace: false,
        geometry: _roomGeometry,
      ),
      const TopologySpaceSpec(
        semanticKey: 'bedroom',
        usage: SpaceUsage.bedroom,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 650,
        preferredAreaDm2: 1000,
        maxAreaDm2: 2200,
        areaWeightBp: 1000,
        nearFixedArea: false,
        requiresExteriorExposure: true,
        wetSpace: false,
        circulationSpace: false,
        geometry: _roomGeometry,
      ),
      const TopologySpaceSpec(
        semanticKey: 'kitchen',
        usage: SpaceUsage.kitchen,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 450,
        preferredAreaDm2: 800,
        maxAreaDm2: 1800,
        areaWeightBp: 800,
        nearFixedArea: false,
        requiresExteriorExposure: true,
        wetSpace: false,
        circulationSpace: false,
        geometry: _roomGeometry,
      ),
      const TopologySpaceSpec(
        semanticKey: 'bathroom',
        usage: SpaceUsage.bathroom,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 250,
        preferredAreaDm2: 400,
        maxAreaDm2: 800,
        areaWeightBp: 400,
        nearFixedArea: true,
        requiresExteriorExposure: false,
        wetSpace: true,
        circulationSpace: false,
        geometry: _serviceGeometry,
      ),
      const TopologySpaceSpec(
        semanticKey: 'entranceHall',
        usage: SpaceUsage.entranceHall,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 1,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 180,
        preferredAreaDm2: 300,
        maxAreaDm2: 700,
        areaWeightBp: 300,
        nearFixedArea: true,
        requiresExteriorExposure: false,
        wetSpace: false,
        circulationSpace: true,
        geometry: _serviceGeometry,
      ),
    ];
