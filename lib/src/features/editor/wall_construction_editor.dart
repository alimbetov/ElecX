import 'package:flutter/material.dart';

import '../../domain/boundary_construction_registry.dart';
import 'canonical_wall_construction_runtime.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';

/// Production Inspector for physical wall construction.
///
/// Values are authored against BoundaryEdgeId through the canonical project
/// mutation timeline. The form never writes a legacy wall ordinal as durable
/// state.
class WallConstructionEditor extends StatelessWidget {
  const WallConstructionEditor({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListenableBuilder(
          listenable: controller.documentHistory,
          builder: (context, _) {
            final wall =
                CanonicalWallConstructionRuntime.activeWall(controller);
            if (wall == null) {
              return _UnavailableConstructionEditor(compact: compact);
            }
            return _WallConstructionForm(
              key: ValueKey('${wall.spaceId.value}:${wall.edgeId.value}'),
              controller: controller,
              wall: wall,
              compact: compact,
            );
          },
        ),
      );
}

class _WallConstructionForm extends StatefulWidget {
  const _WallConstructionForm({
    required this.controller,
    required this.wall,
    required this.compact,
    super.key,
  });

  final EditorController controller;
  final CanonicalWallConstructionView wall;
  final bool compact;

  @override
  State<_WallConstructionForm> createState() => _WallConstructionFormState();
}

class _WallConstructionFormState extends State<_WallConstructionForm> {
  late final TextEditingController _thickness;
  late final TextEditingController _material;
  late final TextEditingController _fireRating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _thickness = TextEditingController();
    _material = TextEditingController();
    _fireRating = TextEditingController();
    _load(widget.wall.profile);
  }

  @override
  void didUpdateWidget(covariant _WallConstructionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wall.profile != widget.wall.profile && !_dirty) {
      _load(widget.wall.profile);
    }
  }

  @override
  void dispose() {
    _thickness.dispose();
    _material.dispose();
    _fireRating.dispose();
    super.dispose();
  }

  BoundaryConstructionProfile? get _candidate {
    final thicknessMm = int.tryParse(_thickness.text.trim());
    final materialId = _material.text.trim();
    if (thicknessMm == null || thicknessMm <= 0 || materialId.isEmpty) {
      return null;
    }
    try {
      return BoundaryConstructionProfile(
        kind: BoundaryConstructionKind.wall,
        thicknessMm: thicknessMm,
        materialId: materialId,
        fireRatingId:
            _fireRating.text.trim().isEmpty ? null : _fireRating.text.trim(),
      );
    } on ArgumentError {
      return null;
    }
  }

  bool get _dirty {
    final candidate = _candidate;
    final current = widget.wall.profile;
    if (candidate != null) return candidate != current;
    return _thickness.text.trim().isNotEmpty ||
        _material.text.trim().isNotEmpty ||
        _fireRating.text.trim().isNotEmpty;
  }

  void _load(BoundaryConstructionProfile? profile) {
    _thickness.text = profile?.thicknessMm.toString() ?? '';
    _material.text = profile?.materialId ?? '';
    _fireRating.text = profile?.fireRatingId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidate = _candidate;
    final edgeLabel = widget.wall.edgeId.value.length <= 14
        ? widget.wall.edgeId.value
        : '…${widget.wall.edgeId.value.substring(widget.wall.edgeId.value.length - 12)}';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_outlined, size: 18),
                const SizedBox(width: 7),
                Text(
                  'СТЕНА / КОНСТРУКЦИЯ',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Canonical BoundaryEdgeId',
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(edgeLabel),
                  ),
                ),
                if (_dirty) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Не сохранено'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: const ValueKey('wall-construction-thickness'),
                    controller: _thickness,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Толщина',
                      suffixText: 'mm',
                      helperText: 'Физическая толщина',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: widget.compact ? 170 : 220,
                  child: TextField(
                    key: const ValueKey('wall-construction-material'),
                    controller: _material,
                    decoration: const InputDecoration(
                      labelText: 'Материал / тип',
                      hintText: 'brick, concrete, partition…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    key: const ValueKey('wall-construction-fire-rating'),
                    controller: _fireRating,
                    decoration: const InputDecoration(
                      labelText: 'Огнестойкость',
                      hintText: 'EI60',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_dirty && candidate == null)
                  const _ConstructionValidationBadge(
                    'Толщина должна быть > 0, материал обязателен',
                  ),
                TextButton(
                  onPressed: _dirty && !_saving
                      ? () => setState(() => _load(widget.wall.profile))
                      : null,
                  child: const Text('Отменить'),
                ),
                FilledButton.icon(
                  onPressed:
                      _dirty && candidate != null && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Сохранить'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Толщина участвует в длине кабеля внутри проходки. Изменение '
              'автоматически пересчитывает связанные penetration и делает '
              'их sizing evidence требующим повторной проверки.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final candidate = _candidate;
    if (candidate == null) return;
    setState(() => _saving = true);
    try {
      final saved = CanonicalWallConstructionRuntime.setActiveWallConstruction(
        controller: widget.controller,
        thicknessMm: candidate.thicknessMm,
        materialId: candidate.materialId,
        fireRatingId: candidate.fireRatingId,
      );
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Изменение конструкции стены сейчас недоступно: canonical '
              'ownership или активная стена не подтверждены.',
            ),
          ),
        );
        return;
      }
      final refreshed = CanonicalWallConstructionRuntime.activeWall(
        widget.controller,
      );
      if (refreshed != null) _load(refreshed.profile);
      setState(() {});
    } on CanonicalWallConstructionEditException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _UnavailableConstructionEditor extends StatelessWidget {
  const _UnavailableConstructionEditor({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Конструкция стены доступна только для canonical wall с '
                  'подтверждённым BoundaryEdgeId и persistence owner.',
                ),
              ),
            ],
          ),
        ),
      );
}

class _ConstructionValidationBadge extends StatelessWidget {
  const _ConstructionValidationBadge(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.error_outline, size: 16),
        label: Text(message),
      );
}
