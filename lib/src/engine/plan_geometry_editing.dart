import 'dart:math' as math;

import '../domain/geometry.dart';

abstract final class PlanGeometryEditing {
  static const int minimumEdgeLengthMm = 300;

  static MmPolygon? moveVertex({
    required MmPolygon boundary,
    required int vertexIndex,
    required MmPoint target,
  }) {
    if (vertexIndex < 0 || vertexIndex >= boundary.vertices.length) return null;
    final vertices = [...boundary.vertices];
    vertices[vertexIndex] = target;
    return _validated(vertices);
  }

  /// Moves one wall parallel to itself. The pointer delta is projected on the
  /// wall normal, so accidental movement along the wall does not distort it.
  static MmPolygon? moveEdge({
    required MmPolygon boundary,
    required int edgeIndex,
    required MmPoint dragStart,
    required MmPoint dragCurrent,
  }) {
    final vertices = boundary.vertices;
    if (edgeIndex < 0 || edgeIndex >= vertices.length) return null;
    final a = vertices[edgeIndex];
    final b = vertices[(edgeIndex + 1) % vertices.length];
    final ex = (b.x - a.x).toDouble();
    final ey = (b.y - a.y).toDouble();
    final length = math.sqrt(ex * ex + ey * ey);
    if (length == 0) return null;

    final nx = -ey / length;
    final ny = ex / length;
    final dx = (dragCurrent.x - dragStart.x).toDouble();
    final dy = (dragCurrent.y - dragStart.y).toDouble();
    final normalDistance = dx * nx + dy * ny;
    final offsetX = (nx * normalDistance).round();
    final offsetY = (ny * normalDistance).round();

    final next = [...vertices];
    next[edgeIndex] = MmPoint(a.x + offsetX, a.y + offsetY);
    final endIndex = (edgeIndex + 1) % vertices.length;
    next[endIndex] = MmPoint(b.x + offsetX, b.y + offsetY);
    return _validated(next);
  }

  static bool isValid(MmPolygon boundary) =>
      _edgeLengthsValid(boundary.vertices) &&
      !_hasSelfIntersection(boundary.vertices) &&
      _signedArea2(boundary.vertices) != 0;

  static MmPolygon? _validated(List<MmPoint> vertices) {
    if (!_edgeLengthsValid(vertices) ||
        _hasSelfIntersection(vertices) ||
        _signedArea2(vertices) == 0) {
      return null;
    }
    return MmPolygon(vertices);
  }

  static bool _edgeLengthsValid(List<MmPoint> vertices) {
    for (var i = 0; i < vertices.length; i++) {
      if (vertices[i].distanceTo(vertices[(i + 1) % vertices.length]) <
          minimumEdgeLengthMm) {
        return false;
      }
    }
    return true;
  }

  static int _signedArea2(List<MmPoint> vertices) {
    var sum = 0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum;
  }

  static bool _hasSelfIntersection(List<MmPoint> vertices) {
    final count = vertices.length;
    for (var i = 0; i < count; i++) {
      final a1 = vertices[i];
      final a2 = vertices[(i + 1) % count];
      for (var j = i + 1; j < count; j++) {
        if (j == i ||
            (j + 1) % count == i ||
            (i + 1) % count == j) {
          continue;
        }
        final b1 = vertices[j];
        final b2 = vertices[(j + 1) % count];
        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  static bool _segmentsIntersect(MmPoint a, MmPoint b, MmPoint c, MmPoint d) {
    int orientation(MmPoint p, MmPoint q, MmPoint r) {
      final value =
          (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
      if (value == 0) return 0;
      return value > 0 ? 1 : 2;
    }

    bool onSegment(MmPoint p, MmPoint q, MmPoint r) =>
        q.x <= math.max(p.x, r.x) &&
        q.x >= math.min(p.x, r.x) &&
        q.y <= math.max(p.y, r.y) &&
        q.y >= math.min(p.y, r.y);

    final o1 = orientation(a, b, c);
    final o2 = orientation(a, b, d);
    final o3 = orientation(c, d, a);
    final o4 = orientation(c, d, b);
    if (o1 != o2 && o3 != o4) return true;
    if (o1 == 0 && onSegment(a, c, b)) return true;
    if (o2 == 0 && onSegment(a, d, b)) return true;
    if (o3 == 0 && onSegment(c, a, d)) return true;
    if (o4 == 0 && onSegment(c, b, d)) return true;
    return false;
  }
}
