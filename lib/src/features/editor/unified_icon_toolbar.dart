import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import '../../engine/editor_layers.dart';
import '../../engine/route_engine.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'editor_viewport_commands.dart';

class UnifiedEditorIconToolbar extends StatelessWidget {
  const UnifiedEditorIconToolbar({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final EditorController controller;
  final bool compact;

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
        icon: Icons.straighten,
        tooltip: 'Направляющая (G)',
      ),
      _toolButton(
        context,
        tool: EditorTool.cableRoute,
        icon: Icons.alt_route,
        tooltip: 'Ручная кабельная трасса (C)',
      ),
      const _ToolbarDivider(),
      _ElectricalPaletteButton(controller: controller),
      _toggleButton(
        context,
        selected: controller.snapEnabled,
        icon: controller.snapEnabled ? Icons.grid_4x4 : Icons.grid_off,
        tooltip: controller.snapEnabled
            ? 'Отключить привязку'
            : 'Включить привязку',
        onPressed: () => controller.setSnapEnabled(!controller.snapEnabled),
      ),
      _toggleButton(
        context,
        selected: controller.dimensionsVisible,
        icon: Icons.straighten,
        tooltip: controller.dimensionsVisible
            ? 'Скрыть размеры'
            : 'Показать размеры',
        onPressed: () => controller.setDimensionsVisible(
          !controller.dimensionsVisible,
        ),
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
        onPressed: () => controller.requestViewportCommand(
          EditorViewportCommand.reset,
        ),
      ),
      _iconButton(
        context,
        icon: Icons.zoom_out,
        tooltip: 'Уменьшить (-)',
        onPressed: () => controller.requestViewportCommand(
          EditorViewportCommand.zoomOut,
        ),
      ),
      _iconButton(
        context,
        icon: Icons.zoom_in,
        tooltip: 'Увеличить (+)',
        onPressed: () => controller.requestViewportCommand(
          EditorViewportCommand.zoomIn,
        ),
      ),
      const _ToolbarDivider(),
      _LayerMenuButton(controller: controller),
      _RoutePreferenceButton(controller: controller),
      _iconButton(
        context,
        icon: Icons.auto_fix_high,
        tooltip: p2.selection.ids.length == 2
            ? 'Автотрасса между двумя выбранными компонентами'
            : 'Для автотрассы выберите два компонента',
        onPressed: p2.selection.ids.length == 2
            ? () => p2.autoRouteSelectedPair()
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
      elevation: 1,
      child: SizedBox(
        height: compact ? 50 : 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          children: buttons,
        ),
      ),
    );
  }

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
          controller.p2.setPlacementType(null);
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
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton.filledTonal(
          onPressed: onPressed,
          isSelected: selected,
          tooltip: tooltip,
          icon: Icon(icon, size: 21),
          style: IconButton.styleFrom(
            minimumSize: const Size(42, 42),
            maximumSize: const Size(42, 42),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ),
      );

  Widget _iconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, size: 21),
          style: IconButton.styleFrom(
            minimumSize: const Size(42, 42),
            maximumSize: const Size(42, 42),
          ),
        ),
      );
}

class _ElectricalPaletteButton extends StatelessWidget {
  const _ElectricalPaletteButton({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.p2.placementType;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: PopupMenuButton<ElectricalComponentType>(
        tooltip: selected == null
            ? 'Добавить электрический компонент'
            : 'Размещение: ${ElectricalComponentDefaults.defaultLabel(selected)}',
        onSelected: (type) {
          if (controller.activeSurface == null) {
            final space = controller.selectedSpace;
            if (space != null) controller.showWall(0);
          }
          controller.setTool(EditorTool.select);
          controller.p2.setPlacementType(type);
        },
        itemBuilder: (context) => [
          for (final type in ElectricalComponentType.values)
            if (type != ElectricalComponentType.custom)
              PopupMenuItem(
                value: type,
                child: ListTile(
                  dense: true,
                  leading: Icon(_componentIcon(type)),
                  title: Text(ElectricalComponentDefaults.defaultLabel(type)),
                ),
              ),
        ],
        child: SizedBox(
          width: 42,
          height: 42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected == null
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              selected == null
                  ? Icons.electrical_services
                  : _componentIcon(selected),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerMenuButton extends StatelessWidget {
  const _LayerMenuButton({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return PopupMenuButton<EditorLayerId>(
      tooltip: 'Слои',
      onSelected: (id) => p2.setLayerVisible(id, !p2.layers.isVisible(id)),
      itemBuilder: (context) => [
        for (final layer in EditorLayerId.values)
          CheckedPopupMenuItem(
            value: layer,
            checked: p2.layers.isVisible(layer),
            child: Text(_layerName(layer)),
          ),
      ],
      child: const SizedBox(
        width: 42,
        height: 42,
        child: Icon(Icons.layers_outlined, size: 21),
      ),
    );
  }
}

class _RoutePreferenceButton extends StatelessWidget {
  const _RoutePreferenceButton({required this.controller});

  final EditorController controller;

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
      child: const SizedBox(
        width: 42,
        height: 42,
        child: Icon(Icons.route_outlined, size: 21),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
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

IconData _componentIcon(ElectricalComponentType type) => switch (type) {
      ElectricalComponentType.socketOutlet => Icons.power_outlined,
      ElectricalComponentType.switchControl => Icons.toggle_on_outlined,
      ElectricalComponentType.lightingPoint => Icons.lightbulb_outline,
      ElectricalComponentType.curtainMotor => Icons.curtains_outlined,
      ElectricalComponentType.junctionBox => Icons.hub_outlined,
      ElectricalComponentType.powerSource => Icons.bolt_outlined,
      ElectricalComponentType.distributionBoard => Icons.electrical_services,
      ElectricalComponentType.custom => Icons.add_box_outlined,
    };
