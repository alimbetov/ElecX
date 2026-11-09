import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'surface_transition_navigator.dart';

enum PortDrivenCableEndpointRole { source, target }

final class PortDrivenCableStartBinding {
  const PortDrivenCableStartBinding({
    required this.componentId,
    required this.portId,
    required this.portKind,
    required this.role,
    required this.p2MutationRevision,
  });

  final String componentId;
  final String portId;
  final ElectricalPortKind portKind;
  final PortDrivenCableEndpointRole role;
  final int p2MutationRevision;
}

final class PortDrivenCableCompletionTarget {
  const PortDrivenCableCompletionTarget({
    required this.componentId,
    required this.componentLabel,
    required this.portId,
    required this.portKind,
    required this.role,
    required this.surface,
    required this.position,
  });

  final String componentId;
  final String componentLabel;
  final String portId;
  final ElectricalPortKind portKind;
  final PortDrivenCableEndpointRole role;
  final RoomSurfaceRef surface;
  final SurfacePointMm position;
}

final class PortDrivenCableCompletionBinding {
  const PortDrivenCableCompletionBinding({
    required this.componentId,
    required this.componentLabel,
    required this.portId,
    required this.portKind,
    required this.role,
    required this.surface,
    required this.position,
    required this.p2MutationRevision,
  });

  final String componentId;
  final String componentLabel;
  final String portId;
  final ElectricalPortKind portKind;
  final PortDrivenCableEndpointRole role;
  final RoomSurfaceRef surface;
  final SurfacePointMm position;
  final int p2MutationRevision;
}

final Expando<PortDrivenCableStartBinding> _portDrivenCableBindings =
    Expando<PortDrivenCableStartBinding>('ElecX port-driven cable start');
final Expando<PortDrivenCableCompletionBinding> _portDrivenCompletionBindings =
    Expando<PortDrivenCableCompletionBinding>(
  'ElecX port-driven cable completion',
);

extension PortDrivenCableAuthoring on EditorController {
  PortDrivenCableStartBinding? get portDrivenCableStartBinding =>
      _portDrivenCableBindings[this];

  PortDrivenCableCompletionBinding? get portDrivenCableCompletionBinding =>
      _portDrivenCompletionBindings[this];

  List<ElectricalPortDefinition> cableAuthoringPortsFor(
    ElectricalComponentPlacement component,
  ) =>
      component.ports.where(_isConnectablePort).toList(growable: false);

  List<ElectricalPortDefinition> get selectedCableAuthoringPorts {
    final component = p2.selectedComponent;
    return component == null
        ? const <ElectricalPortDefinition>[]
        : cableAuthoringPortsFor(component);
  }

  List<PortDrivenCableCompletionTarget> get compatiblePortDrivenCableTargets {
    final surface = activeSurface;
    return surface == null
        ? const <PortDrivenCableCompletionTarget>[]
        : compatiblePortDrivenCableTargetsOn(surface);
  }

  List<PortDrivenCableCompletionTarget> compatiblePortDrivenCableTargetsOn(
    RoomSurfaceRef surface,
  ) {
    final binding = portDrivenCableStartBinding;
    if (binding == null ||
        p2.history.mutationRevision != binding.p2MutationRevision) {
      return const <PortDrivenCableCompletionTarget>[];
    }

    final startComponent = _componentById(p2.components, binding.componentId);
    final startPort = startComponent == null
        ? null
        : _portById(startComponent, binding.portId);
    if (startComponent == null ||
        startPort == null ||
        startPort.kind != binding.portKind) {
      return const <PortDrivenCableCompletionTarget>[];
    }

    final remoteRole = binding.role == PortDrivenCableEndpointRole.source
        ? PortDrivenCableEndpointRole.target
        : PortDrivenCableEndpointRole.source;
    final targets = <PortDrivenCableCompletionTarget>[];
    for (final component in p2.components) {
      if (component.id == binding.componentId || component.surface != surface) {
        continue;
      }
      for (final port in component.ports) {
        if (!_roleAccepts(port.kind, remoteRole)) continue;
        final compatible = binding.role == PortDrivenCableEndpointRole.source
            ? ElectricalPortCompatibility.areCompatible(
                startPort.kind,
                port.kind,
              )
            : ElectricalPortCompatibility.areCompatible(
                port.kind,
                startPort.kind,
              );
        if (!compatible) continue;
        targets.add(
          PortDrivenCableCompletionTarget(
            componentId: component.id,
            componentLabel: component.label,
            portId: port.id,
            portKind: port.kind,
            role: remoteRole,
            surface: component.surface,
            position: component.position,
          ),
        );
      }
    }
    return List.unmodifiable(targets);
  }

