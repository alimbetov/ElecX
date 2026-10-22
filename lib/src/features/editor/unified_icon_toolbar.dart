import 'package:flutter/material.dart';

import '../../domain/component_catalog_v2.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import '../../engine/route_engine.dart';
import 'canonical_boundary_topology_migration_runtime.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
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
    final history = controller.documentHistory;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[controller.p2, history]),
      builder: (context, _) => _buildToolbar(context, history),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    EditorDocumentHistory history,
  ) {
    final p2 = controller.p2;
    final activeWallOrdinal =
        controller.activeSurface?.type == SurfacePlaneType.wall
            ? controller.activeSurface?.wallIndex
            : null;
    final stableEdgeId = activeWallOrdinal == null
        ? null
        : CanonicalBoundaryTopologyMigrationRuntime.edgeIdAtLegacyWallOrdinal(
            controller,
            activeWallOrdinal,
          );
    final identityChangeReady = activeWallOrdinal != null &&
        stableEdgeId != null &&
        CanonicalBoundaryTopologyMigrationRuntime.canChangeLegacyWallIdentity(
          controller,
          activeWallOrdinal,
        );

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
      if (stableEdgeId != null) ...[
        const _ToolbarDivider(),
        if (!identityChangeReady)
          _iconButton(
            context,
            buttonKey: const ValueKey('boundary-adopt-hosts'),
            icon: Icons.link,
            tooltip: 'Подготовить стабильные привязки стены (Alt+A)',
            onPressed: () => _invokeBoundaryAction(
              context,
              () => CanonicalBoundaryTopologyMigrationRuntime.adoptLegacyHosts(
                controller: controller,
              ),
              failureMessage:
                  'Не удалось подготовить стабильные привязки стены.',
            ),
          )
        else ...[
          _iconButton(
            context,
            buttonKey: const ValueKey('boundary-split-edge'),
            icon: Icons.call_split,
            tooltip: 'Разделить стену пополам (Alt+S)',
            onPressed: () => _invokeBoundaryAction(
              context,
              () => CanonicalBoundaryTopologyMigrationRuntime
                  .splitLegacyWallAtMidpoint(
                controller: controller,
                wallOrdinal: activeWallOrdinal,
              ),
              failureMessage: 'Разделение стены отклонено проверками проекта.',
            ),
          ),
          _iconButton(
            context,
            buttonKey: const ValueKey('boundary-merge-edge'),
            icon: Icons.merge_type,
            tooltip: 'Объединить со следующей стеной (Alt+M)',
            onPressed: () => _invokeBoundaryAction(
              context,
              () => CanonicalBoundaryTopologyMigrationRuntime
                  .mergeLegacyWallWithNext(
                controller: controller,
                wallOrdinal: activeWallOrdinal,
              ),
              failureMessage: 'Объединение стены отклонено проверками проекта.',
            ),
          ),
        ],
      ],
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
        tooltip: history.undoLabel == null
            ? 'Отменить'
            : 'Отменить: ${history.undoLabel}',
        onPressed: history.canUndo ? history.undo : null,
      ),
      _iconButton(
        context,
        icon: Icons.redo,
        tooltip: history.redoLabel == null
            ? 'Повторить'
            : 'Повторить: ${history.redoLabel}',
        onPressed: history.canRedo ? history.redo : null,
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

  void _invokeBoundaryAction(
    BuildContext context,
    bool Function() action, {
    required String failureMessage,
  }) {
    String? message;
    try {
      if (action()) return;
      message = failureMessage;
    } on CanonicalBoundaryPostCommitException {
      message = 'Изменение уже применено к модели проекта, но его '
          'сохранение или синхронизация представления завершились ошибкой. '
          'История отмены очищена; проверьте текущее состояние проекта.';
    } catch (_) {
      message = failureMessage;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
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
    Key? buttonKey,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          key: buttonKey,
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
        final selected = catalog.selectedDefinition;
        return PopupMenuButton<String>(
          key: const ValueKey('component-catalog-palette'),
          tooltip: selected == null
              ? 'Каталог компонентов'
              : 'Компонент: ${selected.localizedName('ru')}',
          onSelected: (definitionId) {
            catalog.selectDefinition(definitionId);
            controller.placementCursor.armSelectedDefinition();
          },
          itemBuilder: (context) => [
            for (final definition in catalog.definitions)
              PopupMenuItem<String>(
                value: definition.id,
                child: Text(definition.localizedName('ru')),
              ),
          ],
          child: SizedBox(
            width: target,
            height: target,
            child: Icon(
              selected == null
                  ? Icons.electrical_services_outlined
                  : Icons.electrical_services,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor,
        ),
      );
}

class _LayerMenuButton extends StatelessWidget {
  const _LayerMenuButton({required this.controller, required this.target});

  final EditorController controller;
  final double target;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return PopupMenuButton<String>(
      tooltip: 'Слои',
      itemBuilder: (context) => [
        for (final layer in p2.layers)
          PopupMenuItem<String>(
            value: layer.id,
            onTap: () => p2.toggleLayerVisibility(layer.id),
            child: Row(
              children: [
                Icon(layer.visible ? Icons.visibility : Icons.visibility_off),
                const SizedBox(width: 8),
                Text(layer.name),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: target,
        height: target,
        child: const Icon(Icons.layers_outlined, size: 20),
      ),
    );
  }
}

class _RoutePreferenceButton extends StatelessWidget {
  const _RoutePreferenceButton({required this.controller, required this.target});

  final EditorController controller;
  final double target;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return PopupMenuButton<RoutePreference>(
      tooltip: 'Предпочтение автотрассы',
      initialValue: p2.routePreference,
      onSelected: p2.setRoutePreference,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: RoutePreference.shortest,
          child: Text('Кратчайшая'),
        ),
        PopupMenuItem(
          value: RoutePreference.horizontalFirst,
          child: Text('Сначала горизонталь'),
        ),
        PopupMenuItem(
          value: RoutePreference.verticalFirst,
          child: Text('Сначала вертикаль'),
        ),
      ],
      child: SizedBox(
        width: target,
        height: target,
        child: const Icon(Icons.route_outlined, size: 20),
      ),
    );
  }
}
