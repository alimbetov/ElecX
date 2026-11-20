import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/editor_layers.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'manual_cable_draft_persistence.dart';
import 'port_driven_cable_authoring.dart';

/// Transient, apartment-plan-only selection of two explicit electrical ports.
///
/// This does not create an electrical connection or a physical cable before
/// Apply. Only one-host straight candidates are offered: crossing into another
/// room requires the verified manual/physical routing workflow.
final class PlanPortPairSession extends ChangeNotifier {
  PlanPortPairSession(this.controller);

  final EditorController controller;
  String? _startComponentId;
  String? _startPortId;
  String? _targetComponentId;
  String? _targetPortId;
  int? _revision;
  RoomSurfaceRef? _sourceHost;
  SurfacePointMm? _sourcePosition;
  RoomSurfaceRef? _targetHost;
  SurfacePointMm? _targetPosition;
  Object? _levelAtStart;
  List<ArchitecturalOpening> _openingsAtStart = const [];

  bool get active => _startComponentId != null;
  bool get choosingTarget => active && _targetComponentId == null;
  String? get sourceComponentId => _startComponentId;
  String? get sourcePortId => _startPortId;
  String? get targetComponentId => _targetComponentId;
  String? get targetPortId => _targetPortId;

  ElectricalComponentPlacement? get sourceComponent => _byId(_startComponentId);

  ElectricalComponentPlacement? get targetComponent =>
      _byId(_targetComponentId);

  bool get revisionCurrent =>
      active &&
      controller.p2.history.mutationRevision == _revision &&
      identical(controller.level, _levelAtStart) &&
      _sameOpenings(controller.openings, _openingsAtStart);