  /// Read-only discovery for compatible endpoints in *other* rooms.
  ///
  /// Electrical compatibility is not proof of a physical route: the editor
  /// deliberately does not offer these as finish targets until an approved
  /// cross-room penetration/continuation has been authored and validated.
  /// Never use this list to bypass the exact host/port commit boundary.
  List<PortDrivenCableCompletionTarget> get blockedCrossRoomCableTargets {
    final binding = portDrivenCableStartBinding;
    if (binding == null ||
        p2.history.mutationRevision != binding.p2MutationRevision) {
      return const <PortDrivenCableCompletionTarget>[];
    }
    final source = _componentById(p2.components, binding.componentId);
    final startPort =
        source == null ? null : _portById(source, binding.portId);
    if (source == null ||
        startPort == null ||
        startPort.kind != binding.portKind) {
      return const <PortDrivenCableCompletionTarget>[];
    }
    final remoteRole = binding.role == PortDrivenCableEndpointRole.source
        ? PortDrivenCableEndpointRole.target
        : PortDrivenCableEndpointRole.source;
    final targets = <PortDrivenCableCompletionTarget>[];
    for (final component in p2.components) {
      if (component.id == source.id ||
          component.surface.spaceId == source.surface.spaceId) {
        continue;
      }
      for (final port in component.ports) {
        if (!_roleAccepts(port.kind, remoteRole)) continue;
        final compatible = binding.role == PortDrivenCableEndpointRole.source
            ? ElectricalPortCompatibility.areCompatible(
                startPort.kind,
                port.kind,
              )
            : ElectricalPortCompatibility.areCompatible(
                port.kind,
                startPort.kind,
              );
        if (!compatible) continue;
        targets.add(PortDrivenCableCompletionTarget(
          componentId: component.id,
          componentLabel: component.label,
          portId: port.id,
          portKind: port.kind,
          role: remoteRole,
          surface: component.surface,
          position: component.position,
        ));
      }
    }
    targets.sort((a, b) {
      final bySpace = a.surface.spaceId.compareTo(b.surface.spaceId);
      if (bySpace != 0) return bySpace;
      final byComponent = a.componentId.compareTo(b.componentId);
      return byComponent != 0 ? byComponent : a.portId.compareTo(b.portId);
    });
    return List.unmodifiable(targets);
  }

  bool snapPortDrivenCableCompletionTarget({
    required String componentId,
    required String portId,
  }) {
    final start = portDrivenCableStartBinding;
    final surface = activeSurface;
    if (start == null ||
        surface == null ||
        routeSegments.isEmpty ||
        p2.history.mutationRevision != start.p2MutationRevision ||
        activeRouteSegment == null) {
      return false;
    }

    PortDrivenCableCompletionTarget? target;
    for (final candidate in compatiblePortDrivenCableTargetsOn(surface)) {
      if (candidate.componentId == componentId && candidate.portId == portId) {
        if (target != null) return false;
        target = candidate;
      }
    }
    if (target == null) return false;

    final last = routeSegments.last;
    if (last.surface != target.surface || last.points.isEmpty) return false;
    final points = List<SurfacePointMm>.of(last.points);
    final previous = portDrivenCableCompletionBinding;
    if (previous != null &&
        previous.surface == last.surface &&
        points.last == previous.position) {
      points[points.length - 1] = target.position;
    } else if (points.last != target.position) {
      points.add(target.position);
    }
    routeSegments[routeSegments.length - 1] = SurfaceRouteSegmentDraft(
      surface: last.surface,
      points: List.unmodifiable(points),
    );
    _portDrivenCompletionBindings[this] = PortDrivenCableCompletionBinding(
      componentId: target.componentId,
      componentLabel: target.componentLabel,
      portId: target.portId,
      portKind: target.portKind,
      role: target.role,
      surface: target.surface,
      position: target.position,
      p2MutationRevision: start.p2MutationRevision,
    );
    // Guided completion is transient authoring state. It must not manufacture
    // a P2 history mutation before the physical route commit succeeds.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
    return true;
  }

  bool get portDrivenCableReadyToFinish {
    final start = portDrivenCableStartBinding;
    final completion = portDrivenCableCompletionBinding;
    if (start == null ||
        completion == null ||
        start.role == completion.role ||
        start.p2MutationRevision != completion.p2MutationRevision ||
        p2.history.mutationRevision != start.p2MutationRevision ||
        routeSegments.isEmpty) {
      return false;
    }

    final startComponent = _componentById(p2.components, start.componentId);
    final startPort =
        startComponent == null ? null : _portById(startComponent, start.portId);
    final completionComponent =
        _componentById(p2.components, completion.componentId);
    final completionPort = completionComponent == null
        ? null
        : _portById(completionComponent, completion.portId);
    if (startComponent == null ||
        startPort == null ||
        startPort.kind != start.portKind ||
        completionComponent == null ||
        completionPort == null ||
        completionPort.kind != completion.portKind ||
        completionComponent.surface != completion.surface ||
        completionComponent.position != completion.position) {
      return false;
    }

    final sourceKind = start.role == PortDrivenCableEndpointRole.source
        ? startPort.kind
        : completionPort.kind;
    final targetKind = start.role == PortDrivenCableEndpointRole.target
        ? startPort.kind
        : completionPort.kind;
    if (!ElectricalPortCompatibility.areCompatible(sourceKind, targetKind)) {
      return false;
    }

    final first = routeSegments.first;
    final last = routeSegments.last;
    return first.points.isNotEmpty &&
        last.points.isNotEmpty &&
        first.surface == startComponent.surface &&
        first.points.first == startComponent.position &&
        last.surface == completion.surface &&
        last.points.last == completion.position;
  }

