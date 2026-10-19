import 'package:flutter/foundation.dart';

import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class ComponentMoveState {
  const ComponentMoveState({
    required this.componentId,
    required this.surface,
    required this.originalPosition,
    required this.previewPosition,
    required this.isValid,
  });

  final String componentId;
  final RoomSurfaceRef surface;
  final SurfacePointMm originalPosition;
  final SurfacePointMm previewPosition;
  final bool isValid;

  bool get dirty =>
      originalPosition.xMm != previewPosition.xMm ||
      originalPosition.yMm != previewPosition.yMm;

  ComponentMoveState copyWith({
    SurfacePointMm? previewPosition,
    bool? isValid,
  }) => ComponentMoveState(
    componentId: componentId,
    surface: surface,
    originalPosition: originalPosition,
    previewPosition: previewPosition ?? this.previewPosition,
    isValid: isValid ?? this.isValid,
  );
}

/// Device-independent move transaction for an already placed engineering
/// component. Pointer, stylus, touch and keyboard adapters should all call this
/// session instead of mutating EditorP2Session independently.
final class ComponentMoveSession extends ChangeNotifier {
  ComponentMoveSession(this.controller);

  final EditorController controller;
  ComponentMoveState? _state;

  ComponentMoveState? get state => _state;
  bool get active => _state != null;

  bool begin() {
    final component = controller.p2.selectedComponent;
    if (component == null || !controller.p2.beginMoveSelectedComponent()) {
      return false;
    }
    _state = ComponentMoveState(
      componentId: component.id,
      surface: component.surface,
      originalPosition: component.position,
      previewPosition: component.position,
      isValid: true,
    );
    notifyListeners();
    return true;
  }

  bool preview(SurfacePointMm position, {required bool isValid}) {
    final current = _state;
    if (current == null) return false;
    _state = current.copyWith(previewPosition: position, isValid: isValid);
    if (isValid) {
      controller.p2.previewMoveSelectedComponent(position);
    }
    notifyListeners();
    return isValid;
  }

  bool nudge({
    required int dxMm,
    required int dyMm,
    bool Function(RoomSurfaceRef surface, SurfacePointMm position)? validator,
  }) {
    final current = _state;
    if (current == null) return false;
    final next = SurfacePointMm(
      current.previewPosition.xMm + dxMm,
      current.previewPosition.yMm + dyMm,
    );
    final valid = validator?.call(current.surface, next) ?? true;
    return preview(next, isValid: valid);
  }

  bool commit() {
    final current = _state;
    if (current == null || !current.isValid) return false;
    final committed = controller.p2.commitMoveSelectedComponent();
    _state = null;
    notifyListeners();
    return committed;
  }

  void cancel() {
    if (_state == null) return;
    controller.p2.cancelMoveSelectedComponent();
    _state = null;
    notifyListeners();
  }
}

final Expando<ComponentMoveSession> _moveSessions =
    Expando<ComponentMoveSession>('ElecX component move session');

extension ComponentMoveSessionAccess on EditorController {
  ComponentMoveSession get componentMove =>
      _moveSessions[this] ??= ComponentMoveSession(this);
}
