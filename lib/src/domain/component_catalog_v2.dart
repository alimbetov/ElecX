import 'electrical_placement.dart';
import 'engineering_graph.dart';
import 'room_environment.dart';
import 'surfaces.dart';

enum ComponentPlacementViolationKind {
  surfaceNotAllowed,
  temperatureTooLow,
  temperatureTooHigh,
  humidityTooHigh,
  wetZoneNotAllowed,
  dustyEnvironmentNotAllowed,
  corrosiveEnvironmentNotAllowed,
  usageTypeNotAllowed,
}

final class ComponentPlacementViolation {
  const ComponentPlacementViolation({
    required this.kind,
    required this.message,
  });

  final ComponentPlacementViolationKind kind;
  final String message;
}

final class ComponentMountingPolicy {
  ComponentMountingPolicy({
    required this.allowedSurfaces,
    this.preferredHeightMm,
    this.preferredCeilingOffsetMm,
  }) {
    if (allowedSurfaces.isEmpty) {
      throw ArgumentError('At least one mounting surface must be allowed.');
    }
  }

  final Set<SurfacePlaneType> allowedSurfaces;
  final int? preferredHeightMm;
  final int? preferredCeilingOffsetMm;

  bool allows(RoomSurfaceRef surface) => allowedSurfaces.contains(surface.type);
}

final class ComponentEnvironmentConstraints {
  const ComponentEnvironmentConstraints({
    this.minAmbientC = -40,
    this.maxAmbientC = 55,
    this.maxRelativeHumidityPercent = 100,
    this.allowWetZone = true,
    this.allowDusty = true,
    this.allowCorrosive = false,
    this.allowedUsageTypes,
  });

  final double minAmbientC;
  final double maxAmbientC;
  final double maxRelativeHumidityPercent;
  final bool allowWetZone;
  final bool allowDusty;
  final bool allowCorrosive;
  final Set<RoomUsageType>? allowedUsageTypes;

  List<ComponentPlacementViolation> validate(RoomEnvironment environment) {
    final violations = <ComponentPlacementViolation>[];
    if (environment.designMinC < minAmbientC) {
      violations.add(
        ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.temperatureTooLow,
          message:
              'Room design minimum ${environment.designMinC}°C is below component limit $minAmbientC°C.',
        ),
      );
    }
    if (environment.designMaxC > maxAmbientC) {
      violations.add(
        ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.temperatureTooHigh,
          message:
              'Room design maximum ${environment.designMaxC}°C exceeds component limit $maxAmbientC°C.',
        ),
      );
    }
    final humidity = environment.maxRelativeHumidityPercent;
    if (humidity != null && humidity > maxRelativeHumidityPercent) {
      violations.add(
        ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.humidityTooHigh,
          message:
              'Room humidity $humidity% exceeds component limit $maxRelativeHumidityPercent%.',
        ),
      );
    }
    if (environment.wetZone && !allowWetZone) {
      violations.add(
        const ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.wetZoneNotAllowed,
          message: 'Component is not approved for wet zones.',
        ),
      );
    }
    if (environment.dusty && !allowDusty) {
      violations.add(
        const ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.dustyEnvironmentNotAllowed,
          message: 'Component is not approved for dusty rooms.',
        ),
      );
    }
    if (environment.corrosive && !allowCorrosive) {
      violations.add(
        const ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.corrosiveEnvironmentNotAllowed,
          message: 'Component is not approved for corrosive environments.',
        ),
      );
    }
    final usageTypes = allowedUsageTypes;
    if (usageTypes != null && !usageTypes.contains(environment.usageType)) {
      violations.add(
        ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.usageTypeNotAllowed,
          message:
              'Component is not approved for room usage ${environment.usageType.name}.',
        ),
      );
    }
    return List.unmodifiable(violations);
  }
}

final class ComponentLoadDefaults {
  const ComponentLoadDefaults({
    this.ratedPowerW,
    this.nominalVoltageV,
    this.powerFactor = 1,
    this.poeClass,
  });

  final int? ratedPowerW;
  final int? nominalVoltageV;
  final double powerFactor;
  final String? poeClass;
}

final class ComponentCatalogEntryV2 {
  ComponentCatalogEntryV2({
    required this.id,
    required this.code,
    required this.name,
    required this.discipline,
    required this.systemClass,
    required this.calculationKind,
    required this.mounting,
    required this.environment,
    required this.ports,
    this.loadDefaults = const ComponentLoadDefaults(),
    this.routePreferenceId,
  }) {
    if (id.isEmpty || code.isEmpty || name.isEmpty) {
      throw ArgumentError('Component catalog identity must be non-empty.');
    }
  }

