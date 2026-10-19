import 'package:flutter/material.dart';

import '../../domain/component_catalog_v2.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'engineering_placement_cursor_session.dart';

class DeviceCatalogPanel extends StatefulWidget {
  const DeviceCatalogPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  State<DeviceCatalogPanel> createState() => _DeviceCatalogPanelState();
}

class _DeviceCatalogPanelState extends State<DeviceCatalogPanel> {
  final TextEditingController _searchController = TextEditingController();
  _CatalogFamily? _family;
  bool _compatibleOnly = false;
  bool _repeatPlacement = true;

  EditorController get controller => widget.controller;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = controller.componentCatalog;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final entries = _filteredEntries(catalog.entries);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Поиск оборудования',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _FamilyChip(
                    label: 'Все',
                    selected: _family == null,
                    onPressed: () => setState(() => _family = null),
                  ),
                  for (final family in _CatalogFamily.values)
                    _FamilyChip(
                      label: _familyLabel(family),
                      selected: _family == family,
                      onPressed: () => setState(() => _family = family),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                children: [
                  FilterChip(
                    selected: _compatibleOnly,
                    avatar: const Icon(Icons.layers_outlined, size: 16),
                    label: const Text('Текущая плоскость'),
                    onSelected: (value) =>
                        setState(() => _compatibleOnly = value),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _repeatPlacement,
                    avatar: const Icon(Icons.repeat, size: 16),
                    label: const Text('Повтор'),
                    onSelected: (value) =>
                        setState(() => _repeatPlacement = value),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: catalog.loading
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Нет оборудования для текущего фильтра.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
                          children: _buildGrouped(entries),
                        ),
            ),
          ],
        );
      },
    );
  }

  List<ComponentCatalogEntryV2> _filteredEntries(
    List<ComponentCatalogEntryV2> source,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final activeSurface = controller.activeSurface;
    return source.where((entry) {
      if (_family != null && _familyFor(entry) != _family) return false;
      if (query.isNotEmpty &&
          !entry.name.toLowerCase().contains(query) &&
          !entry.code.toLowerCase().contains(query) &&
          !entry.id.toLowerCase().contains(query)) {
        return false;
      }
      if (_compatibleOnly &&
          activeSurface != null &&
          !entry.mounting.allows(activeSurface)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<Widget> _buildGrouped(List<ComponentCatalogEntryV2> entries) {
    final groups = <String, List<ComponentCatalogEntryV2>>{};
    for (final entry in entries) {
      groups.putIfAbsent(_categoryLabel(entry), () => []).add(entry);
    }
    final result = <Widget>[];
    for (final group in groups.entries) {
      result.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 5),
          child: Text(
            group.key.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final entry in group.value) {
        result.add(_entryTile(entry));
      }
    }
    return result;
  }

  Widget _entryTile(ComponentCatalogEntryV2 entry) {
    final active = controller.activeSurface;
    final compatible = active == null || entry.mounting.allows(active);
    return Card(
      margin: const EdgeInsets.only(bottom: 5),
      elevation: 0,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(_iconFor(entry.systemClass), size: 19),
        title: Text(entry.name),
        subtitle: Text(
          compatible
              ? _mountingLabel(entry)
              : '${_mountingLabel(entry)} · будет открыта подходящая плоскость',
          style: const TextStyle(fontSize: 10),
        ),
        trailing: const Icon(Icons.add_circle_outline, size: 18),
        onTap: () => _startPlacement(entry),
      ),
    );
  }

  void _startPlacement(ComponentCatalogEntryV2 entry) {
    _ensureCompatibleSurface(entry);
    controller.setTool(EditorTool.select);
    controller.placementCursor.beginCatalogPlacement(
      entry.id,
      repeat: _repeatPlacement,
    );
  }

  void _ensureCompatibleSurface(ComponentCatalogEntryV2 entry) {
    final active = controller.activeSurface;
    if (active != null && entry.mounting.allows(active)) return;
    if (entry.mounting.allowedSurfaces.contains(SurfacePlaneType.wall)) {
      controller.showWall(0);
      return;
    }
    if (entry.mounting.allowedSurfaces.contains(SurfacePlaneType.ceiling)) {
      controller.showCeiling();
      return;
    }
    if (entry.mounting.allowedSurfaces.contains(SurfacePlaneType.floor)) {
      controller.showFloor();
    }
  }
}

enum _CatalogFamily { power, lighting, lowCurrent, automation }

_CatalogFamily _familyFor(ComponentCatalogEntryV2 entry) =>
    switch (entry.discipline) {
      EngineeringDiscipline.power => _CatalogFamily.power,
      EngineeringDiscipline.lighting => _CatalogFamily.lighting,
      EngineeringDiscipline.automation => _CatalogFamily.automation,
      EngineeringDiscipline.lowVoltage ||
      EngineeringDiscipline.data ||
      EngineeringDiscipline.cctv ||
      EngineeringDiscipline.accessControl ||
      EngineeringDiscipline.fireAlarm =>
        _CatalogFamily.lowCurrent,
    };

String _familyLabel(_CatalogFamily family) => switch (family) {
      _CatalogFamily.power => 'Силовые',
      _CatalogFamily.lighting => 'Освещение',
      _CatalogFamily.lowCurrent => 'Слаботочные',
      _CatalogFamily.automation => 'Автоматика',
    };

String _categoryLabel(ComponentCatalogEntryV2 entry) => switch (entry.systemClass) {
      EngineeringSystemClass.powerAc || EngineeringSystemClass.powerDc =>
        entry.name.toLowerCase().contains('щит') ? 'Щиты' : 'Розетки и питание',
      EngineeringSystemClass.lighting =>
        entry.name.toLowerCase().contains('выключ') ? 'Выключатели' : 'Свет',
      EngineeringSystemClass.structuredCabling => 'LAN / СКС',
      EngineeringSystemClass.poeNetwork => 'PoE / Wi-Fi',
      EngineeringSystemClass.fiberOptic => 'Оптика',
      EngineeringSystemClass.cctv => 'CCTV',
      EngineeringSystemClass.accessControl => 'СКУД',
      EngineeringSystemClass.fireAlarm => 'Пожарная сигнализация',
      EngineeringSystemClass.automationBus ||
      EngineeringSystemClass.dryContact =>
        'Автоматика',
      EngineeringSystemClass.custom => 'Прочее',
    };

String _mountingLabel(ComponentCatalogEntryV2 entry) {
  final surfaces = entry.mounting.allowedSurfaces.map((type) {
    return switch (type) {
      SurfacePlaneType.wall => 'стена',
      SurfacePlaneType.floor => 'пол',
      SurfacePlaneType.ceiling => 'потолок',
    };
  }).join(', ');
  final height = entry.mounting.preferredHeightMm;
  return height == null ? surfaces : '$surfaces · $height mm';
}

IconData _iconFor(EngineeringSystemClass systemClass) => switch (systemClass) {
      EngineeringSystemClass.powerAc || EngineeringSystemClass.powerDc =>
        Icons.power_outlined,
      EngineeringSystemClass.lighting => Icons.lightbulb_outline,
      EngineeringSystemClass.structuredCabling ||
      EngineeringSystemClass.poeNetwork ||
      EngineeringSystemClass.fiberOptic =>
        Icons.lan_outlined,
      EngineeringSystemClass.cctv => Icons.videocam_outlined,
      EngineeringSystemClass.accessControl => Icons.badge_outlined,
      EngineeringSystemClass.fireAlarm => Icons.local_fire_department_outlined,
      EngineeringSystemClass.automationBus ||
      EngineeringSystemClass.dryContact =>
        Icons.memory_outlined,
      EngineeringSystemClass.custom => Icons.widgets_outlined,
    };

class _FamilyChip extends StatelessWidget {
  const _FamilyChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          selected: selected,
          label: Text(label),
          onSelected: (_) => onPressed(),
          visualDensity: VisualDensity.compact,
        ),
      );
}
