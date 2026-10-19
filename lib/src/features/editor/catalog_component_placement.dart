import '../../domain/component_catalog_v2.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/surfaces.dart';
import '../../engine/command_history.dart';
import 'editor_p2_session.dart';

final Expando<int> _catalogSequences = Expando<int>(
  'ElecX catalog component sequence',
);

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
    final sequence = _nextCatalogSequence(this);
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

int _nextCatalogSequence(EditorP2Session session) {
  final stored = _catalogSequences[session];
  if (stored != null) {
    _catalogSequences[session] = stored + 1;
    return stored;
  }

  final pattern = RegExp(r'^component-(\d+)(?:-|$)');
  var maxSequence = 0;
  for (final component in session.components) {
    final match = pattern.firstMatch(component.id);
    if (match == null) continue;
    final value = int.tryParse(match.group(1)!);
    if (value != null && value > maxSequence) maxSequence = value;
  }

  final next = maxSequence + 1;
  _catalogSequences[session] = next + 1;
  return next;
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
    'power.distribution-board.general' => ElectricalComponentDefaults.portsFor(
      visualType,
    ),
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
  EditorP2State execute(EditorP2State state) =>
      state.copyWith(components: [...state.components, component]);

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
    components: state.components
        .where((item) => item.id != component.id)
        .toList(growable: false),
  );
}
