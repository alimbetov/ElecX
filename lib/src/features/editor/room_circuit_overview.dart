import 'package:flutter/material.dart';

import 'circuit_engineering_status.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

enum RoomCircuitOverviewKind { pass, fail, indeterminate, incomplete, stale }

final class RoomCircuitOverviewEntry {
  const RoomCircuitOverviewEntry({
    required this.loadComponentId,
    required this.circuitName,
    required this.loadLabel,
    required this.boardLabel,
    required this.cableLabel,
    required this.lengthM,
    required this.kind,
    required this.headline,
  });

  final String loadComponentId;
  final String circuitName;
  final String loadLabel;
  final String boardLabel;
  final String cableLabel;
  final double lengthM;
  final RoomCircuitOverviewKind kind;
  final String headline;
}

final class RoomCircuitOverviewModel {
  const RoomCircuitOverviewModel(this.entries);

  final List<RoomCircuitOverviewEntry> entries;

  int count(RoomCircuitOverviewKind kind) =>
      entries.where((entry) => entry.kind == kind).length;

  int get passCount => count(RoomCircuitOverviewKind.pass);
  int get failCount => count(RoomCircuitOverviewKind.fail);
  int get indeterminateCount => count(RoomCircuitOverviewKind.indeterminate);
  int get incompleteCount => count(RoomCircuitOverviewKind.incomplete);
  int get staleCount => count(RoomCircuitOverviewKind.stale);

  static RoomCircuitOverviewModel fromSession({
    required EditorP2Session session,
    required String spaceId,
  }) {
    final entries = <RoomCircuitOverviewEntry>[];
    for (final bundle in session.state.circuitBundles) {
      final load = session.components
          .where((component) => component.id == bundle.cable.endB.componentId)
          .firstOrNull;
      if (load == null || load.surface.spaceId != spaceId) continue;
      final board = session.components
          .where((component) => component.id == bundle.circuit.boardId)
          .firstOrNull;
      final route = session.routes
          .where((route) => route.id == bundle.cable.routeId)
          .firstOrNull;
      if (route == null) {
        entries.add(
          RoomCircuitOverviewEntry(
            loadComponentId: load.id,
            circuitName: bundle.circuit.name,
            loadLabel: load.label,
            boardLabel: board?.label ?? bundle.circuit.boardId ?? '—',
            cableLabel: bundle.cable.designation,
            lengthM: 0,
            kind: RoomCircuitOverviewKind.fail,
            headline: 'Трасса группы отсутствует',
          ),
        );
        continue;
      }
      final status = CircuitEngineeringStatus.evaluate(
        load: load,
        route: route,
        bundle: bundle,
        sizingEvidence: session.sizingEvidenceForLoad(load.id),
      );
      entries.add(
        RoomCircuitOverviewEntry(
          loadComponentId: load.id,
          circuitName: bundle.circuit.name,
          loadLabel: load.label,
          boardLabel: board?.label ?? bundle.circuit.boardId ?? '—',
          cableLabel: bundle.cable.cableSpecId ?? bundle.cable.designation,
          lengthM: status.installationLengthM,
          kind: _kind(status.readiness),
          headline: status.headline,
        ),
      );
    }
    entries.sort((a, b) {
      final severity = _severity(a.kind).compareTo(_severity(b.kind));
      if (severity != 0) return severity;
      return a.circuitName.compareTo(b.circuitName);
    });
    return RoomCircuitOverviewModel(List.unmodifiable(entries));
  }

  static RoomCircuitOverviewKind _kind(
    CircuitEngineeringReadiness readiness,
  ) => switch (readiness) {
    CircuitEngineeringReadiness.sizingPassed => RoomCircuitOverviewKind.pass,
    CircuitEngineeringReadiness.sizingFailed => RoomCircuitOverviewKind.fail,
    CircuitEngineeringReadiness.sizingIndeterminate =>
      RoomCircuitOverviewKind.indeterminate,
    CircuitEngineeringReadiness.sizingEvidenceStale =>
      RoomCircuitOverviewKind.stale,
    CircuitEngineeringReadiness.missingLoadPower ||
    CircuitEngineeringReadiness.missingProtection ||
    CircuitEngineeringReadiness.missingCableSpecification ||
    CircuitEngineeringReadiness.sizingEvidenceRequired =>
      RoomCircuitOverviewKind.incomplete,
  };

