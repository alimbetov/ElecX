import '../apartment_topology.dart';
import '../boundary_topology.dart';
import '../project_identity.dart';
import 'apartment_semantic_validation.dart';

const int p9GeometryGridMm = 10;

enum GeometryEnvelopeSide { north, east, south, west }

enum GeometryOpeningKind { primaryEntry, door, openPassage }

final class GeometrySegmentMm {
  GeometrySegmentMm({required this.start, required this.end}) {
    if (start == end) {
      throw ArgumentError('Geometry segment must have non-zero length.');
    }
    if (start.xMm != end.xMm && start.yMm != end.yMm) {
      throw ArgumentError('Geometry segment must be orthogonal.');
    }
  }

  final BoundaryPointMm start;
  final BoundaryPointMm end;

  int get lengthMm => start.xMm == end.xMm
      ? (end.yMm - start.yMm).abs()
      : (end.xMm - start.xMm).abs();

  bool get vertical => start.xMm == end.xMm;

  String get stableKey => '${start.xMm},${start.yMm}>${end.xMm},${end.yMm}';
}

/// ID-free rectilinear polygon used while browsing P9 candidates.
///
/// Persistent BoundaryEdgeId allocation remains P9.11 responsibility.
final class RectilinearPolygonMm {
  RectilinearPolygonMm._(this.vertices);

  factory RectilinearPolygonMm.normalized(
    Iterable<BoundaryPointMm> input, {
    int gridMm = p9GeometryGridMm,
  }) {
    if (gridMm <= 0) {
      throw ArgumentError.value(gridMm, 'gridMm', 'Must be positive.');
    }
    final normalized = _normalizePoints(input.toList());
    if (normalized.length < 4) {
      throw ArgumentError(
          'Rectilinear polygon requires at least four vertices.');
    }
    for (final point in normalized) {
      if (point.xMm % gridMm != 0 || point.yMm % gridMm != 0) {
        throw ArgumentError(
          'Polygon coordinate ${point.xMm},${point.yMm} is off the $gridMm mm grid.',
        );
      }
    }
    for (var index = 0; index < normalized.length; index++) {
      final start = normalized[index];
      final end = normalized[(index + 1) % normalized.length];
      if (start.xMm != end.xMm && start.yMm != end.yMm) {
        throw ArgumentError('Polygon edge must be orthogonal.');
      }
    }
    if (_twiceSignedArea(normalized) == 0) {
      throw ArgumentError('Polygon must enclose positive area.');
    }
    if (_hasSelfIntersection(normalized)) {
      throw ArgumentError('Polygon must not self-intersect.');
    }

    var stable = normalized;
    if (_twiceSignedArea(stable) < 0) {
      stable = stable.reversed.toList();
    }
    stable = _rotateToStableStart(stable);
    return RectilinearPolygonMm._(List.unmodifiable(stable));
  }

  factory RectilinearPolygonMm.rectangle({
    required int xMm,
    required int yMm,
    required int widthMm,
    required int heightMm,
  }) {
    if (widthMm <= 0 || heightMm <= 0) {
      throw ArgumentError('Rectangle dimensions must be positive.');
    }
    return RectilinearPolygonMm.normalized([
      BoundaryPointMm(xMm: xMm, yMm: yMm),
      BoundaryPointMm(xMm: xMm + widthMm, yMm: yMm),
      BoundaryPointMm(xMm: xMm + widthMm, yMm: yMm + heightMm),
      BoundaryPointMm(xMm: xMm, yMm: yMm + heightMm),
    ]);
  }

  final List<BoundaryPointMm> vertices;

  int get areaMm2 => _twiceSignedArea(vertices).abs() ~/ 2;

  int get minX => vertices.map((point) => point.xMm).reduce(_min);
  int get maxX => vertices.map((point) => point.xMm).reduce(_max);
  int get minY => vertices.map((point) => point.yMm).reduce(_min);
  int get maxY => vertices.map((point) => point.yMm).reduce(_max);

  int get widthMm => maxX - minX;
  int get heightMm => maxY - minY;

  List<GeometrySegmentMm> get segments => List.unmodifiable([
        for (var index = 0; index < vertices.length; index++)
          GeometrySegmentMm(
            start: vertices[index],
            end: vertices[(index + 1) % vertices.length],
          ),
      ]);

  String get stableSerialization =>
      vertices.map((point) => '${point.xMm},${point.yMm}').join(';');
}

final class GeneratedSpaceGeometry {
  const GeneratedSpaceGeometry({
    required this.semanticKey,
    required this.participation,
    required this.polygon,
    required this.fittedAreaDm2,
  });

  final String semanticKey;
  final SpaceAreaParticipation participation;
  final RectilinearPolygonMm polygon;
  final int fittedAreaDm2;

  int get realizedAreaMm2 => polygon.areaMm2;
}

final class GeneratedSharedBoundary {
  GeneratedSharedBoundary({
    required String leftSpaceKey,
    required String rightSpaceKey,
    required this.segment,
  }) : pair = SemanticSpacePair(leftSpaceKey, rightSpaceKey);

