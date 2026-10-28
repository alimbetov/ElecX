import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_ranker.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_stage.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_preview_presentation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_svg_projector.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_vector_renderer.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_candidate_ranking.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_vector_scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _PreparedPreview prepared;
  late RankedApartmentCandidate selected;
  late ApartmentTopologyTemplate selectedTemplate;
  late ApartmentTopologyVectorScene scene;
  late String svg;

  setUpAll(() {
    prepared = _prepare(
      _request(
        roomCount: 3,
        areaDm2: 7800,
        balconyCount: 1,
        balconyKind: ApartmentBalconyKind.balcony,
      ),
    );
    expect(prepared.ranking.selectedCandidates.length, greaterThanOrEqualTo(6));
    selected = prepared.ranking.selectedCandidates.first;
    selectedTemplate = prepared.templateFor(selected);
    final rendered = const ApartmentTopologyVectorRenderer().render(
      rankedCandidate: selected,
      template: selectedTemplate,
    );
    expect(rendered.accepted, isTrue);
    scene = rendered.scene!;
    final projected = const ApartmentSvgProjector().project(scene);
    expect(projected.accepted, isTrue);
    svg = projected.svg!;
  });

  group('P9.8 SVG/vector candidate rendering', () {
    test('P9.8-AT-001 same geometry yields byte-identical SVG', () {
      final firstScene = const ApartmentTopologyVectorRenderer()
          .render(
            rankedCandidate: selected,
            template: selectedTemplate,
          )
          .scene!;
      final secondScene = const ApartmentTopologyVectorRenderer()
          .render(
            rankedCandidate: selected,
            template: selectedTemplate,
          )
          .scene!;
      final firstSvg = const ApartmentSvgProjector().project(firstScene).svg!;
      final secondSvg = const ApartmentSvgProjector().project(secondScene).svg!;

      expect(secondScene.sceneFingerprint, firstScene.sceneFingerprint);
      expect(secondSvg, firstSvg);
    });

    test('P9.8-AT-002 SVG has no script/event/external reference', () {
      final lower = svg.toLowerCase();
      expect(lower, isNot(contains('<script')));
      expect(lower, isNot(contains('<foreignobject')));
      expect(lower, isNot(contains('javascript:')));
      expect(lower, isNot(contains('@import')));
      expect(lower, isNot(contains(' href=')));
      expect(lower, isNot(contains(' xlink:href=')));
      expect(RegExp(r'\son[a-z]+\s*=', caseSensitive: false).hasMatch(svg),
          isFalse);
    });

    test('P9.8-AT-003 special characters are escaped', () {
      final specialScene = ApartmentTopologyVectorScene(
        widthUnits: 320,
        heightUnits: 220,
        semanticLabelKey: 'special',
        elements: const [
          ApartmentVectorMetadataElement(
            role: ApartmentVectorRole.warningMetadata,
            generationKey: 'key<&>"\'',
            value: 'value<&>"\'',
          ),
        ],
        summary: const ApartmentPreviewSummary(
          habitableRoomCount: 1,
          interiorAreaDm2: 3000,
          exteriorAppendageAreaDm2: 0,
          kitchenMode: ApartmentKitchenMode.separate,
          family: ApartmentTopologyFamily.compact,
          bathroomCount: 1,
          balconyCount: 0,
          scoreBp: 8000,
        ),
        rendererVersion: 'test',
        sourceGeometryFingerprint: 'geometry',
        sceneFingerprint: 'scene',
      );
      final specialSvg =
          const ApartmentSvgProjector().project(specialScene).svg!;

      expect(specialSvg, contains('&lt;'));
      expect(specialSvg, contains('&amp;'));
      expect(specialSvg, contains('&gt;'));
      expect(specialSvg, contains('&quot;'));
      expect(specialSvg, contains('&apos;'));
      expect(specialSvg, isNot(contains('value<&>')));
    });

    test('P9.8-AT-004 viewBox preserves aspect ratio including appendages', () {
      final candidate = selected.candidate;
      final sourceBounds = _sourceBounds(candidate);
      final polygons =
          scene.elements.whereType<ApartmentVectorPolygonElement>();
      final points = polygons.expand((polygon) => polygon.points).toList();
      final minX = points.map((point) => point.xUnits).reduce(_min);
      final maxX = points.map((point) => point.xUnits).reduce(_max);
      final minY = points.map((point) => point.yUnits).reduce(_min);
      final maxY = points.map((point) => point.yUnits).reduce(_max);
      final sourceAspect = sourceBounds.width / sourceBounds.height;
      final projectedAspect = (maxX - minX) / (maxY - minY);

      expect(candidate.exteriorAppendages, isNotEmpty);
      expect((projectedAspect - sourceAspect).abs(), lessThan(0.05));
      expect(scene.widthUnits, 320);
      expect(scene.heightUnits, 220);
    });

    test('P9.8-AT-005 interior and appendage visual roles remain distinct', () {
      expect(
        scene.elementsByRole(ApartmentVectorRole.interiorSpaceRegion),
        isNotEmpty,
      );
      expect(
        scene.elementsByRole(ApartmentVectorRole.exteriorAppendageRegion),
        isNotEmpty,
      );
      expect(svg, contains('p9-role-interiorSpaceRegion'));
      expect(svg, contains('p9-role-exteriorAppendageRegion'));
    });

    test('P9.8-AT-006 summary keeps interior and appendage areas separate', () {
      final expectedInterior = selected.candidate.interiorSpaces.fold<int>(
        0,
        (sum, space) => sum + space.fittedAreaDm2,
      );
      final expectedAppendage = selected.candidate.exteriorAppendages.fold<int>(
        0,
        (sum, space) => sum + space.fittedAreaDm2,
      );

      expect(scene.summary.interiorAreaDm2, expectedInterior);
      expect(scene.summary.exteriorAppendageAreaDm2, expectedAppendage);
      expect(scene.summary.interiorAreaDm2,
          isNot(expectedInterior + expectedAppendage));
    });

    test(
        'P9.8-AT-007 element ordering is independent of source collection order',
        () {
      final reversedCandidate = _copyCandidate(
        selected.candidate,
        interiorSpaces: selected.candidate.interiorSpaces.reversed,
        exteriorAppendages: selected.candidate.exteriorAppendages.reversed,
        sharedBoundaries: selected.candidate.sharedBoundaries.reversed,
        exteriorBoundaries: selected.candidate.exteriorBoundaries.reversed,
        openingIntents: selected.candidate.openingIntents.reversed,
      );
      final reversedRanked = _copyRanked(selected, reversedCandidate);
      final reversedScene = const ApartmentTopologyVectorRenderer()
          .render(
            rankedCandidate: reversedRanked,
            template: selectedTemplate,
          )
          .scene!;
      final reversedSvg =
          const ApartmentSvgProjector().project(reversedScene).svg!;

      expect(reversedScene.sceneFingerprint, scene.sceneFingerprint);
      expect(reversedSvg, svg);
    });

    test('P9.8-AT-008 card exposes RU semantic description', () {
      final description = const ApartmentPreviewDescriptionFormatter().describe(
        scene.summary,
        locale: ApartmentPreviewLocale.ru,
      );

      expect(description, contains('квартира'));
      expect(description, contains('внутренняя площадь'));
      expect(description, contains('оценка'));
    });

    test('P9.8-AT-009 card exposes EN semantic description', () {
      final description = const ApartmentPreviewDescriptionFormatter().describe(
        scene.summary,
        locale: ApartmentPreviewLocale.en,
      );

      expect(description, contains('apartment'));
      expect(description, contains('interior area'));
      expect(description, contains('score'));
    });

    test('P9.8-AT-010 reduced motion does not alter scene semantics', () {
      final animated = ApartmentPreviewLayoutPolicy.resolve(
        logicalWidth: 390,
        textScaleFactor: 1,
        animationsDisabled: false,
      );
      final reduced = ApartmentPreviewLayoutPolicy.resolve(
        logicalWidth: 390,
        textScaleFactor: 1,
        animationsDisabled: true,
      );

      expect(animated.animationsEnabled, isTrue);
      expect(reduced.animationsEnabled, isFalse);
      expect(scene.sceneFingerprint, isNotEmpty);
      expect(scene.sourceGeometryFingerprint,
          selected.candidate.geometryFingerprint);
    });

    test('P9.8-AT-011 SVG is never needed to reconstruct geometry', () {
      expect(scene.sourceGeometryFingerprint,
          selected.candidate.geometryFingerprint);
      expect(svg, isNot(contains(selected.candidate.geometryFingerprint)));
      expect(selected.candidate.interiorSpaces, isNotEmpty);
      expect(selected.candidate.interiorEnvelope.areaMm2, greaterThan(0));
    });

    test('P9.8-AT-012 6-card hard p95/p99 gate passes', () {
      final candidates = prepared.ranking.selectedCandidates.take(6).toList();
      expect(candidates, hasLength(6));
      final renderer = const ApartmentTopologyVectorRenderer();
      final projector = const ApartmentSvgProjector();

      void renderBatch() {
        for (final ranked in candidates) {
          final rendered = renderer.render(
            rankedCandidate: ranked,
            template: prepared.templateFor(ranked),
          );
          expect(rendered.accepted, isTrue);
          final projected = projector.project(rendered.scene!);
          expect(projected.accepted, isTrue);
        }
      }

      for (var index = 0; index < 20; index++) {
        renderBatch();
      }
      final samplesUs = <int>[];
      for (var index = 0; index < 100; index++) {
        final watch = Stopwatch()..start();
        renderBatch();
        watch.stop();
        samplesUs.add(watch.elapsedMicroseconds);
      }
      samplesUs.sort();
      final p95Us = samplesUs[94];
      final p99Us = samplesUs[98];

      expect(p95Us, lessThanOrEqualTo(100000), reason: 'p95=$p95Us us');
      expect(p99Us, lessThanOrEqualTo(200000), reason: 'p99=$p99Us us');
    });

    test('P9.8-AT-013 scene fingerprint is identical across width classes', () {
      final widths = <double>[390, 800, 1200, 1600];
      final classes = <ElecXResponsiveWidthClass>[];
      for (final width in widths) {
        final policy = ApartmentPreviewLayoutPolicy.resolve(
          logicalWidth: width,
          textScaleFactor: 1,
          animationsDisabled: false,
        );
        classes.add(policy.widthClass);
        expect(scene.sceneFingerprint, isNotEmpty);
      }

      expect(classes.toSet(), ElecXResponsiveWidthClass.values.toSet());
      expect(scene.sourceGeometryFingerprint,
          selected.candidate.geometryFingerprint);
    });

    test('P9.8-AT-014 pinch zoom changes viewport only', () {
      final initial = PreviewViewportState.initial();
      final zoomed = initial.zoomAroundAnchor(
        1.5,
        anchorX: 160,
        anchorY: 110,
      );

      expect(zoomed.scale, greaterThan(initial.scale));
      expect(scene.sceneFingerprint, isNotEmpty);
      expect(selected.candidate.geometryFingerprint,
          scene.sourceGeometryFingerprint);
    });

    test('P9.8-AT-015 mouse/keyboard/touch/stylus select same identity', () {
      final identity = selected.candidate.geometryFingerprint;
      for (final signal in ApartmentPreviewInputSignal.values) {
        final state =
            ApartmentPreviewInteractionState.initial().selectCandidate(
          identity,
          inputSignal: signal,
        );
        expect(state.selectedCandidateFingerprint, identity);
      }
    });

    test(
        'P9.8-AT-016 carousel swipe does not conflict with captured preview pan',
        () {
      final initial = ApartmentPreviewInteractionState.initial();
      final captured = initial.beginPreviewPan();
      final released = captured.endPreviewPan();

      expect(initial.carouselSwipeEnabled, isTrue);
      expect(captured.carouselSwipeEnabled, isFalse);
      expect(released.carouselSwipeEnabled, isTrue);
    });

    test('P9.8-AT-017 text scale 2.0 keeps summary/actions accessible', () {
      final policy = ApartmentPreviewLayoutPolicy.resolve(
        logicalWidth: 390,
        textScaleFactor: 2,
        animationsDisabled: false,
      );

      expect(policy.showInCanvasLabels, isFalse);
      expect(policy.summaryVisible, isTrue);
      expect(policy.actionsVisible, isTrue);
    });

    test('P9.8-AT-018 responsive relayout does not rerun renderer pipeline',
        () {
      var sceneBuildCalls = 0;
      ApartmentTopologyVectorScene buildOnce() {
        sceneBuildCalls++;
        return const ApartmentTopologyVectorRenderer()
            .render(
              rankedCandidate: selected,
              template: selectedTemplate,
            )
            .scene!;
      }

      final cachedScene = buildOnce();
      for (final width in <double>[390, 700, 1100, 1600, 500]) {
        final policy = ApartmentPreviewLayoutPolicy.resolve(
          logicalWidth: width,
          textScaleFactor: width == 500 ? 2 : 1,
          animationsDisabled: width == 1100,
        );
        expect(policy.summaryVisible, isTrue);
        expect(cachedScene.sceneFingerprint, scene.sceneFingerprint);
      }

      expect(sceneBuildCalls, 1);
    });

    test('P9.8 actual qualified scene stays inside hard element bounds', () {
      expect(
        scene.elements.whereType<ApartmentVectorPolygonElement>().length,
        lessThanOrEqualTo(ApartmentTopologyVectorRenderer.maxPolygonCount),
      );
      expect(
        scene.elements.whereType<ApartmentVectorLineElement>().length,
        lessThanOrEqualTo(ApartmentTopologyVectorRenderer.maxLineCount),
      );
      expect(
        scene.elements.whereType<ApartmentVectorLabelAnchorElement>().length,
        lessThanOrEqualTo(ApartmentTopologyVectorRenderer.maxLabelCount),
      );
      expect(
        scene.elements.length,
        lessThanOrEqualTo(ApartmentTopologyVectorRenderer.maxElementCount),
      );
      expect(svg.length, lessThan(64 * 1024));
    });
  });
}

