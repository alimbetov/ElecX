import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_space_semantics.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

final class ApartmentGeometryGenerationResult {
  ApartmentGeometryGenerationResult({
    required this.candidate,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final ApartmentGeometryCandidate? candidate;
  final List<P9Failure> failures;

  bool get accepted =>
      candidate != null &&
      candidate!.validation.accepted &&
      failures.every((failure) => !failure.isBlocker);
}

/// P9.6 bounded deterministic geometry generator.
///
/// V1 geometry uses a facade strip for every interior space that requires
/// exterior exposure and a contiguous service block for the remaining spaces.
/// The resulting apartment envelope may be rectilinear/L-shaped. It is a
/// candidate-local topology and deliberately does not fit a real Building
/// envelope.
final class ApartmentGeometryGenerator {
  const ApartmentGeometryGenerator();

  static const String geometryAlgorithmVersion = 'p9.facade-strip.v1';
  static const int maxSpaces = 32;
  static const int maxFacadeDepthMm = 8000;
  static const int maxServiceDepthMm = 6000;
  static const int minimumAreaToleranceMm2 = 200000;

  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) {
    final failures = <P9Failure>[];
    final draft = fittedDraft.draft;

    if (!semanticValidation.accepted) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [
          _failure(
            'p9.geometry.semantic-input-invalid',
            facts: {'blockerCount': semanticValidation.blockers.length},
          ),
        ],
      );
    }
    if (draft.templateId != template.templateId ||
        draft.templateVersion != template.templateVersion ||
        draft.intentFingerprint != request.intentFingerprint) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [
          _failure(
            'p9.geometry.lineage-mismatch',
            facts: {
              'draftTemplateId': draft.templateId.value,
              'templateId': template.templateId.value,
              'draftTemplateVersion': draft.templateVersion,
              'templateVersion': template.templateVersion,
            },
          ),
        ],
      );
    }
    if (draft.spaces.length > maxSpaces) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [
          _failure(
            'p9.geometry.unsupported-space-count',
            facts: {'spaceCount': draft.spaces.length, 'maxSpaces': maxSpaces},
          ),
        ],
      );
    }
    if (request.exteriorExposurePreference ==
            ApartmentExteriorExposurePreference.corner ||
        request.exteriorExposurePreference ==
            ApartmentExteriorExposurePreference.oppositeSides) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [
          _failure(
            'p9.geometry.exposure-preference-mismatch',
            facts: {
              'preference': request.exteriorExposurePreference.code,
              'supportedByAlgorithm': 'any|oneSide',
            },
          ),
        ],
      );
    }

    final byDraftKey = <String, DraftSpace>{
      for (final space in draft.spaces) space.semanticKey: space,
    };
    final byAreaKey = <String, FittedSpaceArea>{
      for (final area in fittedDraft.spaces) area.semanticKey: area,
    };
    for (final key in byDraftKey.keys) {
      if (!byAreaKey.containsKey(key)) {
        failures.add(
          _failure('p9.geometry.missing-fitted-area', facts: {'spaceKey': key}),
        );
      }
    }
    if (failures.isNotEmpty) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: failures,
      );
    }

    final interior = <_GeometryInput>[];
    final appendages = <_GeometryInput>[];
    for (final space in draft.spaces) {
      final input = _GeometryInput(space: space, area: byAreaKey[space.semanticKey]!);
      if (space.areaParticipation == SpaceAreaParticipation.exteriorAppendage) {
        appendages.add(input);
      } else {
        interior.add(input);
      }
    }

    final requiredExterior = semanticValidation
        .geometryHandoff.requiredExteriorSpaceKeys
        .toSet();
    final facade = interior
        .where((input) => requiredExterior.contains(input.space.semanticKey))
        .toList();
    final service = interior
        .where((input) => !requiredExterior.contains(input.space.semanticKey))
        .toList();

    if (facade.isEmpty) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [_failure('p9.geometry.exterior-exposure-missing')],
      );
    }

    final stableOrder = <String, int>{
      for (var index = 0;
          index < draft.layoutSkeleton.stableRoleOrder.length;
          index++)
        draft.layoutSkeleton.stableRoleOrder[index]: index,
    };
    facade.sort((left, right) => _compareInput(left, right, stableOrder));
    service.sort((left, right) => _compareService(left, right, stableOrder));
    _bringWetExteriorToFacadeStart(facade, semanticValidation.geometryHandoff);
    _coLocateRequiredBoundaryPairs(
      facade,
      semanticValidation.geometryHandoff.requiredSharedBoundaryPairs,
    );

    final facadeRow = _findRowLayout(
      facade,
      maxDepthMm: maxFacadeDepthMm,
      maxWidthMm: null,
    );
    if (facadeRow == null) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [_failure('p9.geometry.unsatisfiable-area')],
      );
    }

    final serviceRow = service.isEmpty
        ? null
        : _findRowLayout(
            service,
            maxDepthMm: maxServiceDepthMm,
            maxWidthMm: facadeRow.totalWidthMm,
          );
    if (service.isNotEmpty && serviceRow == null) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: [_failure('p9.geometry.unsatisfiable-area')],
      );
    }

    final interiorSpaces = <GeneratedSpaceGeometry>[];
    var xMm = 0;
    for (var index = 0; index < facade.length; index++) {
      final input = facade[index];
      final widthMm = facadeRow.widthsMm[index];
      interiorSpaces.add(
        GeneratedSpaceGeometry(
          semanticKey: input.space.semanticKey,
          participation: input.space.areaParticipation,
          polygon: RectilinearPolygonMm.rectangle(
            xMm: xMm,
            yMm: 0,
            widthMm: widthMm,
            heightMm: facadeRow.depthMm,
          ),
          fittedAreaDm2: input.area.areaDm2,
        ),
      );
      xMm += widthMm;
    }

    final serviceWidthMm = serviceRow?.totalWidthMm ?? 0;
    if (serviceRow != null) {
      xMm = 0;
      for (var index = 0; index < service.length; index++) {
        final input = service[index];
        final widthMm = serviceRow.widthsMm[index];
        interiorSpaces.add(
          GeneratedSpaceGeometry(
            semanticKey: input.space.semanticKey,
            participation: input.space.areaParticipation,
            polygon: RectilinearPolygonMm.rectangle(
              xMm: xMm,
              yMm: facadeRow.depthMm,
              widthMm: widthMm,
              heightMm: serviceRow.depthMm,
            ),
            fittedAreaDm2: input.area.areaDm2,
          ),
        );
        xMm += widthMm;
      }
    }

    final envelope = serviceRow == null
        ? RectilinearPolygonMm.rectangle(
            xMm: 0,
            yMm: 0,
            widthMm: facadeRow.totalWidthMm,
            heightMm: facadeRow.depthMm,
          )
        : _lEnvelope(
            facadeWidthMm: facadeRow.totalWidthMm,
            facadeDepthMm: facadeRow.depthMm,
            serviceWidthMm: serviceWidthMm,
            serviceDepthMm: serviceRow.depthMm,
          );

    final exteriorAppendages = _materializeAppendages(
      inputs: appendages,
      interiorSpaces: interiorSpaces,
      handoff: semanticValidation.geometryHandoff,
      failures: failures,
    );
    if (failures.any((failure) => failure.isBlocker)) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: failures,
      );
    }

    final allSpaces = [...interiorSpaces, ...exteriorAppendages];
    final sharedBoundaries = _deriveSharedBoundaries(allSpaces);
    final exteriorBoundaries = _deriveExteriorBoundaries(
      interiorSpaces,
      envelope,
    );
    final openingIntents = _openingIntents(
      draft: draft,
      handoff: semanticValidation.geometryHandoff,
      interiorSpaces: interiorSpaces,
      sharedBoundaries: sharedBoundaries,
      exteriorBoundaries: exteriorBoundaries,
    );

    final issues = _validateCandidate(
      fittedDraft: fittedDraft,
      template: template,
      request: request,
      handoff: semanticValidation.geometryHandoff,
      envelope: envelope,
      interiorSpaces: interiorSpaces,
      exteriorAppendages: exteriorAppendages,
      sharedBoundaries: sharedBoundaries,
      exteriorBoundaries: exteriorBoundaries,
      openingIntents: openingIntents,
    );
    final validation = GeometryValidationReport(issues);
    final metrics = _metrics(
      fittedDraft: fittedDraft,
      handoff: semanticValidation.geometryHandoff,
      interiorSpaces: interiorSpaces,
      exteriorAppendages: exteriorAppendages,
      sharedBoundaries: sharedBoundaries,
      exteriorBoundaries: exteriorBoundaries,
    );
    final fingerprint = _fingerprint(
      fittedDraft: fittedDraft,
      envelope: envelope,
      interiorSpaces: interiorSpaces,
      exteriorAppendages: exteriorAppendages,
      sharedBoundaries: sharedBoundaries,
      exteriorBoundaries: exteriorBoundaries,
      openingIntents: openingIntents,
    );

    final candidate = ApartmentGeometryCandidate(
      templateId: draft.templateId,
      templateVersion: draft.templateVersion,
      family: draft.family,
      variantSeedId: draft.variantSeedId,
      areaFitFingerprint: fittedDraft.areaFitFingerprint,
      interiorEnvelope: envelope,
      interiorSpaces: interiorSpaces,
      exteriorAppendages: exteriorAppendages,
      sharedBoundaries: sharedBoundaries,
      exteriorBoundaries: exteriorBoundaries,
      openingIntents: openingIntents,
      metrics: metrics,
      validation: validation,
      geometryAlgorithmVersion: geometryAlgorithmVersion,
      geometryFingerprint: fingerprint,
    );

    if (!validation.accepted) {
      failures.add(
        _failure(
          'p9.geometry.candidate-rejected',
          facts: {
            'blockerCount': validation.issues
                .where((issue) =>
                    issue.severity == GeometryValidationSeverity.blocker)
                .length,
          },
        ),
      );
    }
    return ApartmentGeometryGenerationResult(
      candidate: candidate,
      failures: failures,
    );
  }

  _RowLayout? _findRowLayout(
    List<_GeometryInput> inputs, {
    required int maxDepthMm,
    required int? maxWidthMm,
  }) {
    if (inputs.isEmpty) {
      return null;
    }
    final minimumDepth = inputs
        .map((input) => input.space.sourceSpec.geometry.minShortSideMm)
        .reduce(_max);
    final alignedMinimum = _ceilGrid(minimumDepth);
    for (var depthMm = alignedMinimum;
        depthMm <= maxDepthMm;
        depthMm += p9GeometryGridMm) {
      final widths = <int>[];
      var totalWidth = 0;
      var valid = true;
      for (final input in inputs) {
        final widthMm = _nearestGrid(
          (input.area.areaDm2 * 10000) ~/ depthMm,
        );
        if (widthMm <= 0 ||
            !_rectangleSatisfies(
              input,
              widthMm: widthMm,
              heightMm: depthMm,
            )) {
          valid = false;
          break;
        }
        widths.add(widthMm);
        totalWidth += widthMm;
      }
      if (!valid || (maxWidthMm != null && totalWidth > maxWidthMm)) {
        continue;
      }
      return _RowLayout(
        depthMm: depthMm,
        widthsMm: widths,
        totalWidthMm: totalWidth,
      );
    }
    return null;
  }

  bool _rectangleSatisfies(
    _GeometryInput input, {
    required int widthMm,
    required int heightMm,
  }) {
    final geometry = input.space.sourceSpec.geometry;
    final shortSide = _min(widthMm, heightMm);
    final longSide = _max(widthMm, heightMm);
    if (shortSide < geometry.minShortSideMm ||
        (geometry.minLongSideMm != null &&
            longSide < geometry.minLongSideMm!)) {
      return false;
    }
    final aspectBp = widthMm * 10000 ~/ heightMm;
    if (aspectBp < geometry.minAspectBp ||
        aspectBp > geometry.maxAspectBp) {
      return false;
    }
    if (input.space.sourceSpec.requiresExteriorExposure &&
        geometry.minExteriorExposureMm != null &&
        widthMm < geometry.minExteriorExposureMm!) {
      return false;
    }
    final realizedAreaMm2 = widthMm * heightMm;
    final targetAreaMm2 = input.area.areaDm2 * 10000;
    return (realizedAreaMm2 - targetAreaMm2).abs() <=
        _areaToleranceMm2(targetAreaMm2);
  }

  RectilinearPolygonMm _lEnvelope({
    required int facadeWidthMm,
    required int facadeDepthMm,
    required int serviceWidthMm,
    required int serviceDepthMm,
  }) {
    if (serviceWidthMm == facadeWidthMm) {
      return RectilinearPolygonMm.rectangle(
        xMm: 0,
        yMm: 0,
        widthMm: facadeWidthMm,
        heightMm: facadeDepthMm + serviceDepthMm,
      );
    }
    return RectilinearPolygonMm.normalized([
      const BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: facadeWidthMm, yMm: 0),
      BoundaryPointMm(xMm: facadeWidthMm, yMm: facadeDepthMm),
      BoundaryPointMm(xMm: serviceWidthMm, yMm: facadeDepthMm),
      BoundaryPointMm(
        xMm: serviceWidthMm,
        yMm: facadeDepthMm + serviceDepthMm,
      ),
      BoundaryPointMm(xMm: 0, yMm: facadeDepthMm + serviceDepthMm),
    ]);
  }

  List<GeneratedSpaceGeometry> _materializeAppendages({
    required List<_GeometryInput> inputs,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required TopologyGeometryHandoff handoff,
    required List<P9Failure> failures,
  }) {
    if (inputs.isEmpty) {
      return const [];
    }
    final byKey = <String, GeneratedSpaceGeometry>{
      for (final space in interiorSpaces) space.semanticKey: space,
    };
    final result = <GeneratedSpaceGeometry>[];
    final usedHostWidthMm = <String, int>{};

    for (final input in inputs) {
      final access = handoff.accessIntents.where(
        (intent) => intent.pair.leftKey == input.space.semanticKey ||
            intent.pair.rightKey == input.space.semanticKey,
      );
      String? hostKey;
      for (final intent in access) {
        final other = intent.pair.leftKey == input.space.semanticKey
            ? intent.pair.rightKey
            : intent.pair.leftKey;
        if (byKey.containsKey(other)) {
          hostKey = other;
          break;
        }
      }
      final host = hostKey == null ? null : byKey[hostKey];
      if (host == null || host.polygon.minY != 0) {
        failures.add(
          _failure(
            'p9.geometry.appendage-attachment',
            facts: {'spaceKey': input.space.semanticKey, 'hostKey': hostKey},
          ),
        );
        continue;
      }
      final dimensions = _appendageDimensions(
        input,
        maxAttachmentWidthMm: host.polygon.widthMm,
      );
      if (dimensions == null) {
        failures.add(
          _failure(
            'p9.geometry.appendage-attachment',
            facts: {'spaceKey': input.space.semanticKey, 'hostKey': hostKey},
          ),
        );
        continue;
      }
      final used = usedHostWidthMm[hostKey!] ?? 0;
      if (used + dimensions.widthMm > host.polygon.widthMm) {
        failures.add(
          _failure(
            'p9.geometry.appendage-overlap',
            facts: {'spaceKey': input.space.semanticKey, 'hostKey': hostKey},
          ),
        );
        continue;
      }
      usedHostWidthMm[hostKey] = used + dimensions.widthMm;
      result.add(
        GeneratedSpaceGeometry(
          semanticKey: input.space.semanticKey,
          participation: input.space.areaParticipation,
          polygon: RectilinearPolygonMm.rectangle(
            xMm: host.polygon.minX + used,
            yMm: -dimensions.depthMm,
            widthMm: dimensions.widthMm,
            heightMm: dimensions.depthMm,
          ),
          fittedAreaDm2: input.area.areaDm2,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  _AppendageDimensions? _appendageDimensions(
    _GeometryInput input, {
    required int maxAttachmentWidthMm,
  }) {
    final geometry = input.space.sourceSpec.geometry;
    for (var depthMm = _ceilGrid(geometry.minShortSideMm);
        depthMm <= 3000;
        depthMm += p9GeometryGridMm) {
      final widthMm = _nearestGrid(
        (input.area.areaDm2 * 10000) ~/ depthMm,
      );
      if (widthMm > maxAttachmentWidthMm ||
          !_rectangleSatisfies(
            input,
            widthMm: widthMm,
            heightMm: depthMm,
          )) {
        continue;
      }
      return _AppendageDimensions(widthMm: widthMm, depthMm: depthMm);
    }
    return null;
  }

  List<GeneratedSharedBoundary> _deriveSharedBoundaries(
    List<GeneratedSpaceGeometry> spaces,
  ) {
    final result = <GeneratedSharedBoundary>[];
    for (var first = 0; first < spaces.length; first++) {
      for (var second = first + 1; second < spaces.length; second++) {
        GeometrySegmentMm? longest;
        for (final left in spaces[first].polygon.segments) {
          for (final right in spaces[second].polygon.segments) {
            final overlap = intersectCollinearSegments(left, right);
            if (overlap != null &&
                (longest == null || overlap.lengthMm > longest.lengthMm)) {
              longest = overlap;
            }
          }
        }
        if (longest != null) {
          result.add(
            GeneratedSharedBoundary(
              leftSpaceKey: spaces[first].semanticKey,
              rightSpaceKey: spaces[second].semanticKey,
              segment: longest,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }

  List<GeneratedExteriorBoundary> _deriveExteriorBoundaries(
    List<GeneratedSpaceGeometry> spaces,
    RectilinearPolygonMm envelope,
  ) {
    final result = <GeneratedExteriorBoundary>[];
    for (final space in spaces) {
      for (final segment in space.polygon.segments) {
        for (final envelopeSegment in envelope.segments) {
          final overlap = intersectCollinearSegments(segment, envelopeSegment);
          if (overlap == null) {
            continue;
          }
          result.add(
            GeneratedExteriorBoundary(
              spaceSemanticKey: space.semanticKey,
              side: _envelopeSide(overlap, envelope),
              segment: overlap,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }

  GeometryEnvelopeSide _envelopeSide(
    GeometrySegmentMm segment,
    RectilinearPolygonMm envelope,
  ) {
    if (!segment.vertical && segment.start.yMm == envelope.minY) {
      return GeometryEnvelopeSide.north;
    }
    if (!segment.vertical && segment.start.yMm == envelope.maxY) {
      return GeometryEnvelopeSide.south;
    }
    if (segment.vertical && segment.start.xMm == envelope.minX) {
      return GeometryEnvelopeSide.west;
    }
    if (segment.vertical && segment.start.xMm == envelope.maxX) {
      return GeometryEnvelopeSide.east;
    }
    return segment.vertical
        ? GeometryEnvelopeSide.east
        : GeometryEnvelopeSide.south;
  }

  List<OpeningIntent> _openingIntents({
    required ApartmentTopologyDraft draft,
    required TopologyGeometryHandoff handoff,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSharedBoundary> sharedBoundaries,
    required List<GeneratedExteriorBoundary> exteriorBoundaries,
  }) {
    final result = <OpeningIntent>[];
    final entryKey = draft.circulation.entrySpaceKey;
    final entryExterior = exteriorBoundaries
        .where((boundary) => boundary.spaceSemanticKey == entryKey)
        .toList()
      ..sort((left, right) {
        final side = _entrySideOrder(left.side).compareTo(_entrySideOrder(right.side));
        return side != 0
            ? side
            : left.segment.stableKey.compareTo(right.segment.stableKey);
      });
    if (entryExterior.isNotEmpty) {
      result.add(
        OpeningIntent(
          kind: GeometryOpeningKind.primaryEntry,
          fromSpaceKey: entryKey,
          hostSegment: entryExterior.first.segment,
        ),
      );
    }

    final byPair = <String, GeneratedSharedBoundary>{
      for (final boundary in sharedBoundaries) boundary.pair.stableKey: boundary,
    };
    for (final access in handoff.accessIntents) {
      final boundary = byPair[access.pair.stableKey];
      if (boundary == null) {
        continue;
      }
      result.add(
        OpeningIntent(
          kind: access.kind == DraftAccessKind.openPassage
              ? GeometryOpeningKind.openPassage
              : GeometryOpeningKind.door,
          fromSpaceKey: access.pair.leftKey,
          toSpaceKey: access.pair.rightKey,
          hostSegment: boundary.segment,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  List<GeometryValidationIssue> _validateCandidate({
    required AreaFittedTopologyDraft fittedDraft,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
    required TopologyGeometryHandoff handoff,
    required RectilinearPolygonMm envelope,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSpaceGeometry> exteriorAppendages,
    required List<GeneratedSharedBoundary> sharedBoundaries,
    required List<GeneratedExteriorBoundary> exteriorBoundaries,
    required List<OpeningIntent> openingIntents,
  }) {
    final issues = <GeometryValidationIssue>[];
    final draftByKey = <String, DraftSpace>{
      for (final space in fittedDraft.draft.spaces) space.semanticKey: space,
    };
    final byPair = <String, GeneratedSharedBoundary>{
      for (final boundary in sharedBoundaries) boundary.pair.stableKey: boundary,
    };

    for (final generated in [...interiorSpaces, ...exteriorAppendages]) {
      final draftSpace = draftByKey[generated.semanticKey]!;
      final geometry = draftSpace.sourceSpec.geometry;
      final widthMm = generated.polygon.widthMm;
      final heightMm = generated.polygon.heightMm;
      final shortSide = _min(widthMm, heightMm);
      final longSide = _max(widthMm, heightMm);
      final targetAreaMm2 = generated.fittedAreaDm2 * 10000;
      final areaError = (generated.realizedAreaMm2 - targetAreaMm2).abs();
      if (areaError > _areaToleranceMm2(targetAreaMm2)) {
        issues.add(_issue('p9.geometry.unsatisfiable-area', generated.semanticKey));
      }
      if (shortSide < geometry.minShortSideMm ||
          (geometry.minLongSideMm != null && longSide < geometry.minLongSideMm!)) {
        issues.add(_issue('p9.geometry.min-dimension', generated.semanticKey));
      }
      final aspectBp = widthMm * 10000 ~/ heightMm;
      if (aspectBp < geometry.minAspectBp ||
          aspectBp > geometry.maxAspectBp) {
        issues.add(_issue('p9.geometry.aspect-ratio', generated.semanticKey));
      }
      if (generated.polygon.vertices.length > geometry.maxVertices) {
        issues.add(_issue('p9.geometry.vertex-limit', generated.semanticKey));
      }
      if (generated.polygon.vertices.any(
        (point) =>
            point.xMm % p9GeometryGridMm != 0 ||
            point.yMm % p9GeometryGridMm != 0,
      )) {
        issues.add(_issue('p9.geometry.invalid-interior-envelope', generated.semanticKey));
      }
    }

    final realizedInteriorArea = interiorSpaces.fold<int>(
      0,
      (sum, space) => sum + space.realizedAreaMm2,
    );
    final requestedInteriorArea = fittedDraft.requestedInteriorAreaDm2 * 10000;
    if ((realizedInteriorArea - requestedInteriorArea).abs() >
        _areaToleranceMm2(requestedInteriorArea)) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.unassigned-gap',
          severity: GeometryValidationSeverity.blocker,
          facts: {
            'realizedInteriorAreaMm2': realizedInteriorArea,
            'requestedInteriorAreaMm2': requestedInteriorArea,
          },
        ),
      );
    }
    if (envelope.areaMm2 != realizedInteriorArea) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.unassigned-gap',
          severity: GeometryValidationSeverity.blocker,
          facts: {
            'envelopeAreaMm2': envelope.areaMm2,
            'spaceAreaMm2': realizedInteriorArea,
          },
        ),
      );
    }

    for (var first = 0; first < interiorSpaces.length; first++) {
      for (var second = first + 1; second < interiorSpaces.length; second++) {
        if (_rectangleOverlapAreaMm2(
              interiorSpaces[first].polygon,
              interiorSpaces[second].polygon,
            ) >
            0) {
          issues.add(
            GeometryValidationIssue(
              code: 'p9.geometry.space-overlap',
              severity: GeometryValidationSeverity.blocker,
              affectedKeys: [
                interiorSpaces[first].semanticKey,
                interiorSpaces[second].semanticKey,
              ],
            ),
          );
        }
      }
    }

    for (final pair in handoff.requiredSharedBoundaryPairs) {
      final boundary = byPair[pair.stableKey];
      final minLength = fittedDraft.draft.adjacency
          .where((intent) =>
              intent.normalizedPairKey == pair.stableKey &&
              intent.requirement == TopologyAdjacencyRequirement.required)
          .map((intent) => intent.minSharedBoundaryMm ?? 1)
          .fold<int>(1, _max);
      if (boundary == null || boundary.lengthMm < minLength) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.required-boundary-missing',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [pair.leftKey, pair.rightKey],
            facts: {'minSharedBoundaryMm': minLength},
          ),
        );
      }
    }
    for (final pair in handoff.forbiddenSharedBoundaryPairs) {
      if (byPair.containsKey(pair.stableKey)) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.forbidden-boundary-present',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [pair.leftKey, pair.rightKey],
          ),
        );
      }
    }

    final exposureByKey = <String, int>{};
    for (final boundary in exteriorBoundaries) {
      exposureByKey[boundary.spaceSemanticKey] =
          (exposureByKey[boundary.spaceSemanticKey] ?? 0) + boundary.segment.lengthMm;
    }
    for (final key in handoff.requiredExteriorSpaceKeys) {
      final draftSpace = draftByKey[key];
      if (draftSpace == null ||
          draftSpace.areaParticipation == SpaceAreaParticipation.exteriorAppendage) {
        continue;
      }
      final minimum = draftSpace.sourceSpec.geometry.minExteriorExposureMm ?? 1;
      if ((exposureByKey[key] ?? 0) < minimum) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.exterior-exposure-missing',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [key],
            facts: {'minExteriorExposureMm': minimum},
          ),
        );
      }
    }

    final entryCount = openingIntents
        .where((opening) => opening.kind == GeometryOpeningKind.primaryEntry)
        .length;
    if (entryCount != 1) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.invalid-entry',
          severity: GeometryValidationSeverity.blocker,
          facts: {'entryCount': entryCount},
        ),
      );
    }

    final wetSeparation = _wetCoreMaxSeparationMm(
      handoff.wetCoreGroups,
      [...interiorSpaces, ...exteriorAppendages],
    );
    if (wetSeparation > template.wetCorePolicy.maxGroupSeparationMm) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.wet-core-too-dispersed',
          severity: GeometryValidationSeverity.blocker,
          facts: {
            'actualMm': wetSeparation,
            'maximumMm': template.wetCorePolicy.maxGroupSeparationMm,
          },
        ),
      );
    }

    if (request.exteriorExposurePreference !=
            ApartmentExteriorExposurePreference.any &&
        request.exteriorExposurePreference !=
            ApartmentExteriorExposurePreference.oneSide) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.exposure-preference-mismatch',
          severity: GeometryValidationSeverity.blocker,
        ),
      );
    }
    return issues;
  }

  GeometryMetrics _metrics({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologyGeometryHandoff handoff,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSpaceGeometry> exteriorAppendages,
    required List<GeneratedSharedBoundary> sharedBoundaries,
    required List<GeneratedExteriorBoundary> exteriorBoundaries,
  }) {
    var maxAreaError = 0;
    for (final space in [...interiorSpaces, ...exteriorAppendages]) {
      final error =
          (space.realizedAreaMm2 - space.fittedAreaDm2 * 10000).abs();
      maxAreaError = _max(maxAreaError, error);
    }
    final exposureKeys = handoff.requiredExteriorSpaceKeys.toSet();
    return GeometryMetrics(
      interiorAreaMm2: interiorSpaces.fold(
        0,
        (sum, space) => sum + space.realizedAreaMm2,
      ),
      appendageAreaMm2: exteriorAppendages.fold(
        0,
        (sum, space) => sum + space.realizedAreaMm2,
      ),
      maxAreaErrorMm2: maxAreaError,
      sharedBoundaryLengthMm: sharedBoundaries.fold(
        0,
        (sum, boundary) => sum + boundary.lengthMm,
      ),
      exteriorExposureLengthMm: exteriorBoundaries
          .where((boundary) => exposureKeys.contains(boundary.spaceSemanticKey))
          .fold(0, (sum, boundary) => sum + boundary.segment.lengthMm),
      wetCoreMaxSeparationMm: _wetCoreMaxSeparationMm(
        handoff.wetCoreGroups,
        [...interiorSpaces, ...exteriorAppendages],
      ),
    );
  }

  String _fingerprint({
    required AreaFittedTopologyDraft fittedDraft,
    required RectilinearPolygonMm envelope,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSpaceGeometry> exteriorAppendages,
    required List<GeneratedSharedBoundary> sharedBoundaries,
    required List<GeneratedExteriorBoundary> exteriorBoundaries,
    required List<OpeningIntent> openingIntents,
  }) {
    final lines = <String>[
      'p9.apartment.geometry',
      'algorithm=$geometryAlgorithmVersion',
      'areaFit=${fittedDraft.areaFitFingerprint}',
      'envelope=${envelope.stableSerialization}',
    ];
    final spaces = [...interiorSpaces, ...exteriorAppendages]
      ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    for (final space in spaces) {
      lines.add(
        'space=${space.semanticKey}|${space.participation.name}|${space.polygon.stableSerialization}',
      );
    }
    final boundaries = sharedBoundaries.toList()
      ..sort((a, b) => a.pair.stableKey.compareTo(b.pair.stableKey));
    for (final boundary in boundaries) {
      lines.add('shared=${boundary.pair.stableKey}|${boundary.segment.stableKey}');
    }
    final exterior = exteriorBoundaries.toList()
      ..sort((a, b) {
        final key = a.spaceSemanticKey.compareTo(b.spaceSemanticKey);
        return key != 0 ? key : a.segment.stableKey.compareTo(b.segment.stableKey);
      });
    for (final boundary in exterior) {
      lines.add(
        'exterior=${boundary.spaceSemanticKey}|${boundary.side.name}|${boundary.segment.stableKey}',
      );
    }
    for (var index = 0; index < openingIntents.length; index++) {
      final opening = openingIntents[index];
      lines.add(
        'opening=$index|${opening.kind.name}|${opening.fromSpaceKey ?? ''}|${opening.toSpaceKey ?? ''}|${opening.hostSegment.stableKey}',
      );
    }
    return p9Sha256Hex(lines.join('\n'));
  }
}

