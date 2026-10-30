/// Extensible logical transport medium used by engineering ports and edges.
///
/// The identifier is intentionally opaque and case-sensitive. Built-in media
/// cover the first P11 disciplines, while catalogs/plugins may introduce new
/// values without changing a closed enum or project identity contract.
final class EngineeringMedia {
  factory EngineeringMedia(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Media id must be non-empty.');
    }
    return EngineeringMedia._(id);
  }

  const EngineeringMedia._(this.id);

  final String id;

  static const acPower = EngineeringMedia._('power.ac');
  static const dcPower = EngineeringMedia._('power.dc');
  static const lightingControl = EngineeringMedia._('control.lighting');
  static const dryContact = EngineeringMedia._('control.dry-contact');
  static const ethernet = EngineeringMedia._('data.ethernet');
  static const poe = EngineeringMedia._('data.poe');
  static const opticalFiber = EngineeringMedia._('data.optical-fiber');
  static const coax = EngineeringMedia._('data.coax');
  static const rs485 = EngineeringMedia._('bus.rs485');
  static const fireLoop = EngineeringMedia._('life-safety.fire-loop');
  static const securityAccessBus =
      EngineeringMedia._('security.access-control-bus');

  @override
  bool operator ==(Object other) =>
      other is EngineeringMedia && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Extensible semantic capability tag attached to an engineering port.
///
/// Capability tags complement media and direction; they do not replace either.
/// Examples include catalog-defined protocol/profile/features. Parameters such
/// as current, voltage or bandwidth remain typed catalog/engineering data rather
/// than being encoded into this identifier.
final class EngineeringPortCapability {
  factory EngineeringPortCapability(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Capability id must be non-empty.');
    }
    return EngineeringPortCapability._(id);
  }

  const EngineeringPortCapability._(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is EngineeringPortCapability && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
