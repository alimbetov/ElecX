final class WallProfilePoint {
  const WallProfilePoint(this.xMm, this.yMm);

  final int xMm;
  final int yMm;
}

/// Editable wall elevation outline in wall-local millimetres.
///
/// X runs from wall start to wall end. Y runs from finished floor upward.
/// The polygon must describe the usable wall face and may represent beams,
/// steps, sloped tops, niches or other non-rectangular boundaries.
final class WallProfile {
  WallProfile({required List<WallProfilePoint> vertices})
      : vertices = List.unmodifiable(vertices) {
    if (vertices.length < 4) {
      throw ArgumentError('Wall profile must contain at least four vertices.');
    }
    if (vertices.any((point) => point.xMm < 0 || point.yMm < 0)) {
      throw ArgumentError('Wall profile coordinates must be non-negative.');
    }
  }

  factory WallProfile.rectangle({
    required int widthMm,
    required int heightMm,
  }) {
    if (widthMm <= 0 || heightMm <= 0) {
      throw ArgumentError('Wall profile dimensions must be positive.');
    }
    return WallProfile(
      vertices: [
        const WallProfilePoint(0, 0),
        WallProfilePoint(widthMm, 0),
        WallProfilePoint(widthMm, heightMm),
        WallProfilePoint(0, heightMm),
      ],
    );
  }

  final List<WallProfilePoint> vertices;

  int get maxX => vertices.fold(0, (value, point) => point.xMm > value ? point.xMm : value);
  int get maxY => vertices.fold(0, (value, point) => point.yMm > value ? point.yMm : value);

  /// Creates a rectangular downward notch from the top boundary.
  /// Useful for beams and boxed structural elements.
  WallProfile withTopNotch({
    required int startMm,
    required int widthMm,
    required int depthMm,
  }) {
    if (startMm < 0 || widthMm <= 0 || depthMm <= 0) {
      throw ArgumentError('Notch dimensions are invalid.');
    }
    if (startMm + widthMm > maxX || depthMm >= maxY) {
      throw ArgumentError('Notch exceeds wall profile bounds.');
    }

    final top = maxY;
    return WallProfile(
      vertices: [
        const WallProfilePoint(0, 0),
        WallProfilePoint(maxX, 0),
        WallProfilePoint(maxX, top),
        WallProfilePoint(startMm + widthMm, top),
        WallProfilePoint(startMm + widthMm, top - depthMm),
        WallProfilePoint(startMm, top - depthMm),
        WallProfilePoint(startMm, top),
        WallProfilePoint(0, top),
      ],
    );
  }

  /// Replaces the upper contour while preserving floor edge and side edges.
  /// Points must be ordered from left to right and stay inside wall width.
  WallProfile withTopPolyline(List<WallProfilePoint> topPoints) {
    if (topPoints.length < 2) {
      throw ArgumentError('Top polyline requires at least two points.');
    }
    var previousX = -1;
    for (final point in topPoints) {
      if (point.xMm < 0 || point.xMm > maxX || point.yMm <= 0) {
        throw ArgumentError('Top polyline point is outside wall bounds.');
      }
      if (point.xMm <= previousX) {
        throw ArgumentError('Top polyline points must be ordered by X.');
      }
      previousX = point.xMm;
    }
    if (topPoints.first.xMm != 0 || topPoints.last.xMm != maxX) {
      throw ArgumentError('Top polyline must start at X=0 and end at wall width.');
    }

    return WallProfile(
      vertices: [
        const WallProfilePoint(0, 0),
        WallProfilePoint(maxX, 0),
        ...topPoints.reversed,
      ],
    );
  }

  bool containsPoint(int xMm, int yMm) {
    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final a = vertices[i];
      final b = vertices[j];
      final intersects = ((a.yMm > yMm) != (b.yMm > yMm)) &&
          (xMm <
              (b.xMm - a.xMm) * (yMm - a.yMm) / (b.yMm - a.yMm) + a.xMm);
      if (intersects) inside = !inside;
    }
    return inside || _onBoundary(xMm, yMm);
  }

  bool containsRect({
    required int leftMm,
    required int bottomMm,
    required int widthMm,
    required int heightMm,
  }) {
    final right = leftMm + widthMm;
    final top = bottomMm + heightMm;
    return containsPoint(leftMm, bottomMm) &&
        containsPoint(right, bottomMm) &&
        containsPoint(right, top) &&
        containsPoint(leftMm, top);
  }

  bool _onBoundary(int xMm, int yMm) {
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final cross = (xMm - a.xMm) * (b.yMm - a.yMm) -
          (yMm - a.yMm) * (b.xMm - a.xMm);
      if (cross != 0) continue;
      final minX = a.xMm < b.xMm ? a.xMm : b.xMm;
      final maxX = a.xMm > b.xMm ? a.xMm : b.xMm;
      final minY = a.yMm < b.yMm ? a.yMm : b.yMm;
      final maxY = a.yMm > b.yMm ? a.yMm : b.yMm;
      if (xMm >= minX && xMm <= maxX && yMm >= minY && yMm <= maxY) {
        return true;
      }
    }
    return false;
  }
}