  final String id;
  final String code;
  final String name;
  final EngineeringDiscipline discipline;
  final EngineeringSystemClass systemClass;
  final EngineeringCalculationKind calculationKind;
  final ComponentMountingPolicy mounting;
  final ComponentEnvironmentConstraints environment;
  final List<EngineeringPortSpec> ports;
  final ComponentLoadDefaults loadDefaults;
  final String? routePreferenceId;

  List<ComponentPlacementViolation> validatePlacement({
    required RoomSurfaceRef surface,
    RoomEnvironment? roomEnvironment,
  }) {
    final violations = <ComponentPlacementViolation>[];
    if (!mounting.allows(surface)) {
      violations.add(
        ComponentPlacementViolation(
          kind: ComponentPlacementViolationKind.surfaceNotAllowed,
          message: '$name cannot be mounted on ${surface.type.name}.',
        ),
      );
    }
    if (roomEnvironment != null) {
      violations.addAll(environment.validate(roomEnvironment));
    }
    return List.unmodifiable(violations);
  }

  bool canPlaceOn(RoomSurfaceRef surface) =>
      validatePlacement(surface: surface).isEmpty;
}

abstract final class ComponentCatalogV2 {
  static final Map<String, ComponentCatalogEntryV2> _entries = {
    for (final entry in _defaults) entry.id: entry,
  };

  static List<ComponentCatalogEntryV2> get entries =>
      List.unmodifiable(_entries.values);

  static ComponentCatalogEntryV2? byId(String id) => _entries[id];

  static ComponentCatalogEntryV2 require(String id) {
    final entry = byId(id);
    if (entry == null) {
      throw ArgumentError.value(id, 'id', 'Unknown component.');
    }
    return entry;
  }

  static List<ComponentCatalogEntryV2> forSystem(
    EngineeringSystemClass systemClass,
  ) =>
      entries
          .where((entry) => entry.systemClass == systemClass)
          .toList(growable: false);

  static List<ComponentCatalogEntryV2> forSurface(
    SurfacePlaneType surfaceType,
  ) =>
      entries
          .where(
              (entry) => entry.mounting.allowedSurfaces.contains(surfaceType))
          .toList(growable: false);

  static final List<ComponentCatalogEntryV2> _defaults = [
    _socket,
    _switch,
    _light,
    _curtainMotor,
    _junctionBox,
    _powerSource,
    _distributionBoard,
    _cctvCamera,
    _lanOutlet,
    _wifiAccessPoint,
    _smokeDetector,
    _acsReader,
    _doorContact,
    _custom,
  ];

