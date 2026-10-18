import 'package:flutter/material.dart';

import '../../domain/project_model.dart';
import 'editor_controller.dart';
import 'spatial_canvas.dart';

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
          IconButton(onPressed: () {}, tooltip: 'Undo', icon: const Icon(Icons.undo)),
          IconButton(onPressed: () {}, tooltip: 'Redo', icon: const Icon(Icons.redo)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _Toolbar(controller: controller),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                if (!wide) {
                  return SpatialCanvas(controller: controller);
                }
                return Row(
                  children: [
                    SizedBox(width: 240, child: _ProjectTree(controller: controller)),
                    const VerticalDivider(width: 1),
                    Expanded(child: SpatialCanvas(controller: controller)),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 280, child: _PropertiesPanel(controller: controller)),
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
                controller.tool == value ? Theme.of(context).colorScheme.secondaryContainer : null,
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
            tool(EditorTool.roomRectangle, Icons.crop_square, 'Комната'),
            tool(EditorTool.guide, Icons.straighten, 'Направляющая'),
            const SizedBox(width: 10),
            FilterChip(
              selected: controller.snapEnabled,
              onSelected: controller.setSnapEnabled,
              avatar: const Icon(Icons.grid_4x4, size: 18),
              label: const Text('Snap'),
            ),
          ],
        ),
      ),
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
        const ListTile(dense: true, leading: Icon(Icons.location_on_outlined), title: Text('Площадка')),
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: ListTile(dense: true, leading: Icon(Icons.apartment), title: Text('Building A')),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: ListTile(dense: true, leading: const Icon(Icons.layers_outlined), title: Text(controller.level.name)),
        ),
        const Divider(),
        Text('ПОМЕЩЕНИЯ', style: Theme.of(context).textTheme.labelLarge),
        for (final space in controller.level.spaces)
          ListTile(
            dense: true,
            selected: controller.selectedSpaceId == space.id,
            leading: Icon(space.type == SpaceType.corridor ? Icons.linear_scale : Icons.crop_square),
            title: Text(space.name),
            onTap: () {
              controller.selectedSpaceId = space.id;
              controller.notifyListeners();
            },
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
    if (space == null) {
      return const Center(child: Text('Выберите помещение'));
    }
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
        const Divider(height: 32),
        const Text('Локальная сетка'),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: space.grid.minorStepMm,
          items: const [50, 100, 250, 500]
              .map((value) => DropdownMenuItem(value: value, child: Text('$value mm')))
              .toList(),
          onChanged: (value) {
            if (value != null) controller.updateSelectedGrid(value);
          },
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Шаг'),
        ),
        const SizedBox(height: 12),
        const Text('Центровочные линии создаются автоматически по локальному центру помещения.'),
      ],
    );
  }

  Widget _value(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label)), Text(value)]),
      );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final grid = controller.selectedSpace?.grid.minorStepMm ?? 100;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text('Metric · Floor grid ${controller.floorGridMm} mm · Room grid $grid mm · Snap ${controller.snapEnabled ? 'ON' : 'OFF'}'),
    );
  }
}
