import 'package:flutter/material.dart';

import '../../domain/component_catalog_v2.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import '../../engine/route_engine.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'editor_ui_tokens.dart';
import 'editor_viewport_commands.dart';
import 'engineering_placement_cursor_session.dart';

class UnifiedEditorIconToolbar extends StatelessWidget {
  const UnifiedEditorIconToolbar({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final EditorController controller;
  final bool compact;

  double get _target => compact
      ? EditorUiTokens.compactCommandTarget
      : EditorUiTokens.commandTarget;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.p2,
      builder: (context, _) => _buildToolbar(context),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final p2 = controller.p2;
    final buttons = <Widget>[
      _toolButton(
        context,
        tool: EditorTool.select,
        icon: Icons.near_me_outlined,
        tooltip: 'Выбор (V)',
      ),
      if (controller.viewMode == EditorViewMode.plan)
        _toolButton(
          context,
          tool: EditorTool.roomRectangle,
          icon: Icons.crop_square,
          tooltip: 'Комната (R)',
        ),
      _toolButton(
        context,
        tool: EditorTool.guide,
        icon: Icons.horizontal_rule,
        tooltip: 'Направляющая (G)',
      ),
      _toolButton(
        context,
        tool: EditorTool.cableRoute,
        icon: Icons.alt_route,
        tooltip: 'Ручная кабельная трасса (C)',
      ),
      const _ToolbarDivider(),
      _ComponentCatalogPaletteButton(controller: controller, target: _target),
      _toggleButton(
        context,
        selected: controller.snapEnabled,
        icon: controller.snapEnabled ? Icons.grid_4x4 : Icons.grid_off,
        tooltip:
            controller.snapEnabled ? 'Отключить привязку' : 'Включить привязку',
        onPressed: () => controller.setSnapEnabled(!controller.snapEnabled),
      ),
      _toggleButton(
        context,
        selected: controller.dimensionsVisible,
        icon: Icons.straighten,
        tooltip: controller.dimensionsVisible
            ? 'Скрыть размеры'
            : 'Показать размеры',
        onPressed: () =>
            controller.setDimensionsVisible(!controller.dimensionsVisible),
      ),
      const _ToolbarDivider(),
      _iconButton(
        context,
        icon: Icons.undo,
        tooltip: 'Отменить',
        onPressed: p2.canUndo ? p2.undo : null,
      ),
      _iconButton(
        context,
        icon: Icons.redo,
        tooltip: 'Повторить',
        onPressed: p2.canRedo ? p2.redo : null,
      ),
      const _ToolbarDivider(),
      _iconButton(
        context,
        icon: Icons.fit_screen,
        tooltip: 'Вписать текущий вид (0)',
        onPressed: () =>
            controller.requestViewportCommand(EditorViewportCommand.reset),
      ),
      _iconButton(
        context,
        icon: Icons.zoom_out,
        tooltip: 'Уменьшить (-)',
        onPressed: () =>
            controller.requestViewportCommand(EditorViewportCommand.zoomOut),
      ),
      _iconButton(
        context,
        icon: Icons.zoom_in,
        tooltip: 'Увеличить (+)',
        onPressed: () =>
            controller.requestViewportCommand(EditorViewportCommand.zoomIn),
      ),
      const _ToolbarDivider(),
      _LayerMenuButton(controller: controller, target: _target),
      _RoutePreferenceButton(controller: controller, target: _target),
      _iconButton(
        context,
        icon: Icons.auto_fix_high,
        tooltip: p2.selection.ids.length == 2
            ? 'Автотрасса между двумя выбранными компонентами'
            : 'Для автотрассы выберите два компонента',
        onPressed: p2.selection.ids.length == 2
            ? () => p2.autoRouteSelectedPair(space: controller.selectedSpace)
            : null,
      ),
      if (controller.routeSegments.isNotEmpty)
        _iconButton(
          context,
          icon: Icons.clear_all,
          tooltip: 'Очистить черновик ручной трассы',
          onPressed: controller.clearRouteDraft,
        ),
    ];

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: EditorUiTokens.commandBarHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          children: buttons,
        ),
      ),
    );
  }

  ButtonStyle _commandStyle(BuildContext context, {bool selected = false}) =>
      IconButton.styleFrom(
        minimumSize: Size(_target, _target),
        maximumSize: Size(_target, _target),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
      );

  Widget _toolButton(
    BuildContext context, {
    required EditorTool tool,
    required IconData icon,
    required String tooltip,
  }) =>
      _toggleButton(
        context,
        selected: controller.tool == tool,
        icon: icon,
        tooltip: tooltip,
        onPressed: () {
          controller.placementCursor.cancel();
          controller.setTool(tool);
        },
      );

  Widget _toggleButton(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton.filledTonal(
          onPressed: onPressed,
          isSelected: selected,
          tooltip: tooltip,
          icon: Icon(icon, size: 20),
          style: _commandStyle(context, selected: selected),
        ),
      );

  Widget _iconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, size: 20),
          style: _commandStyle(context),
        ),
      );
}

class _ComponentCatalogPaletteButton extends StatelessWidget {
  const _ComponentCatalogPaletteButton({
    required this.controller,
    required this.target,
  });

  final EditorController controller;
  final double target;