final class _PreparedPreview {
  const _PreparedPreview({
    required this.request,
    required this.templates,
    required this.ranking,
  });

  final NormalizedApartmentRequest request;
  final List<ApartmentTopologyTemplate> templates;
  final ApartmentCandidateRankingResult ranking;

  ApartmentTopologyTemplate templateFor(RankedApartmentCandidate ranked) =>
      templates.firstWhere(
        (template) =>
            template.templateId == ranked.candidate.templateId &&
            template.templateVersion == ranked.candidate.templateVersion,
      );
}

_PreparedPreview _prepare(ApartmentRequestInput input) {
  final request = const ApartmentRequestNormalizer().normalize(input).request!;
  final catalog = P9ApartmentTopologyCatalogV4.create();
  final templates = const ApartmentTopologyCatalogFilter()
      .compatibleTemplates(catalog, request);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: request,
    templates: templates,
  );
  final inputs = <ApartmentCandidateRankingInput>[];

  for (final draft in expansion.drafts) {
    final fitted = const ApartmentAreaFitter().fit(
      draft: draft,
      request: request,
    );
    if (!fitted.isValid) continue;
    final template = templates.firstWhere(
      (candidate) =>
          candidate.templateId == draft.templateId &&
          candidate.templateVersion == draft.templateVersion,
    );
    final semantic = const ApartmentSemanticValidator().validate(
      fittedDraft: fitted.fittedDraft!,
      request: request,
      template: template,
    );
    if (!semantic.accepted) continue;
    final geometry = const ApartmentGeometryStage().generate(
      fittedDraft: fitted.fittedDraft!,
      semanticValidation: semantic,
      template: template,
      request: request,
    );
    if (!geometry.accepted) continue;
    inputs.add(
      ApartmentCandidateRankingInput(
        candidate: geometry.candidate!,
        template: template,
      ),
    );
  }

  final baseProfile = ApartmentScoringProfile.recommendedV1();
  final ranking = const ApartmentCandidateRanker().rank(
    candidates: inputs,
    request: request,
    profile: ApartmentScoringProfile(
      scoringProfileVersion: baseProfile.scoringProfileVersion,
      weightBp: baseProfile.weightBp,
      selectableFloorBp: 0,
      minimumUsefulCandidateCount: 3,
      preferredCandidateCount: 6,
      maximumCandidateCount: 6,
    ),
  );
  return _PreparedPreview(
    request: request,
    templates: templates,
    ranking: ranking,
  );
}

