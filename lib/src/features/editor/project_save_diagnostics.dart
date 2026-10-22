import 'dart:io';

import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import 'editor_building_workspace.dart';
import 'editor_p2_session.dart';

enum EditorProjectSaveIssueCode {
  activeTransform,
  unfinishedDraft,
  missingComponent,
  missingPort,
  incompatiblePorts,
  disconnectedRoute,
  missingCircuitRoute,
  invalidCircuitAssignment,
}

final class EditorProjectSaveIssue {
  const EditorProjectSaveIssue({
    required this.code,
    required this.title,
    required this.detail,
    this.routeId,
    this.componentId,
  });

  final EditorProjectSaveIssueCode code;
  final String title;
  final String detail;
  final String? routeId;
  final String? componentId;

  String get userMessage => '$title\n$detail';
}

final class EditorProjectSaveBlockedException implements Exception {
  const EditorProjectSaveBlockedException(this.issue);

  final EditorProjectSaveIssue issue;

  @override
  String toString() => issue.userMessage;
}

abstract final class EditorProjectSaveDiagnostics {
  static List<EditorProjectSaveIssue> validate(
    EditorBuildingWorkspace workspace,
  ) {
    final editor = workspace.editor;
    final issues = <EditorProjectSaveIssue>[];

    if (editor.p2.isManipulating) {
      issues.add(
        const EditorProjectSaveIssue(
          code: EditorProjectSaveIssueCode.activeTransform,
          title: 'Завершите редактирование компонента',
          detail: 'Сейчас активен preview перемещения. Подтвердите его Enter/отпусканием указателя или отмените Escape, затем сохраните проект.',
        ),
      );
    }
    if (editor.routeSegments.isNotEmpty || editor.draftStart != null) {
      issues.add(
        const EditorProjectSaveIssue(
          code: EditorProjectSaveIssueCode.unfinishedDraft,
          title: 'Есть незавершённая трасса',
          detail: 'Завершите построение кабеля или отмените черновик перед сохранением.',
        ),
      );
    }

    final components = {
      for (final component in editor.p2.components) component.id: component,
    };
    final routes = {for (final route in editor.p2.routes) route.id: route};
    for (final route in editor.p2.routes) {
      final sourceComponent = components[route.source.componentId];
      if (sourceComponent == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingComponent,
            title: 'Кабель ссылается на отсутствующий компонент',
            detail:
                'Трасса ${route.id}: источник ${route.source.componentId} не найден. Переподключите или удалите повреждённую трассу.',
            routeId: route.id,
            componentId: route.source.componentId,
          ),
        );
        continue;
      }
      final targetComponent = components[route.target.componentId];
      if (targetComponent == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingComponent,
            title: 'Кабель ссылается на отсутствующий компонент',
            detail:
                'Трасса ${route.id}: приёмник ${route.target.componentId} не найден. Переподключите или удалите повреждённую трассу.',
            routeId: route.id,
            componentId: route.target.componentId,
          ),
        );
        continue;
      }

      final sourcePort = _port(sourceComponent, route.source.portId);
      if (sourcePort == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingPort,
            title: 'Не найден порт источника кабеля',
            detail:
                'Трасса ${route.id}: у «${sourceComponent.label}» нет порта ${route.source.portId}. Переподключите конец кабеля.',
            routeId: route.id,
            componentId: sourceComponent.id,
          ),
        );
        continue;
      }
      final targetPort = _port(targetComponent, route.target.portId);
      if (targetPort == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingPort,
            title: 'Не найден порт приёмника кабеля',
            detail:
                'Трасса ${route.id}: у «${targetComponent.label}» нет порта ${route.target.portId}. Переподключите конец кабеля.',
            routeId: route.id,
            componentId: targetComponent.id,
          ),
        );
        continue;
      }

      if (!ElectricalPortCompatibility.areCompatible(
        sourcePort.kind,
        targetPort.kind,
      )) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.incompatiblePorts,
            title: 'Кабель подключён не к тому типу порта',
            detail:
                'Трасса ${route.id}: «${sourceComponent.label}» ${sourcePort.kind.name} → «${targetComponent.label}» ${targetPort.kind.name}. Эти порты несовместимы. Выберите совместимый вход/выход и переподключите конец кабеля.',
            routeId: route.id,
            componentId: targetComponent.id,
          ),
        );
        continue;
      }

      if (route.segments.isEmpty) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.disconnectedRoute,
            title: 'У кабеля отсутствует геометрия трассы',
            detail:
                'Трасса ${route.id} подключена семантически, но не содержит ни одного физического сегмента. Постройте трассу заново.',
            routeId: route.id,
          ),
        );
        continue;
      }
      if (!ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
        route: route,
        components: editor.p2.components,
      )) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.disconnectedRoute,
            title: 'Конец кабеля оторван от компонента',
            detail:
                'Трасса ${route.id}: физическая точка или поверхность конца не совпадает с подключённым компонентом. Переподключите кабель перед сохранением.',
            routeId: route.id,
          ),
        );
      }
    }
    final registry = CircuitCableRegistry();
    for (final bundle in editor.p2.state.circuitBundles) {
      final route = routes[bundle.cable.routeId];
      if (route == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingCircuitRoute,
            title: 'Инженерная группа потеряла кабельную трассу',
            detail:
                'Группа ${bundle.circuit.id} ссылается на отсутствующую трассу ${bundle.cable.routeId}. Переподключите нагрузку к щиту.',
            routeId: bundle.cable.routeId,
          ),
        );
        continue;
      }
      try {
        registry.registerBundle(
          route: route,
          circuit: bundle.circuit,
          cable: bundle.cable,
          protectiveDevice: bundle.protectiveDevice,
        );
      } catch (error) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.invalidCircuitAssignment,
            title: 'Нарушена целостность электрической группы',
            detail:
                'Группа ${bundle.circuit.id}: $error Исправьте подключение нагрузки к щиту перед сохранением.',
            routeId: route.id,
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  static EditorProjectSaveIssue? firstBlocking(
    EditorBuildingWorkspace workspace,
  ) {
    final issues = validate(workspace);
    return issues.isEmpty ? null : issues.first;
  }

  static String unexpectedPersistenceMessage(Object error) {
    if (error is FileSystemException) {
      return 'Не удалось записать файл проекта. Проверьте доступ к папке документов и свободное место на диске.';
    }
    return 'Не удалось записать проект из-за внутренней ошибки (${error.runtimeType}). Повторите сохранение; если ошибка повторится, откройте диагностику проекта.';
  }

  static ElectricalPortDefinition? _port(
    ElectricalComponentPlacement component,
    String portId,
  ) {
    for (final port in component.ports) {
      if (port.id == portId) return port;
    }
    return null;
  }
}
