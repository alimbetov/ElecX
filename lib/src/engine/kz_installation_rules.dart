import '../domain/installation_guides.dart';

enum InstallationRuleResultKind { pass, fail, notApplicable, indeterminate }

enum NormativeApplicability { applicable, notApplicable, indeterminate }

/// Reproducible evidence explaining why a normative rule produced its result.
final class NormativeEvidence {
  NormativeEvidence({
    required this.source,
    required this.applicability,
    required Iterable<String> facts,
    required this.rationale,
  }) : facts = List.unmodifiable(facts) {
    if (rationale.trim().isEmpty) {
      throw ArgumentError.value(rationale, 'rationale', 'Must be non-empty.');
    }
  }

  final InstallationGuideSource source;
  final NormativeApplicability applicability;
  final List<String> facts;
  final String rationale;
}

final class InstallationRuleResult {
  const InstallationRuleResult({
    required this.ruleId,
    required this.kind,
    required this.message,
    this.source,
    this.evidence,
  });

  final String ruleId;
  final InstallationRuleResultKind kind;
  final String message;
  final InstallationGuideSource? source;
  final NormativeEvidence? evidence;

  bool get isConclusive => kind != InstallationRuleResultKind.indeterminate;
}

abstract final class KzInstallationRules {
  static const sp404106 = InstallationGuideSource(
    code: 'СП РК 4.04-106-2013',
    title:
        'Электрооборудование жилых и общественных зданий. Правила проектирования',
    revision: '2013',
  );

  /// Residential apartments and dormitory living rooms: sockets should be
  /// convenient for use and furniture layout, but not higher than 1.0 m.
  static InstallationRuleResult validateResidentialSocketHeight(int? heightMm) {
    const ruleId = 'KZ-SP404106-15.33-SOCKET-HEIGHT';
    final source = _source('15.33');
    if (heightMm == null || heightMm < 0) {
      return _indeterminate(
        ruleId: ruleId,
        source: source,
        message: 'Недостаточно корректных данных о высоте розетки.',
        facts: ['heightMm=${heightMm ?? 'unknown'}'],
      );
    }
    final pass = heightMm <= 1000;
    return _evaluated(
      ruleId: ruleId,
      source: source,
      pass: pass,
      facts: ['heightMm=$heightMm', 'maximumMm=1000'],
      passMessage: 'Высота розетки соответствует пределу ≤ 1000 mm.',
      failMessage: 'Для квартир/общежитий розетка не должна быть выше 1000 mm.',
    );
  }

  /// General-lighting switches: 0.8…1.7 m above finished floor.
  static InstallationRuleResult validateGeneralLightingSwitchHeight(
    int? heightMm,
  ) {
    const ruleId = 'KZ-SP404106-15.33-SWITCH-HEIGHT';
    final source = _source('15.33');
    if (heightMm == null || heightMm < 0) {
      return _indeterminate(
        ruleId: ruleId,
        source: source,
        message: 'Недостаточно корректных данных о высоте выключателя.',
        facts: ['heightMm=${heightMm ?? 'unknown'}'],
      );
    }
    final pass = heightMm >= 800 && heightMm <= 1700;
    return _evaluated(
      ruleId: ruleId,
      source: source,
      pass: pass,
      facts: ['heightMm=$heightMm', 'minimumMm=800', 'maximumMm=1700'],
      passMessage: 'Высота выключателя находится в диапазоне 800–1700 mm.',
      failMessage:
          'Выключатель общего освещения должен быть на высоте 800–1700 mm.',
    );
  }

  /// Sockets/switches must be at least 0.5 m from gas pipelines.
  static InstallationRuleResult validateDistanceToGasPipe(int? distanceMm) {
    const ruleId = 'KZ-SP404106-15.34-GAS-DISTANCE';
    final source = _source('15.34');
    if (distanceMm == null || distanceMm < 0) {
      return _indeterminate(
        ruleId: ruleId,
        source: source,
        message: 'Недостаточно корректных данных о расстоянии до газопровода.',
        facts: ['distanceMm=${distanceMm ?? 'unknown'}'],
      );
    }
    final pass = distanceMm >= 500;
    return _evaluated(
      ruleId: ruleId,
      source: source,
      pass: pass,
      facts: ['distanceMm=$distanceMm', 'minimumMm=500'],
      passMessage: 'Расстояние до газопровода ≥ 500 mm.',
      failMessage: 'До газопровода требуется не менее 500 mm.',
    );
  }

  /// Schools and preschool institutions use the special 1.8 m rule for rooms
  /// occupied by children. Applicability must be explicit; unknown applicability
  /// is not treated as PASS and therefore fails closed as INDETERMINATE.
  static InstallationRuleResult validateChildOccupancyHeight(
    int? heightMm, {
    bool? childOccupancyConfirmed = true,
  }) {
    const ruleId = 'KZ-SP404106-15.39-CHILD-HEIGHT';
    final source = _source('15.39');
    if (childOccupancyConfirmed == null) {
      return _indeterminate(
        ruleId: ruleId,
        source: source,
        message: 'Не определена применимость требования для помещений детей.',
        facts: const ['childOccupancyConfirmed=unknown'],
      );
    }
    if (!childOccupancyConfirmed) {
      return InstallationRuleResult(
        ruleId: ruleId,
        kind: InstallationRuleResultKind.notApplicable,
        message: 'Специальное требование 1800 mm к помещению не применяется.',
        source: source,
        evidence: NormativeEvidence(
          source: source,
          applicability: NormativeApplicability.notApplicable,
          facts: const ['childOccupancyConfirmed=false'],
          rationale: 'Профиль помещения не подтверждает пребывание детей.',
        ),
      );
    }
    if (heightMm == null || heightMm < 0) {
      return _indeterminate(
        ruleId: ruleId,
        source: source,
        message: 'Недостаточно корректных данных о высоте установки.',
        facts: ['heightMm=${heightMm ?? 'unknown'}'],
      );
    }
    final pass = heightMm == 1800;
    return _evaluated(
      ruleId: ruleId,
      source: source,
      pass: pass,
      facts: ['heightMm=$heightMm', 'requiredMm=1800'],
      passMessage: 'Высота соответствует специальному требованию 1800 mm.',
      failMessage: 'Для помещений пребывания детей требуется 1800 mm.',
    );
  }

  static InstallationGuideSource _source(String clause) =>
      InstallationGuideSource(
        code: sp404106.code,
        title: sp404106.title,
        clause: clause,
        revision: sp404106.revision,
        authority: InstallationGuideAuthority.normative,
      );

  static InstallationRuleResult _evaluated({
    required String ruleId,
    required InstallationGuideSource source,
    required bool pass,
    required Iterable<String> facts,
    required String passMessage,
    required String failMessage,
  }) =>
      InstallationRuleResult(
        ruleId: ruleId,
        kind: pass
            ? InstallationRuleResultKind.pass
            : InstallationRuleResultKind.fail,
        message: pass ? passMessage : failMessage,
        source: source,
        evidence: NormativeEvidence(
          source: source,
          applicability: NormativeApplicability.applicable,
          facts: facts,
          rationale: pass ? passMessage : failMessage,
        ),
      );

  static InstallationRuleResult _indeterminate({
    required String ruleId,
    required InstallationGuideSource source,
    required String message,
    required Iterable<String> facts,
  }) =>
      InstallationRuleResult(
        ruleId: ruleId,
        kind: InstallationRuleResultKind.indeterminate,
        message: message,
        source: source,
        evidence: NormativeEvidence(
          source: source,
          applicability: NormativeApplicability.indeterminate,
          facts: facts,
          rationale: message,
        ),
      );
}