  final SemanticSpacePair pair;
  final GeometrySegmentMm segment;

  int get lengthMm => segment.lengthMm;
}

final class GeneratedExteriorBoundary {
  const GeneratedExteriorBoundary({
    required this.spaceSemanticKey,
    required this.side,
    required this.segment,
  });

  final String spaceSemanticKey;
  final GeometryEnvelopeSide side;
  final GeometrySegmentMm segment;
}

final class OpeningIntent {
  OpeningIntent({
    required this.kind,
    required this.hostSegment,
    this.fromSpaceKey,
    this.toSpaceKey,
  }) {
    if (kind == GeometryOpeningKind.primaryEntry && fromSpaceKey == null) {
      throw ArgumentError(
          'Primary entry must identify the apartment entry space.');
    }
    if (kind != GeometryOpeningKind.primaryEntry &&
        (fromSpaceKey == null || toSpaceKey == null)) {
      throw ArgumentError('Internal opening intent requires two spaces.');
    }
  }

  final GeometryOpeningKind kind;
  final String? fromSpaceKey;
  final String? toSpaceKey;
  final GeometrySegmentMm hostSegment;
}

final class GeometryMetrics {
  const GeometryMetrics({
    required this.interiorAreaMm2,
    required this.appendageAreaMm2,
    required this.maxAreaErrorMm2,
    required this.sharedBoundaryLengthMm,
    required this.exteriorExposureLengthMm,
    required this.wetCoreMaxSeparationMm,
  });

  final int interiorAreaMm2;
  final int appendageAreaMm2;
  final int maxAreaErrorMm2;
  final int sharedBoundaryLengthMm;
  final int exteriorExposureLengthMm;
  final int wetCoreMaxSeparationMm;
}

enum GeometryValidationSeverity { warning, blocker }

final class GeometryValidationIssue {
  GeometryValidationIssue({
    required this.code,
    required this.severity,
    Iterable<String> affectedKeys = const [],
    Map<String, Object?> facts = const {},
  })  : affectedKeys = List.unmodifiable(affectedKeys.toList()..sort()),
        facts = Map.unmodifiable(facts);

  final String code;
  final GeometryValidationSeverity severity;
  final List<String> affectedKeys;
  final Map<String, Object?> facts;

  String get stableKey => '$code|${affectedKeys.join(',')}';
}

final class GeometryValidationReport {
  GeometryValidationReport(Iterable<GeometryValidationIssue> issues)
      : issues = List.unmodifiable(
          issues.toList()..sort((a, b) => a.stableKey.compareTo(b.stableKey)),
        );

  final List<GeometryValidationIssue> issues;

  bool get accepted => issues
      .every((issue) => issue.severity != GeometryValidationSeverity.blocker);
}

final class ApartmentGeometryCandidate {
  ApartmentGeometryCandidate({
    required this.templateId,
    required this.templateVersion,
    required this.family,
    required this.variantSeedId,
    required this.areaFitFingerprint,
    required this.interiorEnvelope,
    required Iterable<GeneratedSpaceGeometry> interiorSpaces,
    required Iterable<GeneratedSpaceGeometry> exteriorAppendages,
    required Iterable<GeneratedSharedBoundary> sharedBoundaries,
    required Iterable<GeneratedExteriorBoundary> exteriorBoundaries,
    required Iterable<OpeningIntent> openingIntents,
    required this.metrics,
    required this.validation,
    required this.geometryAlgorithmVersion,
    required this.geometryFingerprint,
  })  : interiorSpaces = List.unmodifiable(
          interiorSpaces.toList()
            ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey)),
        ),
        exteriorAppendages = List.unmodifiable(
          exteriorAppendages.toList()
            ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey)),
        ),
        sharedBoundaries = List.unmodifiable(
          sharedBoundaries.toList()
            ..sort((a, b) => a.pair.stableKey.compareTo(b.pair.stableKey)),
        ),
        exteriorBoundaries = List.unmodifiable(
          exteriorBoundaries.toList()
            ..sort((a, b) {
              final key = a.spaceSemanticKey.compareTo(b.spaceSemanticKey);
              return key != 0 ? key : a.side.name.compareTo(b.side.name);
            }),
        ),
        openingIntents = List.unmodifiable(openingIntents);

  final TemplateId templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final String variantSeedId;
  final String areaFitFingerprint;
  final RectilinearPolygonMm interiorEnvelope;
  final List<GeneratedSpaceGeometry> interiorSpaces;
  final List<GeneratedSpaceGeometry> exteriorAppendages;
  final List<GeneratedSharedBoundary> sharedBoundaries;
  final List<GeneratedExteriorBoundary> exteriorBoundaries;
  final List<OpeningIntent> openingIntents;
  final GeometryMetrics metrics;
  final GeometryValidationReport validation;
  final String geometryAlgorithmVersion;
  final String geometryFingerprint;
}

