import '../../domain/surfaces.dart';

final class CableMandatoryWaypoint {
  const CableMandatoryWaypoint({
    required this.segmentIndex,
    required this.pointIndex,
    required this.point,
  });

  final int segmentIndex;
  final int pointIndex;
  final SurfacePointMm point;

  Map<String, Object> toJson() => {
        'segmentIndex': segmentIndex,
        'pointIndex': pointIndex,
        'xMm': point.xMm,
        'yMm': point.yMm,
      };

  factory CableMandatoryWaypoint.fromJson(Map<String, Object?> json) {
    final segmentIndex = json['segmentIndex'];
    final pointIndex = json['pointIndex'];
    final xMm = json['xMm'];
    final yMm = json['yMm'];
    if (segmentIndex is! int ||
        pointIndex is! int ||
        xMm is! int ||
        yMm is! int ||
        segmentIndex < 0 ||
        pointIndex < 0) {
      throw FormatException('Invalid cable waypoint payload.');
    }
    return CableMandatoryWaypoint(
      segmentIndex: segmentIndex,
      pointIndex: pointIndex,
      point: SurfacePointMm(xMm, yMm),
    );
  }
}

/// Persistent editing constraints attached to one route identity.
///
/// These are engineering/editor intent, not transient widget state. They are
/// immutable so they can live safely in EditorP2State/history and be serialized
/// by the project persistence layer.
final class CableRouteConstraints {
  CableRouteConstraints({
    Set<int> lockedSegments = const {},
    List<CableMandatoryWaypoint> mandatoryWaypoints = const [],
  })  : lockedSegments = Set.unmodifiable(lockedSegments),
        mandatoryWaypoints = List.unmodifiable(mandatoryWaypoints) {
    if (this.lockedSegments.any((index) => index < 0)) {
      throw ArgumentError('Locked segment indices must be non-negative.');
    }
  }

  static final empty = CableRouteConstraints();

  final Set<int> lockedSegments;
  final List<CableMandatoryWaypoint> mandatoryWaypoints;

  bool get isEmpty => lockedSegments.isEmpty && mandatoryWaypoints.isEmpty;

  bool isSegmentLocked(int segmentIndex) =>
      lockedSegments.contains(segmentIndex);

  bool segmentHasWaypoints(int segmentIndex) => mandatoryWaypoints.any(
        (item) => item.segmentIndex == segmentIndex,
      );

  bool isWaypoint(int segmentIndex, int pointIndex) => mandatoryWaypoints.any(
        (item) =>
            item.segmentIndex == segmentIndex && item.pointIndex == pointIndex,
      );

  CableRouteConstraints toggleSegmentLock(int segmentIndex) {
    if (segmentIndex < 0) {
      throw ArgumentError.value(segmentIndex, 'segmentIndex');
    }
    final next = lockedSegments.toSet();
    if (!next.add(segmentIndex)) next.remove(segmentIndex);
    return CableRouteConstraints(
      lockedSegments: next,
      mandatoryWaypoints: mandatoryWaypoints,
    );
  }

  CableRouteConstraints toggleWaypoint({
    required int segmentIndex,
    required int pointIndex,
    required SurfacePointMm point,
  }) {
    if (segmentIndex < 0 || pointIndex < 0) {
      throw ArgumentError('Waypoint indices must be non-negative.');
    }
    final next = mandatoryWaypoints.toList();
    final existing = next.indexWhere(
      (item) =>
          item.segmentIndex == segmentIndex && item.pointIndex == pointIndex,
    );
    if (existing >= 0) {
      next.removeAt(existing);
    } else {
      next.add(
        CableMandatoryWaypoint(
          segmentIndex: segmentIndex,
          pointIndex: pointIndex,
          point: point,
        ),
      );
    }
    return CableRouteConstraints(
      lockedSegments: lockedSegments,
      mandatoryWaypoints: next,
    );
  }

  /// Rebinds persistent constraints to replacement route geometry.
  ///
  /// Waypoints are physical anchors, so their coordinates are authoritative.
  /// A route edit may insert/remove intermediate vertices before a waypoint;
  /// retaining the old numeric index would then point at the wrong geometry.
  /// We therefore prefer the old index only when it still contains the same
  /// coordinate, otherwise search the same segment for that physical point.
  /// Missing physical anchors are dropped rather than silently rebound to an
  /// unrelated vertex.
  CableRouteConstraints reconcile(List<List<SurfacePointMm>> segmentPoints) {
    final validLocks = lockedSegments
        .where((segmentIndex) => segmentIndex < segmentPoints.length)
        .toSet();
    final nextWaypoints = <CableMandatoryWaypoint>[];
    for (final waypoint in mandatoryWaypoints) {
      if (waypoint.segmentIndex >= segmentPoints.length) continue;
      final points = segmentPoints[waypoint.segmentIndex];
      var index = -1;
      if (waypoint.pointIndex < points.length &&
          _samePoint(points[waypoint.pointIndex], waypoint.point)) {
        index = waypoint.pointIndex;
      } else {
        index = points.indexWhere((point) => _samePoint(point, waypoint.point));
      }
      if (index < 0) continue;
      nextWaypoints.add(
        CableMandatoryWaypoint(
          segmentIndex: waypoint.segmentIndex,
          pointIndex: index,
          point: waypoint.point,
        ),
      );
    }
    return CableRouteConstraints(
      lockedSegments: validLocks,
      mandatoryWaypoints: nextWaypoints,
    );
  }

  Map<String, Object> toJson() => {
        'lockedSegments': lockedSegments.toList()..sort(),
        'mandatoryWaypoints': [
          for (final waypoint in mandatoryWaypoints) waypoint.toJson(),
        ],
      };

  factory CableRouteConstraints.fromJson(Map<String, Object?> json) {
    final lockedRaw = json['lockedSegments'];
    final waypointRaw = json['mandatoryWaypoints'];
    if (lockedRaw is! List || waypointRaw is! List) {
      throw FormatException('Invalid cable route constraint payload.');
    }
    final locked = <int>{};
    for (final value in lockedRaw) {
      if (value is! int || value < 0) {
        throw FormatException('Invalid locked cable segment index.');
      }
      locked.add(value);
    }
    final waypoints = <CableMandatoryWaypoint>[];
    for (final value in waypointRaw) {
      if (value is! Map) {
        throw FormatException('Invalid mandatory cable waypoint.');
      }
      waypoints.add(
        CableMandatoryWaypoint.fromJson(
          value.map((key, item) => MapEntry(key.toString(), item)),
        ),
      );
    }
    return CableRouteConstraints(
      lockedSegments: locked,
      mandatoryWaypoints: waypoints,
    );
  }

  static bool _samePoint(SurfacePointMm a, SurfacePointMm b) =>
      a.xMm == b.xMm && a.yMm == b.yMm;
}
