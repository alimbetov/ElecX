import '../../domain/component_catalog_v2.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/surfaces.dart';
import '../../engine/command_history.dart';
import 'editor_p2_session.dart';

extension CatalogComponentPlacement on EditorP2Session {
  ElectricalComponentPlacement placeCatalogComponent({
    required ComponentCatalogEntryV2 entry,
    required RoomSurfaceRef surface,
    required SurfacePointMm position,
  }) {
    if (!entry.canPlaceOn(surface)) {
      throw StateError(
        'Component ${entry.id} is not allowed on ${surface.type.name}.',
      );
    }
    final sequence = components.length + 1;
    final visualType = legacyVisualTypeForComponentId(entry.id);
    final component = ElectricalComponentPlacement(
      id: 'component-$sequence-${entry.code.toLowerCase()}',
      type: visualType,
      componentTypeId: entry.id,
      surface: surface,
      position: position,
      label: '${entry.name} $sequence',
      ratedPowerW: entry.loadDefaults.ratedPowerW,
      voltageV: entry.loadDefaults.nominalVoltageV ?? 230,
      ports: _legacyPortsFor(entry.id, visualType),
    );

    history.execute(_AddCatalogComponentCommand(component));
    select(component.id);
    return component;
  }
}

List<ElectricalPortDefinition> _legacyPortsFor(
  String componentTypeId,
  ElectricalComponentType visualType,
) {
  // Only exact legacy electrical identities get legacy electrical ports.
  // Low-current systems keep their canonical V2 ports in the catalog and are
  // intentionally not projected into the old ElectricalPortKind model.
  return switch (componentTypeId) {
    'power.socket.general' ||
    'lighting.switch.general' ||
    'lighting.luminaire.general' ||
    'power.junction-box.general' ||
    'power.distribution-board.general' =>
      ElectricalComponentDefaults.portsFor(visualType),
    _ => const <ElectricalPortDefinition>[],
  };
}

final class _AddCatalogComponentCommand
    implements EditorCommand<EditorP2State> {
  const _AddCatalogComponentCommand(this.component);

  final ElectricalComponentPlacement component;

  @override
  String get label => 'Add ${component.label}';

  @override
  EditorP2State execute(EditorP2State state) => state.copyWith(
        components: [...state.components, component],
      );

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
        components: state.components
            .where((item) => item.id != component.id)
            .toList(growable: false),
      );
}
