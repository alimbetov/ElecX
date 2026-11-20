import 'package:flutter/material.dart';

import '../../domain/component_catalog_v2.dart';
import '../../domain/component_taxonomy.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'engineering_placement_cursor_session.dart';
import 'route_selection_session.dart';

/// Temporary UI payload; never stored in the project or engineering graph.
final class EquipmentPaletteDragData {
  const EquipmentPaletteDragData(this.catalogId);
  final String catalogId;
}

/// A shallow, horizontally scrolling palette above the drawing.
///
/// The catalog is the same ComponentCatalogSession as the older inspector;
/// only the presentation and spatial placement affordance differ.
class HorizontalEquipmentPalette extends StatefulWidget {
  const HorizontalEquipmentPalette({
    required this.controller,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final EditorController controller;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<HorizontalEquipmentPalette> createState() =>
      _HorizontalEquipmentPaletteState();
}

class _HorizontalEquipmentPaletteState
    extends State<HorizontalEquipmentPalette> {
  final TextEditingController _search = TextEditingController();
  ComponentCategory? _category;
  final Set<ComponentSubcategory> _collapsedGroups = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(ComponentCatalogEntryV2 entry) {
    final controller = widget.controller;
    final selected = controller.selectedSpace;
    if (selected == null) return;
    controller.setTool(EditorTool.select);
    controller.routeSelection.clear();
    controller.p2.clearSelection();
    final active = controller.activeSurface;
    if (active == null || !entry.mounting.allows(active)) {
      if (entry.mounting.allowedSurfaces.contains(SurfacePlaneType.wall)) {
        controller.showWall(0);
      } else if (entry.mounting.allowedSurfaces
          .contains(SurfacePlaneType.ceiling)) {
        controller.showCeiling();
      } else if (entry.mounting.allowedSurfaces
          .contains(SurfacePlaneType.floor)) {
        controller.showFloor();
      }
    }
    controller.placementCursor.beginCatalogPlacement(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.componentCatalog,
        widget.controller.placementCursor,
      ]),
      builder: (context, _) {
        final catalog = widget.controller.componentCatalog;
        final query = _search.text.trim().toLowerCase();
        final filtered = catalog.entries.where((entry) {
          final taxonomy = ComponentTaxonomyResolver.resolve(entry);
          return (_category == null || taxonomy.category == _category) &&
              (query.isEmpty ||
                  entry.name.toLowerCase().contains(query) ||
                  entry.code.toLowerCase().contains(query));
        }).toList(growable: false);
        final grouped = <ComponentSubcategory, List<ComponentCatalogEntryV2>>{};
        for (final entry in filtered) {
          final group = ComponentTaxonomyResolver.resolve(entry).subcategory;
          grouped.putIfAbsent(group, () => []).add(entry);
        }
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 42,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('equipment-palette-toggle'),
                      tooltip: widget.expanded
                          ? 'Свернуть матрицу оборудования'
                          : 'Развернуть матрицу оборудования',
                      onPressed: widget.onToggle,
                      icon: Icon(widget.expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down),
                    ),
                    const Icon(Icons.widgets_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('EQUIPMENT MATRIX',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(width: 8),
                    Text('${filtered.length}',
                        style: Theme.of(context).textTheme.labelSmall),
                    const Spacer(),
                    if (widget.expanded)
                      SizedBox(
                        width: 190,
                        child: TextField(
                          key: const ValueKey('equipment-palette-search'),
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: Theme.of(context).textTheme.bodySmall,
                          decoration: const InputDecoration(
                            hintText: 'Поиск оборудования',
                            prefixIcon: Icon(Icons.search, size: 17),
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
              if (widget.expanded) ...[
                SizedBox(
                  height: 38,
                  child: ListView(
                    key: const ValueKey('equipment-palette-categories'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _categoryChip(null, 'Все'),
                      for (final category in ComponentCategory.values)
                        if (category != ComponentCategory.custom)
                          _categoryChip(category, _categoryTitle(category)),
                    ],
                  ),
                ),
                if (catalog.loading)
                  const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SizedBox(
                    height: 110,
                    child: grouped.isEmpty
                        ? const Center(child: Text('Нет оборудования'))
                        : ListView(
                            key: const ValueKey('equipment-palette-scroll'),
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
                            children: [
                              for (final group in grouped.entries)
                                _groupStrip(group.key, group.value),
                            ],
                          ),
                  ),
              ],
              Divider(height: 1, color: Theme.of(context).dividerColor),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryChip(ComponentCategory? category, String label) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: FilterChip(
          label: Text(label),
          selected: _category == category,
          onSelected: (_) => setState(() => _category = category),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _groupStrip(
    ComponentSubcategory group,
    List<ComponentCatalogEntryV2> entries,
  ) {
    final collapsed = _collapsedGroups.contains(group);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          InkWell(
            key: ValueKey('equipment-group-${group.name}'),
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedGroups.remove(group);
              } else {
                _collapsedGroups.add(group);
              }
            }),
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(collapsed ? Icons.chevron_right : Icons.expand_less),
                  Text(
                    _subcategoryTitle(group),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text('${entries.length}',
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
          if (!collapsed)
            for (final entry in entries) _draggableCard(entry),
        ],
      ),
    );
  }

  Widget _draggableCard(ComponentCatalogEntryV2 entry) {
    final placing =
        widget.controller.placementCursor.activeComponentTypeId == entry.id;
    final scheme = Theme.of(context).colorScheme;
    final card = SizedBox(
      width: 142,
      child: Card(
        margin: const EdgeInsets.only(left: 5),
        color: placing ? scheme.primaryContainer : null,
        child: InkWell(
          key: ValueKey('equipment-palette-item-${entry.id}'),
          onTap: () => _select(entry),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Row(
              children: [
                Icon(_icon(entry.systemClass), size: 22),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall),
                      Text(entry.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Draggable<EquipmentPaletteDragData>(
      key: ValueKey('equipment-draggable-${entry.id}'),
      data: EquipmentPaletteDragData(entry.id),
      feedback: Material(
        elevation: 5,
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Text(entry.name, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

String _categoryTitle(ComponentCategory c) => switch (c) {
      ComponentCategory.power => 'Силовые',
      ComponentCategory.lighting => 'Освещение',
      ComponentCategory.data => 'Данные',
      ComponentCategory.cctv => 'Камеры',
      ComponentCategory.accessControl => 'СКУД',
      ComponentCategory.fireSafety => 'Пожарные',
      ComponentCategory.automation => 'Автоматика',
      ComponentCategory.infrastructure => 'Инфраструктура',
      ComponentCategory.custom => 'Прочее',
    };

String _subcategoryTitle(ComponentSubcategory c) => switch (c) {
      ComponentSubcategory.socketOutlet => 'Розетки',
      ComponentSubcategory.switchControl => 'Выключатели',
      ComponentSubcategory.luminaire => 'Светильники',
      ComponentSubcategory.distributionBoard => 'Щиты',
      ComponentSubcategory.junctionBox => 'Распредкоробки',
      ComponentSubcategory.powerSource => 'Источники',
      ComponentSubcategory.motorDrive => 'Приводы',
      ComponentSubcategory.dataOutlet => 'LAN / СКС',
      ComponentSubcategory.accessPoint => 'Wi-Fi / PoE',
      ComponentSubcategory.camera => 'Камеры',
      ComponentSubcategory.accessReader => 'Считыватели',
      ComponentSubcategory.detector => 'Извещатели',
      ComponentSubcategory.contactSensor => 'Датчики',
      ComponentSubcategory.fiberTermination => 'Оптика',
      ComponentSubcategory.controller => 'Контроллеры',
      ComponentSubcategory.custom => 'Прочее',
    };

IconData _icon(EngineeringSystemClass c) => switch (c) {
      EngineeringSystemClass.powerAc || EngineeringSystemClass.powerDc =>
        Icons.power_outlined,
      EngineeringSystemClass.lighting => Icons.lightbulb_outline,
      EngineeringSystemClass.structuredCabling ||
      EngineeringSystemClass.poeNetwork ||
      EngineeringSystemClass.fiberOptic => Icons.lan_outlined,
      EngineeringSystemClass.cctv => Icons.videocam_outlined,
      EngineeringSystemClass.accessControl => Icons.badge_outlined,
      EngineeringSystemClass.fireAlarm => Icons.local_fire_department_outlined,
      EngineeringSystemClass.automationBus || EngineeringSystemClass.dryContact =>
        Icons.memory_outlined,
      EngineeringSystemClass.custom => Icons.widgets_outlined,
    };
