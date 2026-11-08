import 'package:flutter/material.dart';

import '../../domain/project_aggregate.dart';
import '../../domain/canonical_power_selection.dart';
import '../../domain/canonical_residual_protection_registry.dart';
import '../../application/project/engineering/canonical_power_selection_diff.dart';
import '../../application/project/engineering/engineering_proposal_diff.dart';
import '../../application/project/engineering/p12_engineering_proposal_source.dart';

/// Read-only rendering of the authoritative project-owned P11/v22 state.
/// The legacy editor group widgets are not evidence of P12 qualification.
class P12EngineeringReviewPanel extends StatelessWidget {
  const P12EngineeringReviewPanel({
    super.key,
    required this.project,
    this.baselineSelections,
    this.proposalSnapshot,
    this.proposalUnavailableReason,
  });

  final ProjectAggregateRoot? project;

  /// Optional independently frozen before-state. Null is NOT an empty state;
  /// without a genuine before-state it is forbidden to show a fabricated diff.
  final CanonicalPowerSelectionRegistry? baselineSelections;

  /// Source-backed P12A.7 proposal, verified against current project baseline.
  final P12EngineeringProposalSnapshot? proposalSnapshot;
  final String? proposalUnavailableReason;

  @override
  Widget build(BuildContext context) {
    final current = project;
    final metadata = current?.engineeringMetadata;
    final engineeringState = metadata?.engineeringState;
    final selections = metadata?.powerSelections ??
        const CanonicalPowerSelectionRegistry.empty();
    final residual = metadata?.residualProtection ??
        const CanonicalResidualProtectionRegistry.empty();
    final diff = current != null && baselineSelections != null
        ? CanonicalPowerSelectionDiff.between(baselineSelections!, selections)
        : null;
    return Column(
      key: const ValueKey('p12-review-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('P12 · Инженерная проверка',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Только просмотр канонического состояния проекта. '
          'Данные прототипа электрических групп не заменяют P11/P12.',
        ),
        const SizedBox(height: 12),
        if (current == null) ...[
          const Text(
            'Канонический проект недоступен для этого окна. '
            'Откройте проект через production Project Hub.',
            key: ValueKey('p12-review-no-project'),
          ),
        ] else ...[
          Text('Версия проекта: ${current.version}',
              key: const ValueKey('p12-review-project-version')),
          Text('P11 цепей: ${engineeringState?.circuits.length ?? 0}',
              key: const ValueKey('p12-review-circuit-count')),
          Text('Выбрано защит/кабелей P12: ${selections.byCircuit.length}',
              key: const ValueKey('p12-review-selection-count')),
          Text('Постоянных групп RCD: ${residual.assignments.length}',
              key: const ValueKey('p12-review-rcd-count')),
          const SizedBox(height: 12),
          if (selections.isEmpty)
            const Text(
              'Нет канонических P12 POWER selections. '
              'Введённые в редакторе параметры пока не являются '
              'утверждённым каталожным выбором.',
              key: ValueKey('p12-review-no-selections'),
            )
          else ...[
            Text('Канонические назначения',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final selected in selections.byCircuit.values)
              _CircuitReviewRow(
                selection: selected,
                assignment: _findAssignment(residual, selected),
              ),
          ],
          const SizedBox(height: 16),
          Text('P12 Engineering Proposal',
              style: Theme.of(context).textTheme.titleMedium),
          if (proposalSnapshot == null)
            Text(
              proposalUnavailableReason ??
                  'Источник P12 proposal не подключён: требуются '
                      'утверждённые расчётные входные данные и evidence.',
              key: const ValueKey('p12-review-proposal-unavailable'),
            )
          else ...[
            Text(
              'Snapshot: ${proposalSnapshot!.proposal.fingerprint}',
              key: const ValueKey('p12-review-proposal-fingerprint'),
            ),
            Text(
              'Цепей в предложении: ${proposalSnapshot!.proposal.entries.length}',
              key: const ValueKey('p12-review-proposal-count'),
            ),
            for (final item in proposalSnapshot!.proposal.entries)
              ListTile(
                key: ValueKey('p12-review-proposal-${item.generationKey}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Цепь: ${item.generationKey}'),
                subtitle: Text(
                  item.status == EngineeringProposalStatus.selected
                      ? 'Кабель: ${item.cableCatalogId} · Защита: ${item.protectionCatalogId}'
                      : 'Не разрешена: отсутствует подтверждённый выбор',
                ),
              ),
            if (proposalSnapshot!.proposal.issues.isNotEmpty) ...[
              Text('Диагностика',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final issue in proposalSnapshot!.proposal.issues)
                Text(
                  issue.name,
                  key: ValueKey('p12-review-issue-${issue.name}'),
                ),
            ],
            if (!proposalSnapshot!.proposal.isFullySelected)
              const Text(
                'Предложение не завершено: требуются исправления и '
                'повторная проверка источников.',
                key: ValueKey('p12-review-proposal-incomplete'),
              ),
          ],
          const SizedBox(height: 16),
          Text('Engineering Diff',
              style: Theme.of(context).textTheme.titleMedium),
          if (diff == null)
            const Text(
              'Нет подтверждённого before-snapshot / P12 proposal. '
              'Diff не рассчитывается из пустого или вымышленного проекта.',
              key: ValueKey('p12-review-diff-unavailable'),
            )
          else if (diff.isEmpty)
            const Text('Отличий от закреплённого снимка нет.',
                key: ValueKey('p12-review-diff-empty'))
          else ...[
            for (final change in diff.changes)
              Text(
                '${change.kind.name.toUpperCase()}: ${change.circuitId.value}'
                ' · оборудование: ${change.equipmentChanged ? "изменено" : "без изменений"}',
                key: ValueKey('p12-review-diff-${change.circuitId.value}'),
              ),
          ],
          const SizedBox(height: 16),
          Text('Safety / Evidence',
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Нет подтверждения актуальных нормативных источников, '
            'расчётов КЗ, ADS и координации аппаратов из доверенного '
            'реестра в этом UI-сценарии. Предварительные параметры '
            'не подтверждают безопасность установки.',
            key: ValueKey('p12-review-evidence-blocked'),
          ),
        ],
        const SizedBox(height: 16),
        const ListTile(
          key: ValueKey('p12-review-apply-blocked'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('Production Apply недоступен'),
          subtitle: Text(
            'Для применения нужны полный P12 proposal, '
            'проверенный реестр evidence, подтверждённые safety gates '
            'и транзакционная повторная проверка.',
          ),
        ),
      ],
    );
  }

  static CanonicalResidualProtectionAssignment? _findAssignment(
    CanonicalResidualProtectionRegistry residual,
    CanonicalPowerCircuitSelection selected,
  ) {
    for (final assignment in residual.assignments) {
      if (assignment.protectedCircuitIds.contains(selected.circuitId)) {
        return assignment;
      }
    }
    return null;
  }
}

class _CircuitReviewRow extends StatelessWidget {
  const _CircuitReviewRow({
    required this.selection,
    required this.assignment,
  });

  final CanonicalPowerCircuitSelection selection;
  final CanonicalResidualProtectionAssignment? assignment;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('p12-review-circuit-${selection.circuitId.value}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text('Цепь ${selection.circuitId.value}'),
      subtitle: Text(
        'Щит: ${selection.boardComponentId.value} · '
        'Кабель: ${selection.cableCatalogId} · '
        'Автомат: ${selection.protectionCatalogId} · '
        'RCD: ${assignment?.upstreamResidualCatalogId ?? "не назначен"}',
      ),
    );
  }
}
