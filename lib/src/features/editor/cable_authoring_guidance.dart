import 'package:flutter/material.dart';

/// User-facing progress for physically verified cable authoring.
///
/// This guide reflects existing authoring state; it never bypasses physical
/// transition validation or commits geometry on the user's behalf.
enum CableAuthoringStage { source, path, destination, ready, blocked }

class CableAuthoringGuidance extends StatelessWidget {
  const CableAuthoringGuidance({
    required this.hasSource,
    required this.hasDraft,
    required this.hasCompatibleTarget,
    required this.readyToFinish,
    required this.transitionDisconnected,
    required this.crossRoomBlocked,
    super.key,
  });

  final bool hasSource;
  final bool hasDraft;
  final bool hasCompatibleTarget;
  final bool readyToFinish;
  final bool transitionDisconnected;
  final bool crossRoomBlocked;

  CableAuthoringStage get stage {
    if (transitionDisconnected) return CableAuthoringStage.blocked;
    if (readyToFinish) return CableAuthoringStage.ready;
    if (!hasSource) return CableAuthoringStage.source;
    if (hasCompatibleTarget) return CableAuthoringStage.destination;
    return CableAuthoringStage.path;
  }

  String get instruction => switch (stage) {
        CableAuthoringStage.source =>
          '1. Выберите щит или устройство и нажмите его начальный порт.',
        CableAuthoringStage.path => crossRoomBlocked
            ? '2. Проложите путь до границы комнаты. Для перехода нужна '
                'подтверждённая проходка — соединение напрямую запрещено.'
            : hasDraft
                ? '2. Добавьте точки трассы. Для смены поверхности доведите '
                    'кабель до общего ребра, затем выберите стену, потолок или пол.'
                : '2. Укажите точки кабеля на поверхности. Переход между '
                    'поверхностями возможен только через физическое примыкание.',
        CableAuthoringStage.destination =>
          '3. Выберите совместимый конечный порт из списка ниже.',
        CableAuthoringStage.ready =>
          '3. Конечный порт привязан. Проверьте трассу и нажмите «Завершить».',
        CableAuthoringStage.blocked =>
          'Переход не подтверждён: вернитесь к общей границе поверхностей. '
              'Маршрут нельзя завершить без непрерывного физического пути.',
      };

  @override
  Widget build(BuildContext context) {
    final current = switch (stage) {
      CableAuthoringStage.source => 0,
      CableAuthoringStage.path || CableAuthoringStage.blocked => 1,
      CableAuthoringStage.destination || CableAuthoringStage.ready => 2,
    };
    final warning = stage == CableAuthoringStage.blocked ||
        (crossRoomBlocked && stage == CableAuthoringStage.path);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Мастер прокладки кабеля. $instruction',
      child: Column(
        key: const ValueKey('cable-guided-authoring'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    key: ValueKey('cable-guidance-step-${index + 1}'),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: index <= current
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      ['1 · Источник', '2 · Путь', '3 · Приёмник'][index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            instruction,
            key: const ValueKey('cable-guidance-instruction'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: warning ? scheme.error : scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}
