import '../domain/installation_guides.dart';

enum InstallationRuleResultKind { pass, fail, notApplicable }

final class InstallationRuleResult {
  const InstallationRuleResult({
    required this.ruleId,
    required this.kind,
    required this.message,
    this.source,
  });

  final String ruleId;
  final InstallationRuleResultKind kind;
  final String message;
  final InstallationGuideSource? source;
}

abstract final class KzInstallationRules {
  static const sp404106 = InstallationGuideSource(
    code: 'СП РК 4.04-106-2013',
    title: 'Электрооборудование жилых и общественных зданий. Правила проектирования',
  );

  /// Residential apartments and dormitory living rooms: sockets should be
  /// convenient for use and furniture layout, but not higher than 1.0 m.
  static InstallationRuleResult validateResidentialSocketHeight(int heightMm) {
    final pass = heightMm >= 0 && heightMm <= 1000;
    return InstallationRuleResult(
      ruleId: 'KZ-SP404106-15.33-SOCKET-HEIGHT',
      kind: pass
          ? InstallationRuleResultKind.pass
          : InstallationRuleResultKind.fail,
      message: pass
          ? 'Высота розетки соответствует пределу ≤ 1000 mm.'
          : 'Для квартир/общежитий розетка не должна быть выше 1000 mm.',
      source: const InstallationGuideSource(
        code: 'СП РК 4.04-106-2013',
        title: 'Электрооборудование жилых и общественных зданий. Правила проектирования',
        clause: '15.33',
      ),
    );
  }

  /// General-lighting switches: 0.8…1.7 m above finished floor.
  static InstallationRuleResult validateGeneralLightingSwitchHeight(
    int heightMm,
  ) {
    final pass = heightMm >= 800 && heightMm <= 1700;
    return InstallationRuleResult(
      ruleId: 'KZ-SP404106-15.33-SWITCH-HEIGHT',
      kind: pass
          ? InstallationRuleResultKind.pass
          : InstallationRuleResultKind.fail,
      message: pass
          ? 'Высота выключателя находится в диапазоне 800–1700 mm.'
          : 'Выключатель общего освещения должен быть на высоте 800–1700 mm.',
      source: const InstallationGuideSource(
        code: 'СП РК 4.04-106-2013',
        title: 'Электрооборудование жилых и общественных зданий. Правила проектирования',
        clause: '15.33',
      ),
    );
  }

  /// Sockets/switches must be at least 0.5 m from gas pipelines.
  static InstallationRuleResult validateDistanceToGasPipe(int distanceMm) {
    final pass = distanceMm >= 500;
    return InstallationRuleResult(
      ruleId: 'KZ-SP404106-15.34-GAS-DISTANCE',
      kind: pass
          ? InstallationRuleResultKind.pass
          : InstallationRuleResultKind.fail,
      message: pass
          ? 'Расстояние до газопровода ≥ 500 mm.'
          : 'До газопровода требуется не менее 500 mm.',
      source: const InstallationGuideSource(
        code: 'СП РК 4.04-106-2013',
        title: 'Электрооборудование жилых и общественных зданий. Правила проектирования',
        clause: '15.34',
      ),
    );
  }

  /// Schools and preschool institutions use the special 1.8 m rule for rooms
  /// occupied by children. This must only be applied when that room-use profile
  /// is explicitly selected.
  static InstallationRuleResult validateChildOccupancyHeight(int heightMm) {
    final pass = heightMm == 1800;
    return InstallationRuleResult(
      ruleId: 'KZ-SP404106-15.39-CHILD-HEIGHT',
      kind: pass
          ? InstallationRuleResultKind.pass
          : InstallationRuleResultKind.fail,
      message: pass
          ? 'Высота соответствует специальному требованию 1800 mm.'
          : 'Для помещений пребывания детей требуется 1800 mm.',
      source: const InstallationGuideSource(
        code: 'СП РК 4.04-106-2013',
        title: 'Электрооборудование жилых и общественных зданий. Правила проектирования',
        clause: '15.39',
      ),
    );
  }
}
