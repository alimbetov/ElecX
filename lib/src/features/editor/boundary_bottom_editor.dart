import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/boundary_editing.dart';
import '../../domain/surfaces.dart';
import 'boundary_edit_session.dart';
import 'editor_controller.dart';
import 'wall_profile_editor_actions.dart';

class BoundaryBottomEditor extends StatefulWidget {
  const BoundaryBottomEditor({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final EditorController controller;
  final bool compact;

  @override
  State<BoundaryBottomEditor> createState() => _BoundaryBottomEditorState();
}

class _BoundaryBottomEditorState extends State<BoundaryBottomEditor> {
  EditorController get controller => widget.controller;
  BoundaryEditSession get session => controller.boundaryEditing;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    session.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant BoundaryBottomEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      oldWidget.controller.boundaryEditing.removeListener(_refresh);
      controller.addListener(_refresh);
      session.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    session.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!session.active || controller.activeWall == null) {
      return const SizedBox.shrink();
    }

    return switch (session.profile) {
      BoundaryEditProfile.openings => _openingEditor(context),
      BoundaryEditProfile.structuralProfile => _beamEditor(context),
      BoundaryEditProfile.wall || null => const SizedBox.shrink(),
    };
  }

  Widget _openingEditor(BuildContext context) {
    final selected = controller.selectedOpening;
    if (selected == null) {
      return _shell(
        context,
        icon: Icons.door_front_door_outlined,
        title: 'ПРОЁМЫ',
        dirty: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  controller.addOpening(ArchitecturalOpeningType.door);
                  final opening = controller.selectedOpening;
                  if (opening != null) session.beginOpeningDraft(opening);
                },
                icon: const Icon(Icons.door_front_door_outlined),
                label: const Text('Добавить дверь'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  controller.addOpening(ArchitecturalOpeningType.window);
                  final opening = controller.selectedOpening;
                  if (opening != null) session.beginOpeningDraft(opening);
                },
                icon: const Icon(Icons.window_outlined),
                label: const Text('Добавить окно'),
              ),
            ),
          ],
        ),
      );
    }

    if (session.openingDraft?.openingId != selected.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.selectedOpening?.id == selected.id) {
          session.beginOpeningDraft(selected);
        }
      });
    }
    final draft =
        session.openingDraft ?? OpeningEditDraft.fromOpening(selected);
    final valid = _openingDraftValid(selected, draft);

    return _shell(
      context,
      icon: draft.type == ArchitecturalOpeningType.window
          ? Icons.window_outlined
          : Icons.door_front_door_outlined,
      title: draft.type == ArchitecturalOpeningType.window
          ? 'РЕДАКТИРОВАНИЕ ОКНА'
          : 'РЕДАКТИРОВАНИЕ ДВЕРИ',
      dirty: session.draftDirty,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<ArchitecturalOpeningType>(
              initialValue: draft.type,
              decoration: const InputDecoration(
                labelText: 'Тип',
                isDense: true,
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
                if (value != null) {
                  session.updateOpeningDraft(draft.copyWith(type: value));
                }
              },
            ),
          ),
          _DraftIntField(
            fieldKey: '${selected.id}:x',
            label: 'X от стены',
            value: draft.offsetFromStartMm,
            onChanged: (value) => session.updateOpeningDraft(
              draft.copyWith(offsetFromStartMm: value),
            ),
          ),
          _DraftIntField(
            fieldKey: '${selected.id}:width',
            label: 'Ширина',
            value: draft.widthMm,
            onChanged: (value) => session.updateOpeningDraft(
              draft.copyWith(widthMm: value),
            ),
          ),
          _DraftIntField(
            fieldKey: '${selected.id}:height',
            label: 'Высота',
            value: draft.heightMm,
            onChanged: (value) => session.updateOpeningDraft(
              draft.copyWith(heightMm: value),
            ),
          ),
          _DraftIntField(
            fieldKey: '${selected.id}:sill',
            label: 'От пола',
            value: draft.sillHeightMm,
            onChanged: (value) => session.updateOpeningDraft(
              draft.copyWith(sillHeightMm: value),
            ),
          ),
          if (!valid) _ValidationBadge('Параметры выходят за профиль стены'),
          TextButton(
            onPressed: session.draftDirty
                ? () {
                    session.discardDraft();
                    session.beginOpeningDraft(selected);
                  }
                : null,
            child: const Text('Отменить'),
          ),
          FilledButton.icon(
            onPressed: session.draftDirty && valid
                ? () => _saveOpening(selected, draft)
                : null,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Сохранить'),
          ),
          IconButton(
            tooltip: 'Удалить проём',
            onPressed: controller.deleteSelectedOpening,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _beamEditor(BuildContext context) {
    final wall = controller.activeWall!;
    final model = controller.activeWallTopNotch;
    var draft = session.beamDraft;

    if (model == null && draft == null) {
      return _shell(
        context,
        icon: Icons.architecture_outlined,
        title: 'БАЛКА / ВЫЕМКА',
        dirty: false,
        child: FilledButton.tonalIcon(
          onPressed: () {
            final width = math.min(
              600,
              math.max(100, wall.lengthMm.round() ~/ 3),
            );
            final start = math.max(
              0,
              (wall.lengthMm.round() - width) ~/ 2,
            );
            final depth = math.min(
              300,
              math.max(50, wall.heightMm ~/ 6),
            );
            session.beginBeamDraft(
              BeamEditDraft.newDraft(
                startMm: start,
                widthMm: width,
                depthMm: depth,
              ),
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить балку / выемку'),
        ),
      );
    }

    if (draft == null && model != null) {
      draft = BeamEditDraft.existing(
        startMm: model.startMm,
        widthMm: model.widthMm,
        depthMm: model.depthMm,
      );
      final next = draft;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && session.beamDraft == null) session.beginBeamDraft(next);
      });
    }

    draft ??= BeamEditDraft.existing(
      startMm: model!.startMm,
      widthMm: model.widthMm,
      depthMm: model.depthMm,
    );

    final valid = _beamDraftValid(draft, wall);
    return _shell(
      context,
      icon: Icons.architecture_outlined,
      title: model == null ? 'НОВАЯ БАЛКА / ВЫЕМКА' : 'РЕДАКТИРОВАНИЕ БАЛКИ',
      dirty: draft.dirty,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _DraftIntField(
            fieldKey: 'beam:x',
            label: 'X от стены',
            value: draft.startMm,
            onChanged: (value) => session.updateBeamDraft(
              draft!.copyWith(startMm: value),
            ),
          ),
          _DraftIntField(
            fieldKey: 'beam:width',
            label: 'Ширина',
            value: draft.widthMm,
            onChanged: (value) => session.updateBeamDraft(
              draft!.copyWith(widthMm: value),
            ),
          ),
          _DraftIntField(
            fieldKey: 'beam:depth',
            label: 'Глубина',
            value: draft.depthMm,
            onChanged: (value) => session.updateBeamDraft(
              draft!.copyWith(depthMm: value),
            ),
          ),
          Chip(
            avatar: const Icon(Icons.height, size: 16),
            label: Text('Низ: ${wall.heightMm - draft.depthMm} mm'),
          ),
          if (!valid)
            _ValidationBadge('Балка выходит за стену или пересекает проём'),
          TextButton(
            onPressed: draft.dirty
                ? () {
                    if (model == null) {
                      session.discardDraft();
                    } else {
                      session.beginBeamDraft(
                        BeamEditDraft.existing(
                          startMm: model.startMm,
                          widthMm: model.widthMm,
                          depthMm: model.depthMm,
                        ),
                      );
                    }
                  }
                : null,
            child: const Text('Отменить'),
          ),
          FilledButton.icon(
            onPressed: draft.dirty && valid ? () => _saveBeam(draft!) : null,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Сохранить'),
          ),
          if (model != null)
            IconButton(
              tooltip: 'Удалить балку / вернуть прямой профиль',
              onPressed: () {
                controller.resetActiveWallProfile();
                session.discardDraft();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  Widget _shell(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool dirty,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.compact ? 10 : 14,
          8,
          widget.compact ? 10 : 14,
          10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 7),
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                if (dirty) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Не сохранено'),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Закрыть редактор',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      requestBoundaryEditorExit(context, controller),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: child),
          ],
        ),
      ),
    );
  }

  bool _openingDraftValid(
    ArchitecturalOpening source,
    OpeningEditDraft draft,
  ) {
    final wall = controller.activeWall;
    if (wall == null ||
        draft.offsetFromStartMm < 0 ||
        draft.widthMm <= 0 ||
        draft.heightMm <= 0 ||
        draft.sillHeightMm < 0) {
      return false;
    }
    try {
      final candidate = draft.toOpening(source);
      return RoomSurfaceResolver.openingFitsWall(
          opening: candidate, wall: wall);
    } on ArgumentError {
      return false;
    }
  }

  bool _beamDraftValid(BeamEditDraft draft, RoomWallSurface wall) {
    if (draft.startMm < 0 ||
        draft.widthMm <= 0 ||
        draft.depthMm <= 0 ||
        draft.startMm + draft.widthMm > wall.lengthMm.round() ||
        draft.depthMm >= wall.heightMm) {
      return false;
    }
    final bottom = wall.heightMm - draft.depthMm;
    final end = draft.startMm + draft.widthMm;
    for (final opening in controller.activeWallOpenings) {
      final overlapsX = opening.offsetFromStartMm < end &&
          opening.endOffsetMm > draft.startMm;
      if (overlapsX && opening.topMm > bottom) return false;
    }
    return true;
  }

  void _saveOpening(
    ArchitecturalOpening source,
    OpeningEditDraft draft,
  ) {
    final saved = controller.updateSelectedOpening(
      type: draft.type,
      offsetFromStartMm: draft.offsetFromStartMm,
      widthMm: draft.widthMm,
      heightMm: draft.heightMm,
      sillHeightMm: draft.sillHeightMm,
    );
    if (saved) {
      final current = controller.selectedOpening;
      if (current != null) {
        session.beginOpeningDraft(current, force: true);
      } else {
        session.markSaved();
      }
    }
  }

  void _saveBeam(BeamEditDraft draft) {
    final saved = controller.addActiveWallTopNotch(
      startMm: draft.startMm,
      widthMm: draft.widthMm,
      depthMm: draft.depthMm,
    );
    if (saved) {
      session.beginBeamDraft(
        BeamEditDraft.existing(
          startMm: draft.startMm,
          widthMm: draft.widthMm,
          depthMm: draft.depthMm,
        ),
      );
    }
  }
}

