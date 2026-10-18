import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'adjacent_room_command.dart';
import 'editor_controller.dart';
import 'editor_keyboard_scope.dart';
import 'editor_layout_policy.dart';
import 'spatial_canvas.dart';
import 'surface_canvas.dart';

class SpatialEditorScreen extends StatefulWidget {
  const SpatialEditorScreen({super.key});

  @override
  State<SpatialEditorScreen> createState() => _SpatialEditorScreenState();
}

class _SpatialEditorScreenState extends State<SpatialEditorScreen> {
  late final EditorController controller;

  @override
  void initState() {
    super.initState();
    controller = EditorController.demo()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditorKeyboardScope(
      controller: controller,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mode = EditorLayoutPolicy.forWidth(constraints.maxWidth);
          final isDesktop = mode == EditorLayoutMode.desktop;
          final canvas = controller.viewMode == EditorViewMode.plan
              ? SpatialCanvas(controller: controller)
              : SurfaceCanvas(controller: controller);

          return Scaffold(
            drawer: isDesktop
                ? null
                : Drawer(
                    width: EditorLayoutPolicy.navigatorWidth(mode),
                    child: SafeArea(
                      child: _ProjectNavigator(controller: controller),
                    ),
                  ),
            endDrawer: isDesktop
                ? null
                : Drawer(
                    width: EditorLayoutPolicy.inspectorWidth(mode),
                    child: SafeArea(
                      child: _Inspector(controller: controller),
                    ),
                  ),
            appBar: _EditorAppBar(controller: controller, mode: mode),
            body: Column(
              children: [
                if (mode != EditorLayoutMode.mobile)
                  _ToolStrip(controller: controller, compact: !isDesktop),
                _SurfaceStrip(controller: controller, compact: mode != EditorLayoutMode.desktop),
                Expanded(
                  child: isDesktop
                      ? Row(
                          children: [
                            SizedBox(
                              width: EditorLayoutPolicy.navigatorWidth(mode),
                              child: _ProjectNavigator(controller: controller),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: canvas),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: EditorLayoutPolicy.inspectorWidth(mode),
                              child: _Inspector(controller: controller),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            Positioned.fill(child: canvas),
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: _CanvasContextBadge(controller: controller),
                            ),
                          ],
                        ),
                ),
                if (mode != EditorLayoutMode.mobile)
                  _StatusBar(controller: controller),
              ],
            ),
            bottomNavigationBar: mode == EditorLayoutMode.mobile
                ? _MobileToolBar(controller: controller)
                : null,
          );
        },
      ),
    );
  }
}

class _EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditorAppBar({required this.controller, required this.mode});

  final EditorController controller;
  final EditorLayoutMode mode;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedSpace;
    final compact = mode != EditorLayoutMode.desktop;
    return AppBar(
      titleSpacing: compact ? 6 : 18,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            compact ? 'ElecX' : 'ElecX Spatial Editor',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            selected == null
                ? 'Building A · ${controller.level.name}'
                : '${controller.level.name} · ${selected.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        if (mode == EditorLayoutMode.desktop) ...[
          IconButton(
            onPressed: () {},
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
          ),
        ] else ...[
          Builder(
            builder: (context) => IconButton(
              onPressed: Scaffold.of(context).openEndDrawer,
              tooltip: 'Свойства',
              icon: const Icon(Icons.tune),
            ),
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.controller, required this.compact});

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: SizedBox(
        height: compact ? 54 : 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          children: [
            _ToolAction(
              controller: controller,
              tool: EditorTool.select,
              icon: Icons.near_me_outlined,
              label: 'Выбор',
              compact: compact,
            ),
            if (controller.viewMode == EditorViewMode.plan)
              _ToolAction(
                controller: controller,
                tool: EditorTool.roomRectangle,
                icon: Icons.crop_square,
                label: 'Комната',
                compact: compact,
              ),
            _ToolAction(
              controller: controller,
              tool: EditorTool.guide,
              icon: Icons.straighten,
              label: 'Линия',
              compact: compact,
            ),
            _ToolAction(
              controller: controller,
              tool: EditorTool.cableRoute,
              icon: Icons.alt_route,
              label: 'Трасса',
              compact: compact,
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: controller.snapEnabled,
              onSelected: controller.setSnapEnabled,
              avatar: const Icon(Icons.grid_4x4, size: 17),
              label: Text(compact ? 'Snap' : 'Привязка'),
            ),
            const SizedBox(width: 6),
            FilterChip(
              selected: controller.dimensionsVisible,
              onSelected: controller.setDimensionsVisible,
              avatar: const Icon(Icons.straighten, size: 17),
              label: Text(compact ? 'Размер' : 'Размеры'),
            ),
            if (controller.routeSegments.isNotEmpty) ...[
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.route, size: 17),
                label: Text(
                  '${(controller.routeLengthMm / 1000).toStringAsFixed(2)} m',
                ),
                onPressed: controller.clearRouteDraft,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolAction extends StatelessWidget {
  const _ToolAction({
    required this.controller,
    required this.tool,
    required this.icon,
    required this.label,
    required this.compact,
  });

  final EditorController controller;
  final EditorTool tool;
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = controller.tool == tool;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton.filledTonal(
          onPressed: () => controller.setTool(tool),
          isSelected: selected,
          tooltip: label,
          icon: Icon(icon),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilledButton.tonalIcon(
        onPressed: () => controller.setTool(tool),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            selected ? Theme.of(context).colorScheme.secondaryContainer : null,
          ),
        ),
      ),
    );
  }
}

