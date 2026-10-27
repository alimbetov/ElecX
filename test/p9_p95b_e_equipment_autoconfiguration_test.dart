import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_evidence_binding.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_equipment_autoconfiguration_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_equipment_selection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_verified_product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-B..E equipment auto-configuration', () {
    test('P9.5-B-Q01 catalog fingerprint is deterministic and revision-aware',
        () {
      final variants = _variants();
      final first = _catalog(variants: variants);
      final reordered = _catalog(variants: variants.reversed);
      final revised = _catalog(variants: variants, revision: 'r2');

      expect(first.catalogFingerprint, reordered.catalogFingerprint);
      expect(first.catalogFingerprint, isNot(revised.catalogFingerprint));
    });

    test('P9.5-C-Q02 unresolved requirements fail closed', () {
      final result =
          const ApartmentEquipmentAutoConfigurationService().configure(
        requirements: _requirements(),
        catalog: _catalog(),
      );

      expect(result.accepted, isFalse);
      expect(result.configuration, isNull);
      expect(result.failures.single.code, 'EQUIPMENT_REQUIREMENTS_UNRESOLVED');
    });

    test('P9.5-CDE-Q03 selects eligible products and explains rejections', () {
      final requirements = _requirements().bindAuthoritativeEvidence(_facts());
      final result =
          const ApartmentEquipmentAutoConfigurationService().configure(
        requirements: requirements,
        catalog: _catalog(),
      );

      expect(requirements.readyForEquipmentConfiguration, isTrue);
      expect(result.accepted, isTrue);
      final configuration = result.configuration!;
      expect(
        configuration
            .selectedFor(ApartmentEquipmentConfigurationSlot.protection)
            .variantId,
        'rcbo-16a-6ka',
      );
      expect(
        configuration
            .selectedFor(ApartmentEquipmentConfigurationSlot.conductor)
            .variantId,
        'cable-2.5',
      );
      expect(
        configuration
            .selectedFor(ApartmentEquipmentConfigurationSlot.panel)
            .variantId,
        'panel-12',
      );
      expect(configuration.totalPriceMinor, 22300);
      expect(configuration.currencyCode, 'KZT');
      expect(
        configuration.rejectedCandidates.any(
          (decision) =>
              decision.variant.variantId == 'mcb-16a-6ka' &&
              decision.reasonCodes.contains(
                'p9.equipment.reject.residualProtectionMissing',
              ),
        ),
        isTrue,
      );
      expect(
        configuration.rejectedCandidates.any(
          (decision) =>
              decision.variant.variantId == 'rcbo-16a-badnorm' &&
              decision.state ==
                  ApartmentEquipmentCandidateState.normativeRejected,
        ),
        isTrue,
      );
    });

    test('P9.5-D-Q04 winner and fingerprint ignore catalog input order', () {
      final requirements = _requirements().bindAuthoritativeEvidence(_facts());
      const service = ApartmentEquipmentAutoConfigurationService();
      final first = service.configure(
        requirements: requirements,
        catalog: _catalog(),
      );
      final reversed = service.configure(
        requirements: requirements,
        catalog: _catalog(variants: _variants().reversed),
      );

      expect(first.configuration!.configurationFingerprint,
          reversed.configuration!.configurationFingerprint);
      for (final slot in ApartmentEquipmentConfigurationSlot.values) {
        expect(
          first.configuration!.selectedFor(slot).variantId,
          reversed.configuration!.selectedFor(slot).variantId,
        );
      }
    });

    test('P9.5-E-Q05 requirements and catalog provenance enter lineage', () {
      const service = ApartmentEquipmentAutoConfigurationService();
      final first = service.configure(
        requirements: _requirements().bindAuthoritativeEvidence(_facts()),
        catalog: _catalog(),
      );
      final revisedFacts = service.configure(
        requirements: _requirements().bindAuthoritativeEvidence(
          _facts(sourceRevision: 'engineering-r2'),
        ),
        catalog: _catalog(),
      );
      final revisedCatalog = service.configure(
        requirements: _requirements().bindAuthoritativeEvidence(_facts()),
        catalog: _catalog(revision: 'r2'),
      );

      expect(
        first.configuration!.configurationFingerprint,
        isNot(revisedFacts.configuration!.configurationFingerprint),
      );
      expect(
        first.configuration!.configurationFingerprint,
        isNot(revisedCatalog.configuration!.configurationFingerprint),
      );
    });

    test('P9.5-C-Q06 missing feasible equipment class blocks configuration',
        () {
      final requirements = _requirements().bindAuthoritativeEvidence(_facts());
      final withoutCable = _variants().where(
        (variant) => variant.kind != ApartmentEquipmentProductKind.cable,
      );
      final result =
          const ApartmentEquipmentAutoConfigurationService().configure(
        requirements: requirements,
        catalog: _catalog(variants: withoutCable),
      );

      expect(result.accepted, isFalse);
      expect(result.failures.single.code, 'EQUIPMENT_NO_ELIGIBLE_CONDUCTOR');
    });
  });
}

