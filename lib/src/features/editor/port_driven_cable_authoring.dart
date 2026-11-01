import '../../domain/electrical_placement.dart';
import '../../domain/surface_routing.dart';
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

final Expando<PortDrivenCableStartBinding> _portDrivenCableBindings =
    Expando<PortDrivenCableStartBinding>('ElecX port-driven cable start');

extension PortDrivenCableAuthoring on EditorController {
  PortDrivenCableStartBinding? get portDrivenCableStartBinding =>
      _portDrivenCableBindings[this];

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

  void clearPortDrivenCableStartBinding() {
    _portDrivenCableBindings[this] = null;
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