  static final ComponentCatalogEntryV2 _socket = ComponentCatalogEntryV2(
    id: 'power.socket.general',
    code: 'SOCKET-GENERAL',
    name: 'Розетка',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall},
      preferredHeightMm: 300,
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -10,
      maxAmbientC: 40,
      maxRelativeHumidityPercent: 80,
      allowWetZone: false,
      allowDusty: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'power-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(nominalVoltageV: 230),
    routePreferenceId: 'power.standard',
  );

  static final ComponentCatalogEntryV2 _switch = ComponentCatalogEntryV2(
    id: 'lighting.switch.general',
    code: 'SWITCH-GENERAL',
    name: 'Выключатель',
    discipline: EngineeringDiscipline.lighting,
    systemClass: EngineeringSystemClass.lighting,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall},
      preferredHeightMm: 900,
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -10,
      maxAmbientC: 40,
      maxRelativeHumidityPercent: 80,
      allowWetZone: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'power-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
      EngineeringPortSpec(
        id: 'switched-out',
        direction: EngineeringPortDirection.output,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(nominalVoltageV: 230),
    routePreferenceId: 'lighting.wall-control',
  );

  static final ComponentCatalogEntryV2 _light = ComponentCatalogEntryV2(
    id: 'lighting.luminaire.general',
    code: 'LIGHT-GENERAL',
    name: 'Светильник',
    discipline: EngineeringDiscipline.lighting,
    systemClass: EngineeringSystemClass.lighting,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.ceiling, SurfacePlaneType.wall},
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -20,
      maxAmbientC: 45,
      maxRelativeHumidityPercent: 90,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'power-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(
      ratedPowerW: 15,
      nominalVoltageV: 230,
    ),
    routePreferenceId: 'lighting.ceiling',
  );

  static final ComponentCatalogEntryV2 _curtainMotor = ComponentCatalogEntryV2(
    id: 'power.motor.curtain',
    code: 'CURTAIN-MOTOR',
    name: 'Привод штор',
    discipline: EngineeringDiscipline.automation,
    systemClass: EngineeringSystemClass.powerAc,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall, SurfacePlaneType.ceiling},
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: 0,
      maxAmbientC: 45,
      maxRelativeHumidityPercent: 80,
      allowWetZone: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'power-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
      EngineeringPortSpec(
        id: 'control',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {
          EngineeringConnectionType.dryContact,
          EngineeringConnectionType.rs485,
        },
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(
      ratedPowerW: 150,
      nominalVoltageV: 230,
    ),
    routePreferenceId: 'automation.curtain',
  );

  static final ComponentCatalogEntryV2 _junctionBox = ComponentCatalogEntryV2(
    id: 'power.junction-box.general',
    code: 'JB-GENERAL',
    name: 'Распределительная коробка',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall, SurfacePlaneType.ceiling},
    ),
    environment: const ComponentEnvironmentConstraints(),
    ports: [
      EngineeringPortSpec(
        id: 'in',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
      EngineeringPortSpec(
        id: 'out',
        direction: EngineeringPortDirection.output,
        allowedConnections: const {EngineeringConnectionType.acSinglePhase},
      ),
    ],
    routePreferenceId: 'power.junction',
  );

  static final ComponentCatalogEntryV2 _powerSource = ComponentCatalogEntryV2(
    id: 'power.source.general',
    code: 'POWER-SOURCE',
    name: 'Источник питания',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall, SurfacePlaneType.floor},
    ),
    environment: const ComponentEnvironmentConstraints(
      allowWetZone: false,
      allowCorrosive: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'power-out',
        direction: EngineeringPortDirection.output,
        allowedConnections: const {
          EngineeringConnectionType.acSinglePhase,
          EngineeringConnectionType.acThreePhase,
        },
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(nominalVoltageV: 230),
    routePreferenceId: 'power.source',
  );

  static final ComponentCatalogEntryV2 _distributionBoard =
      ComponentCatalogEntryV2(
    id: 'power.distribution-board.general',
    code: 'DB-GENERAL',
    name: 'Распределительный щит',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    calculationKind: EngineeringCalculationKind.powerCableSizing,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {
        SurfacePlaneType.wall,
        SurfacePlaneType.floor,
      },
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -10,
      maxAmbientC: 40,
      maxRelativeHumidityPercent: 80,
      allowWetZone: false,
      allowCorrosive: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'incoming',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {
          EngineeringConnectionType.acSinglePhase,
          EngineeringConnectionType.acThreePhase,
        },
      ),
      EngineeringPortSpec(
        id: 'outgoing',
        direction: EngineeringPortDirection.output,
        allowedConnections: const {
          EngineeringConnectionType.acSinglePhase,
          EngineeringConnectionType.acThreePhase,
        },
      ),
    ],
    routePreferenceId: 'power.board',
  );

  static final ComponentCatalogEntryV2 _cctvCamera = ComponentCatalogEntryV2(
    id: 'cctv.camera.poe',
    code: 'CAM-POE',
    name: 'IP-камера PoE',
    discipline: EngineeringDiscipline.cctv,
    systemClass: EngineeringSystemClass.cctv,
    calculationKind: EngineeringCalculationKind.poePowerBudget,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall, SurfacePlaneType.ceiling},
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -20,
      maxAmbientC: 50,
      maxRelativeHumidityPercent: 95,
      allowWetZone: true,
      allowDusty: true,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'network-poe',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {
          EngineeringConnectionType.poe,
          EngineeringConnectionType.ethernetCopper,
        },
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(
      ratedPowerW: 12,
      poeClass: 'PoE+',
    ),
    routePreferenceId: 'data.poe',
  );

  static final ComponentCatalogEntryV2 _lanOutlet = ComponentCatalogEntryV2(
    id: 'data.outlet.rj45',
    code: 'DATA-RJ45',
    name: 'Информационная розетка RJ45',
    discipline: EngineeringDiscipline.data,
    systemClass: EngineeringSystemClass.structuredCabling,
    calculationKind: EngineeringCalculationKind.copperLinkLength,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall},
      preferredHeightMm: 300,
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: 0,
      maxAmbientC: 50,
      maxRelativeHumidityPercent: 90,
      allowWetZone: false,
      allowCorrosive: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'data',
        direction: EngineeringPortDirection.bidirectional,
        allowedConnections: const {EngineeringConnectionType.ethernetCopper},
      ),
    ],
    routePreferenceId: 'data.copper',
  );

  static final ComponentCatalogEntryV2 _wifiAccessPoint =
      ComponentCatalogEntryV2(
    id: 'data.wifi-ap.poe',
    code: 'WIFI-AP-POE',
    name: 'Wi-Fi точка доступа PoE',
    discipline: EngineeringDiscipline.data,
    systemClass: EngineeringSystemClass.poeNetwork,
    calculationKind: EngineeringCalculationKind.poePowerBudget,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {
        SurfacePlaneType.ceiling,
        SurfacePlaneType.wall,
      },
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: 0,
      maxAmbientC: 45,
      maxRelativeHumidityPercent: 90,
      allowWetZone: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'network-poe',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.poe},
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(
      ratedPowerW: 20,
      poeClass: 'PoE+',
    ),
    routePreferenceId: 'data.poe',
  );

  static final ComponentCatalogEntryV2 _smokeDetector = ComponentCatalogEntryV2(
    id: 'fire.detector.smoke',
    code: 'FIRE-SMOKE',
    name: 'Дымовой извещатель',
    discipline: EngineeringDiscipline.fireAlarm,
    systemClass: EngineeringSystemClass.fireAlarm,
    calculationKind: EngineeringCalculationKind.fireLoopElectrical,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.ceiling},
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -10,
      maxAmbientC: 55,
      maxRelativeHumidityPercent: 95,
      allowWetZone: false,
      allowDusty: false,
      allowCorrosive: false,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'loop-in',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.fireLoop},
      ),
      EngineeringPortSpec(
        id: 'loop-out',
        direction: EngineeringPortDirection.output,
        allowedConnections: const {EngineeringConnectionType.fireLoop},
      ),
    ],
    routePreferenceId: 'fire.loop',
  );

  static final ComponentCatalogEntryV2 _acsReader = ComponentCatalogEntryV2(
    id: 'acs.reader.general',
    code: 'ACS-READER',
    name: 'Считыватель СКУД',
    discipline: EngineeringDiscipline.accessControl,
    systemClass: EngineeringSystemClass.accessControl,
    calculationKind: EngineeringCalculationKind.dcVoltageDrop,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall},
      preferredHeightMm: 1200,
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -20,
      maxAmbientC: 50,
      maxRelativeHumidityPercent: 95,
      allowWetZone: true,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'power',
        direction: EngineeringPortDirection.input,
        allowedConnections: const {EngineeringConnectionType.dcPower},
      ),
      EngineeringPortSpec(
        id: 'bus',
        direction: EngineeringPortDirection.bidirectional,
        allowedConnections: const {EngineeringConnectionType.rs485},
      ),
    ],
    loadDefaults: const ComponentLoadDefaults(
      ratedPowerW: 5,
      nominalVoltageV: 12,
    ),
    routePreferenceId: 'acs.low-voltage',
  );

  static final ComponentCatalogEntryV2 _doorContact = ComponentCatalogEntryV2(
    id: 'acs.contact.door',
    code: 'ACS-DOOR-CONTACT',
    name: 'Датчик двери',
    discipline: EngineeringDiscipline.accessControl,
    systemClass: EngineeringSystemClass.dryContact,
    calculationKind: EngineeringCalculationKind.connectivityOnly,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {SurfacePlaneType.wall},
    ),
    environment: const ComponentEnvironmentConstraints(
      minAmbientC: -30,
      maxAmbientC: 55,
      maxRelativeHumidityPercent: 95,
      allowWetZone: true,
    ),
    ports: [
      EngineeringPortSpec(
        id: 'contact',
        direction: EngineeringPortDirection.output,
        allowedConnections: const {EngineeringConnectionType.dryContact},
      ),
    ],
    routePreferenceId: 'acs.signal',
  );

  static final ComponentCatalogEntryV2 _custom = ComponentCatalogEntryV2(
    id: 'custom.component.general',
    code: 'CUSTOM',
    name: 'Компонент',
    discipline: EngineeringDiscipline.automation,
    systemClass: EngineeringSystemClass.custom,
    calculationKind: EngineeringCalculationKind.connectivityOnly,
    mounting: ComponentMountingPolicy(
      allowedSurfaces: const {
        SurfacePlaneType.wall,
        SurfacePlaneType.ceiling,
        SurfacePlaneType.floor,
      },
    ),
    environment: const ComponentEnvironmentConstraints(),
    ports: [
      EngineeringPortSpec(
        id: 'custom',
        direction: EngineeringPortDirection.bidirectional,
        allowedConnections: const {EngineeringConnectionType.custom},
      ),
    ],
    routePreferenceId: 'custom',
  );
}

abstract final class LegacyElectricalCatalogAdapter {
  static String componentIdFor(ElectricalComponentType type) => switch (type) {
        ElectricalComponentType.socketOutlet => 'power.socket.general',
        ElectricalComponentType.switchControl => 'lighting.switch.general',
        ElectricalComponentType.lightingPoint => 'lighting.luminaire.general',
        ElectricalComponentType.curtainMotor => 'power.motor.curtain',
        ElectricalComponentType.junctionBox => 'power.junction-box.general',
        ElectricalComponentType.powerSource => 'power.source.general',
        ElectricalComponentType.distributionBoard =>
          'power.distribution-board.general',
        ElectricalComponentType.custom => 'custom.component.general',
      };

  static ComponentCatalogEntryV2 entryFor(ElectricalComponentType type) =>
      ComponentCatalogV2.require(componentIdFor(type));
}