ApartmentEngineeringDesignRequirements _requirements() =>
    ApartmentEngineeringDesignRequirements(
      requirementsVersion: apartmentEngineeringRequirementsVersion,
      selectedCandidateFingerprint: 'candidate-fp',
      projectionFingerprint: 'projection-fp',
      graphFingerprint: 'graph-fp',
      placementFingerprint: 'placement-fp',
      normativeEvidenceFingerprint: 'normative-fp',
      normativeProfileId: 'kz.residential.lv',
      normativeProfileVersion: '2026.1',
      requirements: [
        _requirement(
          'supply',
          ApartmentEngineeringRequirementDomain.supply,
          const [
            'supply.availablePowerW',
            'supply.frequencyHz',
            'supply.phaseCount',
            'supply.prospectiveShortCircuitCurrentA',
            'supply.voltageV',
          ],
          ApartmentEngineeringRequirementCriticality.safetyCritical,
        ),
        _requirement(
          'load',
          ApartmentEngineeringRequirementDomain.load,
          const [
            'load.connectedPowerW',
            'load.designCurrentA',
            'load.designPowerW',
            'load.diversityPolicy',
          ],
          ApartmentEngineeringRequirementCriticality.engineeringCritical,
        ),
        _requirement(
          'circuit',
          ApartmentEngineeringRequirementDomain.circuit,
          const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
          ApartmentEngineeringRequirementCriticality.engineeringCritical,
        ),
        _requirement(
          'protection',
          ApartmentEngineeringRequirementDomain.protection,
          const [
            'protection.disconnection',
            'protection.overload',
            'protection.residualCurrent',
            'protection.shortCircuit',
          ],
          ApartmentEngineeringRequirementCriticality.safetyCritical,
        ),
      ],
    );

ApartmentEngineeringRequirement _requirement(
  String id,
  ApartmentEngineeringRequirementDomain domain,
  List<String> facts,
  ApartmentEngineeringRequirementCriticality criticality,
) =>
    ApartmentEngineeringRequirement(
      requirementId: 'req-$id',
      domain: domain,
      subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
      subjectStableId: 'projection-fp',
      evidenceState: ApartmentEngineeringRequirementEvidenceState.notEvaluated,
      criticality: criticality,
      rationaleCode: 'qualification.$id',
      requiredFactKeys: facts,
    );

List<ApartmentEngineeringFactEvidence> _facts({
  String sourceRevision = 'engineering-r1',
}) =>
    [
      _fact('supply.availablePowerW', 7000, ApartmentEngineeringFactUnit.watt,
          sourceRevision),
      _fact('supply.frequencyHz', 50, ApartmentEngineeringFactUnit.hertz,
          sourceRevision),
      _fact('supply.phaseCount', 1, ApartmentEngineeringFactUnit.count,
          sourceRevision),
      _fact('supply.prospectiveShortCircuitCurrentA', 4500,
          ApartmentEngineeringFactUnit.ampere, sourceRevision),
      _fact('supply.voltageV', 230, ApartmentEngineeringFactUnit.volt,
          sourceRevision),
      _fact('load.connectedPowerW', 3500, ApartmentEngineeringFactUnit.watt,
          sourceRevision),
      _fact('load.designCurrentA', 16, ApartmentEngineeringFactUnit.ampere,
          sourceRevision),
      _fact('load.designPowerW', 3680, ApartmentEngineeringFactUnit.watt,
          sourceRevision),
      _textFact('load.diversityPolicy', 'residential.v1', sourceRevision),
      _decimalFact('circuit.conductorConstraints', 2.5,
          ApartmentEngineeringFactUnit.squareMillimeter, sourceRevision),
      _textFact('circuit.definition', 'single-final-circuit', sourceRevision),
      _textFact('circuit.installationMethod', 'B2', sourceRevision),
      _textFact('circuit.loadAssignments', 'general-sockets', sourceRevision),
      _textFact('protection.disconnection', 'automatic-disconnection',
          sourceRevision),
      _fact('protection.overload', 16, ApartmentEngineeringFactUnit.ampere,
          sourceRevision),
      _fact('protection.residualCurrent', 30,
          ApartmentEngineeringFactUnit.milliampere, sourceRevision),
      _decimalFact('protection.shortCircuit', 6.0,
          ApartmentEngineeringFactUnit.kiloampere, sourceRevision),
    ];

ApartmentEngineeringFactEvidence _fact(
  String key,
  int value,
  ApartmentEngineeringFactUnit unit,
  String revision,
) =>
    ApartmentEngineeringFactEvidence(
      factKey: key,
      valueKind: ApartmentEngineeringFactValueKind.integer,
      value: value,
      unit: unit,
      sourceId: 'engineering-input',
      sourceRevision: revision,
    );

ApartmentEngineeringFactEvidence _decimalFact(
  String key,
  double value,
  ApartmentEngineeringFactUnit unit,
  String revision,
) =>
    ApartmentEngineeringFactEvidence(
      factKey: key,
      valueKind: ApartmentEngineeringFactValueKind.decimal,
      value: value,
      unit: unit,
      sourceId: 'engineering-input',
      sourceRevision: revision,
    );

