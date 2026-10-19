import 'package:flutter/foundation.dart';

import '../../domain/cable_identity.dart';
import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_routing.dart';
import 'editor_controller.dart';

final class CircuitCableRegistrySession extends ChangeNotifier {
  CircuitCableRegistrySession() : registry = CircuitCableRegistry();

  final CircuitCableRegistry registry;

  CircuitCableBundle? bundleByRouteId(String routeId) =>
      registry.bundleByRouteId(routeId);

  void registerBundle({
    required ElectricalCableRoute route,
    required CircuitRef circuit,
    required CableIdentity cable,
    ProtectiveDeviceRef? protectiveDevice,
  }) {
    registry.registerBundle(
      route: route,
      circuit: circuit,
      cable: cable,
      protectiveDevice: protectiveDevice,
    );
    notifyListeners();
  }
}

final Expando<CircuitCableRegistrySession> _sessions =
    Expando<CircuitCableRegistrySession>('ElecX circuit cable registry');

extension CircuitCableRegistrySessionAccess on EditorController {
  CircuitCableRegistrySession get circuitCableRegistry =>
      _sessions[this] ??= CircuitCableRegistrySession();
}
