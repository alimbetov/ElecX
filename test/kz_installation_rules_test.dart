import 'package:electra/src/engine/kz_installation_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('residential socket height allows values up to 1000 mm', () {
    expect(
      KzInstallationRules.validateResidentialSocketHeight(300).kind,
      InstallationRuleResultKind.pass,
    );
    expect(
      KzInstallationRules.validateResidentialSocketHeight(1000).kind,
      InstallationRuleResultKind.pass,
    );
    expect(
      KzInstallationRules.validateResidentialSocketHeight(1100).kind,
      InstallationRuleResultKind.fail,
    );
  });

  test('general lighting switch height is 800 to 1700 mm', () {
    expect(
      KzInstallationRules.validateGeneralLightingSwitchHeight(900).kind,
      InstallationRuleResultKind.pass,
    );
    expect(
      KzInstallationRules.validateGeneralLightingSwitchHeight(700).kind,
      InstallationRuleResultKind.fail,
    );
    expect(
      KzInstallationRules.validateGeneralLightingSwitchHeight(1800).kind,
      InstallationRuleResultKind.fail,
    );
  });

  test('gas pipe distance requires at least 500 mm', () {
    expect(
      KzInstallationRules.validateDistanceToGasPipe(500).kind,
      InstallationRuleResultKind.pass,
    );
    expect(
      KzInstallationRules.validateDistanceToGasPipe(499).kind,
      InstallationRuleResultKind.fail,
    );
  });

  test('child occupancy special profile requires 1800 mm', () {
    expect(
      KzInstallationRules.validateChildOccupancyHeight(1800).kind,
      InstallationRuleResultKind.pass,
    );
    expect(
      KzInstallationRules.validateChildOccupancyHeight(900).kind,
      InstallationRuleResultKind.fail,
    );
  });
}
