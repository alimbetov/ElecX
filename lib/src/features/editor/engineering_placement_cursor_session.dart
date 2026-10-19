import 'package:flutter/foundation.dart';

import '../../domain/component_catalog_v2.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/engineering_placement_cursor.dart';
import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import 'catalog_component_placement.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class EngineeringPlacementCursorSession extends ChangeNotifier {
  EngineeringPlacementCursorSession(this.controller);

  final EditorController controller;
  EngineeringPlacementCursorState? _state;
  String? _requestedComponentTypeId;
  bool _repeatPlacement = false;

  EngineeringPlacementCursorState? get state => _state;
  bool get repeatPlacement => _repeatPlacement;

  String? get activeComponentTypeId =>
      _requestedComponentTypeId ??
      (controller.p2.placementType == null
          ? null
          : legacyComponentTypeId(controller.p2.placementType!));

  bool get active =>
      activeComponentTypeId != null && controller.activeSurface != null;

  void setRepeatPlacement(bool value) {
    if (_repeatPlacement == value) return;
    _repeatPlacement = value;
    notifyListeners();
  }

  void beginCatalogPlacement(
    String componentTypeId, {
    bool repeat = false,
  }) {
    controller.componentCatalog.require(componentTypeId);
    _requestedComponentTypeId = componentTypeId;
    _repeatPlacement = repeat;
    controller.p2.setPlacementType(null);
    _state = null;
    ensure();
    notifyListeners();
  }

  EngineeringPlacementCursorState? ensure() {
    final componentTypeId = activeComponentTypeId;
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (componentTypeId == null || surface == null || space == null) {
      _state = null;
      return null;
    }

    final entry = controller.componentCatalog.byId(componentTypeId);
    if (entry == null) {
      _state = null;
      return null;
    }

    final current = _state;
    if (current != null &&
        current.surface == surface &&
        current.componentTypeId == componentTypeId) {
      return current;
    }

    late final SurfacePointMm initial;
    var snapKind = PlacementCursorSnapKind.centerAxis;
    var snapLabel = 'CENTER';
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall!;
      final preferredHeight = entry.mounting.preferredHeightMm;
      final yMm = preferredHeight ?? wall.heightMm ~/ 2;
      if (preferredHeight != null) {
        snapKind = PlacementCursorSnapKind.installationGuide;
        snapLabel = '${entry.code} $preferredHeight';
      }
      initial = SurfacePointMm(wall.lengthMm.round() ~/ 2, yMm);
    } else {
      final bounds = space.boundary.bounds;
      initial = SurfacePointMm(bounds.width ~/ 2, bounds.height ~/ 2);
    }

    _state = EngineeringPlacementCursorState(
      surface: surface,
      position: initial,
      componentTypeId: componentTypeId,
      snapKind: snapKind,
      snapLabel: snapLabel,
      isValid: _isUsable(entry, surface, initial),
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
    final entry = controller.componentCatalog.byId(current.componentTypeId);
    if (entry == null) return false;
    final next = EngineeringPlacementCursor.moveTo(
      current,
      position,
      snapKind: snapKind,
      snapLabel: snapLabel,
      isValid: _isUsable(entry, current.surface, position),
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
    final entry = controller.componentCatalog.byId(current.componentTypeId);
    if (entry == null) return false;
    controller.p2.placeCatalogComponent(
      entry: entry,
      surface: current.surface,
      position: current.position,
    );

    if (_repeatPlacement) {
      _state = EngineeringPlacementCursorState(
        surface: current.surface,
        position: current.position,
        componentTypeId: current.componentTypeId,
        snapKind: current.snapKind,
        snapLabel: current.snapLabel,
        isValid: current.isValid,
      );
    } else {
      _requestedComponentTypeId = null;
      controller.p2.setPlacementType(null);
      _state = null;
    }
    notifyListeners();
    return true;
  }

  void cancel() {
    _requestedComponentTypeId = null;
    _repeatPlacement = false;
    controller.p2.setPlacementType(null);
    _state = null;
    notifyListeners();
  }

  bool _isUsable(
    ComponentCatalogEntryV2 entry,
    RoomSurfaceRef surface,
    SurfacePointMm point,
  ) {
    final space = controller.selectedSpace;
    if (space == null || point.xMm < 0 || point.yMm < 0) return false;
    if (!entry.canPlaceOn(surface)) return false;

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
