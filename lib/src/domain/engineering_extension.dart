import 'canonical_engineering_graph.dart';
import 'engineering_classification.dart';
import 'engineering_graph.dart';

final class EngineeringExtensionDisciplineDefinition {
  EngineeringExtensionDisciplineDefinition({
    required this.key,
    required this.legacyFamily,
  }) {
    if (key.isBuiltIn) {
      throw ArgumentError(
          'Extension cannot redeclare built-in discipline $key.');
    }
  }

  final EngineeringDisciplineKey key;
  final EngineeringDiscipline legacyFamily;
}

final class EngineeringExtensionSystemDefinition {
  EngineeringExtensionSystemDefinition({
    required this.key,
    required this.disciplineKey,
    required this.legacySystemFamily,
    Iterable<EngineeringMedia> media = const [],
    Iterable<EngineeringPortCapability> portCapabilities = const [],
  })  : media = Set.unmodifiable(media),
        portCapabilities = Set.unmodifiable(portCapabilities) {
    if (key.isBuiltIn) {
      throw ArgumentError('Extension cannot redeclare built-in system $key.');
    }
  }

  final EngineeringSystemKey key;
  final EngineeringDisciplineKey disciplineKey;
  final EngineeringSystemClass legacySystemFamily;
  final Set<EngineeringMedia> media;
  final Set<EngineeringPortCapability> portCapabilities;
}

/// One versioned cross-discipline extension declaration.
///
/// The declaration contains metadata only. Components and connections remain in
/// [CanonicalEngineeringGraph]; an extension never owns a parallel graph store.
final class EngineeringExtensionContract {
  EngineeringExtensionContract({
    required String id,
    required String version,
    Iterable<EngineeringExtensionDisciplineDefinition> disciplines = const [],
    Iterable<EngineeringExtensionSystemDefinition> systems = const [],
  })  : id = _nonEmpty(id, 'id'),
        version = _nonEmpty(version, 'version'),
        disciplines = List.unmodifiable(disciplines),
        systems = List.unmodifiable(systems) {
    final disciplineKeys = <EngineeringDisciplineKey>{};
    final systemKeys = <EngineeringSystemKey>{};
    for (final discipline in this.disciplines) {
      if (!disciplineKeys.add(discipline.key)) {
        throw ArgumentError(
            'Duplicate extension discipline ${discipline.key}.');
      }
    }
    for (final system in this.systems) {
      if (!systemKeys.add(system.key)) {
        throw ArgumentError('Duplicate extension system ${system.key}.');
      }
      final builtInDiscipline =
          EngineeringDisciplineKey.legacyValue(system.disciplineKey);
      if (builtInDiscipline != null) continue;
      final declaredDiscipline = _discipline(
        this.disciplines,
        system.disciplineKey,
      );
      if (declaredDiscipline == null) {
        throw ArgumentError(
          'System ${system.key} references undeclared discipline '
          '${system.disciplineKey}.',
        );
      }
    }
  }

  final String id;
  final String version;
  final List<EngineeringExtensionDisciplineDefinition> disciplines;
  final List<EngineeringExtensionSystemDefinition> systems;
}

enum EngineeringExtensionIssueCode {
  unknownDisciplineKey,
  disciplineLegacyMismatch,
  unknownSystemKey,
  systemLegacyMismatch,
  systemDisciplineMismatch,
  unsupportedSystemMedia,
  unsupportedSystemCapability,
}

final class EngineeringExtensionIssue {
  const EngineeringExtensionIssue({
    required this.code,
    required this.message,
  });

  final EngineeringExtensionIssueCode code;
  final String message;
}

final class EngineeringExtensionValidationReport {
  EngineeringExtensionValidationReport(
    Iterable<EngineeringExtensionIssue> issues,
  ) : issues = List.unmodifiable(issues);

  final List<EngineeringExtensionIssue> issues;

  bool get isValid => issues.isEmpty;