Future<bool> resolveBoundaryDraft(
  BuildContext context,
  EditorController controller,
) async {
  final session = controller.boundaryEditing;
  if (!session.draftDirty) return true;

  final result = await showDialog<_DirtyDraftChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Сохранить изменения?'),
      content: const Text(
        'В редакторе границ есть несохранённые изменения.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _DirtyDraftChoice.cancel),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _DirtyDraftChoice.discard),
          child: const Text('Не сохранять'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _DirtyDraftChoice.save),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );

  switch (result) {
    case _DirtyDraftChoice.discard:
      session.discardDraft();
      return true;
    case _DirtyDraftChoice.save:
      final saved = _commitBoundaryDraft(controller);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Невозможно сохранить: параметры конфликтуют с геометрией стены.',
            ),
          ),
        );
      }
      return saved;
    case _DirtyDraftChoice.cancel:
    case null:
      return false;
  }
}

Future<bool> requestBoundaryEditorExit(
  BuildContext context,
  EditorController controller,
) async {
  final resolved = await resolveBoundaryDraft(context, controller);
  if (!resolved) return false;
  controller.boundaryEditing.exit(force: true);
  return true;
}

bool _commitBoundaryDraft(EditorController controller) {
  final session = controller.boundaryEditing;
  final openingDraft = session.openingDraft;
  if (openingDraft != null) {
    final selected = controller.selectedOpening;
    if (selected == null || selected.id != openingDraft.openingId) return false;
    final saved = controller.updateSelectedOpening(
      type: openingDraft.type,
      offsetFromStartMm: openingDraft.offsetFromStartMm,
      widthMm: openingDraft.widthMm,
      heightMm: openingDraft.heightMm,
      sillHeightMm: openingDraft.sillHeightMm,
    );
    if (!saved) return false;
    final current = controller.selectedOpening;
    if (current != null) {
      session.beginOpeningDraft(current, force: true);
    } else {
      session.markSaved();
    }
    return true;
  }

  final beamDraft = session.beamDraft;
  if (beamDraft != null) {
    final saved = controller.addActiveWallTopNotch(
      startMm: beamDraft.startMm,
      widthMm: beamDraft.widthMm,
      depthMm: beamDraft.depthMm,
    );
    if (!saved) return false;
    session.beginBeamDraft(
      BeamEditDraft.existing(
        startMm: beamDraft.startMm,
        widthMm: beamDraft.widthMm,
        depthMm: beamDraft.depthMm,
      ),
    );
    return true;
  }

  return true;
}

enum _DirtyDraftChoice { save, discard, cancel }

class _DraftIntField extends StatelessWidget {
  const _DraftIntField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String fieldKey;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        child: TextFormField(
          key: ValueKey(fieldKey),
          initialValue: '$value',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            suffixText: 'mm',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (text) {
            final parsed = int.tryParse(text);
            if (parsed != null) onChanged(parsed);
          },
        ),
      );
}

class _ValidationBadge extends StatelessWidget {
  const _ValidationBadge(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(
          Icons.warning_amber_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.error,
        ),
        label: Text(message),
      );
}