final class _GeometryInput {
  const _GeometryInput({required this.space, required this.area});

  final DraftSpace space;
  final FittedSpaceArea area;
}

final class _RowLayout {
  const _RowLayout({
    required this.depthMm,
    required this.widthsMm,
    required this.totalWidthMm,
  });

  final int depthMm;
  final List<int> widthsMm;
  final int totalWidthMm;
}

final class _AppendageDimensions {
  const _AppendageDimensions({required this.widthMm, required this.depthMm});

  final int widthMm;
  final int depthMm;
}

void _bringWetExteriorToFacadeStart(
  List<_GeometryInput> facade,
  TopologyGeometryHandoff handoff,
) {
  final wetKeys = handoff.wetCoreGroups.expand((group) => group).toSet();
  final index = facade.indexWhere(
    (input) => wetKeys.contains(input.space.semanticKey),
  );
  if (index > 0) {
    final value = facade.removeAt(index);
    facade.insert(0, value);
  }
}

void _coLocateRequiredBoundaryPairs(
  List<_GeometryInput> facade,
  List<SemanticSpacePair> requiredPairs,
) {
  for (final pair in requiredPairs) {
    final left = facade.indexWhere((input) => input.space.semanticKey == pair.leftKey);
    final right = facade.indexWhere((input) => input.space.semanticKey == pair.rightKey);
    if (left < 0 || right < 0 || (left - right).abs() == 1) {
      continue;
    }
    final value = facade.removeAt(right);
    final updatedLeft = facade.indexWhere(
      (input) => input.space.semanticKey == pair.leftKey,
    );
    facade.insert(updatedLeft + 1, value);
  }
}