class _MobileToolBar extends StatelessWidget {
  const _MobileToolBar({required this.controller});

  final EditorController controller;

  int get selectedIndex => switch (controller.tool) {
        EditorTool.select => 0,
        EditorTool.roomRectangle => 1,
        EditorTool.guide => 2,
        EditorTool.cableRoute => 3,
      };

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 68,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            controller.setTool(EditorTool.select);
          case 1:
            if (controller.viewMode != EditorViewMode.plan) controller.showPlan();
            controller.setTool(EditorTool.roomRectangle);
          case 2:
            controller.setTool(EditorTool.guide);
          case 3:
            controller.setTool(EditorTool.cableRoute);
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.near_me_outlined), label: 'Выбор'),
        NavigationDestination(icon: Icon(Icons.crop_square), label: 'Комната'),
        NavigationDestination(icon: Icon(Icons.straighten), label: 'Линия'),
        NavigationDestination(icon: Icon(Icons.alt_route), label: 'Трасса'),
      ],
    );
  }
}

class _SurfaceStrip extends StatelessWidget {
  const _SurfaceStrip({required this.controller, required this.compact});

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: compact ? 46 : 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 6 : 8,
          ),
          children: [
            _surfaceChip(
              'План',
              Icons.map_outlined,
              controller.viewMode == EditorViewMode.plan,
              controller.showPlan,
            ),
            if (space != null) ...[
              const SizedBox(width: 6),
              _surfaceChip(
                'Пол',
                Icons.grid_on,
                controller.activeSurface?.type == SurfacePlaneType.floor,
                controller.showFloor,
              ),
              const SizedBox(width: 6),
              _surfaceChip(
                'Потолок',
                Icons.view_in_ar_outlined,
                controller.activeSurface?.type == SurfacePlaneType.ceiling,
                controller.showCeiling,
              ),
              for (var i = 0; i < space.boundary.vertices.length; i++) ...[
                const SizedBox(width: 6),
                _surfaceChip(
                  compact ? 'W${i + 1}' : 'Стена ${i + 1}',
                  Icons.crop_landscape,
                  controller.activeSurface?.type == SurfacePlaneType.wall &&
                      controller.activeSurface?.wallIndex == i,
                  () => controller.showWall(i),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _surfaceChip(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ProjectNavigator extends StatelessWidget {
  const _ProjectNavigator({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text('ПРОЕКТ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          const ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 6),
            leading: Icon(Icons.location_on_outlined),
            title: Text('Площадка'),
          ),
          const ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: 22, right: 6),
            leading: Icon(Icons.apartment),
            title: Text('Building A'),
          ),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 38, right: 6),
            leading: const Icon(Icons.layers_outlined),
            title: Text(controller.level.name),
            trailing: Text('${controller.level.spaces.length}'),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ПОМЕЩЕНИЯ',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                onPressed: () => controller.setTool(EditorTool.roomRectangle),
                tooltip: 'Новая комната',
                icon: const Icon(Icons.add_box_outlined),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final space in controller.level.spaces)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 5),
              color: controller.selectedSpaceId == space.id
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                dense: true,
                selected: controller.selectedSpaceId == space.id,
                leading: Icon(
                  space.type == SpaceType.corridor
                      ? Icons.linear_scale
                      : Icons.crop_square,
                ),
                title: Text(space.name),
                subtitle: Text(
                  '${space.boundary.bounds.width} × ${space.boundary.bounds.height} mm',
                ),
                onTap: () {
                  controller.selectSpace(space.id);
                  if (Navigator.canPop(context)) Navigator.maybePop(context);
                },
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: controller.selectedSpace == null
                ? null
                : () => _showAdjacentRoomDialog(context, controller),
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('Примыкающая комната'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAdjacentRoomDialog(
  BuildContext context,
  EditorController controller,
) async {
  final walls = controller.selectedWalls;
  if (walls.isEmpty) return;

  var wallIndex = 0;
  var offsetMm = 0;
  var sharedLengthMm = walls.first.lengthMm.round();
  var depthMm = 3000;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final wall = walls[wallIndex];
        return AlertDialog(
          title: const Text('Примыкающая комната'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: wallIndex,
                    decoration: const InputDecoration(
                      labelText: 'Стена',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < walls.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            'Стена ${i + 1} · ${walls[i].lengthMm.round()} mm',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        wallIndex = value;
                        offsetMm = 0;
                        sharedLengthMm = walls[value].lengthMm.round();
                        error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _IntField(
                    key: ValueKey('adjacent-offset-$wallIndex'),
                    label: 'Отступ от начала стены',
                    value: offsetMm,
                    onChanged: (value) => offsetMm = value,
                  ),
                  const SizedBox(height: 10),
                  _IntField(
                    key: ValueKey('adjacent-length-$wallIndex'),
                    label: 'Общая граница',
                    value: sharedLengthMm,
                    onChanged: (value) => sharedLengthMm = value,
                  ),
                  const SizedBox(height: 10),
                  _IntField(
                    label: 'Глубина комнаты',
                    value: depthMm,
                    onChanged: (value) => depthMm = value,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Стена: ${wall.lengthMm.round()} mm'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final ok = AdjacentRoomCommand.execute(
                  controller,
                  wallIndex: wallIndex,
                  depthMm: depthMm,
                  offsetFromWallStartMm: offsetMm,
                  sharedLengthMm: sharedLengthMm,
                );
                if (ok) {
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() {
                    error = 'Проверьте длину, отступ и глубину.';
                  });
                }
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    ),
  );
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    if (space == null) {
      return const Center(child: Text('Выберите помещение'));
    }
    final bounds = space.boundary.bounds;
    final surface = controller.activeSurface;
    final wall = controller.activeWall;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('СВОЙСТВА', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(space.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _ValueRow('Тип', space.type.name),
          _ValueRow('Ширина', '${bounds.width} mm'),
          _ValueRow('Глубина', '${bounds.height} mm'),
          if (surface != null) ...[
            const Divider(height: 24),
            _ValueRow('Плоскость', _surfaceName(surface)),
          ],
          if (wall != null) ...[
            _ValueRow('Длина стены', '${wall.lengthMm.round()} mm'),
            _ValueRow('Высота', '${wall.heightMm} mm'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.previousWall,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Пред.'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.nextWall,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('След.'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('ДВЕРИ И ОКНА', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.addOpening(
                      ArchitecturalOpeningType.door,
                    ),
                    icon: const Icon(Icons.door_front_door_outlined),
                    label: const Text('Дверь'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.addOpening(
                      ArchitecturalOpeningType.window,
                    ),
                    icon: const Icon(Icons.window_outlined),
                    label: const Text('Окно'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final opening in controller.activeWallOpenings)
              Card(
                elevation: 0,
                color: controller.selectedOpeningId == opening.id
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    opening.type == ArchitecturalOpeningType.window
                        ? Icons.window_outlined
                        : Icons.door_front_door_outlined,
                  ),
                  title: Text(_openingName(opening)),
                  subtitle: Text(
                    '${opening.offsetFromStartMm} · '
                    '${opening.widthMm}×${opening.heightMm} mm',
                  ),
                  onTap: () => controller.selectOpening(opening.id),
                ),
              ),
            if (controller.selectedOpening case final opening?) ...[
              const SizedBox(height: 8),
              _OpeningEditor(controller: controller, opening: opening),
            ],
          ],
          if (controller.routeSegments.isNotEmpty) ...[
            const Divider(height: 24),
            Text('ТРАССА', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _ValueRow(
              'Длина',
              '${(controller.routeLengthMm / 1000).toStringAsFixed(3)} m',
            ),
            _ValueRow('Плоскостей', '${controller.routeSegments.length}'),
          ],
          const Divider(height: 24),
          Text('СЕТКА', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: space.grid.minorStepMm,
            items: const [50, 100, 250, 500]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('$value mm'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) controller.updateSelectedGrid(value);
            },
            decoration: const InputDecoration(
              labelText: 'Шаг сетки',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningEditor extends StatelessWidget {
  const _OpeningEditor({required this.controller, required this.opening});

  final EditorController controller;
  final ArchitecturalOpening opening;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Редактирование', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _SubmitIntField(
            key: ValueKey('${opening.id}-offset-${opening.offsetFromStartMm}'),
            label: 'Позиция от начала стены',
            value: opening.offsetFromStartMm,
            onSubmit: (value) => controller.updateSelectedOpening(
              offsetFromStartMm: value,
            ),
          ),
          const SizedBox(height: 8),
          _SubmitIntField(
            key: ValueKey('${opening.id}-width-${opening.widthMm}'),
            label: 'Ширина',
            value: opening.widthMm,
            onSubmit: (value) => controller.updateSelectedOpening(widthMm: value),
          ),
          const SizedBox(height: 8),
          _SubmitIntField(
            key: ValueKey('${opening.id}-height-${opening.heightMm}'),
            label: 'Высота',
            value: opening.heightMm,
            onSubmit: (value) => controller.updateSelectedOpening(heightMm: value),
          ),
          const SizedBox(height: 8),
          _SubmitIntField(
            key: ValueKey('${opening.id}-sill-${opening.sillHeightMm}'),
            label: 'Подоконник / от пола',
            value: opening.sillHeightMm,
            onSubmit: (value) => controller.updateSelectedOpening(
              sillHeightMm: value,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: controller.deleteSelectedOpening,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить проём'),
          ),
        ],
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mm',
        border: const OutlineInputBorder(),
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

class _SubmitIntField extends StatelessWidget {
  const _SubmitIntField({
    required this.label,
    required this.value,
    required this.onSubmit,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mm',
        border: const OutlineInputBorder(),
      ),
      onFieldSubmitted: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) onSubmit(parsed);
      },
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(value, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _CanvasContextBadge extends StatelessWidget {
  const _CanvasContextBadge({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedSpace;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_toolIcon(controller.tool), size: 16),
            const SizedBox(width: 6),
            Text(
              selected == null
                  ? _toolName(controller.tool)
                  : '${selected.name} · ${_toolName(controller.tool)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final grid = controller.selectedSpace?.grid.minorStepMm ?? 100;
    final surface = controller.activeSurface;
    final view = surface == null ? 'Plan' : _surfaceName(surface);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        'Metric · $view · grid $grid mm · '
        'Snap ${controller.snapEnabled ? 'ON' : 'OFF'} · '
        '${_toolName(controller.tool)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String _surfaceName(RoomSurfaceRef surface) => switch (surface.type) {
      SurfacePlaneType.floor => 'Пол',
      SurfacePlaneType.ceiling => 'Потолок',
      SurfacePlaneType.wall => 'Стена ${(surface.wallIndex ?? 0) + 1}',
    };

String _openingName(ArchitecturalOpening opening) => switch (opening.type) {
      ArchitecturalOpeningType.door => 'Дверь',
      ArchitecturalOpeningType.window => 'Окно',
      ArchitecturalOpeningType.passage => 'Проход',
      ArchitecturalOpeningType.technicalOpening => 'Тех. проём',
    };

String _toolName(EditorTool tool) => switch (tool) {
      EditorTool.select => 'Выбор',
      EditorTool.roomRectangle => 'Комната',
      EditorTool.guide => 'Направляющая',
      EditorTool.cableRoute => 'Трасса',
    };

IconData _toolIcon(EditorTool tool) => switch (tool) {
      EditorTool.select => Icons.near_me_outlined,
      EditorTool.roomRectangle => Icons.crop_square,
      EditorTool.guide => Icons.straighten,
      EditorTool.cableRoute => Icons.alt_route,
    };
