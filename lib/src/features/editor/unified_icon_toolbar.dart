import 'package:flutter/material.dart';

import 'editor_controller.dart';
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
        tooltip: 'Кабельная трасса (C)',
      ),
      const _ToolbarDivider(),
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
      if (controller.routeSegments.isNotEmpty) ...[
        const _ToolbarDivider(),
        _iconButton(
          context,
          icon: Icons.clear_all,
          tooltip: 'Очистить черновик трассы',
          onPressed: controller.clearRouteDraft,
        ),
      ],
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
        onPressed: () => controller.setTool(tool),
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
    required VoidCallback onPressed,
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

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: VerticalDivider(width: 1),
      );
}