  void requireValid() {
    if (isValid) return;
    throw StateError(
      issues.map((issue) => '${issue.code.name}: ${issue.message}').join('\n'),
    );
  }
}

/// Resolves extension metadata while leaving graph ownership unchanged.
final class EngineeringExtensionRegistry {
  EngineeringExtensionRegistry(
      Iterable<EngineeringExtensionContract> contracts) {
    final contractMap = <String, EngineeringExtensionContract>{};
    final disciplineMap =
        <EngineeringDisciplineKey, EngineeringExtensionDisciplineDefinition>{};
    final systemMap =
        <EngineeringSystemKey, EngineeringExtensionSystemDefinition>{};

    for (final contract in contracts) {
      if (contractMap.containsKey(contract.id)) {
        throw ArgumentError('Duplicate engineering extension ${contract.id}.');
      }
      contractMap[contract.id] = contract;
      for (final discipline in contract.disciplines) {
        if (disciplineMap.containsKey(discipline.key)) {
          throw ArgumentError(
            'Discipline ${discipline.key} is declared by multiple extensions.',
          );
        }
        disciplineMap[discipline.key] = discipline;
      }
      for (final system in contract.systems) {
        if (systemMap.containsKey(system.key)) {
          throw ArgumentError(
            'System ${system.key} is declared by multiple extensions.',
          );
        }
        systemMap[system.key] = system;
      }
    }

    _contracts = Map.unmodifiable(contractMap);
    _disciplines = Map.unmodifiable(disciplineMap);
    _systems = Map.unmodifiable(systemMap);
  }

  late final Map<String, EngineeringExtensionContract> _contracts;
  late final Map<EngineeringDisciplineKey,
      EngineeringExtensionDisciplineDefinition> _disciplines;
  late final Map<EngineeringSystemKey, EngineeringExtensionSystemDefinition>
      _systems;

  EngineeringExtensionContract? contract(String id) => _contracts[id];

  EngineeringExtensionSystemDefinition? system(EngineeringSystemKey key) =>
      _systems[key];

  EngineeringExtensionValidationReport validateGraph(
    CanonicalEngineeringGraph graph,
  ) {
    final issues = <EngineeringExtensionIssue>[];
    for (final component in graph.components) {
      _validateComponent(component, issues);
    }
    for (final connection in graph.connections) {
      _validateConnection(connection, issues);
    }
    return EngineeringExtensionValidationReport(issues);
  }

