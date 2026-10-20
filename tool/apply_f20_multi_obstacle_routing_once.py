from pathlib import Path

p = Path('lib/src/engine/normative_route_engine.dart')
text = p.read_text()

anchor = '''    final seen = <String>{};
    final candidates = <RouteCandidate>[];
'''
insert = '''    final graphPath = _searchOrthogonalPath(
      source: source,
      target: target,
      context: context,
    );
    if (graphPath != null) paths.add(graphPath);

    final seen = <String>{};
    final candidates = <RouteCandidate>[];
'''
if anchor not in text:
    raise SystemExit('candidate anchor not found')
text = text.replace(anchor, insert, 1)

marker = '''  static RouteCandidate _candidate(
'''
helper = r'''  static List<SurfacePointMm>? _searchOrthogonalPath({
    required SurfacePointMm source,
    required SurfacePointMm target,
    required RouteNormativeContext context,
  }) {
    if (source == target) return null;

    final minX = context.edgeClearanceMm;
    final maxX = context.widthMm - context.edgeClearanceMm;
    final minY = context.edgeClearanceMm;
    final maxY = context.heightMm - context.edgeClearanceMm;
    if (minX > maxX || minY > maxY) return null;

    final clearance = context.detourClearanceMm > context.edgeClearanceMm
        ? context.detourClearanceMm
        : context.edgeClearanceMm + 1;
    final xs = <int>{source.xMm, target.xMm, minX, maxX};
    final ys = <int>{source.yMm, target.yMm, minY, maxY};
    for (final obstacle in context.obstacles) {
      xs
        ..add((obstacle.leftMm - clearance).clamp(minX, maxX))
        ..add((obstacle.rightMm + clearance).clamp(minX, maxX));
      ys
        ..add((obstacle.topMm - clearance).clamp(minY, maxY))
        ..add((obstacle.bottomMm + clearance).clamp(minY, maxY));
    }

    final sortedX = xs.where((x) => x >= minX && x <= maxX).toList()..sort();
    final sortedY = ys.where((y) => y >= minY && y <= maxY).toList()..sort();
    if (sortedX.length * sortedY.length > 30000) return null;

    final nodes = <SurfacePointMm>[];
    final nodeIndex = <String, int>{};
    bool usablePoint(SurfacePointMm point) {
      if (context.obstacles.any((obstacle) => obstacle.contains(point))) {
        return false;
      }
      if (context.boundary.length >= 3 &&
          !_insideOrBoundary(point, context.boundary)) {
        return false;
      }
      return true;
    }

    for (final y in sortedY) {
      for (final x in sortedX) {
        final point = SurfacePointMm(x, y);
        if (point != source && point != target && !usablePoint(point)) continue;
        nodeIndex['$x,$y'] = nodes.length;
        nodes.add(point);
      }
    }
    final sourceIndex = nodeIndex['${source.xMm},${source.yMm}'];
    final targetIndex = nodeIndex['${target.xMm},${target.yMm}'];
    if (sourceIndex == null || targetIndex == null) return null;

    final adjacency = <int, List<(int, int)>>{};
    void connectLine(List<int> line) {
      for (var i = 1; i < line.length; i++) {
        final aIndex = line[i - 1];
        final bIndex = line[i];
        final a = nodes[aIndex];
        final b = nodes[bIndex];
        final validation = validate(points: [a, b], context: context);
        if (!validation.isValid) continue;
        final length = (a.xMm - b.xMm).abs() + (a.yMm - b.yMm).abs();
        adjacency.putIfAbsent(aIndex, () => <(int, int)>[]).add((bIndex, length));
        adjacency.putIfAbsent(bIndex, () => <(int, int)>[]).add((aIndex, length));
      }
    }

    for (final y in sortedY) {
      final line = <int>[];
      for (final x in sortedX) {
        final index = nodeIndex['$x,$y'];
        if (index != null) line.add(index);
      }
      connectLine(line);
    }
    for (final x in sortedX) {
      final line = <int>[];
      for (final y in sortedY) {
        final index = nodeIndex['$x,$y'];
        if (index != null) line.add(index);
      }
      connectLine(line);
    }

    // Direction is part of the state so bend cost is deterministic and the
    // shortest result is engineering-friendly, not merely geometrically short.
    // 0 = none/start, 1 = horizontal, 2 = vertical.
    final distance = <(int, int), double>{(sourceIndex, 0): 0};
    final previous = <(int, int), (int, int)>{};
    final unvisited = <(int, int)>{(sourceIndex, 0)};
    (int, int)? bestTarget;

    while (unvisited.isNotEmpty) {
      (int, int)? current;
      var bestDistance = double.infinity;
      for (final candidate in unvisited) {
        final value = distance[candidate] ?? double.infinity;
        if (value < bestDistance) {
          bestDistance = value;
          current = candidate;
        }
      }
      if (current == null) break;
      unvisited.remove(current);
      final currentNode = current.$1;
      final currentDirection = current.$2;
      if (currentNode == targetIndex) {
        bestTarget = current;
        break;
      }
      for (final edge in adjacency[currentNode] ?? const <(int, int)>[]) {
        final nextNode = edge.$1;
        final a = nodes[currentNode];
        final b = nodes[nextNode];
        final nextDirection = a.yMm == b.yMm ? 1 : 2;
        final bendPenalty = currentDirection != 0 && currentDirection != nextDirection
            ? 250.0
            : 0.0;
        final nextState = (nextNode, nextDirection);
        final nextDistance = bestDistance + edge.$2 + bendPenalty;
        if (nextDistance < (distance[nextState] ?? double.infinity)) {
          distance[nextState] = nextDistance;
          previous[nextState] = current;
          unvisited.add(nextState);
        }
      }
    }

    if (bestTarget == null) return null;
    final reversed = <SurfacePointMm>[];
    var cursor = bestTarget;
    while (true) {
      reversed.add(nodes[cursor.$1]);
      if (cursor.$1 == sourceIndex && cursor.$2 == 0) break;
      final parent = previous[cursor];
      if (parent == null) return null;
      cursor = parent;
    }
    final path = reversed.reversed.toList(growable: false);
    final compact = _compactCollinear(path);
    return validate(points: compact, context: context).isValid
        ? List.unmodifiable(compact)
        : null;
  }

  static List<SurfacePointMm> _compactCollinear(List<SurfacePointMm> points) {
    if (points.length <= 2) return _compact(points);
    final result = <SurfacePointMm>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final a = result.last;
      final b = points[i];
      final c = points[i + 1];
      final collinear = (a.xMm == b.xMm && b.xMm == c.xMm) ||
          (a.yMm == b.yMm && b.yMm == c.yMm);
      if (!collinear) result.add(b);
    }
    result.add(points.last);
    return result;
  }

'''
if marker not in text:
    raise SystemExit('candidate method marker not found')
