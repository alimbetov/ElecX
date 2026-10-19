import 'dart:math' as math;

final class MmPoint {
  const MmPoint(this.x, this.y);

  final int x;
  final int y;

  double distanceTo(MmPoint other) {
    final dx = (x - other.x).toDouble();
    final dy = (y - other.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      other is MmPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

final class MmBounds {
  const MmBounds({
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
  })  : assert(right >= left),
        assert(top >= bottom);

  factory MmBounds.fromPoints(MmPoint a, MmPoint b) => MmBounds(
        left: math.min(a.x, b.x),
        bottom: math.min(a.y, b.y),
        right: math.max(a.x, b.x),
        top: math.max(a.y, b.y),
      );

  final int left;
  final int bottom;
  final int right;
  final int top;

  int get width => right - left;
  int get height => top - bottom;
  MmPoint get center => MmPoint(left + width ~/ 2, bottom + height ~/ 2);

  bool contains(MmPoint point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= bottom &&
      point.y <= top;

  bool intersects(MmBounds other) =>
      left <= other.right &&
      right >= other.left &&
      bottom <= other.top &&
      top >= other.bottom;

  MmBounds expanded(int marginMm) {
    if (marginMm < 0) {
      throw ArgumentError.value(marginMm, 'marginMm', 'Must be non-negative.');
    }
    return MmBounds(
      left: left - marginMm,
      bottom: bottom - marginMm,
      right: right + marginMm,
      top: top + marginMm,
    );
  }

  MmBounds union(MmBounds other) => MmBounds(
        left: math.min(left, other.left),
        bottom: math.min(bottom, other.bottom),
        right: math.max(right, other.right),
        top: math.max(top, other.top),
      );
}

final class MmPolygon {
  MmPolygon(Iterable<MmPoint> vertices)
      : vertices = List.unmodifiable(vertices) {
    if (this.vertices.length < 3) {
      throw ArgumentError('A room boundary requires at least three vertices.');
    }
  }

  factory MmPolygon.rectangle(MmPoint a, MmPoint b) {
    final left = math.min(a.x, b.x);
    final right = math.max(a.x, b.x);
    final bottom = math.min(a.y, b.y);
    final top = math.max(a.y, b.y);
    if (left == right || bottom == top) {
      throw ArgumentError(
          'A room rectangle must have non-zero width and height.');
    }
    return MmPolygon([
      MmPoint(left, bottom),
      MmPoint(right, bottom),
      MmPoint(right, top),
      MmPoint(left, top),
    ]);
  }

  final List<MmPoint> vertices;

  MmBounds get bounds {
    final xs = vertices.map((point) => point.x);
    final ys = vertices.map((point) => point.y);
    return MmBounds(
      left: xs.reduce((a, b) => a < b ? a : b),
      bottom: ys.reduce((a, b) => a < b ? a : b),
      right: xs.reduce((a, b) => a > b ? a : b),
      top: ys.reduce((a, b) => a > b ? a : b),
    );
  }

  bool contains(MmPoint point) {
    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final a = vertices[i];
      final b = vertices[j];
      final crosses = (a.y > point.y) != (b.y > point.y);
      if (!crosses) continue;
      final crossingX = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
      if (point.x < crossingX) inside = !inside;
    }
    return inside;
  }
}
