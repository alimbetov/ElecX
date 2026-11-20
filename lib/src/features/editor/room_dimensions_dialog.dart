import 'package:flutter/material.dart';

/// Exact plan coordinates and dimensions, always expressed in model mm.
final class RoomDimensionsInput {
  const RoomDimensionsInput({
    required this.name,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.lengthMm,
  });

  final String name;
  final int xMm;
  final int yMm;
  final int widthMm;
  final int lengthMm;
}

/// An explicit alternative to the undiscoverable two-click rectangle tool.
/// Its result is only an intent; the owning screen commits it through the
/// canonical mutation service when a canonical project is active.
class RoomDimensionsDialog extends StatefulWidget {
  const RoomDimensionsDialog({
    super.key,
    this.initialName = 'Новая комната',
    this.initialXMm = 0,
    this.initialYMm = 0,
  });

  final String initialName;
  final int initialXMm;
  final int initialYMm;

  @override
  State<RoomDimensionsDialog> createState() => _RoomDimensionsDialogState();
}

class _RoomDimensionsDialogState extends State<RoomDimensionsDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _width;
  late final TextEditingController _length;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _x = TextEditingController(text: '${widget.initialXMm}');
    _y = TextEditingController(text: '${widget.initialYMm}');
    _width = TextEditingController(text: '4000');
    _length = TextEditingController(text: '3500');
  }

  @override
  void dispose() {
    _name.dispose();
    _x.dispose();
    _y.dispose();
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  String? _coordinate(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed.abs() > 100000000) {
      return 'Введите координату в мм';
    }
    return null;
  }

  String? _dimension(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 300 || parsed > 100000) {
      return 'От 300 до 100 000 мм';
    }
    return null;
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) =>
      TextFormField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'мм',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: validator,
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const ValueKey('room-dimensions-dialog'),
        title: const Text('Создать комнату'),
        content: SizedBox(
          width: 390,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const ValueKey('room-name-input'),
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Укажите название'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          key: const ValueKey('room-width-input'),
                          controller: _width,
                          label: 'Ширина (X)',
                          validator: _dimension,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          key: const ValueKey('room-length-input'),
                          controller: _length,
                          label: 'Длина (Y)',
                          validator: _dimension,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Положение на плане этажа'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          key: const ValueKey('room-x-input'),
                          controller: _x,
                          label: 'Начало X',
                          validator: _coordinate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          key: const ValueKey('room-y-input'),
                          controller: _y,
                          label: 'Начало Y',
                          validator: _coordinate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Прямоугольник создаётся на активном этаже в миллиметрах. '
                    'Ширина и длина должны быть не менее 300 мм.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('room-dimensions-submit'),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.of(context).pop(
                RoomDimensionsInput(
                  name: _name.text.trim(),
                  xMm: int.parse(_x.text.trim()),
                  yMm: int.parse(_y.text.trim()),
                  widthMm: int.parse(_width.text.trim()),
                  lengthMm: int.parse(_length.text.trim()),
                ),
              );
            },
            child: const Text('Создать'),
          ),
        ],
      );
}
