import 'package:elecx/src/application/project/wizard/apartment/apartment_access_spine_geometry_generator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_stage.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_area_fit.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_semantic_validation.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_draft.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.6 deterministic geometry generation', () {
    test('P9.6-AT-013 supported 1..10-room corpus has accepted geometry', () {
      for (var rooms = 1; rooms <= 10; rooms++) {
        final result = _firstAccepted(
          _request(roomCount: rooms, areaDm2: _representativeArea(rooms)),
        );

        expect(result, isNotNull, reason: 'rooms=$rooms must yield geometry');
        expect(result!.candidate.validation.accepted, isTrue);
        expect(
          result.candidate.geometryAlgorithmVersion,
          ApartmentAccessSpineGeometryGenerator.graphAwareV2AlgorithmVersion,
          reason: 'rooms=$rooms must preserve V2 strategy provenance',
        );
        expect(
          result.candidate.metrics.interiorAreaMm2,
          closeTo(_representativeArea(rooms) * 10000, 200000),
        );
      }
    });

    test('P9.6-AT-009/014 coordinates and fingerprint are deterministic', () {
      final input = _request(roomCount: 3, areaDm2: 7800);
      final first = _firstAccepted(input)!;
      final second = _firstAccepted(input)!;

      expect(
        second.candidate.geometryFingerprint,
        first.candidate.geometryFingerprint,
      );
      expect(
        second.candidate.interiorEnvelope.stableSerialization,
        first.candidate.interiorEnvelope.stableSerialization,
      );
      for (final space in [
        ...first.candidate.interiorSpaces,
        ...first.candidate.exteriorAppendages,
      ]) {
        for (final point in space.polygon.vertices) {
          expect(point.xMm % p9GeometryGridMm, 0);
          expect(point.yMm % p9GeometryGridMm, 0);
        }
      }
    });

    test('P9.6-AT-006 open-plan required boundary is realized', () {
      final result = _firstAccepted(
        _request(
          roomCount: 2,
          areaDm2: 6000,
          kitchenMode: ApartmentKitchenMode.openPlan,
        ),
      );

      expect(result, isNotNull);
      final required =
          result!.semantic.geometryHandoff.requiredSharedBoundaryPairs;
      expect(required, isNotEmpty);
      final realized = {
        for (final boundary in result.candidate.sharedBoundaries)
          boundary.pair.stableKey: boundary.lengthMm,
      };
      for (final pair in required) {
        expect(realized[pair.stableKey], isNotNull, reason: pair.stableKey);
        expect(realized[pair.stableKey]!, greaterThan(0));
      }
    });

    test('P9.6-AT-017 access intents survive geometry', () {
      for (var rooms = 1; rooms <= 10; rooms++) {
        final result = _firstAccepted(
          _request(roomCount: rooms, areaDm2: _representativeArea(rooms)),
        );
        expect(result, isNotNull, reason: 'rooms=$rooms must yield geometry');
        final fixture = result!;
        final internalOpenings = fixture.candidate.openingIntents
            .where(
                (opening) => opening.kind != GeometryOpeningKind.primaryEntry)
            .toList();
        final realizedPairs = <String, GeometryOpeningKind>{};
        for (final opening in internalOpenings) {
          final from = opening.fromSpaceKey;
          final to = opening.toSpaceKey;
          expect(from, isNotNull, reason: 'rooms=$rooms opening missing from');
          expect(to, isNotNull, reason: 'rooms=$rooms opening missing to');
          realizedPairs[_pairKey(from!, to!)] = opening.kind;
        }

        for (final intent in fixture.semantic.geometryHandoff.accessIntents) {
          final expectedKind = intent.kind == DraftAccessKind.openPassage
              ? GeometryOpeningKind.openPassage
              : GeometryOpeningKind.door;
          expect(
            realizedPairs[intent.pair.stableKey],
            expectedKind,
            reason:
                'rooms=$rooms lost required access ${intent.pair.stableKey}',
          );
        }
      }
    });

    test('P9.6-AT-018 actual opening graph reaches every interior space', () {
      for (var rooms = 1; rooms <= 10; rooms++) {
        final result = _firstAccepted(
          _request(roomCount: rooms, areaDm2: _representativeArea(rooms)),
        );
        expect(result, isNotNull, reason: 'rooms=$rooms must yield geometry');
        final fixture = result!;
        final internalOpenings = fixture.candidate.openingIntents
            .where(
                (opening) => opening.kind != GeometryOpeningKind.primaryEntry)
            .toList();
        final primaryEntries = fixture.candidate.openingIntents
            .where(
                (opening) => opening.kind == GeometryOpeningKind.primaryEntry)
            .toList();
        expect(primaryEntries, hasLength(1), reason: 'rooms=$rooms entry');
        final entryKey = primaryEntries.single.fromSpaceKey!;
        final reachable = _reachableFrom(entryKey, internalOpenings);
        final interiorKeys = fixture.candidate.interiorSpaces
            .map((space) => space.semanticKey)
            .toSet();
        expect(
          reachable.containsAll(interiorKeys),
          isTrue,
          reason:
              'rooms=$rooms unreachable=${interiorKeys.difference(reachable).toList()..sort()}',
        );
      }
    });

    test('P9.6-AT-010/011 balcony remains outside interior accounting', () {
      final result = _firstAccepted(
        _request(
          roomCount: 3,
          areaDm2: 7800,
          balconyCount: 1,
          balconyKind: ApartmentBalconyKind.balcony,
        ),
      );

      expect(result, isNotNull);
      expect(result!.candidate.exteriorAppendages, hasLength(1));
      expect(result.candidate.metrics.appendageAreaMm2, greaterThan(0));
      expect(
        result.candidate.metrics.interiorAreaMm2,
        closeTo(7800 * 10000, 200000),
      );
      expect(
        result.candidate.metrics.interiorAreaMm2,
        isNot(result.candidate.metrics.interiorAreaMm2 +
            result.candidate.metrics.appendageAreaMm2),
      );
    });

    test('corner exposure fails closed until multi-side layout is implemented',
        () {
      final normalized = const ApartmentRequestNormalizer()
          .normalize(
            _request(
              roomCount: 3,
              areaDm2: 7800,
              exposure: ApartmentExteriorExposurePreference.corner,
            ),
          )
          .request!;
      final prepared = _firstPrepared(normalized);
      expect(prepared, isNotNull);

      final generated = const ApartmentGeometryStage().generate(
        fittedDraft: prepared!.fitted,
        semanticValidation: prepared.semantic,
        template: prepared.template,
        request: normalized,
      );

      expect(generated.accepted, isFalse);
      expect(
        generated.failures.map((failure) => failure.code),
        contains('p9.geometry.exposure-preference-mismatch'),
      );
    });
  });
}

