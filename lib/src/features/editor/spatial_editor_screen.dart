import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
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
        title: const Text('БЦ Alatau · Этаж 1'),
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
                final wide = constraints.maxWidth >= 980;
                final canvas = controller.viewMode == EditorViewMode.plan
                    ? SpatialCanvas(controller: controller)
                    : SurfaceCanvas(controller: controller);
                if (!wide) return canvas;
                return Row(
                  children: [
                    SizedBox(
                      width: 240,
                      child: _ProjectTree(controller: controller),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: canvas),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 300,
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
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                tooltip: 'Очистить текущую трассу',
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
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            _viewChip(
              context,
              label: 'План',
              icon: Icons.map_outlined,
              selected: controller.viewMode == EditorViewMode.plan,
              onTap: controller.showPlan,
            ),
            if (space != null) ...[
              const SizedBox(width: 6),
              _viewChip(
                context,
                label: 'Пол',
                icon: Icons.grid_on,
                selected:
                    controller.activeSurface?.type == SurfacePlaneType.floor,
                onTap: controller.showFloor,
              ),
              const SizedBox(width: 6),
              _viewChip(
                context,
                label: 'Потолок',
                icon: Icons.view_in_ar_outlined,
                selected:
                    controller.activeSurface?.type == SurfacePlaneType.ceiling,
                onTap: controller.showCeiling,
              ),
              const SizedBox(width: 12),
              for (var i = 0; i < space.boundary.vertices.length; i++) ...[
                _viewChip(
                  context,
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

  Widget _viewChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _ProjectTree extends StatelessWidget {
  const _ProjectTree({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('ОБЪЕКТ', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        const ListTile(
          dense: true,
          leading: Icon(Icons.location_on_outlined),
          title: Text('Площадка'),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: ListTile(
            dense: true,
            leading: Icon(Icons.apartment),
            title: Text('Building A'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.layers_outlined),
            title: Text(controller.level.name),
          ),
        ),
        const Divider(),
        Text('ПОМЕЩЕНИЯ', style: Theme.of(context).textTheme.labelLarge),
        for (final space in controller.level.spaces)
          ListTile(
            dense: true,
            selected: controller.selectedSpaceId == space.id,
            leading: Icon(
              space.type == SpaceType.corridor
                  ? Icons.linear_scale
                  : Icons.crop_square,
            ),
            title: Text(space.name),
            onTap: () => controller.selectSpace(space.id),
          ),
      ],
    );
  }
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
        Text(space.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _value('Тип', space.type.name),
        _value('Ширина', '${bounds.width} mm'),
        _value('Длина', '${bounds.height} mm'),
        _value('Центр X', '${space.referenceFrame.origin.x} mm'),
        _value('Центр Y', '${space.referenceFrame.origin.y} mm'),
        if (surface != null) ...[
          const Divider(height: 32),
          Text(
            'Активная плоскость',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _value('Тип', _surfaceName(surface)),
          if (controller.activeWall case final wall?) ...[
            _value('Длина стены', '${wall.lengthMm.round()} mm'),
            _value('Высота', '${wall.heightMm} mm'),
            _value('Проёмы', '${controller.activeWallOpenings.length}'),
            const SizedBox(height: 12),
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
          ],
        ],
        if (controller.routeSegments.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Трасса', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _value(
            'Длина',
            '${(controller.routeLengthMm / 1000).toStringAsFixed(3)} m',
          ),
          _value('Плоскостей', '${controller.routeSegments.length}'),
        ],
        const Divider(height: 32),
        const Text('Локальная сетка'),
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
            border: OutlineInputBorder(),
            labelText: 'Шаг',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Сетка, центровочные линии и размеры работают в координатах '
          'активной плоскости.',
        ),
      ],
    );
  }

  String _surfaceName(RoomSurfaceRef surface) => switch (surface.type) {
        SurfacePlaneType.floor => 'Пол',
        SurfacePlaneType.ceiling => 'Потолок',
        SurfacePlaneType.wall => 'Стена ${(surface.wallIndex ?? 0) + 1}',
      };

  Widget _value(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [Expanded(child: Text(label)), Text(value)],
        ),
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
