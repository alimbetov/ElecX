import '../domain/electrical_placement.dart';
import '../domain/geometry.dart';
import '../domain/surfaces.dart';
import 'snap_engine.dart';

enum CableEndpointRole { source, target }

/// Resolves semantic snap anchors for cable endpoints.
///
/// Current component symbols use the placement origin as their port anchor, so
/// endpoints visually center on the component. The contract is intentionally
/// port-specific: catalog symbols can later provide per-port offsets without
/// changing cable editing or snapping APIs.
abstract final class PortSnapResolver {
  static List<SemanticSnapAnchor> anchorsFor({
    required Iterable<ElectricalComponentPlacement> components,
    required RoomSurfaceRef surface,
    required CableEndpointRole role,
    String? excludeComponentId,
  }) {
    final anchors = <SemanticSnapAnchor>[];
    for (final component in components) {
      if (component.surface != surface || component.id == excludeComponentId) {
        continue;
      }
      for (final port in component.ports) {
        if (!_compatible(port.kind, role)) continue;
        anchors.add(
          SemanticSnapAnchor(
            kind: SnapKind.port,
            point: MmPoint(component.position.xMm, component.position.yMm),
            sourceId: '${component.id}:${port.id}',
          ),
        );
      }
      if (component.ports.isEmpty) {
        anchors.add(
          SemanticSnapAnchor(
            kind: SnapKind.componentAnchor,
            point: MmPoint(component.position.xMm, component.position.yMm),
            sourceId: component.id,
          ),
        );
      }
    }
    return List.unmodifiable(anchors);
  }

  static bool _compatible(ElectricalPortKind kind, CableEndpointRole role) =>
      switch (role) {
        CableEndpointRole.source =>
          kind == ElectricalPortKind.powerOut ||
              kind == ElectricalPortKind.controlOut,
        CableEndpointRole.target =>
          kind == ElectricalPortKind.powerIn ||
              kind == ElectricalPortKind.controlIn,
      };
}