  void _validateComponent(
    EngineeringGraphComponent component,
    List<EngineeringExtensionIssue> issues,
  ) {
    final builtInDiscipline =
        EngineeringDisciplineKey.legacyValue(component.disciplineKey);
    if (builtInDiscipline != null) {
      if (builtInDiscipline != component.discipline) {
        issues.add(
          EngineeringExtensionIssue(
            code: EngineeringExtensionIssueCode.disciplineLegacyMismatch,
            message: 'Component ${component.id} discipline key '
                '${component.disciplineKey} conflicts with legacy family '
                '${component.discipline.name}.',
          ),
        );
      }
    } else {
      final definition = _disciplines[component.disciplineKey];
      if (definition == null) {
        issues.add(
          EngineeringExtensionIssue(
            code: EngineeringExtensionIssueCode.unknownDisciplineKey,
            message: 'Component ${component.id} uses unknown discipline '
                '${component.disciplineKey}.',
          ),
        );
      } else if (definition.legacyFamily != component.discipline) {
        issues.add(
          EngineeringExtensionIssue(
            code: EngineeringExtensionIssueCode.disciplineLegacyMismatch,
            message: 'Component ${component.id} custom discipline legacy '
                'family does not match its extension contract.',
          ),
        );
      }
    }

    final builtInSystem = EngineeringSystemKey.legacyValue(component.systemKey);
    if (builtInSystem != null) {
      if (builtInSystem != component.systemClass) {
        issues.add(
          EngineeringExtensionIssue(
            code: EngineeringExtensionIssueCode.systemLegacyMismatch,
            message: 'Component ${component.id} system key '
                '${component.systemKey} conflicts with legacy family '
                '${component.systemClass.name}.',
          ),
        );
      }
      return;
    }

    final definition = _systems[component.systemKey];
    if (definition == null) {
      issues.add(
        EngineeringExtensionIssue(
          code: EngineeringExtensionIssueCode.unknownSystemKey,
          message: 'Component ${component.id} uses unknown system '
              '${component.systemKey}.',
        ),
      );
      return;
    }
    if (definition.legacySystemFamily != component.systemClass) {
      issues.add(
        EngineeringExtensionIssue(
          code: EngineeringExtensionIssueCode.systemLegacyMismatch,
          message: 'Component ${component.id} custom system legacy family '
              'does not match its extension contract.',
        ),
      );
    }
    if (definition.disciplineKey != component.disciplineKey) {
      issues.add(
        EngineeringExtensionIssue(
          code: EngineeringExtensionIssueCode.systemDisciplineMismatch,
          message: 'Component ${component.id} system ${component.systemKey} '
              'belongs to discipline ${definition.disciplineKey}, not '
              '${component.disciplineKey}.',
        ),
      );
    }
    for (final port in component.ports) {
      for (final medium in port.media) {
        if (!definition.media.contains(medium)) {
          issues.add(
            EngineeringExtensionIssue(
              code: EngineeringExtensionIssueCode.unsupportedSystemMedia,
              message:
                  'Component ${component.id} system ${component.systemKey} '
                  'does not declare medium $medium.',
            ),
          );
        }
      }
      for (final capability in port.capabilities) {
        if (!definition.portCapabilities.contains(capability)) {
          issues.add(
            EngineeringExtensionIssue(
              code: EngineeringExtensionIssueCode.unsupportedSystemCapability,
              message:
                  'Component ${component.id} system ${component.systemKey} '
                  'does not declare capability $capability.',
            ),
          );
        }
      }
    }
  }

  void _validateConnection(
    EngineeringGraphConnection connection,
    List<EngineeringExtensionIssue> issues,
  ) {
    final builtInSystem =
        EngineeringSystemKey.legacyValue(connection.systemKey);
    if (builtInSystem != null) {
      if (builtInSystem != connection.systemClass) {
        issues.add(
          EngineeringExtensionIssue(
            code: EngineeringExtensionIssueCode.systemLegacyMismatch,
            message: 'Connection ${connection.id} system key '
                '${connection.systemKey} conflicts with legacy family '
                '${connection.systemClass.name}.',
          ),
        );
      }
      return;
    }

    final definition = _systems[connection.systemKey];
    if (definition == null) {
      issues.add(
        EngineeringExtensionIssue(
          code: EngineeringExtensionIssueCode.unknownSystemKey,
          message: 'Connection ${connection.id} uses unknown system '
              '${connection.systemKey}.',
        ),
      );
      return;
    }
    if (definition.legacySystemFamily != connection.systemClass) {
      issues.add(
        EngineeringExtensionIssue(
          code: EngineeringExtensionIssueCode.systemLegacyMismatch,
          message: 'Connection ${connection.id} custom system legacy family '
              'does not match its extension contract.',
        ),
      );
    }
    final medium = connection.media;
    if (medium != null && !definition.media.contains(medium)) {
      issues.add(
        EngineeringExtensionIssue(
          code: EngineeringExtensionIssueCode.unsupportedSystemMedia,
          message: 'Connection ${connection.id} system ${connection.systemKey} '
              'does not declare medium $medium.',
        ),
      );
    }
  }
}

EngineeringExtensionDisciplineDefinition? _discipline(
  Iterable<EngineeringExtensionDisciplineDefinition> disciplines,
  EngineeringDisciplineKey key,
) {
  for (final discipline in disciplines) {
    if (discipline.key == key) return discipline;
  }
  return null;
}

String _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}
