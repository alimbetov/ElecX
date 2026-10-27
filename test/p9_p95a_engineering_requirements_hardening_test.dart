import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/p9_canonical_serialization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-A engineering requirements hardening', () {
    test('P9.5-A-Q11 proven requirement rejects missing mandatory evidence',
        () {
      expect(
        () => _requirement(
          state: ApartmentEngineeringRequirementEvidenceState.proven,
          evidence: [_voltageEvidence()],
        ),
        throwsArgumentError,
      );
    });

    test('P9.5-A-Q12 proven requirement requires complete typed evidence', () {
      final requirement = _requirement(
        state: ApartmentEngineeringRequirementEvidenceState.proven,
        evidence: [_voltageEvidence(), _phaseCountEvidence()],
      );

      expect(requirement.isResolved, isTrue);
      expect(requirement.blocksEquipmentConfiguration, isFalse);
      expect(requirement.factEvidence.keys, [
        'supply.phaseCount',
        'supply.voltageV',
      ]);
      expect(requirement.establishedFacts['supply.voltageV'], '230 V');
      expect(requirement.establishedFacts['supply.phaseCount'], '3 count');
      expect(
        () => requirement.establishedFacts['fabricated'] = '1',
        throwsUnsupportedError,
      );
    });

    test('P9.5-A-Q13 indeterminate critical evidence blocks configuration', () {
      final safetyCritical = _requirement(
        state: ApartmentEngineeringRequirementEvidenceState.indeterminate,
        evidence: [_voltageEvidence()],
      );
      final advisory = _requirement(
        state: ApartmentEngineeringRequirementEvidenceState.indeterminate,
        criticality: ApartmentEngineeringRequirementCriticality.advisory,
        evidence: [_voltageEvidence()],
      );

      expect(safetyCritical.isResolved, isFalse);
      expect(safetyCritical.blocksEquipmentConfiguration, isTrue);
      expect(advisory.isResolved, isFalse);
      expect(advisory.blocksEquipmentConfiguration, isFalse);
    });

    test('P9.5-A-Q14 not-evaluated and N/A states cannot carry proven facts',
        () {
      for (final state in [
        ApartmentEngineeringRequirementEvidenceState.notEvaluated,
        ApartmentEngineeringRequirementEvidenceState.notApplicable,
      ]) {
        expect(
          () => _requirement(
            state: state,
            evidence: [_voltageEvidence()],
          ),
          throwsArgumentError,
        );
      }
    });

    test('P9.5-A-Q15 undeclared evidence fact fails closed', () {
      expect(
        () => _requirement(
          state: ApartmentEngineeringRequirementEvidenceState.indeterminate,
          evidence: [
            ApartmentEngineeringFactEvidence(
              factKey: 'supply.fabricatedCurrentA',
              valueKind: ApartmentEngineeringFactValueKind.integer,
              value: 16,
              unit: ApartmentEngineeringFactUnit.ampere,
              sourceId: 'project-input',
              sourceRevision: 'r1',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('P9.5-A-Q16 legacy string facts are rejected', () {
      expect(
        () => ApartmentEngineeringRequirement(
          requirementId: 'req-legacy',
          domain: ApartmentEngineeringRequirementDomain.supply,
          subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
          subjectStableId: 'projection-1',
          evidenceState: ApartmentEngineeringRequirementEvidenceState.proven,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          rationaleCode: 'test.legacy',
          requiredFactKeys: const ['supply.voltageV'],
          establishedFacts: const {'supply.voltageV': '230'},
        ),
        throwsArgumentError,
      );
    });

    test('P9.5-A-Q17 typed fact value must match declared value kind', () {
      expect(
        () => ApartmentEngineeringFactEvidence(
          factKey: 'supply.voltageV',
          valueKind: ApartmentEngineeringFactValueKind.integer,
          value: '230',
          unit: ApartmentEngineeringFactUnit.volt,
          sourceId: 'project-input',
          sourceRevision: 'r1',
        ),
        throwsArgumentError,
      );
      expect(
        () => ApartmentEngineeringFactEvidence(
          factKey: 'supply.voltageV',
          valueKind: ApartmentEngineeringFactValueKind.decimal,
          value: double.nan,
          unit: ApartmentEngineeringFactUnit.volt,
          sourceId: 'project-input',
          sourceRevision: 'r1',
        ),
        throwsArgumentError,
      );
    });

    test('P9.5-A-Q18 duplicate typed evidence fails closed', () {
      expect(
        () => _requirement(
          state: ApartmentEngineeringRequirementEvidenceState.indeterminate,
          evidence: [_voltageEvidence(), _voltageEvidence()],
        ),
        throwsArgumentError,
      );
    });

    test('P9.5-A-Q19 canonical encoding prevents delimiter collisions', () {
      final first = p9CanonicalSerializeFields(const [
        MapEntry('a', 'b|c=d'),
      ]);
      final second = p9CanonicalSerializeFields(const [
        MapEntry('a', 'b'),
        MapEntry('c', 'd'),
      ]);

      expect(first, isNot(second));
    });

    test('P9.5-A-Q20 typed provenance participates in deterministic identity',
        () {
      final first = _voltageEvidence();
      final same = _voltageEvidence();
      final differentRevision = ApartmentEngineeringFactEvidence(
        factKey: 'supply.voltageV',
        valueKind: ApartmentEngineeringFactValueKind.integer,
        value: 230,
        unit: ApartmentEngineeringFactUnit.volt,
        sourceId: 'project-input',
        sourceRevision: 'r2',
      );

      expect(first.stableSerialization, same.stableSerialization);
      expect(first.evidenceFingerprint, same.evidenceFingerprint);
      expect(
        differentRevision.evidenceFingerprint,
        isNot(first.evidenceFingerprint),
      );
      expect(apartmentEngineeringRequirementsVersion, 'p9.requirements.v3');
    });
  });
}

ApartmentEngineeringRequirement _requirement({
  required ApartmentEngineeringRequirementEvidenceState state,
  ApartmentEngineeringRequirementCriticality criticality =
      ApartmentEngineeringRequirementCriticality.safetyCritical,
  Iterable<ApartmentEngineeringFactEvidence> evidence = const [],
}) =>
    ApartmentEngineeringRequirement(
      requirementId: 'req-test',
      domain: ApartmentEngineeringRequirementDomain.supply,
      subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
      subjectStableId: 'projection-1',
      evidenceState: state,
      criticality: criticality,
      rationaleCode: 'test.requirement',
      requiredFactKeys: const [
        'supply.phaseCount',
        'supply.voltageV',
      ],
      factEvidence: evidence,
    );

ApartmentEngineeringFactEvidence _voltageEvidence() =>
    ApartmentEngineeringFactEvidence(
      factKey: 'supply.voltageV',
      valueKind: ApartmentEngineeringFactValueKind.integer,
      value: 230,
      unit: ApartmentEngineeringFactUnit.volt,
      sourceId: 'project-input',
      sourceRevision: 'r1',
    );

ApartmentEngineeringFactEvidence _phaseCountEvidence() =>
    ApartmentEngineeringFactEvidence(
      factKey: 'supply.phaseCount',
      valueKind: ApartmentEngineeringFactValueKind.integer,
      value: 3,
      unit: ApartmentEngineeringFactUnit.count,
      sourceId: 'project-input',
      sourceRevision: 'r1',
    );
