import 'apartment_topology/apartment_geometry.dart';

/// Exact integer tests shared by P9 geometry qualification and P10 composition.
/// Boundary contact is legal; a positive interior intersection is a collision.
abstract final class RectilinearPolygonRelations {
  static bool overlapsInterior(
      RectilinearPolygonMm first, RectilinearPolygonMm second) {
    if (first.maxX <= second.minX ||
        second.maxX <= first.minX ||
        first.maxY <= second.minY ||
        second.maxY <= first.minY) {
      return false;
    }
    final xs = {
      ...first.vertices.map((point) => point.xMm),
      ...second.vertices.map((point) => point.xMm)
    }.toList()
      ..sort();
    final ys = {
      ...first.vertices.map((point) => point.yMm),
      ...second.vertices.map((point) => point.yMm)
    }.toList()
      ..sort();
    for (var x = 0; x < xs.length - 1; x++) {
      if (xs[x + 1] <= first.minX ||
          xs[x] >= first.maxX ||
          xs[x + 1] <= second.minX ||
          xs[x] >= second.maxX) {
        continue;
      }
      for (var y = 0; y < ys.length - 1; y++) {
        if (ys[y + 1] <= first.minY ||
            ys[y] >= first.maxY ||
            ys[y + 1] <= second.minY ||
            ys[y] >= second.maxY) {
          continue;
        }
        if (_containsDoubledPoint(
                first, xs[x] + xs[x + 1], ys[y] + ys[y + 1]) &&
            _containsDoubledPoint(
                second, xs[x] + xs[x + 1], ys[y] + ys[y + 1])) {
          return true;
        }
      }
    }
    return false;
  }

  static List<GeometrySegmentMm> sharedSegments(
          RectilinearPolygonMm first, RectilinearPolygonMm second) =>
      [
        for (final a in first.segments)
          for (final b in second.segments)
            if (intersectCollinearSegments(a, b) case final segment?) segment,
      ]..sort((a, b) => a.stableKey.compareTo(b.stableKey));

  static bool containsSegment(
      GeometrySegmentMm edge, GeometrySegmentMm segment) {
    final shared = intersectCollinearSegments(edge, segment);
    return shared != null && shared.lengthMm == segment.lengthMm;
  }

  static bool _containsDoubledPoint(
      RectilinearPolygonMm polygon, int x2, int y2) {
    var inside = false;
    for (final edge in polygon.segments) {
      if (!edge.vertical) continue;
      final minY =
          edge.start.yMm < edge.end.yMm ? edge.start.yMm : edge.end.yMm;
      final maxY =
          edge.start.yMm > edge.end.yMm ? edge.start.yMm : edge.end.yMm;
      if (y2 > minY * 2 && y2 < maxY * 2 && edge.start.xMm * 2 > x2) {
        inside = !inside;
      }
    }
    return inside;
  }
}
