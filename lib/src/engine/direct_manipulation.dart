import '../domain/geometry.dart';

enum ManipulationHandleKind {
  move,
  resizeStart,
  resizeEnd,
  vertex,
  routePoint,
  rotate,
}

final class ManipulationHandle {
  const ManipulationHandle({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.worldPoint,
  });

  final String id;
  final String ownerId;
  final ManipulationHandleKind kind;
  final MmPoint worldPoint;
}

final class ManipulationSession {
  const ManipulationSession({
    required this.handle,
    required this.startWorld,
    required this.currentWorld,
  });

  final ManipulationHandle handle;
  final MmPoint startWorld;
  final MmPoint currentWorld;

  int get deltaX => currentWorld.x - startWorld.x;
  int get deltaY => currentWorld.y - startWorld.y;

  ManipulationSession update(MmPoint point) => ManipulationSession(
        handle: handle,
        startWorld: startWorld,
        currentWorld: point,
      );
}

abstract final class DirectManipulationEngine {
  static ManipulationHandle? hitTest({
    required Iterable<ManipulationHandle> handles,
    required MmPoint point,
    required double radiusMm,
  }) {
    ManipulationHandle? best;
    var bestDistance = double.infinity;
    for (final handle in handles) {
      final distance = handle.worldPoint.distanceTo(point);
      if (distance <= radiusMm && distance < bestDistance) {
        best = handle;
        bestDistance = distance;
      }
    }
    return best;
  }

  static ManipulationSession begin({
    required ManipulationHandle handle,
    required MmPoint startWorld,
  }) =>
      ManipulationSession(
        handle: handle,
        startWorld: startWorld,
        currentWorld: startWorld,
      );
}
