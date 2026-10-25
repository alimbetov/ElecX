import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_candidate_ranking.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/apartment_topology/apartment_vector_scene.dart';
import '../../../../domain/project_space_semantics.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

final class ApartmentVectorSceneBuildResult {
  ApartmentVectorSceneBuildResult({
    required this.scene,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final ApartmentTopologyVectorScene? scene;
  final List<P9Failure> failures;

  bool get accepted =>
      scene != null && failures.every((failure) => !failure.isBlocker);
}

/// P9.8 provider-neutral vector-scene renderer.
///
/// The renderer is intentionally one-way: immutable P9.6 geometry is projected
/// into bounded display primitives. It never mutates topology/geometry, never
/// recalculates P9.7 scores and never allocates canonical project identities.
final class ApartmentTopologyVectorRenderer {
  const ApartmentTopologyVectorRenderer();

  static const String rendererVersion = 'p9.vector.v1';
  static const int logicalPaddingUnits = 12;
  static const int maxPolygonCount = 40;
  static const int maxLineCount = 128;
  static const int maxLabelCount = 32;
  static const int maxElementCount = 256;

  ApartmentVectorSceneBuildResult render({
    required RankedApartmentCandidate rankedCandidate,
    required ApartmentTopologyTemplate template,
  }) {
    final candidate = rankedCandidate.candidate;
    final failures = <P9Failure>[];

    if (!candidate.validation.accepted) {
      failures.add(
        _failure(
          'p9.render.summary-inconsistent',
          facts: {'reason': 'candidateNotAcceptedByP9.6'},
        ),
      );
      return ApartmentVectorSceneBuildResult(scene: null, failures: failures);
    }
    if (candidate.templateId != template.templateId ||
        candidate.templateVersion != template.templateVersion ||
        candidate.family != template.family) {
      failures.add(
        _failure(
          'p9.render.summary-inconsistent',
          facts: {
            'reason': 'candidateTemplateMismatch',
            'candidateTemplateId': candidate.templateId.value,
            'templateId': template.templateId.value,
          },
        ),
      );
      return ApartmentVectorSceneBuildResult(scene: null, failures: failures);
    }

    final invalidKey = _firstInvalidKey(candidate);
    if (invalidKey != null) {
      failures.add(
        _failure(
          'p9.render.invalid-scene-key',
          facts: {'semanticKey': invalidKey},
        ),
      );
      return ApartmentVectorSceneBuildResult(scene: null, failures: failures);
    }

    final bounds = _displayBounds(candidate);
    if (bounds == null || bounds.widthMm <= 0 || bounds.heightMm <= 0) {
      failures.add(_failure('p9.render.invalid-bounds'));
      return ApartmentVectorSceneBuildResult(scene: null, failures: failures);
    }
    final projection = _Projection.forBounds(bounds);

    final summary = _summary(
      rankedCandidate: rankedCandidate,
      template: template,
    );
    if (summary == null) {
      failures.add(
        _failure(
          'p9.render.summary-inconsistent',
          facts: {'reason': 'unsupportedTemplateSummary'},
        ),
      );
      return ApartmentVectorSceneBuildResult(scene: null, failures: failures);
    }

    final elements = <ApartmentVectorElement>[];
    elements.add(
      ApartmentVectorPolygonElement(
        role: ApartmentVectorRole.interiorEnvelope,
        generationKey: 'envelope:interior',
        points: _projectPolygon(candidate.interiorEnvelope, projection),
      ),
    );

    final interior = candidate.interiorSpaces.toList()
      ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    for (final space in interior) {
      elements.add(
        ApartmentVectorPolygonElement(
          role: ApartmentVectorRole.interiorSpaceRegion,
          generationKey: 'space:${space.semanticKey}',
          points: _projectPolygon(space.polygon, projection),
        ),
      );
    }

    final appendages = candidate.exteriorAppendages.toList()
      ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    for (final space in appendages) {
      elements.add(
        ApartmentVectorPolygonElement(
          role: ApartmentVectorRole.exteriorAppendageRegion,
          generationKey: 'appendage:${space.semanticKey}',
          points: _projectPolygon(space.polygon, projection),
        ),
      );
    }

    final partitions = candidate.sharedBoundaries.toList()
      ..sort((a, b) {
        final segment = a.segment.stableKey.compareTo(b.segment.stableKey);
        return segment != 0 ? segment : a.pair.stableKey.compareTo(b.pair.stableKey);
      });
    for (final boundary in partitions) {
      elements.add(
        ApartmentVectorLineElement(
          role: ApartmentVectorRole.internalPartition,
          generationKey:
              'partition:${boundary.pair.stableKey}:${boundary.segment.stableKey}',
          start: projection.point(boundary.segment.start.xMm,
              boundary.segment.start.yMm),
          end: projection.point(
              boundary.segment.end.xMm, boundary.segment.end.yMm),
        ),
      );
    }

    final openings = candidate.openingIntents.toList()
      ..sort((a, b) => _openingKey(a).compareTo(_openingKey(b)));
    for (final opening in openings) {
      final start = opening.hostSegment.start;
      final end = opening.hostSegment.end;
      final anchor = projection.point(
        (start.xMm + end.xMm) ~/ 2,
        (start.yMm + end.yMm) ~/ 2,
      );
      elements.add(
        ApartmentVectorMarkerElement(
          role: opening.kind == GeometryOpeningKind.primaryEntry
              ? ApartmentVectorRole.entryMarker
              : ApartmentVectorRole.accessMarker,
          generationKey: _openingKey(opening),
          anchor: anchor,
          markerKind: opening.kind.name,
        ),
      );
    }

    final labelSpaces = <GeneratedSpaceGeometry>[...interior, ...appendages]
      ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    for (final space in labelSpaces) {
      elements.add(
        ApartmentVectorLabelAnchorElement(
          generationKey: 'label:${space.semanticKey}',
          semanticLabelKey: 'space.${_baseKey(space.semanticKey)}',
          anchor: projection.point(
            (space.polygon.minX + space.polygon.maxX) ~/ 2,
            (space.polygon.minY + space.polygon.maxY) ~/ 2,
          ),
        ),
      );
    }

    final wetCoreCount = interior.where((space) {
      final spec = _specForSpace(template, space.semanticKey);
      return spec?.wetSpace ?? false;
    }).length;
    elements.add(
      ApartmentVectorMetadataElement(
        role: ApartmentVectorRole.wetCoreMetadata,
        generationKey: 'metadata:wet-core-count',
        value: '$wetCoreCount',
      ),
    );

    final warnings = candidate.validation.issues
        .where((issue) => issue.severity == GeometryValidationSeverity.warning)
        .toList()
      ..sort((a, b) => a.stableKey.compareTo(b.stableKey));
    for (final warning in warnings) {
      elements.add(
        ApartmentVectorMetadataElement(
          role: ApartmentVectorRole.warningMetadata,
          generationKey: 'warning:${warning.stableKey}',
          value: warning.code,
        ),
      );
    }

    final limitFailure = _validateElementLimits(elements);
    if (limitFailure != null) {
      failures.add(limitFailure);
      return ApartmentVectorSceneBuildResult(scene: null, failures: failures);
    }

    final canonicalScene = <String>[
      'p9.apartment.vector-scene',
      'rendererVersion=$rendererVersion',
      'geometryFingerprint=${candidate.geometryFingerprint}',
      'widthUnits=$p9ApartmentCardViewBoxWidth',
      'heightUnits=$p9ApartmentCardViewBoxHeight',
      'semanticLabelKey=wizard.apartment.candidate.preview',
      'summary=${summary.stableSerialization}',
      for (final element in elements) element.stableSerialization,
    ].join('\n');
    final sceneFingerprint = p9Sha256Hex(canonicalScene);

    return ApartmentVectorSceneBuildResult(
      scene: ApartmentTopologyVectorScene(
        widthUnits: p9ApartmentCardViewBoxWidth,
        heightUnits: p9ApartmentCardViewBoxHeight,
        semanticLabelKey: 'wizard.apartment.candidate.preview',
        elements: elements,
        summary: summary,
        rendererVersion: rendererVersion,
        sourceGeometryFingerprint: candidate.geometryFingerprint,
        sceneFingerprint: sceneFingerprint,
      ),
      failures: failures,
    );
  }

  ApartmentPreviewSummary? _summary({
    required RankedApartmentCandidate rankedCandidate,
    required ApartmentTopologyTemplate template,
  }) {
    final candidate = rankedCandidate.candidate;
    if (template.constraints.supportedKitchenModes.length != 1) {
      return null;
    }
    final kitchenMode = template.constraints.supportedKitchenModes.single;
    var habitableRoomCount = 0;
    var bathroomCount = 0;
    var balconyCount = 0;
    for (final space in candidate.interiorSpaces) {
      final usage = _specForSpace(template, space.semanticKey)?.usage;
      if (_isHabitableUsage(usage)) {
        habitableRoomCount++;
      }
      if (usage == SpaceUsage.bathroom || usage == SpaceUsage.showerRoom) {
        bathroomCount++;
      }
    }
    for (final space in candidate.exteriorAppendages) {
      final usage = _specForSpace(template, space.semanticKey)?.usage;
      if (usage == SpaceUsage.balcony ||
          usage == SpaceUsage.loggia ||
          usage == SpaceUsage.terrace) {
        balconyCount++;
      }
    }
    final interiorAreaDm2 = candidate.interiorSpaces.fold<int>(
      0,
      (sum, space) => sum + space.fittedAreaDm2,
    );
    final appendageAreaDm2 = candidate.exteriorAppendages.fold<int>(
      0,
      (sum, space) => sum + space.fittedAreaDm2,
    );
    if (habitableRoomCount <= 0 ||
        interiorAreaDm2 <= 0 ||
        rankedCandidate.finalScoreBp < 0 ||
        rankedCandidate.finalScoreBp > 10000) {
      return null;
    }
    return ApartmentPreviewSummary(
      habitableRoomCount: habitableRoomCount,
      interiorAreaDm2: interiorAreaDm2,
      exteriorAppendageAreaDm2: appendageAreaDm2,
      kitchenMode: kitchenMode,
      family: candidate.family,
      bathroomCount: bathroomCount,
      balconyCount: balconyCount,
      scoreBp: rankedCandidate.finalScoreBp,
    );
  }

  P9Failure? _validateElementLimits(List<ApartmentVectorElement> elements) {
    final polygons = elements.whereType<ApartmentVectorPolygonElement>().length;
    final lines = elements.whereType<ApartmentVectorLineElement>().length;
    final labels = elements.whereType<ApartmentVectorLabelAnchorElement>().length;
    if (polygons <= maxPolygonCount &&
        lines <= maxLineCount &&
        labels <= maxLabelCount &&
        elements.length <= maxElementCount) {
      return null;
    }
    return _failure(
      'p9.render.element-limit',
      facts: {
        'polygonCount': polygons,
        'lineCount': lines,
        'labelCount': labels,
        'elementCount': elements.length,
      },
    );
  }
}

List<ApartmentVectorPoint> _projectPolygon(
  RectilinearPolygonMm polygon,
  _Projection projection,
) =>
    [
      for (final point in polygon.vertices)
        projection.point(point.xMm, point.yMm),
    ];

String? _firstInvalidKey(ApartmentGeometryCandidate candidate) {
  final keys = <String>[
    for (final space in candidate.interiorSpaces) space.semanticKey,
    for (final space in candidate.exteriorAppendages) space.semanticKey,
  ];
  for (final key in keys) {
    if (key.trim().isEmpty || key.codeUnits.any((unit) => unit < 32)) {
      return key;
    }
  }
  return null;
}

_BoundsMm? _displayBounds(ApartmentGeometryCandidate candidate) {
  var minX = candidate.interiorEnvelope.minX;
  var minY = candidate.interiorEnvelope.minY;
  var maxX = candidate.interiorEnvelope.maxX;
  var maxY = candidate.interiorEnvelope.maxY;
  for (final appendage in candidate.exteriorAppendages) {
    if (appendage.polygon.minX < minX) minX = appendage.polygon.minX;
    if (appendage.polygon.minY < minY) minY = appendage.polygon.minY;
    if (appendage.polygon.maxX > maxX) maxX = appendage.polygon.maxX;
    if (appendage.polygon.maxY > maxY) maxY = appendage.polygon.maxY;
  }
  if (maxX <= minX || maxY <= minY) {
    return null;
  }
  return _BoundsMm(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

TopologySpaceSpec? _specForSpace(
  ApartmentTopologyTemplate template,
  String semanticKey,
) {
  final baseKey = _baseKey(semanticKey);
  for (final spec in template.spaces) {
    if (spec.semanticKey == baseKey) return spec;
  }
  return null;
}

String _baseKey(String semanticKey) {
  final index = semanticKey.indexOf(':');
  return index < 0 ? semanticKey : semanticKey.substring(0, index);
}

bool _isHabitableUsage(SpaceUsage? usage) =>
    usage == SpaceUsage.livingRoom ||
    usage == SpaceUsage.bedroom ||
    usage == SpaceUsage.kitchenLiving ||
    usage == SpaceUsage.diningRoom ||
    usage == SpaceUsage.office ||
    usage == SpaceUsage.study;

String _openingKey(OpeningIntent opening) {
  final left = opening.fromSpaceKey ?? '-';
  final right = opening.toSpaceKey ?? '-';
  return 'opening:${opening.kind.name}:$left:$right:${opening.hostSegment.stableKey}';
}

final class _BoundsMm {
  const _BoundsMm({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  int get widthMm => maxX - minX;
  int get heightMm => maxY - minY;
}

final class _Projection {
  const _Projection({
    required this.bounds,
    required this.numerator,
    required this.denominator,
    required this.offsetX,
    required this.offsetY,
  });

  factory _Projection.forBounds(_BoundsMm bounds) {
    const availableWidth =
        p9ApartmentCardViewBoxWidth - ApartmentTopologyVectorRenderer.logicalPaddingUnits * 2;
    const availableHeight =
        p9ApartmentCardViewBoxHeight - ApartmentTopologyVectorRenderer.logicalPaddingUnits * 2;
    final widthLimited =
        availableWidth * bounds.heightMm <= availableHeight * bounds.widthMm;
    final numerator = widthLimited ? availableWidth : availableHeight;
    final denominator = widthLimited ? bounds.widthMm : bounds.heightMm;
    final projectedWidth = bounds.widthMm * numerator ~/ denominator;
    final projectedHeight = bounds.heightMm * numerator ~/ denominator;
    final offsetX = ApartmentTopologyVectorRenderer.logicalPaddingUnits +
        (availableWidth - projectedWidth) ~/ 2;
    final offsetY = ApartmentTopologyVectorRenderer.logicalPaddingUnits +
        (availableHeight - projectedHeight) ~/ 2;
    return _Projection(
      bounds: bounds,
      numerator: numerator,
      denominator: denominator,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  final _BoundsMm bounds;
  final int numerator;
  final int denominator;
  final int offsetX;
  final int offsetY;

  ApartmentVectorPoint point(int xMm, int yMm) {
    final x = offsetX + _roundDiv((xMm - bounds.minX) * numerator, denominator);
    final y = offsetY + _roundDiv((yMm - bounds.minY) * numerator, denominator);
    return ApartmentVectorPoint(xUnits: x, yUnits: y);
  }
}

int _roundDiv(int numerator, int denominator) =>
    (numerator + denominator ~/ 2) ~/ denominator;

P9Failure _failure(String code, {Map<String, Object?> facts = const {}}) =>
    P9Failure(
      code: code,
      stage: P9FailureStage.rendering,
      severity: P9FailureSeverity.blocker,
      facts: facts,
    );