final class _GeneratedFixture {
  const _GeneratedFixture({
    required this.candidate,
    required this.semantic,
  });

  final ApartmentGeometryCandidate candidate;
  final TopologySemanticValidation semantic;
}

final class _PreparedFixture {
  const _PreparedFixture({
    required this.fitted,
    required this.semantic,
    required this.template,
  });

  final AreaFittedTopologyDraft fitted;
  final TopologySemanticValidation semantic;
  final ApartmentTopologyTemplate template;
}

_GeneratedFixture? _firstAccepted(ApartmentRequestInput input) {
  final normalized =
      const ApartmentRequestNormalizer().normalize(input).request!;
  final catalog = P9ApartmentTopologyCatalogV4.create();
  final templates = const ApartmentTopologyCatalogFilter()
      .compatibleTemplates(catalog, normalized);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: normalized,
    templates: templates,
  );

  for (final draft in expansion.drafts) {
    final fitted = const ApartmentAreaFitter().fit(
      draft: draft,
      request: normalized,
    );
    if (!fitted.isValid) {
      continue;
    }
    final template = templates.firstWhere(
      (candidate) =>
          candidate.templateId == draft.templateId &&
          candidate.templateVersion == draft.templateVersion,
    );
    final semantic = const ApartmentSemanticValidator().validate(
      fittedDraft: fitted.fittedDraft!,
      request: normalized,
      template: template,
    );
    if (!semantic.accepted) {
      continue;
    }
    final geometry = const ApartmentGeometryStage().generate(
      fittedDraft: fitted.fittedDraft!,
      semanticValidation: semantic,
      template: template,
      request: normalized,
    );
    if (geometry.accepted) {
      return _GeneratedFixture(
        candidate: geometry.candidate!,
        semantic: semantic,
      );
    }
  }
  return null;
}

_PreparedFixture? _firstPrepared(NormalizedApartmentRequest normalized) {
  final catalog = P9ApartmentTopologyCatalogV4.create();
  final templates = const ApartmentTopologyCatalogFilter()
      .compatibleTemplates(catalog, normalized);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: normalized,
    templates: templates,
  );
  for (final draft in expansion.drafts) {
    final fitted = const ApartmentAreaFitter().fit(
      draft: draft,
      request: normalized,
    );
    if (!fitted.isValid) {
      continue;
    }
    final template = templates.firstWhere(
      (candidate) =>
          candidate.templateId == draft.templateId &&
          candidate.templateVersion == draft.templateVersion,
    );
    final semantic = const ApartmentSemanticValidator().validate(
      fittedDraft: fitted.fittedDraft!,
      request: normalized,
      template: template,
    );
    if (semantic.accepted) {
      return _PreparedFixture(
        fitted: fitted.fittedDraft!,
        semantic: semantic,
        template: template,
      );
    }
  }
  return null;
}

Set<String> _reachableFrom(
  String entryKey,
  List<OpeningIntent> openings,
) {
  final neighbors = <String, Set<String>>{};
  for (final opening in openings) {
    final from = opening.fromSpaceKey;
    final to = opening.toSpaceKey;
    if (from == null || to == null) {
      continue;
    }
    neighbors.putIfAbsent(from, () => <String>{}).add(to);
    neighbors.putIfAbsent(to, () => <String>{}).add(from);
  }
  final visited = <String>{entryKey};
  final queue = <String>[entryKey];
  var index = 0;
  while (index < queue.length) {
    final current = queue[index++];
    final next = (neighbors[current] ?? const <String>{}).toList()..sort();
    for (final key in next) {
      if (visited.add(key)) {
        queue.add(key);
      }
    }
  }
  return visited;
}

String _pairKey(String left, String right) =>
    left.compareTo(right) <= 0 ? '$left|$right' : '$right|$left';

ApartmentRequestInput _request({
  required int roomCount,
  required int areaDm2,
  ApartmentKitchenMode kitchenMode = ApartmentKitchenMode.separate,
  int balconyCount = 0,
  ApartmentBalconyKind balconyKind = ApartmentBalconyKind.none,
  ApartmentExteriorExposurePreference exposure =
      ApartmentExteriorExposurePreference.any,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: balconyCount,
      balconyKind: balconyKind,
      kitchenMode: kitchenMode,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: exposure,
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
