import 'package:flutter/material.dart';

import '../../app/alien_cockpit_tokens.dart';
import '../../domain/component_catalog_v2.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_ui_tokens.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([catalog, controller.placementCursor]),
      builder: (context, _) {
        final entries = _filteredEntries(catalog.entries);
        return Column(
          children: [
            _CatalogHeader(
              count: entries.length,
              activeComponentTypeId:
                  controller.placementCursor.activeComponentTypeId,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Поиск оборудования',
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close, size: 16),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 36,
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
                    avatar: const Icon(Icons.layers_outlined, size: 15),
                    label: const Text('Плоскость'),
                    onSelected: (value) =>
                        setState(() => _compatibleOnly = value),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _repeatPlacement,
                    avatar: const Icon(Icons.repeat, size: 15),
                    label: const Text('Повтор'),
                    onSelected: (value) =>
                        setState(() => _repeatPlacement = value),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
            Expanded(
              child: catalog.loading
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                      ? const _EmptyCatalogState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 18),
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
        _SectionHeader(label: group.key, count: group.value.length),
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
    final placing = controller.placementCursor.activeComponentTypeId == entry.id;
    return _EquipmentCard(
      entry: entry,
      compatible: compatible,
      placing: placing,
      mountingLabel: _mountingLabel(entry),
      onTap: () => _startPlacement(entry),
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

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.count,
    required this.activeComponentTypeId,
  });

  final int count;
  final String? activeComponentTypeId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: EditorUiTokens.panelHeaderHeight + 4,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: AlienCockpitTokens.signalCyan.withValues(alpha: 0.16),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.widgets_outlined,
            size: 17,
            color: AlienCockpitTokens.signalCyan,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'EQUIPMENT MATRIX',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (activeComponentTypeId != null)
            const Padding(
              padding: EdgeInsets.only(right: 7),
              child: Icon(
                Icons.radar,
                size: 15,
                color: AlienCockpitTokens.signalAqua,
              ),
            ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(5, 9, 5, 5),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: AlienCockpitTokens.signalViolet,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      letterSpacing: 0.85,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
            ),
          ],
        ),
      );
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.entry,
    required this.compatible,
    required this.placing,
    required this.mountingLabel,
    required this.onTap,
  });

  final ComponentCatalogEntryV2 entry;
  final bool compatible;
  final bool placing;
  final String mountingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signal = placing
        ? AlienCockpitTokens.signalAqua
        : compatible
            ? AlienCockpitTokens.signalCyan
            : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: placing
            ? signal.withValues(alpha: 0.075)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(
            color: placing
                ? signal.withValues(alpha: 0.52)
                : scheme.outlineVariant.withValues(alpha: 0.58),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: signal.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: signal.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(_iconFor(entry.systemClass), size: 18, color: signal),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.code} · ${entry.systemClass.name.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9.5,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.25,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        compatible
                            ? mountingLabel
                            : '$mountingLabel · откроется совместимая плоскость',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9.5,
                              color: compatible
                                  ? scheme.onSurfaceVariant
                                  : AlienCockpitTokens.signalWarning,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  placing ? Icons.radar : Icons.add_circle_outline,
                  size: 18,
                  color: signal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radar,
                size: 28,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 9),
              Text(
                'Нет оборудования для текущего фильтра',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      );
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

// Transitional presentation mapping. The domain taxonomy should move into
// ComponentCatalogEntryV2 so UI never infers categories from localized names.
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
  return height == null ? surfaces : '$surfaces · H $height mm';
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
