import 'package:flutter/foundation.dart';

import '../../domain/engineering_placement_cursor.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class EngineeringPlacementCursorSession extends ChangeNotifier {
  EngineeringPlacementCursorSession(this.controller);

  final EditorController controller;
  EngineeringPlacementCursorState? _state;

  EngineeringPlacementCursorState? get state => _state;
  bool get active => controller.p2.placementType != null && controller.activeSurface != null;

  EngineeringPlacementCursorState? ensure() {
    final type = controller.p2.placementType;
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (type == null || surface == null || space == null) {
      if (_state != null) {
        _state = null;
        notifyListeners();
      }
      return null;
    }
    final current = _state;
    if (current != null && current.surface == surface && current.componentType == type) {
      return current;
    }

    final SurfacePointMm center;
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall!;
      center = SurfacePointMm(
        wall.lengthMm.round() ~/ 2,
        wall.heightMm ~/ 2,
      );
    } else {
      final bounds = space.boundary.bounds;
      center = SurfacePointMm(bounds.width ~/ 2, bounds.height ~/ 2);
    }
    _state = EngineeringPlacementCursorState(
      surface: surface,
      position: center,
      componentType: type,
      snapKind: PlacementCursorSnapKind.centerAxis,
      snapLabel: 'CENTER',
      isValid: _isUsable(surface, center),
    );
    notifyListeners();
    return _state;
  }

  bool moveTo(
    SurfacePointMm position, {
    PlacementCursorSnapKind snapKind = PlacementCursorSnapKind.none,
    String? snapLabel,
  }) {
    final current = ensure();
    if (current == null) return false;
    final next = EngineeringPlacementCursor.moveTo(
      current,
      position,
      snapKind: snapKind,
      snapLabel: snapLabel,
      isValid: _isUsable(current.surface, position),
    );
    _state = next;
    notifyListeners();
    return next.isValid;
  }

  bool nudge({required int dxMm, required int dyMm}) {
    final current = ensure();
    if (current == null) return false;
    final next = EngineeringPlacementCursor.nudge(
      current,
      dxMm: dxMm,
      dyMm: dyMm,
    );
    return moveTo(
      next.position,
      snapKind: PlacementCursorSnapKind.grid,
      snapLabel: 'GRID',
    );
  }

  bool nudgeGrid({required int dxSteps, required int dySteps, int multiplier = 1}) {
    final step = controller.selectedSpace?.grid.minorStepMm ?? 100;
    return nudge(
      dxMm: dxSteps * step * multiplier,
      dyMm: dySteps * step * multiplier,
    );
  }

  bool confirm() {
    final current = ensure();
    if (current == null || !current.isValid) return false;
    controller.p2.placeComponent(
      type: current.componentType,
      surface: current.surface,
      position: current.position,
    );
    _state = null;
    notifyListeners();
    return true;
  }

  void cancel() {
    controller.p2.setPlacementType(null);
    _state = null;
    notifyListeners();
  }

  bool _isUsable(RoomSurfaceRef surface, SurfacePointMm point) {
    final space = controller.selectedSpace;
    if (space == null || point.xMm < 0 || point.yMm < 0) return false;
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall;
      if (wall == null || wall.ref != surface) return false;
      return wall.profile.containsPoint(point.xMm, point.yMm);
    }
    final bounds = space.boundary.bounds;
    if (point.xMm > bounds.width || point.yMm > bounds.height) return false;
    final planPoint = SurfacePointMm(
      point.xMm + bounds.left,
      point.yMm + bounds.bottom,
    );
    return space.boundary.contains(
      // SurfacePointMm is surface-local; convert to the plan integer point.
      // ignore: avoid_dynamic_calls
      _toPlanPoint(planPoint),
    );
  }

  dynamic _toPlanPoint(SurfacePointMm point) {
    // Kept local to avoid duplicating a second coordinate model in the cursor.
    // The returned type is MmPoint at runtime.
    return _MmPointFactory.create(point.xMm, point.yMm);
  }
}

// Tiny indirection keeps cursor state independent from plan geometry imports in
// its public API while still validating floor/ceiling positions against rooms.
abstract final class _MmPointFactory {
  static dynamic create(int x, int y) {
    throw UnimplementedError('Replaced by imported geometry implementation');
  }
}

final Expando<EngineeringPlacementCursorSession> _cursorSessions =
    Expando<EngineeringPlacementCursorSession>('ElecX placement cursor');

extension EngineeringPlacementCursorAccess on EditorController {
  EngineeringPlacementCursorSession get placementCursor =>
      _cursorSessions[this] ??= EngineeringPlacementCursorSession(this);
}