int _compareInput(
  _GeometryInput left,
  _GeometryInput right,
  Map<String, int> stableOrder,
) {
  final leftOrder = stableOrder[left.space.semanticKey] ?? 1 << 20;
  final rightOrder = stableOrder[right.space.semanticKey] ?? 1 << 20;
  final order = leftOrder.compareTo(rightOrder);
  return order != 0
      ? order
      : left.space.semanticKey.compareTo(right.space.semanticKey);
}

int _compareService(
  _GeometryInput left,
  _GeometryInput right,
  Map<String, int> stableOrder,
) {
  final leftEntry = left.space.usage == SpaceUsage.entranceHall ? 0 : 1;
  final rightEntry = right.space.usage == SpaceUsage.entranceHall ? 0 : 1;
  final entry = leftEntry.compareTo(rightEntry);
  if (entry != 0) {
    return entry;
  }
  final leftWet = left.space.sourceSpec.wetSpace ? 0 : 1;
  final rightWet = right.space.sourceSpec.wetSpace ? 0 : 1;
  final wet = leftWet.compareTo(rightWet);
  return wet != 0 ? wet : _compareInput(left, right, stableOrder);
}

GeometryValidationIssue _issue(String code, String key) =>
    GeometryValidationIssue(
      code: code,
      severity: GeometryValidationSeverity.blocker,
      affectedKeys: [key],
    );

