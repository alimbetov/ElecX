import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/boundary_topology.dart';

/// Independent P9.6 structural validation over the packed candidate.
///
/// These checks are intentionally outside the packing algorithm so every
/// current/future geometry strategy is held to the same acceptance boundary.
final class ApartmentGeometryStructuralValidator {
  const ApartmentGeometryStructuralValidator();

  GeometryValidationReport validate({
    required ApartmentGeometryCandidate candidate,
    required AreaFittedTopologyDraft fittedDraft,
  }) {
    final issues = <GeometryValidationIssue>[];
    final draftByKey = <String, DraftSpace>{
      for (final space in fittedDraft.draft.spaces) space.semanticKey: space,
    };
    final allSpaces = [
      ...candidate.interiorSpaces,
      ...candidate.exteriorAppendages,
    ];

    for (final space in allSpaces) {
      final draft = draftByKey[space.semanticKey];
      if (draft == null) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.unknown-generated-space',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [space.semanticKey],
          ),
        );
        continue;
      }
      final maxVertices = draft.sourceSpec.geometry.maxVertices;
      if (space.polygon.vertices.length > maxVertices) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.vertex-limit',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [space.semanticKey],
            facts: {
              'actualVertices': space.polygon.vertices.length,
              'maxVertices': maxVertices,
            },
          ),
        );
      }
    }

    _validatePairwiseOverlap(
      issues: issues,
      spaces: candidate.interiorSpaces,
      code: 'p9.geometry.space-overlap',
    );
    _validatePairwiseOverlap(
      issues: issues,
      spaces: candidate.exteriorAppendages,
      code: 'p9.geometry.appendage-overlap',
    );
    for (final appendage in candidate.exteriorAppendages) {
      for (final interior in candidate.interiorSpaces) {
        if (!_hasPositiveAreaOverlap(appendage.polygon, interior.polygon)) {
          continue;
        }
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.appendage-interior-overlap',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [appendage.semanticKey, interior.semanticKey],
          ),
        );
      }
    }

    return GeometryValidationReport(issues);
  }

  void _validatePairwiseOverlap({
    required List<GeometryValidationIssue> issues,
    required List<GeneratedSpaceGeometry> spaces,
    required String code,
  }) {
    for (var first = 0; first < spaces.length; first++) {
      for (var second = first + 1; second < spaces.length; second++) {
        if (!_hasPositiveAreaOverlap(
          spaces[first].polygon,
          spaces[second].polygon,
        )) {
          continue;
        }
        issues.add(
          GeometryValidationIssue(
            code: code,
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [
              spaces[first].semanticKey,
              spaces[second].semanticKey,
            ],
          ),
        );
      }
    }
  }

  bool _hasPositiveAreaOverlap(
    RectilinearPolygonMm first,
    RectilinearPolygonMm second,
  ) {
    if (first.maxX <= second.minX ||
        second.maxX <= first.minX ||
        first.maxY <= second.minY ||
        second.maxY <= first.minY) {
      return false;
    }

    final xs = <int>{
      ...first.vertices.map((point) => point.xMm),
      ...second.vertices.map((point) => point.xMm),
    }.toList()
      ..sort();
    final ys = <int>{
      ...first.vertices.map((point) => point.yMm),
      ...second.vertices.map((point) => point.yMm),
    }.toList()
      ..sort();

    for (var xIndex = 0; xIndex < xs.length - 1; xIndex++) {
      final x0 = xs[xIndex];
      final x1 = xs[xIndex + 1];
      if (x1 <= first.minX ||
          x0 >= first.maxX ||
          x1 <= second.minX ||
          x0 >= second.maxX) {
        continue;
      }
      for (var yIndex = 0; yIndex < ys.length - 1; yIndex++) {
        final y0 = ys[yIndex];
        final y1 = ys[yIndex + 1];
        if (y1 <= first.minY ||
            y0 >= first.maxY ||
            y1 <= second.minY ||
            y0 >= second.maxY) {
          continue;
        }
        final pointX2 = x0 + x1;
        final pointY2 = y0 + y1;
        if (_containsDoubledPoint(first, pointX2, pointY2) &&
            _containsDoubledPoint(second, pointX2, pointY2)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _containsDoubledPoint(
    RectilinearPolygonMm polygon,
    int pointX2,
    int pointY2,
  ) {
    var inside = false;
    final vertices = polygon.vertices;
    for (var index = 0; index < vertices.length; index++) {
      final first = vertices[index];
      final second = vertices[(index + 1) % vertices.length];
      if (first.xMm != second.xMm) {
        continue;
      }
      final minY2 = _min(first.yMm, second.yMm) * 2;
      final maxY2 = _max(first.yMm, second.yMm) * 2;
      if (pointY2 <= minY2 || pointY2 >= maxY2) {
        continue;
      }
      if (first.xMm * 2 > pointX2) {
        inside = !inside;
      }
    }
    return inside;
  }
}

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;
