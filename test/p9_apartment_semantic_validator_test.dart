import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_area_fit.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_semantic_validation.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v1.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_draft.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ApartmentSemanticValidator();

  group('P9.5 adjacency and wet-core validation', () {
    test('P9.5-AT-001 qualified candidate is fully reachable from entry', () {
      final qualified = _qualified(rooms: 3, areaDm2: 7000);
      final report = validator.validate(
        fittedDraft: qualified.fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(report.accepted, isTrue);
      expect(
        report.metrics.entryReachableSpaceCount,
        qualified.fitted.draft.spaces.length,
      );
      expect(report.metrics.privateTransitViolations, 0);
    });

    test('P9.5-AT-002 disconnected bedroom is rejected', () {
      final qualified = _qualified(rooms: 3, areaDm2: 7000);
      final bedroom = qualified.fitted.draft.spaces.firstWhere(
        (space) => space.usage == SpaceUsage.bedroom,
      );
      final circulation = DraftCirculationGraph(
        entrySpaceKey: qualified.fitted.draft.circulation.entrySpaceKey,
        accessEdges: qualified.fitted.draft.circulation.accessEdges.where(
          (edge) =>
              edge.fromSpaceKey != bedroom.semanticKey &&
              edge.toSpaceKey != bedroom.semanticKey,
        ),
      );
      final fitted = _withDraft(
        qualified.fitted,
        _cloneDraft(qualified.fitted.draft, circulation: circulation),
      );

      final report = validator.validate(
        fittedDraft: fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(report.accepted, isFalse);
      expect(
        report.blockers.map((blocker) => blocker.code),
        contains('p9.semantic.disconnected-space'),
      );
    });

    test('P9.5-AT-003 bedroom as only transit path is rejected', () {
      final fixture = _privateTransitFixture();
      final report = validator.validate(
        fittedDraft: fixture.fitted,
        request: fixture.qualified.request,
        template: fixture.qualified.template,
      );

      expect(report.accepted, isFalse);
      expect(report.metrics.privateTransitViolations, greaterThan(0));
      expect(
        report.blockers.map((blocker) => blocker.code),
        contains('p9.semantic.private-transit'),
      );
    });

    test('P9.5-AT-004 unqualified ensuite access is rejected in v1', () {
      final fixture = _privateTransitFixture();
      final report = validator.validate(
        fittedDraft: fixture.fitted,
        request: fixture.qualified.request,
        template: fixture.qualified.template,
      );

      expect(
        report.blockers.any(
          (blocker) =>
              blocker.ruleId == 'p9.semantic.bathroom-privacy.v1-no-ensuite',
        ),
        isTrue,
      );
    });

    test('P9.5-AT-005 separate kitchen semantic mismatch is rejected', () {
      final qualified = _qualified(rooms: 2, areaDm2: 5000);
      final changedSpaces = [
        for (final space in qualified.fitted.draft.spaces)
          space.usage == SpaceUsage.kitchen
              ? DraftSpace(
                  semanticKey: space.semanticKey,
                  baseSemanticKey: space.baseSemanticKey,
                  ordinal: space.ordinal,
                  usage: SpaceUsage.kitchenLiving,
                  type: space.type,
                  areaParticipation: space.areaParticipation,
                  sourceSpec: space.sourceSpec,
                )
              : space,
      ];
      final fitted = _withDraft(
        qualified.fitted,
        _cloneDraft(qualified.fitted.draft, spaces: changedSpaces),
      );
      final report = validator.validate(
        fittedDraft: fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(
        report.blockers.map((blocker) => blocker.code),
        contains('p9.semantic.kitchen-mode-mismatch'),
      );
    });

    test('P9.5-AT-006 kitchenLiving production semantics are accepted', () {
      final qualified = _qualified(
        rooms: 3,
        areaDm2: 7000,
        kitchenMode: ApartmentKitchenMode.kitchenLiving,
      );
      final report = validator.validate(
        fittedDraft: qualified.fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(report.accepted, isTrue);
      expect(
        qualified.fitted.draft.spaces
            .where((space) => space.usage == SpaceUsage.kitchenLiving),
        hasLength(1),
      );
    });

    test('P9.5-AT-007 balcony attached only to corridor is rejected', () {
      final qualified = _qualified(
        rooms: 4,
        areaDm2: 9000,
        balconyCount: 1,
        balconyKind: ApartmentBalconyKind.balcony,
      );
      final appendage = qualified.fitted.draft.spaces.firstWhere(
        (space) => space.usage == SpaceUsage.balcony,
      );
      final corridor = qualified.fitted.draft.spaces.firstWhere(
        (space) => space.usage == SpaceUsage.corridor,
      );
      final edges = qualified.fitted.draft.circulation.accessEdges
          .where(
            (edge) =>
                edge.fromSpaceKey != appendage.semanticKey &&
                edge.toSpaceKey != appendage.semanticKey,
          )
          .toList()
        ..add(
          DraftAccessEdge(
            fromSpaceKey: corridor.semanticKey,
            toSpaceKey: appendage.semanticKey,
            kind: DraftAccessKind.door,
          ),
        );
      final fitted = _withDraft(
        qualified.fitted,
        _cloneDraft(
          qualified.fitted.draft,
          circulation: DraftCirculationGraph(
            entrySpaceKey: qualified.fitted.draft.circulation.entrySpaceKey,
            accessEdges: edges,
          ),
        ),
      );
      final report = validator.validate(
        fittedDraft: fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(
        report.blockers.map((blocker) => blocker.code),
        contains('p9.semantic.invalid-balcony-attachment'),
      );
    });

    test('P9.5-AT-008 corrupt wet-core membership is rejected', () {
      final qualified = _qualified(rooms: 3, areaDm2: 7000);
      final fitted = _withDraft(
        qualified.fitted,
        _cloneDraft(
          qualified.fitted.draft,
          wetCore: DraftWetCoreGrouping(const []),
        ),
      );
      final report = validator.validate(
        fittedDraft: fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(
        report.blockers.map((blocker) => blocker.code),
        contains('p9.semantic.invalid-wet-core'),
      );
    });

    test('P9.5-AT-009 preferred miss is accepted with penalty metadata', () {
      final qualified = _qualified(rooms: 3, areaDm2: 7000);
      final adjacency = qualified.fitted.draft.adjacency
          .where(
            (intent) =>
                intent.requirement != TopologyAdjacencyRequirement.preferred,
          )
          .toList();
      final fitted = _withDraft(
        qualified.fitted,
        _cloneDraft(qualified.fitted.draft, adjacency: adjacency),
      );
      final report = validator.validate(
        fittedDraft: fitted,
        request: qualified.request,
        template: qualified.template,
      );

      expect(report.accepted, isTrue);
      expect(report.preferenceMisses, isNotEmpty);
      expect(
        report.preferenceMisses.every((miss) => miss.penaltyBp > 0),
        isTrue,
      );
    });

    test('P9.5-AT-010 source-order permutation yields equivalent report', () {
      final qualified = _qualified(rooms: 3, areaDm2: 7000);
      final reversedDraft = _cloneDraft(
        qualified.fitted.draft,
        adjacency: qualified.fitted.draft.adjacency.reversed.toList(),
        circulation: DraftCirculationGraph(
          entrySpaceKey: qualified.fitted.draft.circulation.entrySpaceKey,
          accessEdges:
              qualified.fitted.draft.circulation.accessEdges.reversed.toList(),
        ),
      );
      final reversedTemplate = _cloneTemplate(
        qualified.template,
        adjacencyRules: qualified.template.adjacencyRules.reversed.toList(),
      );
      final first = validator.validate(
        fittedDraft: qualified.fitted,
        request: qualified.request,
        template: qualified.template,
      );
      final second = validator.validate(
        fittedDraft: _withDraft(qualified.fitted, reversedDraft),
        request: qualified.request,
        template: reversedTemplate,
      );

      expect(second.accepted, first.accepted);
      expect(
        second.metrics.entryReachableSpaceCount,
        first.metrics.entryReachableSpaceCount,
      );
      expect(second.metrics.maxAccessDepth, first.metrics.maxAccessDepth);
      expect(
        second.metrics.privateTransitViolations,
        first.metrics.privateTransitViolations,
      );
      expect(
        second.geometryHandoff.requiredExteriorSpaceKeys,
        first.geometryHandoff.requiredExteriorSpaceKeys,
      );
    });

    test('P9.5-AT-011 supported 1..10-room corpus has zero blockers', () {
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
        final qualified = _qualified(rooms: rooms, areaDm2: areas[rooms]!);
        final report = validator.validate(
          fittedDraft: qualified.fitted,
          request: qualified.request,
          template: qualified.template,
        );
        expect(
          report.accepted,
          isTrue,
          reason:
              'rooms=$rooms blockers=${report.blockers.map((blocker) => blocker.stableKey).toList()}',
        );
      }
    });

    test('P9.5-AT-012 blockers expose stable code and affected keys', () {
      final qualified = _qualified(rooms: 3, areaDm2: 7000);
      final exposed = qualified.fitted.draft.spaces.firstWhere(
        (space) => space.sourceSpec.requiresExteriorExposure,
      );
      final assignments = Map<String, DraftExteriorSide>.of(
        qualified.fitted.draft.exteriorExposure.assignments,
      )..remove(exposed.semanticKey);
      final fitted = _withDraft(
        qualified.fitted,
        _cloneDraft(
          qualified.fitted.draft,
          exteriorExposure: DraftExteriorExposure(assignments),
        ),
      );
      final report = validator.validate(
        fittedDraft: fitted,
        request: qualified.request,
        template: qualified.template,
      );
      final blocker = report.blockers.firstWhere(
        (item) => item.code == 'p9.semantic.exterior-exposure-unavailable',
      );

      expect(blocker.code, 'p9.semantic.exterior-exposure-unavailable');
      expect(blocker.ruleId, isNotEmpty);
      expect(blocker.affectedKeys, contains(exposed.semanticKey));
      expect(blocker.stableKey, isNotEmpty);
    });
  });
}

final class _Qualified {
  const _Qualified({
    required this.request,
    required this.template,
    required this.fitted,
  });

  final NormalizedApartmentRequest request;
  final ApartmentTopologyTemplate template;
  final AreaFittedTopologyDraft fitted;
}

final class _TransitFixture {
  const _TransitFixture({required this.qualified, required this.fitted});

  final _Qualified qualified;
  final AreaFittedTopologyDraft fitted;
}

_Qualified _qualified({
  required int rooms,
  required int areaDm2,
  ApartmentKitchenMode kitchenMode = ApartmentKitchenMode.separate,
  int bathroomCount = 1,
  int balconyCount = 0,
  ApartmentBalconyKind balconyKind = ApartmentBalconyKind.none,
}) {
  const normalizer = ApartmentRequestNormalizer();
  final request = normalizer
      .normalize(
        ApartmentRequestInput(
          habitableRoomCount: rooms,
          approximateAreaDm2: areaDm2,
          bathroomCount: bathroomCount,
          separateWcCount: 0,
          balconyCount: balconyCount,
          balconyKind: balconyKind,
          kitchenMode: kitchenMode,
          corridorMode: ApartmentCorridorMode.auto,
          exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
        ),
      )
      .request!;
  final catalog = P9ApartmentTopologyCatalogV1.create();
  const filter = ApartmentTopologyCatalogFilter();
  final templates = filter.compatibleTemplates(catalog, request);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: request,
    templates: templates,
  );
  for (final draft in expansion.drafts) {
    final fitted = const ApartmentAreaFitter().fit(
      draft: draft,
      request: request,
    );
    if (!fitted.isValid) {
      continue;
    }
    final template = templates.firstWhere(
      (candidate) =>
          candidate.templateId == draft.templateId &&
          candidate.templateVersion == draft.templateVersion,
    );
    return _Qualified(
      request: request,
      template: template,
      fitted: fitted.fittedDraft!,
    );
  }
  throw StateError('No qualified P9 fixture for rooms=$rooms area=$areaDm2.');
}

_TransitFixture _privateTransitFixture() {
  final qualified = _qualified(rooms: 3, areaDm2: 7000);
  final draft = qualified.fitted.draft;
  final bedroom = draft.spaces.firstWhere(
    (space) => space.usage == SpaceUsage.bedroom,
  );
  final bathroom = draft.spaces.firstWhere(
    (space) => space.usage == SpaceUsage.bathroom,
  );
  final edges = draft.circulation.accessEdges
      .where(
        (edge) =>
            edge.fromSpaceKey != bathroom.semanticKey &&
            edge.toSpaceKey != bathroom.semanticKey,
      )
      .toList()
    ..add(
      DraftAccessEdge(
        fromSpaceKey: bedroom.semanticKey,
        toSpaceKey: bathroom.semanticKey,
        kind: DraftAccessKind.door,
      ),
    );
  final changed = _cloneDraft(
    draft,
    circulation: DraftCirculationGraph(
      entrySpaceKey: draft.circulation.entrySpaceKey,
      accessEdges: edges,
    ),
  );
  return _TransitFixture(
    qualified: qualified,
    fitted: _withDraft(qualified.fitted, changed),
  );
}

ApartmentTopologyDraft _cloneDraft(
  ApartmentTopologyDraft source, {
  List<DraftSpace>? spaces,
  List<DraftAdjacencyIntent>? adjacency,
  DraftCirculationGraph? circulation,
  DraftExteriorExposure? exteriorExposure,
  DraftWetCoreGrouping? wetCore,
}) =>
    ApartmentTopologyDraft(
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      family: source.family,
      variantSeedId: source.variantSeedId,
      intentFingerprint: source.intentFingerprint,
      spaces: spaces ?? source.spaces,
      adjacency: adjacency ?? source.adjacency,
      circulation: circulation ?? source.circulation,
      exteriorExposure: exteriorExposure ?? source.exteriorExposure,
      wetCore: wetCore ?? source.wetCore,
      layoutSkeleton: source.layoutSkeleton,
      semanticSignature: source.semanticSignature,
      draftFingerprint: source.draftFingerprint,
    );

AreaFittedTopologyDraft _withDraft(
  AreaFittedTopologyDraft source,
  ApartmentTopologyDraft draft,
) =>
    AreaFittedTopologyDraft(
      draft: draft,
      requestedInteriorAreaDm2: source.requestedInteriorAreaDm2,
      spaces: source.spaces,
      allocatedInteriorAreaDm2: source.allocatedInteriorAreaDm2,
      exteriorAppendageAreaDm2: source.exteriorAppendageAreaDm2,
      interiorResidualDm2: source.interiorResidualDm2,
      areaPolicyVersion: source.areaPolicyVersion,
      allocatorVersion: source.allocatorVersion,
      areaFitFingerprint: source.areaFitFingerprint,
    );

ApartmentTopologyTemplate _cloneTemplate(
  ApartmentTopologyTemplate source, {
  required List<TopologyAdjacencyRule> adjacencyRules,
}) =>
    ApartmentTopologyTemplate(
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      family: source.family,
      stableOrder: source.stableOrder,
      constraints: source.constraints,
      spaces: source.spaces,
      adjacencyRules: adjacencyRules,
      areaProfile: source.areaProfile,
      circulationPolicy: source.circulationPolicy,
      wetCorePolicy: source.wetCorePolicy,
      variantSeeds: source.variantSeeds,
    );