P9Failure _failure(
  String code, {
  Map<String, Object?> facts = const {},
}) =>
    P9Failure(
      code: code,
      stage: P9FailureStage.geometry,
      severity: P9FailureSeverity.blocker,
      facts: facts,
    );

int _areaToleranceMm2(int targetAreaMm2) =>
    _max(ApartmentGeometryGenerator.minimumAreaToleranceMm2, targetAreaMm2 ~/ 200);

int _nearestGrid(int valueMm) {
  if (valueMm <= 0) {
    return 0;
  }
  final lower = valueMm ~/ p9GeometryGridMm * p9GeometryGridMm;
  final upper = lower + p9GeometryGridMm;
  return valueMm - lower <= upper - valueMm ? lower : upper;
}

int _ceilGrid(int valueMm) =>
    ((valueMm + p9GeometryGridMm - 1) ~/ p9GeometryGridMm) * p9GeometryGridMm;

int _rectangleOverlapAreaMm2(
  RectilinearPolygonMm first,
  RectilinearPolygonMm second,
) {
  final width = _min(first.maxX, second.maxX) - _max(first.minX, second.minX);
  final height = _min(first.maxY, second.maxY) - _max(first.minY, second.minY);
  return width > 0 && height > 0 ? width * height : 0;
}

int _wetCoreMaxSeparationMm(
  List<List<String>> groups,
  List<GeneratedSpaceGeometry> spaces,
) {
  final byKey = {for (final space in spaces) space.semanticKey: space};
  var maximum = 0;
  for (final group in groups) {
    for (var first = 0; first < group.length; first++) {
      for (var second = first + 1; second < group.length; second++) {
        final left = byKey[group[first]];
        final right = byKey[group[second]];
        if (left == null || right == null) {
          continue;
        }
        final dx = _axisGap(left.polygon.minX, left.polygon.maxX, right.polygon.minX, right.polygon.maxX);
        final dy = _axisGap(left.polygon.minY, left.polygon.maxY, right.polygon.minY, right.polygon.maxY);
        maximum = _max(maximum, dx + dy);
      }
    }
  }
  return maximum;
}

int _axisGap(int aMin, int aMax, int bMin, int bMax) {
  if (aMax < bMin) {
    return bMin - aMax;
  }
  if (bMax < aMin) {
    return aMin - bMax;
  }
  return 0;
}

int _entrySideOrder(GeometryEnvelopeSide side) => switch (side) {
      GeometryEnvelopeSide.west => 0,
      GeometryEnvelopeSide.south => 1,
      GeometryEnvelopeSide.east => 2,
      GeometryEnvelopeSide.north => 3,
    };

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;
