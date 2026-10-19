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

enum ElectricalPortKind {
  powerIn,
  powerOut,
  controlIn,
  controlOut,
  neutral,
  earth,
}

final class ElectricalPortDefinition {
  const ElectricalPortDefinition({required this.id, required this.kind});

  final String id;
  final ElectricalPortKind kind;
}

/// An engineering component placed on one physical room surface.
/// Coordinates are persisted in surface-local millimetres, never pixels.
///
/// [componentTypeId] is the canonical V2 catalog identity. [type] remains as a
/// legacy rendering/routing fallback while the editor migrates away from the
/// electrical-only enum.
final class ElectricalComponentPlacement {
  ElectricalComponentPlacement({
    required this.id,
    required this.type,
    required this.surface,
    required this.position,
    required this.label,
    String? componentTypeId,
    this.rotationDegrees = 0,
    this.ratedPowerW,
    this.voltageV = 230,
    this.ports = const [],
  }) : componentTypeId = componentTypeId ?? legacyComponentTypeId(type) {
    if (id.isEmpty) {
      throw ArgumentError('Component id must be non-empty.');
    }
    if (this.componentTypeId.isEmpty) {
      throw ArgumentError('componentTypeId must be non-empty.');
    }
    if (label.isEmpty) {
      throw ArgumentError('Component label must be non-empty.');
    }
    if (voltageV <= 0) {
      throw ArgumentError.value(voltageV, 'voltageV');
    }
    if (ratedPowerW != null && ratedPowerW! < 0) {
      throw ArgumentError.value(ratedPowerW, 'ratedPowerW');
    }
  }

  final String id;
  final ElectricalComponentType type;
  final String componentTypeId;
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
    String? componentTypeId,
    int? rotationDegrees,
    int? ratedPowerW,
    int? voltageV,
  }) =>
      ElectricalComponentPlacement(
        id: id,
        type: type,
        componentTypeId: componentTypeId ?? this.componentTypeId,
        surface: surface ?? this.surface,
        position: position ?? this.position,
        label: label ?? this.label,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        ratedPowerW: ratedPowerW ?? this.ratedPowerW,
        voltageV: voltageV ?? this.voltageV,
        ports: ports,
      );
}

String legacyComponentTypeId(ElectricalComponentType type) => switch (type) {
      ElectricalComponentType.socketOutlet => 'power.socket.general',
      ElectricalComponentType.switchControl => 'lighting.switch.general',
      ElectricalComponentType.lightingPoint => 'lighting.luminaire.general',
      ElectricalComponentType.curtainMotor => 'legacy.curtain-motor',
      ElectricalComponentType.junctionBox => 'power.junction-box.general',
      ElectricalComponentType.powerSource => 'legacy.power-source',
      ElectricalComponentType.distributionBoard =>
        'power.distribution-board.general',
      ElectricalComponentType.custom => 'legacy.custom',
    };

ElectricalComponentType legacyVisualTypeForComponentId(String componentTypeId) =>
    switch (componentTypeId) {
      'power.socket.general' => ElectricalComponentType.socketOutlet,
      'lighting.switch.general' => ElectricalComponentType.switchControl,
      'lighting.luminaire.general' => ElectricalComponentType.lightingPoint,
      'power.junction-box.general' => ElectricalComponentType.junctionBox,
      'power.distribution-board.general' =>
        ElectricalComponentType.distributionBoard,
      'legacy.curtain-motor' => ElectricalComponentType.curtainMotor,
      'legacy.power-source' => ElectricalComponentType.powerSource,
      _ => ElectricalComponentType.custom,
    };

abstract final class ElectricalComponentDefaults {
  static List<ElectricalPortDefinition> portsFor(
    ElectricalComponentType type,
  ) =>
      switch (type) {
        ElectricalComponentType.socketOutlet => const [
            ElectricalPortDefinition(
              id: 'power-in',
              kind: ElectricalPortKind.powerIn,
            ),
            ElectricalPortDefinition(
              id: 'earth',
              kind: ElectricalPortKind.earth,
            ),
          ],
        ElectricalComponentType.switchControl => const [
            ElectricalPortDefinition(
              id: 'power-in',
              kind: ElectricalPortKind.powerIn,
            ),
            ElectricalPortDefinition(
              id: 'control-out',
              kind: ElectricalPortKind.controlOut,
            ),
          ],
        ElectricalComponentType.lightingPoint => const [
            ElectricalPortDefinition(
              id: 'power-in',
              kind: ElectricalPortKind.powerIn,
            ),
            ElectricalPortDefinition(
              id: 'control-in',
              kind: ElectricalPortKind.controlIn,
            ),
            ElectricalPortDefinition(
              id: 'earth',
              kind: ElectricalPortKind.earth,
            ),
          ],
        ElectricalComponentType.curtainMotor => const [
            ElectricalPortDefinition(
              id: 'power-in',
              kind: ElectricalPortKind.powerIn,
            ),
            ElectricalPortDefinition(
              id: 'control-in',
              kind: ElectricalPortKind.controlIn,
            ),
            ElectricalPortDefinition(
              id: 'earth',
              kind: ElectricalPortKind.earth,
            ),
          ],
        ElectricalComponentType.junctionBox => const [
            ElectricalPortDefinition(
              id: 'power-in',
              kind: ElectricalPortKind.powerIn,
            ),
            ElectricalPortDefinition(
              id: 'power-out',
              kind: ElectricalPortKind.powerOut,
            ),
          ],
        ElectricalComponentType.powerSource => const [
            ElectricalPortDefinition(
              id: 'power-out',
              kind: ElectricalPortKind.powerOut,
            ),
            ElectricalPortDefinition(
              id: 'earth',
              kind: ElectricalPortKind.earth,
            ),
          ],
        ElectricalComponentType.distributionBoard => const [
            ElectricalPortDefinition(
              id: 'power-out',
              kind: ElectricalPortKind.powerOut,
            ),
            ElectricalPortDefinition(
              id: 'earth',
              kind: ElectricalPortKind.earth,
            ),
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