  @override
  Widget build(BuildContext context) {
    final catalog = controller.componentCatalog;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final selectedId = controller.placementCursor.activeComponentTypeId;
        final selected = selectedId == null ? null : catalog.byId(selectedId);
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: PopupMenuButton<String>(
            enabled: catalog.loaded && catalog.entries.isNotEmpty,
            tooltip: catalog.loading
                ? 'Загрузка каталога…'
                : selected == null
                    ? 'Добавить инженерный компонент'
                    : 'Размещение: ${selected.name}',
            onSelected: (componentTypeId) {
              final entry = catalog.require(componentTypeId);
              _ensureCompatibleSurface(entry);
              controller.setTool(EditorTool.select);
              controller.placementCursor.beginCatalogPlacement(componentTypeId);
            },
            itemBuilder: (context) => [
              for (final entry in catalog.entries)
                PopupMenuItem(
                  value: entry.id,
                  child: ListTile(
                    dense: true,
                    leading: Icon(_catalogIcon(entry.systemClass)),
                    title: Text(entry.name),
                    subtitle: Text(
                      '${entry.discipline.name} · ${entry.systemClass.name}',
                    ),
                  ),
                ),
            ],
            child: SizedBox(
              width: target,
              height: target,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected == null
                      ? scheme.surfaceContainerHigh
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  selected == null
                      ? Icons.widgets_outlined
                      : _catalogIcon(selected.systemClass),
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
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

class _LayerMenuButton extends StatelessWidget {
  const _LayerMenuButton({required this.controller, required this.target});

  final EditorController controller;
  final double target;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Слои: видимость и блокировка',
      onPressed: () => _showLayers(context),
      icon: const Icon(Icons.layers_outlined, size: 20),
      style: IconButton.styleFrom(
        minimumSize: Size(target, target),
        maximumSize: Size(target, target),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    );
  }

  Future<void> _showLayers(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: controller.p2,
        builder: (context, _) => AlertDialog(
          title: const Text('Слои'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final layer in EditorLayerId.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconButton(
                      tooltip: controller.p2.layers.isVisible(layer)
                          ? 'Скрыть слой'
                          : 'Показать слой',
                      onPressed: () => controller.p2.setLayerVisible(
                        layer,
                        !controller.p2.layers.isVisible(layer),
                      ),
                      icon: Icon(
                        controller.p2.layers.isVisible(layer)
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    title: Text(_layerName(layer)),
                    trailing: IconButton(
                      tooltip: controller.p2.layers.isLocked(layer)
                          ? 'Разблокировать слой'
                          : 'Заблокировать слой',
                      onPressed: () => controller.p2.setLayerLocked(
                        layer,
                        !controller.p2.layers.isLocked(layer),
                      ),
                      icon: Icon(
                        controller.p2.layers.isLocked(layer)
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePreferenceButton extends StatelessWidget {
  const _RoutePreferenceButton({
    required this.controller,
    required this.target,
  });

  final EditorController controller;
  final double target;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RoutePreference>(
      tooltip: 'Режим автотрассировки',
      onSelected: controller.p2.setRoutePreference,
      itemBuilder: (context) => [
        for (final preference in RoutePreference.values)
          CheckedPopupMenuItem(
            value: preference,
            checked: controller.p2.routePreference == preference,
            child: Text(_routePreferenceName(preference)),
          ),
      ],
      child: SizedBox(
        width: target,
        height: target,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.route_outlined, size: 20),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: VerticalDivider(width: 1),
      );
}

String _layerName(EditorLayerId layer) => switch (layer) {
      EditorLayerId.architecture => 'Архитектура',
      EditorLayerId.openings => 'Проёмы',
      EditorLayerId.electrical => 'Электрика',
      EditorLayerId.cableRoutes => 'Кабельные трассы',
      EditorLayerId.dimensions => 'Размеры',
      EditorLayerId.guides => 'Направляющие',
    };

String _routePreferenceName(RoutePreference preference) => switch (preference) {
      RoutePreference.shortest => 'Кратчайший путь',
      RoutePreference.orthogonal => 'Ортогонально',
      RoutePreference.preferWall => 'Предпочитать стены',
      RoutePreference.preferCeiling => 'Предпочитать потолок',
      RoutePreference.preferFloor => 'Предпочитать пол',
    };

IconData _catalogIcon(EngineeringSystemClass systemClass) =>
    switch (systemClass) {
      EngineeringSystemClass.powerAc ||
      EngineeringSystemClass.powerDc =>
        Icons.electrical_services,
      EngineeringSystemClass.lighting => Icons.lightbulb_outline,
      EngineeringSystemClass.structuredCabling => Icons.lan_outlined,
      EngineeringSystemClass.poeNetwork => Icons.wifi_outlined,
      EngineeringSystemClass.fiberOptic => Icons.cable_outlined,
      EngineeringSystemClass.cctv => Icons.videocam_outlined,
      EngineeringSystemClass.accessControl => Icons.badge_outlined,
      EngineeringSystemClass.fireAlarm => Icons.local_fire_department_outlined,
      EngineeringSystemClass.automationBus => Icons.account_tree_outlined,
      EngineeringSystemClass.dryContact => Icons.sensors_outlined,
      EngineeringSystemClass.custom => Icons.add_box_outlined,
    };