  static int _severity(RoomCircuitOverviewKind kind) => switch (kind) {
    RoomCircuitOverviewKind.fail => 0,
    RoomCircuitOverviewKind.stale => 1,
    RoomCircuitOverviewKind.incomplete => 2,
    RoomCircuitOverviewKind.indeterminate => 3,
    RoomCircuitOverviewKind.pass => 4,
  };
}

class RoomCircuitOverviewPanel extends StatelessWidget {
  const RoomCircuitOverviewPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return AnimatedBuilder(
      animation: Listenable.merge([controller, p2]),
      builder: (context, _) {
        final space = controller.selectedSpace;
        if (space == null) return const SizedBox.shrink();
        final model = RoomCircuitOverviewModel.fromSession(
          session: p2,
          spaceId: space.id,
        );
        return Card(
          key: const ValueKey('room-circuit-overview'),
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ExpansionTile(
            key: const ValueKey('room-circuit-overview-expansion'),
            initiallyExpanded: false,
            title: Text('Группы комнаты · ${model.entries.length}'),
            subtitle: model.entries.isEmpty
                ? const Text('Подключённых групп пока нет')
                : Text(_summary(model)),
            children: [
              if (model.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Выберите нагрузку и подключите её к щиту.'),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: model.entries.length,
                    itemBuilder: (context, index) {
                      final entry = model.entries[index];
                      return ListTile(
                        key: ValueKey(
                          'room-circuit-overview-entry-${entry.loadComponentId}',
                        ),
                        dense: true,
                        leading: Tooltip(
                          message: _kindLabel(entry.kind),
                          child: Icon(_kindIcon(entry.kind), size: 20),
                        ),
                        title: Text(
                          '${entry.circuitName} · ${entry.loadLabel}',
                        ),
                        subtitle: Text(
                          '${_kindLabel(entry.kind)} · ${entry.headline}\n'
                          '${entry.boardLabel} · ${entry.cableLabel} · '
                          '${entry.lengthM.toStringAsFixed(2)} м',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => p2.select(entry.loadComponentId),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _summary(RoomCircuitOverviewModel model) => [
    if (model.failCount > 0) 'FAIL ${model.failCount}',
    if (model.staleCount > 0) 'STALE ${model.staleCount}',
    if (model.incompleteCount > 0) 'ДАННЫЕ ${model.incompleteCount}',
    if (model.indeterminateCount > 0) '? ${model.indeterminateCount}',
    if (model.passCount > 0) 'PASS ${model.passCount}',
  ].join(' · ');

  static String _kindLabel(RoomCircuitOverviewKind kind) => switch (kind) {
    RoomCircuitOverviewKind.pass => 'PASS',
    RoomCircuitOverviewKind.fail => 'FAIL',
    RoomCircuitOverviewKind.indeterminate => 'INDETERMINATE',
    RoomCircuitOverviewKind.incomplete => 'ТРЕБУЮТСЯ ДАННЫЕ',
    RoomCircuitOverviewKind.stale => 'STALE',
  };

  static IconData _kindIcon(RoomCircuitOverviewKind kind) => switch (kind) {
    RoomCircuitOverviewKind.pass => Icons.check_circle_outline,
    RoomCircuitOverviewKind.fail => Icons.error_outline,
    RoomCircuitOverviewKind.indeterminate => Icons.help_outline,
    RoomCircuitOverviewKind.incomplete => Icons.edit_note_outlined,
    RoomCircuitOverviewKind.stale => Icons.history_toggle_off,
  };
}
