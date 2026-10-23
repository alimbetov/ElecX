import 'package:flutter/material.dart';

import '../../app/engineering_colors.dart';
import '../../domain/component_catalog_v2.dart';
import '../../domain/component_taxonomy.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'editor_ui_tokens.dart';
import 'engineering_placement_cursor_session.dart';
import 'engineering_selection_inspector.dart';
import 'route_selection_session.dart';
import 'wall_construction_editor.dart';

class DeviceCatalogPanel extends StatefulWidget {
  const DeviceCatalogPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  State<DeviceCatalogPanel> createState() => _DeviceCatalogPanelState();
}

class _DeviceCatalogPanelState extends State<DeviceCatalogPanel> {
  final TextEditingController _searchController = TextEditingController();
  ComponentCategory? _category;
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
      listenable: Listenable.merge([
        controller,
        catalog,
        controller.placementCursor,
        controller.p2,
        controller.routeSelection,
      ]),
      builder: (context, _) {
        final placing = controller.placementCursor.active;
        final hasEngineeringSelection =
            controller.routeSelection.selectedRouteId != null ||
                controller.p2.selectedComponent != null;
        if (!placing && hasEngineeringSelection) {
          return _InspectorMode(
            controller: controller,
            onBackToCatalog: _clearEngineeringSelection,
          );
        }
        return _catalogWithWallConstruction(context, catalog);
      },
    );
  }

  Widget _catalogWithWallConstruction(
    BuildContext context,
    ComponentCatalogSession catalog,
  ) {
    final showWallConstruction =
        controller.activeSurface?.type == SurfacePlaneType.wall;
    return Column(
      children: [
        if (showWallConstruction) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: WallConstructionEditor(
                controller: controller,
                compact: true,
              ),
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(child: _catalog(context, catalog)),
      ],
    );
  }

  Widget _catalog(BuildContext context, ComponentCatalogSession catalog) {
    final scheme = Theme.of(context).colorScheme;
    final entries = _filteredEntries(catalog.entries);
    return Column(
      children: [
        _CatalogHeader(
          count: entries.length,
          activeComponentTypeId:
              controller.placementCursor.activeComponentTypeId,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
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
              _FilterChip(
                label: 'Все',
                selected: _category == null,
                onPressed: () => setState(() => _category = null),
              ),
              for (final category in ComponentCategory.values)
                if (category != ComponentCategory.custom)
                  _FilterChip(
                    label: _categoryLabel(category),
                    selected: _category == category,
                    onPressed: () => setState(() => _category = category),
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
                onSelected: (value) => setState(() => _compatibleOnly = value),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              FilterChip(
                selected: _repeatPlacement,
                avatar: const Icon(Icons.repeat, size: 15),
                label: const Text('Повтор'),
                onSelected: (value) => setState(() => _repeatPlacement = value),
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
  }

  void _clearEngineeringSelection() {
    controller.routeSelection.clear();
    controller.p2.clearSelection();
  }

  List<ComponentCatalogEntryV2> _filteredEntries(
    List<ComponentCatalogEntryV2> source,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final activeSurface = controller.activeSurface;
    return source.where((entry) {
      final taxonomy = ComponentTaxonomyResolver.resolve(entry);
      if (_category != null && taxonomy.category != _category) return false;
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
    final groups = <ComponentSubcategory, List<ComponentCatalogEntryV2>>{};
    for (final entry in entries) {
      final taxonomy = ComponentTaxonomyResolver.resolve(entry);
      groups.putIfAbsent(taxonomy.subcategory, () => []).add(entry);
    }
    final result = <Widget>[];
    for (final group in groups.entries) {
      result.add(
        _SectionHeader(
          label: _subcategoryLabel(group.key),
          count: group.value.length,
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
    final placing =
        controller.placementCursor.activeComponentTypeId == entry.id;
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
    controller.routeSelection.clear();
    controller.p2.clearSelection();
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

class _InspectorMode extends StatelessWidget {
  const _InspectorMode({
    required this.controller,
    required this.onBackToCatalog,
  });

  final EditorController controller;
  final VoidCallback onBackToCatalog;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final engineering = EngineeringColors.of(context);
    return Column(
      children: [
        Container(
          height: EditorUiTokens.panelHeaderHeight + 4,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: engineering.active.withValues(alpha: 0.22),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 17,
                color: engineering.active,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'ENGINEERING INSPECTOR',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Вернуться в каталог',
                visualDensity: VisualDensity.compact,
                onPressed: onBackToCatalog,
                icon: const Icon(Icons.widgets_outlined, size: 17),
              ),
            ],
          ),
        ),
        Expanded(child: EngineeringSelectionInspector(controller: controller)),
      ],
    );
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
    final engineering = EngineeringColors.of(context);
    return Container(
      height: EditorUiTokens.panelHeaderHeight + 4,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: engineering.info.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.widgets_outlined, size: 17, color: engineering.info),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'EQUIPMENT MATRIX',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(letterSpacing: 0.9, fontWeight: FontWeight.w700),
            ),
          ),
          if (activeComponentTypeId != null)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Icon(Icons.radar, size: 15, color: engineering.active),
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
  Widget build(BuildContext context) {
    final engineering = EngineeringColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 9, 5, 5),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: engineering.category,
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
    final engineering = EngineeringColors.of(context);
    final signal = placing
        ? engineering.active
        : compatible
            ? engineering.info
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
                    border: Border.all(color: signal.withValues(alpha: 0.28)),
                  ),
                  child: Icon(
                    _iconFor(entry.systemClass),
                    size: 18,
                    color: signal,
                  ),
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
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                                  : engineering.warning,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

String _categoryLabel(ComponentCategory category) => switch (category) {
      ComponentCategory.power => 'Силовые',
      ComponentCategory.lighting => 'Освещение',
      ComponentCategory.data => 'Данные',
      ComponentCategory.cctv => 'CCTV',
      ComponentCategory.accessControl => 'СКУД',
      ComponentCategory.fireSafety => 'Пожарные',
      ComponentCategory.automation => 'Автоматика',
      ComponentCategory.infrastructure => 'Инфраструктура',
      ComponentCategory.custom => 'Прочее',
    };

String _subcategoryLabel(ComponentSubcategory category) => switch (category) {
      ComponentSubcategory.socketOutlet => 'Розетки',
      ComponentSubcategory.switchControl => 'Выключатели',
      ComponentSubcategory.luminaire => 'Светильники',
      ComponentSubcategory.distributionBoard => 'Щиты',
      ComponentSubcategory.junctionBox => 'Распределительные коробки',
      ComponentSubcategory.powerSource => 'Источники питания',
      ComponentSubcategory.motorDrive => 'Приводы',
      ComponentSubcategory.dataOutlet => 'LAN / СКС',
      ComponentSubcategory.accessPoint => 'Wi-Fi / PoE',
      ComponentSubcategory.camera => 'Камеры',
      ComponentSubcategory.accessReader => 'Считыватели',
      ComponentSubcategory.detector => 'Извещатели',
      ComponentSubcategory.contactSensor => 'Контакты / датчики',
      ComponentSubcategory.fiberTermination => 'Оптика',
      ComponentSubcategory.controller => 'Контроллеры',
      ComponentSubcategory.custom => 'Прочее',
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
      EngineeringSystemClass.powerAc ||
      EngineeringSystemClass.powerDc =>
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
