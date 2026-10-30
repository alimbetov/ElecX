import 'project_identity.dart';

/// One logical endpoint: an existing component identity and its local port ID.
///
/// Catalog port keys may repeat on separate components. The pair retains each
/// opaque value verbatim and never allocates or parses a concatenated identity.
final class EngineeringPortRef {
  const EngineeringPortRef({required this.componentId, required this.portId});

  final ComponentId componentId;
  final PortId portId;

  @override
  bool operator ==(Object other) =>
      other is EngineeringPortRef &&
      other.componentId == componentId &&
      other.portId == portId;

  @override
  int get hashCode => Object.hash(componentId, portId);

  @override
  String toString() =>
      'EngineeringPortRef(componentId: $componentId, portId: $portId)';
}
