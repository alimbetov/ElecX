import 'package:flutter/material.dart';

import '../../domain/boundary_editing.dart';
import 'boundary_bottom_editor.dart';
import 'boundary_edit_session.dart';
import 'editor_controller.dart';

class BoundaryEditPanel extends StatelessWidget {
  const BoundaryEditPanel({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final session = controller.boundaryEditing;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.active) {
          return FilledButton.tonalIcon(
            onPressed: () => session.enter(),
            icon: const Icon(Icons.border_style_outlined, size: 18),
            label: Text(compact ? 'Границы' : 'Редактировать границы'),
          );
        }

        final selected = <BoundaryEditProfile>{session.profile!};
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<BoundaryEditProfile>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: BoundaryEditProfile.wall,
                      icon: Icon(Icons.crop_square, size: 17),
                      label: Text('Стена'),
                    ),
                    ButtonSegment(
                      value: BoundaryEditProfile.structuralProfile,
                      icon: Icon(Icons.architecture_outlined, size: 17),
                      label: Text('Балка'),
                    ),
                    ButtonSegment(
                      value: BoundaryEditProfile.openings,
                      icon: Icon(Icons.door_front_door_outlined, size: 17),
                      label: Text('Проёмы'),
                    ),
                  ],
                  selected: selected,
                  onSelectionChanged: (value) async {
                    if (value.isEmpty || value.first == session.profile) return;
                    final resolved = await resolveBoundaryDraft(
                      context,
                      controller,
                    );
                    if (!resolved || !context.mounted) return;
                    session.setProfile(value.first);
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => requestBoundaryEditorExit(
                    context,
                    controller,
                  ),
                  tooltip: 'Выйти из редактирования границ',
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