GeometrySegmentMm? intersectCollinearSegments(
  GeometrySegmentMm first,
  GeometrySegmentMm second,
) {
  if (first.vertical != second.vertical) {
    return null;
  }
  if (first.vertical) {
    if (first.start.xMm != second.start.xMm) {
      return null;
    }
    final start = _max(
      _min(first.start.yMm, first.end.yMm),
      _min(second.start.yMm, second.end.yMm),
    );
    final end = _min(
      _max(first.start.yMm, first.end.yMm),
      _max(second.start.yMm, second.end.yMm),
    );
    if (end <= start) {
      return null;
    }
    return GeometrySegmentMm(
      start: BoundaryPointMm(xMm: first.start.xMm, yMm: start),
      end: BoundaryPointMm(xMm: first.start.xMm, yMm: end),
    );
  }

  if (first.start.yMm != second.start.yMm) {
    return null;
  }
  final start = _max(
    _min(first.start.xMm, first.end.xMm),
    _min(second.start.xMm, second.end.xMm),
  );
  final end = _min(
    _max(first.start.xMm, first.end.xMm),
    _max(second.start.xMm, second.end.xMm),
  );
  if (end <= start) {
    return null;
  }
  return GeometrySegmentMm(
    start: BoundaryPointMm(xMm: start, yMm: first.start.yMm),
    end: BoundaryPointMm(xMm: end, yMm: first.start.yMm),
  );
}

List<BoundaryPointMm> _normalizePoints(List<BoundaryPointMm> input) {
  final points = <BoundaryPointMm>[];
  for (final point in input) {
    if (points.isEmpty || points.last != point) {
      points.add(point);
    }
  }
  if (points.length > 1 && points.first == points.last) {
    points.removeLast();
  }
  var changed = true;
  while (changed && points.length >= 4) {
    changed = false;
    for (var index = 0; index < points.length; index++) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      if (_collinear(previous, current, next)) {
        points.removeAt(index);
        changed = true;
        break;
      }
    }
  }
  return points;
}

List<BoundaryPointMm> _rotateToStableStart(List<BoundaryPointMm> points) {
  var best = 0;
  for (var index = 1; index < points.length; index++) {
    if (_comparePoint(points[index], points[best]) < 0) {
      best = index;
    }
  }
  return [
    for (var offset = 0; offset < points.length; offset++)
      points[(best + offset) % points.length],
  ];
}

int _comparePoint(BoundaryPointMm left, BoundaryPointMm right) {
  final x = left.xMm.compareTo(right.xMm);
  return x != 0 ? x : left.yMm.compareTo(right.yMm);
}

bool _collinear(
  BoundaryPointMm first,
  BoundaryPointMm middle,
  BoundaryPointMm last,
) =>
    (first.xMm == middle.xMm && middle.xMm == last.xMm) ||
    (first.yMm == middle.yMm && middle.yMm == last.yMm);

int _twiceSignedArea(List<BoundaryPointMm> points) {
  var area = 0;
  // Translate before multiplying: Site coordinates can approach 1e9 mm while
  // building extents remain small. Absolute cross-products lose integer bits
  // on Dart/JS even though the final area is well inside the exact range.
  final origin = points.first;
  for (var index = 0; index < points.length; index++) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    area += (current.xMm - origin.xMm) * (next.yMm - origin.yMm) -
        (next.xMm - origin.xMm) * (current.yMm - origin.yMm);
  }
  return area;
}

bool _hasSelfIntersection(List<BoundaryPointMm> points) {
  final segments = <GeometrySegmentMm>[
    for (var index = 0; index < points.length; index++)
      GeometrySegmentMm(
        start: points[index],
        end: points[(index + 1) % points.length],
      ),
  ];
  for (var first = 0; first < segments.length; first++) {
    for (var second = first + 1; second < segments.length; second++) {
      final adjacent =
          second == first + 1 || (first == 0 && second == segments.length - 1);
      if (adjacent) {
        continue;
      }
      if (_segmentsIntersect(segments[first], segments[second])) {
        return true;
      }
    }
  }
  return false;
}

bool _segmentsIntersect(GeometrySegmentMm first, GeometrySegmentMm second) {
  if (first.vertical && second.vertical) {
    return first.start.xMm == second.start.xMm &&
        _intervalsTouch(
          first.start.yMm,
          first.end.yMm,
          second.start.yMm,
          second.end.yMm,
        );
  }
  if (!first.vertical && !second.vertical) {
    return first.start.yMm == second.start.yMm &&
        _intervalsTouch(
          first.start.xMm,
          first.end.xMm,
          second.start.xMm,
          second.end.xMm,
        );
  }
  final vertical = first.vertical ? first : second;
  final horizontal = first.vertical ? second : first;
  return vertical.start.xMm >= _min(horizontal.start.xMm, horizontal.end.xMm) &&
      vertical.start.xMm <= _max(horizontal.start.xMm, horizontal.end.xMm) &&
      horizontal.start.yMm >= _min(vertical.start.yMm, vertical.end.yMm) &&
      horizontal.start.yMm <= _max(vertical.start.yMm, vertical.end.yMm);
}

bool _intervalsTouch(int a1, int a2, int b1, int b2) =>
    _max(_min(a1, a2), _min(b1, b2)) <= _min(_max(a1, a2), _max(b1, b2));

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;
