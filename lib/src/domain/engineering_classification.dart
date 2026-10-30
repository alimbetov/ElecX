import 'engineering_graph.dart';

/// Extensible stable discipline identity carried by the canonical graph.
///
/// Built-in keys are explicit constants rather than persisted enum ordinals or
/// display names. Custom keys remain opaque and are resolved by an extension
/// contract.
final class EngineeringDisciplineKey {
  EngineeringDisciplineKey(String id) : id = _nonEmpty(id, 'id');

  final String id;

  static final architecture = EngineeringDisciplineKey('core.architecture');
  static final power = EngineeringDisciplineKey('core.power');
  static final lighting = EngineeringDisciplineKey('core.lighting');
  static final lowVoltage = EngineeringDisciplineKey('core.low-voltage');
  static final data = EngineeringDisciplineKey('core.data');
  static final cctv = EngineeringDisciplineKey('core.cctv');
  static final accessControl = EngineeringDisciplineKey('core.access-control');
  static final fireAlarm = EngineeringDisciplineKey('core.fire-alarm');
  static final automation = EngineeringDisciplineKey('core.automation');

  static EngineeringDisciplineKey fromLegacy(EngineeringDiscipline value) =>
      switch (value) {
        EngineeringDiscipline.architecture => architecture,
        EngineeringDiscipline.power => power,
        EngineeringDiscipline.lighting => lighting,
        EngineeringDiscipline.lowVoltage => lowVoltage,
        EngineeringDiscipline.data => data,
        EngineeringDiscipline.cctv => cctv,
        EngineeringDiscipline.accessControl => accessControl,
        EngineeringDiscipline.fireAlarm => fireAlarm,
        EngineeringDiscipline.automation => automation,
      };

  static EngineeringDiscipline? legacyValue(EngineeringDisciplineKey key) =>
      switch (key.id) {
        'core.architecture' => EngineeringDiscipline.architecture,
        'core.power' => EngineeringDiscipline.power,
        'core.lighting' => EngineeringDiscipline.lighting,
        'core.low-voltage' => EngineeringDiscipline.lowVoltage,
        'core.data' => EngineeringDiscipline.data,
        'core.cctv' => EngineeringDiscipline.cctv,
        'core.access-control' => EngineeringDiscipline.accessControl,
        'core.fire-alarm' => EngineeringDiscipline.fireAlarm,
        'core.automation' => EngineeringDiscipline.automation,
        _ => null,
      };

  bool get isBuiltIn => legacyValue(this) != null;

  @override
  bool operator ==(Object other) =>
      other is EngineeringDisciplineKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Extensible stable engineering-system identity carried by components/edges.
final class EngineeringSystemKey {
  EngineeringSystemKey(String id) : id = _nonEmpty(id, 'id');

  final String id;

  static final powerAc = EngineeringSystemKey('core.power-ac');
  static final powerDc = EngineeringSystemKey('core.power-dc');
  static final lighting = EngineeringSystemKey('core.lighting');
  static final structuredCabling =
      EngineeringSystemKey('core.structured-cabling');
  static final poeNetwork = EngineeringSystemKey('core.poe-network');
  static final fiberOptic = EngineeringSystemKey('core.fiber-optic');
  static final cctv = EngineeringSystemKey('core.cctv');
  static final accessControl = EngineeringSystemKey('core.access-control');
  static final fireAlarm = EngineeringSystemKey('core.fire-alarm');
  static final automationBus = EngineeringSystemKey('core.automation-bus');
  static final dryContact = EngineeringSystemKey('core.dry-contact');
  static final custom = EngineeringSystemKey('core.custom');

  static EngineeringSystemKey fromLegacy(EngineeringSystemClass value) =>
      switch (value) {
        EngineeringSystemClass.powerAc => powerAc,
        EngineeringSystemClass.powerDc => powerDc,
        EngineeringSystemClass.lighting => lighting,
        EngineeringSystemClass.structuredCabling => structuredCabling,
        EngineeringSystemClass.poeNetwork => poeNetwork,
        EngineeringSystemClass.fiberOptic => fiberOptic,
        EngineeringSystemClass.cctv => cctv,
        EngineeringSystemClass.accessControl => accessControl,
        EngineeringSystemClass.fireAlarm => fireAlarm,
        EngineeringSystemClass.automationBus => automationBus,
        EngineeringSystemClass.dryContact => dryContact,
        EngineeringSystemClass.custom => custom,
      };

  static EngineeringSystemClass? legacyValue(EngineeringSystemKey key) =>
      switch (key.id) {
        'core.power-ac' => EngineeringSystemClass.powerAc,
        'core.power-dc' => EngineeringSystemClass.powerDc,
        'core.lighting' => EngineeringSystemClass.lighting,
        'core.structured-cabling' => EngineeringSystemClass.structuredCabling,
        'core.poe-network' => EngineeringSystemClass.poeNetwork,
        'core.fiber-optic' => EngineeringSystemClass.fiberOptic,
        'core.cctv' => EngineeringSystemClass.cctv,
        'core.access-control' => EngineeringSystemClass.accessControl,
        'core.fire-alarm' => EngineeringSystemClass.fireAlarm,
        'core.automation-bus' => EngineeringSystemClass.automationBus,
        'core.dry-contact' => EngineeringSystemClass.dryContact,
        'core.custom' => EngineeringSystemClass.custom,
        _ => null,
      };

  bool get isBuiltIn => legacyValue(this) != null;

  @override
  bool operator ==(Object other) => other is EngineeringSystemKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

String _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}
