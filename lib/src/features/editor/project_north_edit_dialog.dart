import 'package:flutter/material.dart';

import '../../domain/project_orientation.dart';

/// Stateful P5D editor for canonical Project North.
///
/// The dialog owns its [TextEditingController] for the full route lifecycle so
/// the controller is disposed only after the dialog subtree itself is removed.
/// It never mutates project state directly; a successful submit only returns a
/// validated [ProjectEngineeringNorth] value to the application edit path.
final class ProjectNorthEditDialog extends StatefulWidget {
  const ProjectNorthEditDialog({
    required this.initialValue,
    super.key,
  });

  final ProjectEngineeringNorth? initialValue;

  @override
  State<ProjectNorthEditDialog> createState() =>
      _ProjectNorthEditDialogState();
}

final class _ProjectNorthEditDialogState extends State<ProjectNorthEditDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.degrees.toStringAsFixed(3) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite) {
      setState(() {
        _validationError = 'Введите конечное числовое значение угла.';
      });
      return;
    }

    final north = ProjectEngineeringNorth.fromDegrees(parsed);
    Navigator.of(context).pop(north);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('project-north-dialog'),
      title: const Text('Project North'),
      content: TextField(
        key: const ValueKey('project-north-angle-input'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Угол',
          suffixText: '°',
          helperText:
              '0° = вверх по плану; положительное направление по часовой стрелке',
          errorText: _validationError,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel-project-north'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('apply-project-north'),
          onPressed: _submit,
          child: const Text('Применить'),
        ),
      ],
    );
  }
}
