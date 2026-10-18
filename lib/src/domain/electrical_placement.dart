import 'surfaces.dart';

enum ElectricalComponentType {
  socketOutlet,
  switchControl,
  lightingPoint,
  curtainMotor,
  junctionBox,
  powerSource,
  distributionBoard,
  custom,
}

enum ElectricalPortKind { powerIn, powerOut, controlIn, controlOut, neutral, earth }

final class ElectricalPortDefinition {
  const ElectricalPortDefinition({required this.id, required this.kind});

  final String id;
  final ElectricalPortKind kind;
}

/// An engineering component placed on one physical room surface.
/// Coordinates are persisted in surface-local millimetres, never pixels.
final class ElectricalComponentPlacement {
  ElectricalComponentPlacement({
    required this.id,
    required this.type,
    required this.surface,
    required this.position,
    required this.label,
    this.rotationDegrees = 0,
    this.ratedPowerW,
    this.voltageV = 230,
    this.ports = const [],
  }) {
    if (id.isEmpty) throw ArgumentError('Component id must be non-empty.');
    if (label.isEmpty) throw ArgumentError('Component label must be non-empty.');
    if (voltageV <= 0) throw ArgumentError.value(voltageV, 'voltageV');
    if (ratedPowerW != null && ratedPowerW! < 0) {
      throw ArgumentError.value(ratedPowerW, 'ratedPowerW');
    }
  }

  final String id;
  final ElectricalComponentType type;
  final RoomSurfaceRef surface;
  final SurfacePointMm position;
  final String label;
  final int rotationDegrees;
  final int? ratedPowerW;
  final int voltageV;
  final List<ElectricalPortDefinition> ports;

  ElectricalComponentPlacement copyWith({
    RoomSurfaceRef? surface,
    SurfacePointMm? position,
    String? label,
    int? rotationDegrees,
    int? ratedPowerW,
    int? voltageV,
  }) =>
      ElectricalComponentPlacement(
        id: id,
        type: type,
        surface: surface ?? this.surface,
        position: position ?? this.position,
        label: label ?? this.label,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        ratedPowerW: ratedPowerW ?? this.ratedPowerW,
        voltageV: voltageV ?? this.voltageV,
        ports: ports,
      );
}

abstract final class ElectricalComponentDefaults {
  static List<ElectricalPortDefinition> portsFor(ElectricalComponentType type) => switch (type) {
        ElectricalComponentType.socketOutlet => const [
            ElectricalPortDefinition(id: 'power-in', kind: ElectricalPortKind.powerIn),
            ElectricalPortDefinition(id: 'earth', kind: ElectricalPortKind.earth),
          ],
        ElectricalComponentType.switchControl => const [
            ElectricalPortDefinition(id: 'power-in', kind: ElectricalPortKind.powerIn),
            ElectricalPortDefinition(id: 'control-out', kind: ElectricalPortKind.controlOut),
          ],
        ElectricalComponentType.lightingPoint => const [
            ElectricalPortDefinition(id: 'power-in', kind: ElectricalPortKind.powerIn),
            ElectricalPortDefinition(id: 'control-in', kind: ElectricalPortKind.controlIn),
            ElectricalPortDefinition(id: 'earth', kind: ElectricalPortKind.earth),
          ],
        ElectricalComponentType.curtainMotor => const [
            ElectricalPortDefinition(id: 'power-in', kind: ElectricalPortKind.powerIn),
            ElectricalPortDefinition(id: 'control-in', kind: ElectricalPortKind.controlIn),
            ElectricalPortDefinition(id: 'earth', kind: ElectricalPortKind.earth),
          ],
        ElectricalComponentType.junctionBox => const [
            ElectricalPortDefinition(id: 'power-in', kind: ElectricalPortKind.powerIn),
            ElectricalPortDefinition(id: 'power-out', kind: ElectricalPortKind.powerOut),
          ],
        ElectricalComponentType.powerSource => const [
            ElectricalPortDefinition(id: 'power-out', kind: ElectricalPortKind.powerOut),
            ElectricalPortDefinition(id: 'earth', kind: ElectricalPortKind.earth),
          ],
        ElectricalComponentType.distributionBoard => const [
            ElectricalPortDefinition(id: 'power-out', kind: ElectricalPortKind.powerOut),
            ElectricalPortDefinition(id: 'earth', kind: ElectricalPortKind.earth),
          ],
        ElectricalComponentType.custom => const [],
      };

  static String defaultLabel(ElectricalComponentType type) => switch (type) {
        ElectricalComponentType.socketOutlet => 'Розетка',
        ElectricalComponentType.switchControl => 'Выключатель',
        ElectricalComponentType.lightingPoint => 'Точка освещения',
        ElectricalComponentType.curtainMotor => 'Привод штор',
        ElectricalComponentType.junctionBox => 'Распредкоробка',
        ElectricalComponentType.powerSource => 'Источник питания',
        ElectricalComponentType.distributionBoard => 'Щит',
        ElectricalComponentType.custom => 'Компонент',
      };
}
