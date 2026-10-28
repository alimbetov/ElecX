import 'package:elecx/src/engine/kz_installation_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown measurement is indeterminate rather than pass or fail', () {
    final result = KzInstallationRules.validateResidentialSocketHeight(null);

    expect(result.kind, InstallationRuleResultKind.indeterminate);
    expect(result.isConclusive, isFalse);
    expect(result.evidence, isNotNull);
    expect(
      result.evidence!.applicability,
      NormativeApplicability.indeterminate,
    );
  });

  test('invalid negative measurement fails closed as indeterminate', () {
    final result = KzInstallationRules.validateDistanceToGasPipe(-1);

    expect(result.kind, InstallationRuleResultKind.indeterminate);
    expect(result.evidence!.facts, contains('distanceMm=-1'));
  });

  test('child occupancy applicability distinguishes N/A from unknown', () {
    final notApplicable = KzInstallationRules.validateChildOccupancyHeight(
      900,
      childOccupancyConfirmed: false,
    );
    final unknown = KzInstallationRules.validateChildOccupancyHeight(
      900,
      childOccupancyConfirmed: null,
    );

    expect(notApplicable.kind, InstallationRuleResultKind.notApplicable);
    expect(
      notApplicable.evidence!.applicability,
      NormativeApplicability.notApplicable,
    );
    expect(unknown.kind, InstallationRuleResultKind.indeterminate);
  });

  test('evaluated result carries pinned source revision and facts', () {
    final result = KzInstallationRules.validateGeneralLightingSwitchHeight(900);

    expect(result.kind, InstallationRuleResultKind.pass);
    expect(result.source!.revision, '2013');
    expect(result.source!.isRevisionPinned, isTrue);
    expect(result.source!.clause, '15.33');
    expect(result.evidence!.facts, contains('heightMm=900'));
  });
}
