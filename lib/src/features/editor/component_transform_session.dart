import 'package:flutter/foundation.dart';

import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_edit_session.dart';
import 'editor_p2_session.dart';

final class ComponentTransformPreview {
  const ComponentTransformPreview({
    required this.componentId,
    required this.surface,
    required this.originalPosition,
    required this.position,
    required this.isValid,
  });

  final String componentId;
  final RoomSurfaceRef surface;
  final SurfacePointMm originalPosition;
  final SurfacePointMm position;
  final bool isValid;

  bool get dirty =>
      originalPosition.xMm != position.xMm ||
      originalPosition.yMm != position.yMm;
}

/// Canonical component transform transaction.
///
/// Input adapters must normalize mouse drag, keyboard arrows, touch/stylus drag
/// and mobile precision-pad movement into [preview]/[nudge] calls here.
final class ComponentTransformSession extends ChangeNotifier
    implements EditorEditSession<ComponentTransformPreview> {
  ComponentTransformSession(this.controller);

  final EditorController controller;
  ComponentTransformPreview? _preview;
  EditorEditSessionPhase _phase = EditorEditSessionPhase.idle;

  @override
  EditorEditSessionPhase get phase => _phase;

  @override
  bool get active =>
      _phase == EditorEditSessionPhase.previewing ||
      _phase == EditorEditSessionPhase.invalid;

  @override
  ComponentTransformPreview? get previewState => _preview;

  @override
  bool begin() {
    if (active) return false;
    final component = controller.p2.selectedComponent;
    if (component == null || !controller.p2.beginMoveSelectedComponent()) {
      return false;
    }
    _preview = ComponentTransformPreview(
      componentId: component.id,
      surface: component.surface,
      originalPosition: component.position,
      position: component.position,
      isValid: true,
    );
    _phase = EditorEditSessionPhase.previewing;
    notifyListeners();
    return true;
  }

  bool preview(SurfacePointMm position, {required bool isValid}) {
    final current = _preview;
    if (current == null || !active) return false;
    _preview = ComponentTransformPreview(
      componentId: current.componentId,
      surface: current.surface,
      originalPosition: current.originalPosition,
      position: position,
      isValid: isValid,
    );
    _phase = isValid
        ? EditorEditSessionPhase.previewing
        : EditorEditSessionPhase.invalid;
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
    final current = _preview;
    if (current == null || !active) return false;
    final next = SurfacePointMm(
      current.position.xMm + dxMm,
      current.position.yMm + dyMm,
    );
    return preview(
      next,
      isValid: validator?.call(current.surface, next) ?? true,
    );
  }

  @override
  bool validate() => _preview?.isValid ?? false;

  @override
  bool commit() {
    final current = _preview;
    if (current == null || !current.isValid) return false;
    if (!current.dirty) {
      controller.p2.cancelMoveSelectedComponent();
      _preview = null;
      _phase = EditorEditSessionPhase.cancelled;
      notifyListeners();
      return false;
    }
    final committed = controller.p2.commitMoveSelectedComponent();
    if (!committed) return false;
    _preview = null;
    _phase = EditorEditSessionPhase.committed;
    notifyListeners();
    return true;
  }

  @override
  void cancel() {
    if (!active) return;
    controller.p2.cancelMoveSelectedComponent();
    _preview = null;
    _phase = EditorEditSessionPhase.cancelled;
    notifyListeners();
  }
}

final Expando<ComponentTransformSession> _transformSessions =
    Expando<ComponentTransformSession>('ElecX component transform session');

extension ComponentTransformSessionAccess on EditorController {
  ComponentTransformSession get componentTransform =>
      _transformSessions[this] ??= ComponentTransformSession(this);
}
