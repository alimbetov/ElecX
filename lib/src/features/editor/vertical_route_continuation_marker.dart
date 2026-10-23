import '../../domain/project_identity.dart';
import '../../domain/route_host.dart';

enum VerticalRouteContinuationDirection { upward, downward }

/// Presentation-safe description of one committed inter-level cable
/// continuation. It carries stable physical SlabId identity and never infers a
/// vertical crossing from geometry alone.
final class VerticalRouteContinuationMarker {
  const VerticalRouteContinuationMarker({
    required this.transitionId,
    required this.routeId,
    required this.slabId,
    required this.direction,
    required this.currentSurface,
    required this.targetSurface,
  });

  final String transitionId;
  final String routeId;
  final SlabId slabId;
  final VerticalRouteContinuationDirection direction;
  final RoomSurfaceRef currentSurface;
  final RoomSurfaceRef targetSurface;

  String get glyph =>
      direction == VerticalRouteContinuationDirection.upward ? '↑' : '↓';

  String get semanticsLabel =>
      'Трасса $routeId: продолжить ${direction == VerticalRouteContinuationDirection.upward ? 'на уровень выше' : 'на уровень ниже'} через перекрытие ${slabId.value}';
}

abstract final class VerticalRouteContinuationMarkerResolver {
  static VerticalRouteContinuationMarker? resolve({
    required String routeId,
    required RouteHostTransition transition,
    required RoomSurfaceRef currentSurface,
  }) {
    if (routeId.trim().isEmpty ||
        transition.kind != RouteHostTransitionKind.levelPenetration ||
        !transition.requiresPenetration ||
        transition.slabId == null) {
      return null;
    }

    final from = transition.fromHost.surface;
    final to = transition.toHost.surface;
    if (from == null || to == null) return null;

    final target = currentSurface == from
        ? to
        : currentSurface == to
            ? from
            : null;
    if (target == null) return null;

    final direction = _direction(currentSurface, target);
    if (direction == null) return null;

    return VerticalRouteContinuationMarker(
      transitionId: transition.id,
      routeId: routeId,
      slabId: transition.slabId!,
      direction: direction,
      currentSurface: currentSurface,
      targetSurface: target,
    );
  }

  static VerticalRouteContinuationDirection? _direction(
    RoomSurfaceRef current,
    RoomSurfaceRef target,
  ) {
    if (current.type == SurfacePlaneType.ceiling &&
        target.type == SurfacePlaneType.floor) {
      return VerticalRouteContinuationDirection.upward;
    }
    if (current.type == SurfacePlaneType.floor &&
        target.type == SurfacePlaneType.ceiling) {
      return VerticalRouteContinuationDirection.downward;
    }
    return null;
  }
}
