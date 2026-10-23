import 'package:flutter/material.dart';

import '../../domain/boundary_construction_registry.dart';
import 'canonical_wall_construction_runtime.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'wall_construction_edit_contract.dart';

/// Production Inspector for physical wall construction.
///
/// Values are authored against BoundaryEdgeId through the canonical project
/// mutation timeline. The form never writes a legacy wall ordinal as durable
/// state, and every save is bound to the exact session/host/version captured
/// when the draft baseline was established.
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
            final baseline =
                CanonicalWallConstructionEditContract.capture(controller);
            if (baseline == null) {
              return _UnavailableConstructionEditor(compact: compact);
            }
            if (compact) {
              return _CompactWallConstructionEditor(
                controller: controller,
                baseline: baseline,
              );
            }
            return _WallConstructionForm(
              key: _formKey,
              controller: controller,
              baseline: baseline,
              compact: false,
            );
          },
        ),
      );

  /// Keep one state object while the selection/version changes so a dirty
  /// draft can become an explicit conflict instead of being silently replaced.
  static const ValueKey<String> _formKey =
      ValueKey('canonical-wall-construction-form');
}

class _CompactWallConstructionEditor extends StatelessWidget {
  const _CompactWallConstructionEditor({
    required this.controller,
    required this.baseline,
  });

  final EditorController controller;
  final CanonicalWallConstructionEditBaseline baseline;

  @override
  Widget build(BuildContext context) {
    final profile = baseline.profile;
    final summary = profile == null
        ? 'Конструкция не задана'
        : '${profile.thicknessMm} mm · ${profile.materialId}'
            '${profile.fireRatingId == null ? '' : ' · ${profile.fireRatingId}'}';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        key: const ValueKey('wall-construction-open-editor'),
        onTap: () => _openEditor(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'СТЕНА / КОНСТРУКЦИЯ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => ListenableBuilder(
                  listenable: controller.documentHistory,
                  builder: (context, _) {
                    final liveBaseline =
                        CanonicalWallConstructionEditContract.capture(
                      controller,
                    );
                    if (liveBaseline == null) {
                      return const _UnavailableConstructionEditor(
                        compact: false,
                      );
                    }
                    return _WallConstructionForm(
                      key: WallConstructionEditor._formKey,
                      controller: controller,
                      baseline: liveBaseline,
                      compact: false,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
}

class _WallConstructionForm extends StatefulWidget {
  const _WallConstructionForm({
    required this.controller,
    required this.baseline,
    required this.compact,
    super.key,
  });

  final EditorController controller;
  final CanonicalWallConstructionEditBaseline baseline;
  final bool compact;

  @override
  State<_WallConstructionForm> createState() => _WallConstructionFormState();
}

class _WallConstructionFormState extends State<_WallConstructionForm> {
  late final TextEditingController _thickness;
  late final TextEditingController _material;
  late final TextEditingController _fireRating;
  late CanonicalWallConstructionEditBaseline _baseline;
  bool _saving = false;
  bool _conflict = false;

  @override
  void initState() {
    super.initState();
    _thickness = TextEditingController();
    _material = TextEditingController();
    _fireRating = TextEditingController();
    _baseline = widget.baseline;
    _load(_baseline.profile);
  }

  @override
  void didUpdateWidget(covariant _WallConstructionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.baseline;
    if (!_baseline.sameTarget(incoming)) {
      if (_dirty) {
        _conflict = true;
        return;
      }
      _baseline = incoming;
      _conflict = false;
      _load(incoming.profile);
      return;
    }

    final changedExternally =
        incoming.expectedVersion != _baseline.expectedVersion ||
            incoming.profile != _baseline.profile;
    if (!changedExternally) return;

    if (_dirty) {
      _conflict = true;
      return;
    }
    _baseline = incoming;
    _conflict = false;
    _load(incoming.profile);
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

  bool get _dirty => !_draftMatches(_baseline.profile);

  bool _draftMatches(BoundaryConstructionProfile? profile) {
    final thickness = _thickness.text.trim();
    final material = _material.text.trim();
    final fireRating = _fireRating.text.trim();
    if (profile == null) {
      return thickness.isEmpty && material.isEmpty && fireRating.isEmpty;
    }
    return thickness == profile.thicknessMm.toString() &&
        material == profile.materialId &&
        fireRating == (profile.fireRatingId ?? '');
  }

  void _load(BoundaryConstructionProfile? profile) {
    _thickness.text = profile?.thicknessMm.toString() ?? '';
    _material.text = profile?.materialId ?? '';
    _fireRating.text = profile?.fireRatingId ?? '';
  }

  void _discardDraftAndReload() {
    setState(() {
      _baseline = widget.baseline;
      _conflict = false;
      _load(_baseline.profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidate = _candidate;
    final edgeLabel = _baseline.edgeId.value.length <= 14
        ? _baseline.edgeId.value
        : '…${_baseline.edgeId.value.substring(_baseline.edgeId.value.length - 12)}';

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
                if (_conflict) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    avatar: Icon(Icons.sync_problem, size: 16),
                    visualDensity: VisualDensity.compact,
                    label: Text('Конфликт'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_conflict) ...[
              _ConstructionConflictBanner(onReload: _discardDraftAndReload),
              const SizedBox(height: 8),
            ],
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
                  onPressed: (_dirty || _conflict) && !_saving
                      ? _discardDraftAndReload
                      : null,
                  child: Text(_conflict ? 'Обновить' : 'Отменить'),
                ),
                FilledButton.icon(
                  onPressed:
                      _dirty && candidate != null && !_saving && !_conflict
                          ? _save
                          : null,
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
    if (candidate == null || _conflict) return;
    setState(() => _saving = true);
    try {
      final refreshed = CanonicalWallConstructionEditContract.save(
        controller: widget.controller,
        baseline: _baseline,
        profile: candidate,
      );
      if (!mounted) return;
      setState(() {
        _baseline = refreshed;
        _conflict = false;
        _load(refreshed.profile);
      });
    } on CanonicalWallConstructionEditConflictException catch (error) {
      if (!mounted) return;
      setState(() => _conflict = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 56 : 0),
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 14),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    compact
                        ? 'Canonical wall editor недоступен'
                        : 'Конструкция стены доступна только для canonical wall с подтверждённым BoundaryEdgeId и persistence owner.',
                    maxLines: compact ? 1 : null,
                    overflow:
                        compact ? TextOverflow.ellipsis : TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ConstructionConflictBanner extends StatelessWidget {
  const _ConstructionConflictBanner({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.error),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync_problem, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Конструкция стены или версия проекта изменилась вне этой '
                  'формы. Черновик не будет сохранён поверх новых данных.',
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onReload,
                child: const Text('Загрузить актуальное'),
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
