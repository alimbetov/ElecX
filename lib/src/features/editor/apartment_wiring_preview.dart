import 'package:flutter/material.dart';

import '../../domain/cable_identity.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/project_identity.dart';
import 'canonical_room_boundary_projection.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'remote_board_route_preview.dart';

/// An apartment proposal is a set of the existing physical-route proposals,
/// not a second electrical model. Unresolved loads remain explicit errors.
final class ApartmentWiringPreview {
  ApartmentWiringPreview._(this.routes, this.blockers, this.switchCount);
  final List<RemoteBoardRoutePreview> routes;
  final List<String> blockers;
  final int switchCount;

  static ApartmentWiringPreview create(EditorController editor) {
    final p2 = editor.p2;
    final boards = p2.components
        .where((c) => c.type == ElectricalComponentType.distributionBoard)
        .toList();
    final switches = p2.components
        .where((c) => c.type == ElectricalComponentType.switchControl)
        .length;
    if (boards.length != 1) {
      return ApartmentWiringPreview._(
          const [],
          ['Требуется один распределительный щит; найдено: ${boards.length}.'],
          switches);
    }
    final board = boards.single;
    final grouped = <String, CircuitRef>{};
    final byId = {for (final c in p2.components) c.id: c};
    String groupKey(ElectricalComponentPlacement load) =>
        '${load.surface.spaceId}:${load.type.name}';
    for (final bundle in p2.state.circuitBundles) {
      final load = byId[bundle.cable.endB.componentId];
      if (load != null &&
          bundle.circuit.boardId == board.id &&
          bundle.circuit.protectiveDeviceId == null) {
        grouped.putIfAbsent(groupKey(load), () => bundle.circuit);
      }
    }
    final planned = <RemoteBoardRoutePreview>[];
    final blockers = <String>[];
    final factory = SecureRandomEntityIdFactory();
    final names = {for (final s in editor.level.spaces) s.id: s.name};
    for (final load in p2.components) {
      if (load.type != ElectricalComponentType.socketOutlet &&
          load.type != ElectricalComponentType.lightingPoint) {
        continue;
      }
      if (p2.circuitBundleForLoad(load.id) != null) continue;
      final key = groupKey(load);
      final circuit = grouped[key] ??
          CircuitRef(
              id: factory.newCircuitId().value,
              name:
                  '${load.type == ElectricalComponentType.socketOutlet ? 'Розетки' : 'Освещение'} · '
                  '${names[load.surface.spaceId] ?? load.surface.spaceId}',
              boardId: board.id);
      try {
        final route = RemoteBoardRoutePreview.create(
            controller: editor,
            board: board,
            load: load,
            assignedCircuit: circuit);
        grouped[key] = circuit;
        planned.add(route);
      } on StateError catch (e) {
        blockers.add('${load.label}: ${e.message}');
      } on ArgumentError catch (e) {
        blockers.add('${load.label}: ${e.message}');
      } on CanonicalRoomBoundaryProjectionException catch (e) {
        blockers.add('${load.label}: ${e.message}');
      }
    }
    return ApartmentWiringPreview._(
        List.unmodifiable(planned), List.unmodifiable(blockers), switches);
  }

  bool apply() => RemoteBoardRoutePreview.applyAll(routes);
  void discard() {
    for (final route in routes) {
      route.discard();
    }
  }
}

Future<void> showApartmentWiringPreview(
    BuildContext context, EditorController editor) async {
  final preview = ApartmentWiringPreview.create(editor);
  final count = preview.routes.length;
  final before =
      editor.p2.state.circuitBundles.map((b) => b.circuit.id).toSet();
  final newGroups = preview.routes
      .map((r) => r.bundle.circuit.id)
      .toSet()
      .difference(before)
      .length;
  try {
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              key: const ValueKey('apartment-wiring-preview'),
              title: const Text('Проложить электропроводку · Preview'),
              content: SizedBox(
                  width: 700,
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (count > 0) ...[
                        SizedBox(
                            height: 270,
                            width: 700,
                            child: CustomPaint(
                                key: const ValueKey('apartment-wiring-plan'),
                                painter: PhysicalRoutePlanPainter(
                                    level: editor.level,
                                    routes: [
                                      for (final p in preview.routes) p.route
                                    ],
                                    edgeOrder: preview.routes.first.edgeOrder,
                                    scheme: Theme.of(context).colorScheme))),
                        Text(
                            'Diff: +$count трасс, +$count кабелей, +$newGroups групп. '
                            'Существующие трассы сохранены.'),
                        for (final p in preview.routes)
                          Text(
                              '${p.bundle.circuit.name} · ${p.bundle.cable.designation} · '
                              '${(p.route.geometricLengthMm / 1000).toStringAsFixed(2)} м'),
                      ] else
                        const Text('Новых допустимых трасс не найдено.'),
                      if (preview.blockers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Не построено: ${preview.blockers.length}',
                            key: const ValueKey('apartment-wiring-blocked')),
                        for (final blocker in preview.blockers) Text(blocker),
                      ],
                      const SizedBox(height: 8),
                      Text(
                          'Выключатели: ${preview.switchCount}. Управление светом '
                          'не создаётся этим предложением; его нужно спроектировать отдельно.'),
                      const Text(
                          'NOT QUALIFIED: L/N/PE, сечения и защиты не подтверждены. '
                          'Это физические трассы питания, а не завершённая схема квартиры.'),
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Отмена')),
                if (count > 0)
                  FilledButton(
                      key: const ValueKey('apartment-wiring-apply'),
                      onPressed: () {
                        final applied = preview.apply();
                        Navigator.pop(dialogContext);
                        if (applied) editor.showPlan();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(applied
                                ? 'Применено трасс: $count. Квалификация не завершена.'
                                : 'Проект изменился. Повторите предпросмотр.')));
                      },
                      child: Text('Применить $count трасс')),
              ],
            ));
  } finally {
    preview.discard();
  }
}