  bool get ready {
    final source = sourceComponent;
    final target = targetComponent;
    if (!revisionCurrent ||
        source == null ||
        target == null ||
        controller.viewMode != EditorViewMode.plan ||
        controller.tool != EditorTool.select ||
        controller.p2.isManipulating ||
        controller.routeSegments.isNotEmpty ||
        controller.portDrivenCableStartBinding != null ||
        !controller.p2.layers.isVisible(EditorLayerId.electrical) ||
        controller.p2.layers.isLocked(EditorLayerId.electrical) ||
        !controller.p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        controller.p2.layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    return source.surface == _sourceHost &&
        source.position == _sourcePosition &&
        target.surface == _targetHost &&
        target.position == _targetPosition &&
        source.surface == target.surface &&
        compatiblePortsFor(target).any((port) => port.id == _targetPortId) &&
        straightRouteBlockReason == null;
  }

  /// Explanatory fail-closed validation of the proposed straight segment.
  ///
  /// Choosing electrically compatible ports alone does not prove that a
  /// direct cable avoids doors, windows or non-orthogonal geometry. This is
  /// a preliminary physical check, not KZ normative certification.
  String? get straightRouteBlockReason {
    if (!active || _targetComponentId == null) return null;
    if (!revisionCurrent) {
      return 'Планировка или параметры проекта изменились. '
          'Выберите порты заново.';
    }
    final source = sourceComponent;
    final target = targetComponent;
    if (source == null || target == null) {
      return 'Устройство было удалено или недоступно.';
    }
    if (source.surface != target.surface ||
        source.surface != _sourceHost ||
        target.surface != _targetHost ||
        source.position != _sourcePosition ||
        target.position != _targetPosition) {
      return 'Изменились физические привязки устройств.';
    }
    final context = controller.routeNormativeContextFor(source.surface);
    if (context == null) {
      return 'Не удалось подтвердить физическую поверхность кабеля.';
    }
    final validation = NormativeRouteEngine.validate(
      points: [source.position, target.position],
      context: context,
    );
    if (!validation.isValid) {
      return validation.issues.first.message;
    }
    return null;
  }

  double? get straightLengthMm {
    if (!ready) return null;
    final a = sourceComponent!.position;
    final b = targetComponent!.position;
    return math.sqrt(
      math.pow(a.xMm - b.xMm, 2) + math.pow(a.yMm - b.yMm, 2),
    );
  }

  bool start({
    required String componentId,
    required String portId,
  }) {
    final source = _byId(componentId);
    if (source == null ||
        controller.viewMode != EditorViewMode.plan ||
        controller.tool != EditorTool.select ||
        controller.p2.isManipulating ||
        controller.routeSegments.isNotEmpty ||
        controller.portDrivenCableStartBinding != null ||
        !controller.p2.layers.isVisible(EditorLayerId.electrical) ||
        controller.p2.layers.isLocked(EditorLayerId.electrical) ||
        !controller.p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        controller.p2.layers.isLocked(EditorLayerId.cableRoutes) ||
        !controller
            .cableAuthoringPortsFor(source)
            .any((port) => port.id == portId)) {
      return false;
    }
    _startComponentId = componentId;
    _startPortId = portId;
    _targetComponentId = null;
    _targetPortId = null;
    _revision = controller.p2.history.mutationRevision;
    _sourceHost = source.surface;
    _sourcePosition = source.position;
    _targetHost = null;
    _targetPosition = null;
    _levelAtStart = controller.level;
    _openingsAtStart = List.unmodifiable(controller.openings);
    notifyListeners();
    return true;
  }

  List<ElectricalPortDefinition> compatiblePortsFor(
    ElectricalComponentPlacement candidate,
  ) {
    final source = sourceComponent;
    if (!revisionCurrent ||
        source == null ||
        source.id == candidate.id ||
        source.surface != candidate.surface ||
        source.surface != _sourceHost ||
        source.position != _sourcePosition) {
      return const [];
    }
    final startPort =
        source.ports.where((port) => port.id == _startPortId).firstOrNull;
    if (startPort == null) return const [];
    return List.unmodifiable([
      for (final port in controller.cableAuthoringPortsFor(candidate))
        if (ElectricalPortCompatibility.areCompatible(
              startPort.kind,
              port.kind,
            ) ||
            ElectricalPortCompatibility.areCompatible(
              port.kind,
              startPort.kind,
            ))
          port,
    ]);
  }

  bool chooseTarget({
    required String componentId,
    required String portId,
  }) {
    if (!choosingTarget) return false;
    final component = _byId(componentId);
    if (component == null ||
        !compatiblePortsFor(component).any((port) => port.id == portId)) {
      return false;
    }
    _targetComponentId = componentId;
    _targetPortId = portId;
    _targetHost = component.surface;
    _targetPosition = component.position;
    notifyListeners();
    return true;
  }

  /// Returns a physical cable only through the existing port-driven committer.
  /// On failure any transient draft is discarded; no fake route is persisted.
  bool applyStraightRoute() {
    if (!ready) return false;
    final sourceId = _startComponentId!;
    final startPortId = _startPortId!;
    final targetId = _targetComponentId!;
    final targetPortId = _targetPortId!;
    final previousSelection = controller.p2.selection;

    void restoreWorkspaceAfterFailure() {
      controller.cancelManualCableDraft(exitTool: true);
      controller.setTool(EditorTool.select);
      controller.showPlan();
      final previousId = previousSelection.primaryId;
      if (previousId != null) {
        controller.p2.select(previousId);
      } else {
        controller.p2.clearSelection();
      }
    }

    controller.p2.select(sourceId);
    if (!controller.beginPortDrivenCableFromSelectedPort(startPortId)) {
      restoreWorkspaceAfterFailure();
      return false;
    }
    final snapped = controller.snapPortDrivenCableCompletionTarget(
      componentId: targetId,
      portId: targetPortId,
    );
    final committed = snapped && controller.finishManualCableDraft();
    if (!committed) {
      restoreWorkspaceAfterFailure();
      return false;
    }
    controller.setTool(EditorTool.select);
    controller.showPlan();
    reset();
    controller.p2.select(targetId);
    return true;
  }

  void reset() {
    if (!active) return;
    _startComponentId = null;
    _startPortId = null;
    _targetComponentId = null;
    _targetPortId = null;
    _revision = null;
    _sourceHost = null;
    _sourcePosition = null;
    _targetHost = null;
    _targetPosition = null;
    _levelAtStart = null;
    _openingsAtStart = const [];
    notifyListeners();
  }

  static bool _sameOpenings(
    List<ArchitecturalOpening> current,
    List<ArchitecturalOpening> baseline,
  ) {
    if (current.length != baseline.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (!identical(current[i], baseline[i])) return false;
    }
    return true;
  }

  ElectricalComponentPlacement? _byId(String? componentId) {
    if (componentId == null) return null;
    for (final component in controller.p2.components) {
      if (component.id == componentId) return component;
    }
    return null;
  }
}

final Expando<PlanPortPairSession> _planPortPairSessions =
    Expando<PlanPortPairSession>('ElecX plan port pair');

extension PlanPortPairAccess on EditorController {
  PlanPortPairSession get planPortPair =>
      _planPortPairSessions[this] ??= PlanPortPairSession(this);
}