ApartmentEngineeringFactEvidence _textFact(
  String key,
  String value,
  String revision,
) =>
    ApartmentEngineeringFactEvidence(
      factKey: key,
      valueKind: ApartmentEngineeringFactValueKind.text,
      value: value,
      unit: ApartmentEngineeringFactUnit.code,
      sourceId: 'engineering-input',
      sourceRevision: revision,
    );

ApartmentVerifiedProductVariantCatalog _catalog({
  Iterable<ApartmentVerifiedProductVariant>? variants,
  String revision = 'r1',
}) =>
    ApartmentVerifiedProductVariantCatalog(
      catalogId: 'qualification-catalog',
      catalogRevision: revision,
      sourceId: 'qualification-import',
      sourceRevision: '2026-10-27',
      currencyCode: 'KZT',
      variants: variants ?? _variants(),
    );

List<ApartmentVerifiedProductVariant> _variants() => [
      _protection('mcb-16a-6ka', ApartmentEquipmentProductKind.circuitBreaker,
          16, 6, 1, 5000),
      _protection(
          'rcbo-16a-3ka', ApartmentEquipmentProductKind.rcbo, 16, 3, 2, 8000),
      _protection(
          'rcbo-16a-6ka', ApartmentEquipmentProductKind.rcbo, 16, 6, 2, 12000),
      _protection('rcbo-20a-10ka', ApartmentEquipmentProductKind.rcbo, 20, 10,
          2, 11000),
      _protection('rcbo-16a-badnorm', ApartmentEquipmentProductKind.rcbo, 16, 6,
          2, 9000,
          profileId: 'other.profile'),
      _cable('cable-1.5', 1.5, 20, 200),
      _cable('cable-2.5', 2.5, 21, 300),
      _cable('cable-4.0', 4, 27, 350),
      _panel('panel-12', 12, 10000),
      _panel('panel-18', 18, 9000),
    ];

ApartmentVerifiedProductVariant _protection(
  String id,
  ApartmentEquipmentProductKind kind,
  double currentA,
  double breakingKA,
  int modules,
  int priceMinor, {
  String profileId = 'kz.residential.lv',
}) =>
    ApartmentVerifiedProductVariant(
      variantId: id,
      manufacturer: 'Qualification Manufacturer',
      model: id,
      kind: kind,
      ratings: ApartmentEquipmentTechnicalRatings(
        ratedVoltageV: 230,
        ratedCurrentA: currentA,
        breakingCapacityKA: breakingKA,
        residualCurrentMA:
            kind == ApartmentEquipmentProductKind.rcbo ? 30 : null,
        poleCount: kind == ApartmentEquipmentProductKind.rcbo ? 2 : 1,
        moduleWidth: modules,
      ),
      technicalSourceId: 'datasheet:$id',
      technicalSourceRevision: '1',
      price: _price(id, priceMinor),
      normativeDeclarations: [_declaration(id, profileId)],
    );

ApartmentVerifiedProductVariant _cable(
  String id,
  double crossSection,
  double ampacity,
  int priceMinor,
) =>
    ApartmentVerifiedProductVariant(
      variantId: id,
      manufacturer: 'Qualification Cable',
      model: id,
      kind: ApartmentEquipmentProductKind.cable,
      ratings: ApartmentEquipmentTechnicalRatings(
        conductorCrossSectionMm2: crossSection,
        currentCapacityA: ampacity,
      ),
      technicalSourceId: 'datasheet:$id',
      technicalSourceRevision: '1',
      price: _price(id, priceMinor),
      normativeDeclarations: [_declaration(id, 'kz.residential.lv')],
    );

ApartmentVerifiedProductVariant _panel(
  String id,
  int modules,
  int priceMinor,
) =>
    ApartmentVerifiedProductVariant(
      variantId: id,
      manufacturer: 'Qualification Panel',
      model: id,
      kind: ApartmentEquipmentProductKind.distributionBoard,
      ratings: ApartmentEquipmentTechnicalRatings(
        supportedPhaseCount: 1,
        moduleCapacity: modules,
      ),
      technicalSourceId: 'datasheet:$id',
      technicalSourceRevision: '1',
      price: _price(id, priceMinor),
      normativeDeclarations: [_declaration(id, 'kz.residential.lv')],
    );

ApartmentVerifiedPrice _price(String id, int amountMinor) =>
    ApartmentVerifiedPrice(
      amountMinor: amountMinor,
      currencyCode: 'KZT',
      sourceId: 'price:$id',
      sourceRevision: '2026-10-27',
    );

ApartmentProductNormativeDeclaration _declaration(
  String id,
  String profileId,
) =>
    ApartmentProductNormativeDeclaration(
      declarationId: 'norm:$id',
      profileId: profileId,
      profileVersion: '2026.1',
      sourceId: 'normative-source:$id',
      sourceRevision: '1',
    );