  bool beginPortDrivenCableFromSelectedPort(String portId) {
    if (routeSegments.isNotEmpty ||
        portDrivenCableStartBinding != null ||
        p2.isManipulating ||
        !p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        p2.layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }

    final component = p2.selectedComponent;
    if (component == null) return false;

    ElectricalPortDefinition? port;
    for (final candidate in component.ports) {
      if (candidate.id == portId && _isConnectablePort(candidate)) {
        port = candidate;
        break;
      }
    }
    if (port == null || !_legacyCommitCanResolveExactly(component, port)) {
      return false;
    }

    if (!SurfaceTransitionNavigator.navigate(this, component.surface)) {
      return false;
    }
    final draftSurface = activeSurface;
    if (draftSurface == null || draftSurface != component.surface) {
      return false;
    }

    setTool(EditorTool.cableRoute);
    _portDrivenCompletionBindings[this] = null;
    _portDrivenCableBindings[this] = PortDrivenCableStartBinding(
      componentId: component.id,
      portId: port.id,
      portKind: port.kind,
      role: _roleFor(port.kind),
      p2MutationRevision: p2.history.mutationRevision,
    );
    routeSegments.add(
      SurfaceRouteSegmentDraft(
        surface: draftSurface,
        points: [component.position],
      ),
    );
    // The draft is intentionally outside P2 history until physical commit.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
    return true;
  }

  void clearPortDrivenCableCompletionBinding() {
    _portDrivenCompletionBindings[this] = null;
  }

  void clearPortDrivenCableStartBinding() {
    _portDrivenCableBindings[this] = null;
    _portDrivenCompletionBindings[this] = null;
  }
}

bool _legacyCommitCanResolveExactly(
  ElectricalComponentPlacement component,
  ElectricalPortDefinition port,
) {
  final role = _roleFor(port.kind);
  if (role == PortDrivenCableEndpointRole.source) {
    return component.ports.where(_isSourcePort).length == 1;
  }
  return component.ports
          .where((candidate) => candidate.kind == port.kind)
          .length ==
      1;
}

ElectricalComponentPlacement? _componentById(
  Iterable<ElectricalComponentPlacement> components,
  String componentId,
) {
  for (final component in components) {
    if (component.id == componentId) return component;
  }
  return null;
}

ElectricalPortDefinition? _portById(
  ElectricalComponentPlacement component,
  String portId,
) {
  for (final port in component.ports) {
    if (port.id == portId) return port;
  }
  return null;
}

bool _isConnectablePort(ElectricalPortDefinition port) => switch (port.kind) {
      ElectricalPortKind.powerIn ||
      ElectricalPortKind.powerOut ||
      ElectricalPortKind.controlIn ||
      ElectricalPortKind.controlOut =>
        true,
      ElectricalPortKind.neutral || ElectricalPortKind.earth => false,
    };

bool _isSourcePort(ElectricalPortDefinition port) => switch (port.kind) {
      ElectricalPortKind.powerOut || ElectricalPortKind.controlOut => true,
      _ => false,
    };

bool _roleAccepts(
  ElectricalPortKind kind,
  PortDrivenCableEndpointRole role,
) =>
    switch (role) {
      PortDrivenCableEndpointRole.source =>
        kind == ElectricalPortKind.powerOut ||
            kind == ElectricalPortKind.controlOut,
      PortDrivenCableEndpointRole.target =>
        kind == ElectricalPortKind.powerIn ||
            kind == ElectricalPortKind.controlIn,
    };

PortDrivenCableEndpointRole _roleFor(ElectricalPortKind kind) => switch (kind) {
      ElectricalPortKind.powerOut ||
      ElectricalPortKind.controlOut =>
        PortDrivenCableEndpointRole.source,
      ElectricalPortKind.powerIn ||
      ElectricalPortKind.controlIn =>
        PortDrivenCableEndpointRole.target,
      ElectricalPortKind.neutral ||
      ElectricalPortKind.earth =>
        throw ArgumentError.value(kind, 'kind', 'Port is not routable.'),
    };
