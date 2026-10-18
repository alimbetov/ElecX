import 'package:flutter/material.dart';

import '../../domain/surfaces.dart';
import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'plan_geometry_editor_actions.dart';
import 'wall_profile_editor_actions.dart';

class EngineeringInspector extends StatelessWidget {
  const EngineeringInspector({required this.workspace, super.key});

  final EditorBuildingWorkspace workspace;

  EditorController get controller => workspace.editor;

  int get _stepMm => controller.selectedSpace?.grid.minorStepMm ?? 100;

  @override
  Widget build(BuildContext context) {
    final space = controller.selectedSpace;
    if (space == null) {
      return const _InspectorEmptyState();
    }
    final bounds = space.boundary.bounds;
    final level = workspace.activeLevel;
    final zone = workspace.selectedZone;
    final wall = controller.activeWall;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        _SectionLabel('КОНТЕКСТ'),
        _ValueRow(
          'Режим',
          workspace.context == EditorWorkspaceContext.siteOutdoor
              ? 'Площадка / двор'
              : 'Здание',
        ),
        if (workspace.context == EditorWorkspaceContext.buildingLevel) ...[
          _ValueRow('Уровень', level?.displayName ?? controller.level.name),
          if (zone != null) _ValueRow('Зона', zone.name),
        ],
        const Divider(height: 18),
        _SectionLabel('ПОМЕЩЕНИЕ'),
        _ValueRow('Название', space.name),
        _ValueRow('Тип', space.type.name),
        _ValueRow('BBox', '${bounds.width} × ${bounds.height} mm'),
        if (wall != null) ...[
          const Divider(height: 18),
          _wallSection(context, wall),
          const Divider(height: 18),
          _openingSection(context),
        ],
        if (controller.routeSegments.isNotEmpty) ...[
          const Divider(height: 18),
          _routeSection(context),
        ],
        const Divider(height: 18),
        _gridSection(),
      ],
    );
  }

  Widget _wallSection(BuildContext context, RoomWallSurface wall) {
    final notch = controller.activeWallTopNotch;
    final external = controller.activeWallIsExternal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('СТЕНА'),
        _ValueRow('Длина', '${wall.lengthMm.round()} mm'),
        _ValueRow('Высота', '${wall.heightMm} mm'),
        if (external) ...[
          _ValueRow('Шаг перемещения', '$_stepMm mm'),
          const SizedBox(height: 6),
          const _DirectionCaption(
            icon: Icons.swap_vert,
            text: 'Внешняя стена — перемещение по нормали',
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.nudgeActiveWallNormal(-_stepMm),
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: Text('-$_stepMm'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.nudgeActiveWallNormal(_stepMm),
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: Text('+$_stepMm'),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 6),
          const _DirectionCaption(
            icon: Icons.link,
            text: 'Общая граница: directional-кнопки скрыты',
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: IconButton.outlined(
                tooltip: 'Предыдущая стена',
                onPressed: controller.previousWall,
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: IconButton.outlined(
                tooltip: 'Следующая стена',
                onPressed: controller.nextWall,
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FilledButton.tonalIcon(
          onPressed: () => _showWallProfileDialog(context, wall),
          icon: const Icon(Icons.account_tree_outlined, size: 17),
          label: const Text('Балка / выемка'),
        ),
        if (notch != null) ...[
          const SizedBox(height: 7),
          const _DirectionCaption(
            icon: Icons.open_with,
            text: 'Балка: ←/→ вдоль стены, ↑/↓ по глубине',
          ),
          const SizedBox(height: 5),
          _ValueRow(
            'Балка',
            'X ${notch.startMm} · ${notch.widthMm}×${notch.depthMm} mm',
          ),
          Row(
            children: [
              Expanded(
                child: IconButton.outlined(
                  tooltip: 'Балка влево',
                  onPressed: () => controller.nudgeActiveWallTopNotchX(-_stepMm),
                  icon: const Icon(Icons.arrow_back, size: 18),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: IconButton.outlined(
                  tooltip: 'Балка вправо',
                  onPressed: () => controller.nudgeActiveWallTopNotchX(_stepMm),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: IconButton.outlined(
                  tooltip: 'Уменьшить глубину балки',
                  onPressed: () => controller.nudgeActiveWallTopNotchDepth(-_stepMm),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: IconButton.outlined(
                  tooltip: 'Увеличить глубину балки',
                  onPressed: () => controller.nudgeActiveWallTopNotchDepth(_stepMm),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
              ),
            ],
          ),
        ],
        if (controller.activeWallHasCustomProfile) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: controller.resetActiveWallProfile,
            icon: const Icon(Icons.restart_alt, size: 17),
            label: const Text('Сбросить профиль стены'),
          ),
        ],
      ],
    );
  }

  Widget _openingSection(BuildContext context) {
    final openings = controller.activeWallOpenings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('ДВЕРИ И ОКНА')),
            Text('${openings.length}', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.addOpening(ArchitecturalOpeningType.door),
                icon: const Icon(Icons.door_front_door_outlined, size: 17),
                label: const Text('Дверь'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.addOpening(ArchitecturalOpeningType.window),
                icon: const Icon(Icons.window_outlined, size: 17),
                label: const Text('Окно'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (openings.isEmpty)
          const _InlineEmptyState('На этой стене пока нет проёмов.'),
        for (final opening in openings)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              minTileHeight: 38,
              selected: controller.selectedOpeningId == opening.id,
              selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              leading: Icon(
                opening.type == ArchitecturalOpeningType.window
                    ? Icons.window_outlined
                    : Icons.door_front_door_outlined,
                size: 17,
              ),
              title: Text(_openingName(opening)),
              subtitle: Text(
                'x ${opening.offsetFromStartMm} · ${opening.widthMm}×${opening.heightMm} mm',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => controller.selectOpening(opening.id),
            ),
          ),
        if (controller.selectedOpening case final opening?) ...[
          const SizedBox(height: 4),
          _OpeningEditor(
            controller: controller,
            opening: opening,
            stepMm: _stepMm,
          ),
        ],
      ],
    );
  }

  Widget _routeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('ТРАССА')),
            IconButton(
              tooltip: 'Очистить черновик трассы',
              visualDensity: VisualDensity.compact,
              onPressed: controller.clearRouteDraft,
              icon: const Icon(Icons.clear_all, size: 17),
            ),
          ],
        ),
        _ValueRow(
          'Длина',
          '${(controller.routeLengthMm / 1000).toStringAsFixed(3)} m',
        ),
        _ValueRow('Сегментов', '${controller.routeSegments.length}'),
      ],
    );
  }

  Widget _gridSection() {
    final space = controller.selectedSpace!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('СЕТКА'),
        const SizedBox(height: 6),
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
            if (value != null) {
              controller.updateSelectedGrid(value);
            }
          },
          decoration: const InputDecoration(labelText: 'Шаг сетки'),
        ),
      ],
    );
  }

  Future<void> _showWallProfileDialog(
    BuildContext context,
    RoomWallSurface wall,
  ) async {
    final current = controller.activeWallTopNotch;
    var startMm = current?.startMm ?? (wall.lengthMm * 0.25).round();
    var widthMm = current?.widthMm ?? 600;
    var depthMm = current?.depthMm ?? 300;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Балка / выемка'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IntEditor(
                  label: 'X от начала стены',
                  value: startMm,
                  onChanged: (value) => startMm = value,
                ),
                const SizedBox(height: 8),
                _IntEditor(
                  label: 'Ширина',
                  value: widthMm,
                  onChanged: (value) => widthMm = value,
                ),
                const SizedBox(height: 8),
                _IntEditor(
                  label: 'Глубина вниз',
                  value: depthMm,
                  onChanged: (value) => depthMm = value,
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
                final ok = controller.addActiveWallTopNotch(
                  startMm: startMm,
                  widthMm: widthMm,
                  depthMm: depthMm,
                );
                if (ok) {
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() {
                    error = 'Профиль недопустим или пересекает существующий проём.';
                  });
                }
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningEditor extends StatelessWidget {
  const _OpeningEditor({
    required this.controller,
    required this.opening,
    required this.stepMm,
  });

  final EditorController controller;
  final ArchitecturalOpening opening;
  final int stepMm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DirectionCaption(
              icon: Icons.swap_horiz,
              text: 'Проём перемещается только вдоль стены',
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.nudgeSelectedOpening(-stepMm),
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: Text('-$stepMm'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.nudgeSelectedOpening(stepMm),
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    label: Text('+$stepMm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            DropdownButtonFormField<ArchitecturalOpeningType>(
              initialValue: opening.type,
              decoration: const InputDecoration(labelText: 'Тип'),
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
                if (value != null) {
                  controller.updateSelectedOpening(type: value);
                }
              },
            ),
            const SizedBox(height: 6),
            _SubmitIntField(
              key: ValueKey('${opening.id}-offset-${opening.offsetFromStartMm}'),
              label: 'Позиция',
              value: opening.offsetFromStartMm,
              onSubmit: (value) => controller.updateSelectedOpening(
                offsetFromStartMm: value,
              ),
            ),
            const SizedBox(height: 6),
            _SubmitIntField(
              key: ValueKey('${opening.id}-width-${opening.widthMm}'),
              label: 'Ширина',
              value: opening.widthMm,
              onSubmit: (value) => controller.updateSelectedOpening(widthMm: value),
            ),
            const SizedBox(height: 6),
            _SubmitIntField(
              key: ValueKey('${opening.id}-height-${opening.heightMm}'),
              label: 'Высота',
              value: opening.heightMm,
              onSubmit: (value) => controller.updateSelectedOpening(heightMm: value),
            ),
            const SizedBox(height: 6),
            _SubmitIntField(
              key: ValueKey('${opening.id}-sill-${opening.sillHeightMm}'),
              label: 'От пола',
              value: opening.sillHeightMm,
              onSubmit: (value) => controller.updateSelectedOpening(sillHeightMm: value),
            ),
            TextButton.icon(
              onPressed: controller.deleteSelectedOpening,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('Удалить проём'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionCaption extends StatelessWidget {
  const _DirectionCaption({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      );
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
  Widget build(BuildContext context) => TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: label, suffixText: 'mm'),
        onFieldSubmitted: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) {
            onSubmit(parsed);
          }
        },
      );
}

class _IntEditor extends StatelessWidget {
  const _IntEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: 'mm'),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(value, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

class _InspectorEmptyState extends StatelessWidget {
  const _InspectorEmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Выберите помещение, стену или инженерный объект.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
}

String _openingName(ArchitecturalOpening opening) => switch (opening.type) {
      ArchitecturalOpeningType.door => 'Дверь',
      ArchitecturalOpeningType.window => 'Окно',
      ArchitecturalOpeningType.passage => 'Проход',
      ArchitecturalOpeningType.technicalOpening => 'Тех. проём',
    };