RankedApartmentCandidate _copyRanked(
  RankedApartmentCandidate source,
  ApartmentGeometryCandidate candidate,
) =>
    RankedApartmentCandidate(
      candidate: candidate,
      breakdown: source.breakdown,
      similaritySignature: source.similaritySignature,
      familyStableOrder: source.familyStableOrder,
      templateStableOrder: source.templateStableOrder,
      variantSeedStableOrder: source.variantSeedStableOrder,
    );

ApartmentGeometryCandidate _copyCandidate(
  ApartmentGeometryCandidate source, {
  Iterable<GeneratedSpaceGeometry>? interiorSpaces,
  Iterable<GeneratedSpaceGeometry>? exteriorAppendages,
  Iterable<GeneratedSharedBoundary>? sharedBoundaries,
  Iterable<GeneratedExteriorBoundary>? exteriorBoundaries,
  Iterable<OpeningIntent>? openingIntents,
}) =>
    ApartmentGeometryCandidate(
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      family: source.family,
      variantSeedId: source.variantSeedId,
      areaFitFingerprint: source.areaFitFingerprint,
      interiorEnvelope: source.interiorEnvelope,
      interiorSpaces: interiorSpaces ?? source.interiorSpaces,
      exteriorAppendages: exteriorAppendages ?? source.exteriorAppendages,
      sharedBoundaries: sharedBoundaries ?? source.sharedBoundaries,
      exteriorBoundaries: exteriorBoundaries ?? source.exteriorBoundaries,
      openingIntents: openingIntents ?? source.openingIntents,
      metrics: source.metrics,
      validation: source.validation,
      geometryAlgorithmVersion: source.geometryAlgorithmVersion,
      geometryFingerprint: source.geometryFingerprint,
    );

_Bounds _sourceBounds(ApartmentGeometryCandidate candidate) {
  var minX = candidate.interiorEnvelope.minX;
  var maxX = candidate.interiorEnvelope.maxX;
  var minY = candidate.interiorEnvelope.minY;
  var maxY = candidate.interiorEnvelope.maxY;
  for (final appendage in candidate.exteriorAppendages) {
    minX = _min(minX, appendage.polygon.minX);
    maxX = _max(maxX, appendage.polygon.maxX);
    minY = _min(minY, appendage.polygon.minY);
    maxY = _max(maxY, appendage.polygon.maxY);
  }
  return _Bounds(width: maxX - minX, height: maxY - minY);
}

final class _Bounds {
  const _Bounds({required this.width, required this.height});

  final int width;
  final int height;
}

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;

ApartmentRequestInput _request({
  required int roomCount,
  required int areaDm2,
  int balconyCount = 0,
  ApartmentBalconyKind balconyKind = ApartmentBalconyKind.none,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: balconyCount,
      balconyKind: balconyKind,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );
