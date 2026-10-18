import 'package:flutter/foundation.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/engineering_placement_cursor.dart';
import '../../domain/geometry.dart';
import '../../domain/installation_guides.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class EngineeringPlacementCursorSession extends ChangeNotifier {
  EngineeringPlacementCursorSession(this.controller);

  final EditorController controller;
  EngineeringPlacementCursorState? _state;

  EngineeringPlacementCursorState? get state => _state;
  bool get active =>
      controller.p2.placementType != null && controller.activeSurface != null;

  EngineeringPlacementCursorState? ensure() {
    final type = controller.p2.placementType;
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (type == null || surface == null || space == null) {
      _state = null;
      return null;
    }
    final current = _state;
    if (current != null &&
        current.surface == surface &&
        current.componentType == type) {
      return current;
    }

    late final SurfacePointMm initial;
    var snapKind = PlacementCursorSnapKind.centerAxis;
    var snapLabel = 'CENTER';
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall!;
      final profile = InstallationGuideProfile.residentialProjectDefault;
      final yMm = switch (type) {
        ElectricalComponentType.socketOutlet => profile.socketHeightMm,
        ElectricalComponentType.switchControl => profile.switchHeightMm,
        _ => wall.heightMm ~/ 2,
      };
      if (type == ElectricalComponentType.socketOutlet ||
          type == ElectricalComponentType.switchControl) {
        snapKind = PlacementCursorSnapKind.installationGuide;
        snapLabel = type == ElectricalComponentType.socketOutlet
            ? 'SOCKET ${profile.socketHeightMm}'
            : 'SWITCH ${profile.switchHeightMm}';
      }
      initial = SurfacePointMm(wall.lengthMm.round() ~/ 2, yMm);
    } else {
      final bounds = space.boundary.bounds;
      initial = SurfacePointMm(bounds.width ~/ 2, bounds.height ~/ 2);
    }
    _state = EngineeringPlacementCursorState(
      surface: surface,
      position: initial,
      componentType: type,
      snapKind: snapKind,
      snapLabel: snapLabel,
      isValid: _isUsable(surface, initial),
    );
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

  bool nudgeGrid({
    required int dxSteps,
    required int dySteps,
    int multiplier = 1,
  }) {
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
    return space.boundary.contains(
      MmPoint(
        point.xMm + bounds.left,
        point.yMm + bounds.bottom,
      ),
    );
  }
}

final Expando<EngineeringPlacementCursorSession> _cursorSessions =
    Expando<EngineeringPlacementCursorSession>('ElecX placement cursor');

extension EngineeringPlacementCursorAccess on EditorController {
  EngineeringPlacementCursorSession get placementCursor =>
      _cursorSessions[this] ??= EngineeringPlacementCursorSession(this);
}
