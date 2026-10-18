import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'adjacent_room_command.dart';
import 'editor_controller.dart';
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

  void _refresh() => setState(() {});

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ElecX Spatial Editor'),
            Text(
              'БЦ Alatau · Building A · Этаж 1',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
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
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _Toolbar(controller: controller),
          _SurfaceNavigator(controller: controller),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1080;
                final canvas = controller.viewMode == EditorViewMode.plan
                    ? SpatialCanvas(controller: controller)
                    : SurfaceCanvas(controller: controller);
                if (!wide) return canvas;
                return Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _ProjectTree(controller: controller),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: canvas),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 350,
                      child: _PropertiesPanel(controller: controller),
                    ),
                  ],
                );
              },
            ),
          ),
          _StatusBar(controller: controller),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    Widget tool(EditorTool value, IconData icon, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilledButton.tonalIcon(
            onPressed: () => controller.setTool(value),
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                controller.tool == value
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
              ),
            ),
          ),
        );

    return Material(
      elevation: 1,
      child: SizedBox(
        height: 58,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          children: [
            tool(EditorTool.select, Icons.near_me_outlined, 'Выбор'),
            if (controller.viewMode == EditorViewMode.plan)
              tool(EditorTool.roomRectangle, Icons.crop_square, 'Комната'),
            tool(EditorTool.guide, Icons.straighten, 'Направляющая'),
            tool(EditorTool.cableRoute, Icons.alt_route, 'Трасса'),
            const SizedBox(width: 10),
            FilterChip(
              selected: controller.snapEnabled,
              onSelected: controller.setSnapEnabled,
              avatar: const Icon(Icons.grid_4x4, size: 18),
              label: const Text('Snap'),
            ),
            const SizedBox(width: 6),
            FilterChip(
              selected: controller.dimensionsVisible,
              onSelected: controller.setDimensionsVisible,
              avatar: const Icon(Icons.straighten, size: 18),
              label: const Text('Размеры'),
            ),
            if (controller.routeSegments.isNotEmpty) ...[
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.route, size: 18),
                label: Text(
                  '${(controller.routeLengthMm / 1000).toStringAsFixed(2)} m',
                ),
                onPressed: controller.clearRouteDraft,
              ),
            ],
            const SizedBox(width: 12),
            IconButton(
              onPressed: controller.zoomOut,
              tooltip: 'Уменьшить',
              icon: const Icon(Icons.zoom_out),
            ),
            TextButton(
              onPressed: controller.resetZoom,
              child: Text('${(controller.zoom * 100).round()}%'),
            ),
            IconButton(
              onPressed: controller.zoomIn,
              tooltip: 'Увеличить',
              icon: const Icon(Icons.zoom_in),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceNavigator extends StatelessWidget {
  const _SurfaceNavigator({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _viewChip(
              label: 'План этажа',
              icon: Icons.map_outlined,
              selected: controller.viewMode == EditorViewMode.plan,
              onTap: controller.showPlan,
            ),
            if (space != null) ...[
              const SizedBox(width: 10),
              Chip(label: Text(space.name)),
              const SizedBox(width: 10),
              _viewChip(
                label: 'Пол',
                icon: Icons.grid_on,
                selected:
                    controller.activeSurface?.type == SurfacePlaneType.floor,
                onTap: controller.showFloor,
              ),
              const SizedBox(width: 6),
              _viewChip(
                label: 'Потолок',
                icon: Icons.view_in_ar_outlined,
                selected:
                    controller.activeSurface?.type == SurfacePlaneType.ceiling,
                onTap: controller.showCeiling,
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < space.boundary.vertices.length; i++) ...[
                _viewChip(
                  label: 'Стена ${i + 1}',
                  icon: Icons.crop_landscape,
                  selected: controller.activeSurface?.type ==
                          SurfacePlaneType.wall &&
                      controller.activeSurface?.wallIndex == i,
                  onTap: () => controller.showWall(i),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(icon, size: 16),
        label: Text(label),
      );
}

class _ProjectTree extends StatelessWidget {
  const _ProjectTree({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          Text('НАВИГАТОР ПРОЕКТА', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          const _TreeRow(depth: 0, icon: Icons.location_on_outlined, label: 'Площадка'),
          const _TreeRow(depth: 1, icon: Icons.apartment, label: 'Building A'),
          _TreeRow(
            depth: 2,
            icon: Icons.layers_outlined,
            label: controller.level.name,
            trailing: '${controller.level.spaces.length}',
          ),
          const Divider(height: 24),
          Text('ПОМЕЩЕНИЯ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final space in controller.level.spaces)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 6),
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
                onTap: () => controller.selectSpace(space.id),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => controller.setTool(EditorTool.roomRectangle),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Нарисовать комнату'),
          ),
          const SizedBox(height: 8),
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
            title: const Text('Добавить примыкающую комнату'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Базовое помещение: ${controller.selectedSpace?.name}'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: wallIndex,
                    decoration: const InputDecoration(
                      labelText: 'Сторона примыкания',
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
                  const SizedBox(height: 12),
                  _DialogIntField(
                    key: ValueKey('offset-$wallIndex'),
                    label: 'Отступ от начала стены, mm',
                    initialValue: offsetMm,
                    onChanged: (value) => offsetMm = value,
                  ),
                  const SizedBox(height: 12),
                  _DialogIntField(
                    key: ValueKey('length-$wallIndex'),
                    label: 'Длина общей границы, mm',
                    initialValue: sharedLengthMm,
                    onChanged: (value) => sharedLengthMm = value,
                  ),
                  const SizedBox(height: 12),
                  _DialogIntField(
                    label: 'Глубина новой комнаты, mm',
                    initialValue: depthMm,
                    onChanged: (value) => depthMm = value,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Доступная длина стены: ${wall.lengthMm.round()} mm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
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
                      error = 'Проверьте отступ, длину общей границы и глубину.';
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
}

class _DialogIntField extends StatelessWidget {
  const _DialogIntField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: '$initialValue',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (text) {
          final value = int.tryParse(text);
          if (value != null) onChanged(value);
        },
      );
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final int depth;
  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(icon, size: 20),
          title: Text(label),
          trailing: trailing == null ? null : Text(trailing!),
        ),
      );
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    if (space == null) return const Center(child: Text('Выберите помещение'));
    final surface = controller.activeSurface;
    final bounds = space.boundary.bounds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('СВОЙСТВА', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Text(space.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _value('Тип', space.type.name),
        _value('Габарит X', '${bounds.width} mm'),
        _value('Габарит Y', '${bounds.height} mm'),
        _value('Центр X', '${space.referenceFrame.origin.x} mm'),
        _value('Центр Y', '${space.referenceFrame.origin.y} mm'),
        if (surface != null) ...[
          const Divider(height: 28),
          Text('ПЛОСКОСТЬ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _value('Тип', _surfaceName(surface)),
          if (controller.activeWall case final wall?) ...[
            _value('Длина стены', '${wall.lengthMm.round()} mm'),
            _value('Высота', '${wall.heightMm} mm'),
            const SizedBox(height: 10),
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
            const Divider(height: 28),
            Text('ДВЕРИ И ОКНА', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.addOpening(ArchitecturalOpeningType.door),
                    icon: const Icon(Icons.door_front_door_outlined),
                    label: const Text('Дверь'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.addOpening(ArchitecturalOpeningType.window),
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
                    'x ${opening.offsetFromStartMm} · ${opening.widthMm}×${opening.heightMm} mm',
                  ),
                  onTap: () => controller.selectOpening(opening.id),
                ),
              ),
            if (controller.selectedOpening case final opening?) ...[
              const SizedBox(height: 10),
              _OpeningEditor(controller: controller, opening: opening),
            ],
          ],
        ],
        if (controller.routeSegments.isNotEmpty) ...[
          const Divider(height: 28),
          Text('ТРАССА', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _value(
            'Длина',
            '${(controller.routeLengthMm / 1000).toStringAsFixed(3)} m',
          ),
          _value('Плоскостей', '${controller.routeSegments.length}'),
        ],
        const Divider(height: 28),
        Text('СЕТКА', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: space.grid.minorStepMm,
          items: const [50, 100, 250, 500]
              .map(
                (value) => DropdownMenuItem(value: value, child: Text('$value mm')),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) controller.updateSelectedGrid(value);
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Шаг',
          ),
        ),
      ],
    );
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

  Widget _value(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label)), Text(value)]),
      );
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
          const SizedBox(height: 10),
          DropdownButtonFormField<ArchitecturalOpeningType>(
            initialValue: opening.type,
            decoration: const InputDecoration(
              labelText: 'Тип',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: ArchitecturalOpeningType.door,
                child: Text('Дверь'),
              ),
              DropdownMenuItem(
                value: ArchitecturalOpeningType.window,
                child: Text('Окно'),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.updateSelectedOpening(type: value);
            },
          ),
          const SizedBox(height: 8),
          _OpeningIntField(
            key: ValueKey('${opening.id}-offset-${opening.offsetFromStartMm}'),
            label: 'Позиция от начала стены, mm',
            value: opening.offsetFromStartMm,
            onSubmit: (value) =>
                controller.updateSelectedOpening(offsetFromStartMm: value),
          ),
          const SizedBox(height: 8),
          _OpeningIntField(
            key: ValueKey('${opening.id}-width-${opening.widthMm}'),
            label: 'Ширина, mm',
            value: opening.widthMm,
            onSubmit: (value) => controller.updateSelectedOpening(widthMm: value),
          ),
          const SizedBox(height: 8),
          _OpeningIntField(
            key: ValueKey('${opening.id}-height-${opening.heightMm}'),
            label: 'Высота, mm',
            value: opening.heightMm,
            onSubmit: (value) => controller.updateSelectedOpening(heightMm: value),
          ),
          const SizedBox(height: 8),
          _OpeningIntField(
            key: ValueKey('${opening.id}-sill-${opening.sillHeightMm}'),
            label: 'Высота от пола / подоконник, mm',
            value: opening.sillHeightMm,
            onSubmit: (value) =>
                controller.updateSelectedOpening(sillHeightMm: value),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter применяет значение. Проём не может выходить за границы стены.',
            style: Theme.of(context).textTheme.bodySmall,
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

class _OpeningIntField extends StatelessWidget {
  const _OpeningIntField({
    required this.label,
    required this.value,
    required this.onSubmit,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onSubmit;

  @override
  Widget build(BuildContext context) => TextFormField(
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

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final grid = controller.selectedSpace?.grid.minorStepMm ?? 100;
    final surface = controller.activeSurface;
    final view = surface == null
        ? 'Plan'
        : switch (surface.type) {
            SurfacePlaneType.floor => 'Floor',
            SurfacePlaneType.ceiling => 'Ceiling',
            SurfacePlaneType.wall => 'Wall ${(surface.wallIndex ?? 0) + 1}',
          };
    final route = controller.routeSegments.isEmpty
        ? ''
        : ' · Route ${(controller.routeLengthMm / 1000).toStringAsFixed(3)} m';
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        'Metric · $view · Floor grid ${controller.floorGridMm} mm · '
        'Room grid $grid mm · Snap ${controller.snapEnabled ? 'ON' : 'OFF'} · '
        'Zoom ${(controller.zoom * 100).round()}%$route',
      ),
    );
  }
}