text = text.replace(marker, helper + marker, 1)
p.write_text(text)

Path('test/f20_multi_obstacle_routing_test.dart').write_text(r'''import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const surface = RoomSurfaceRef.wall('room-f20', 0);

  test('F20 finds an orthogonal path requiring multiple obstacle detours', () {
    const context = RouteNormativeContext(
      surface: surface,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
      detourClearanceMm: 50,
      obstacles: [
        RouteObstacleMm(
          id: 'lower-block',
          leftMm: 800,
          topMm: 0,
          rightMm: 1200,
          bottomMm: 1300,
        ),
        RouteObstacleMm(
          id: 'upper-block',
          leftMm: 1800,
          topMm: 700,
          rightMm: 2200,
          bottomMm: 2000,
        ),
      ],
    );
    const source = SurfacePointMm(200, 1000);
    const target = SurfacePointMm(2800, 1000);

    final candidates = NormativeRouteEngine.buildCandidates(
      source: source,
      target: target,
      context: context,
    );
    final best = candidates.firstWhere((candidate) => candidate.validation.isValid);

    expect(best.points.first, source);
    expect(best.points.last, target);
    expect(best.points.length, greaterThanOrEqualTo(6));
    expect(
      NormativeRouteEngine.validate(points: best.points, context: context).isValid,
      isTrue,
    );
    expect(best.points.any((point) => point.yMm >= 1350), isTrue);
    expect(best.points.any((point) => point.yMm <= 650), isTrue);
  });

  test('F20 returns no valid candidate when obstacles form a complete barrier', () {
    const context = RouteNormativeContext(
      surface: surface,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
      detourClearanceMm: 50,
      obstacles: [
        RouteObstacleMm(
          id: 'barrier',
          leftMm: 1400,
          topMm: 0,
          rightMm: 1600,
          bottomMm: 2000,
        ),
      ],
    );
    final candidates = NormativeRouteEngine.buildCandidates(
      source: const SurfacePointMm(200, 1000),
      target: const SurfacePointMm(2800, 1000),
      context: context,
    );
    expect(candidates.where((candidate) => candidate.validation.isValid), isEmpty);
  });

  test('F20 keeps simple direct routing optimal when no detour is needed', () {
    const context = RouteNormativeContext(
      surface: surface,
      widthMm: 3000,
      heightMm: 2000,
      edgeClearanceMm: 0,
    );
    final candidates = NormativeRouteEngine.buildCandidates(
      source: const SurfacePointMm(200, 500),
      target: const SurfacePointMm(2800, 500),
      context: context,
    );
    final best = candidates.first;
    expect(best.validation.isValid, isTrue);
    expect(best.points, const [SurfacePointMm(200, 500), SurfacePointMm(2800, 500)]);
  });
}
''')
