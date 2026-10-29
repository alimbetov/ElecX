import '../../../../domain/project_orientation.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_contracts.dart';
import 'building_common_core_composition.dart';
import 'building_generation_parameters.dart';
import 'building_level_stack_generator.dart';
import 'cottage_composition.dart';
import 'residential_tower_composition.dart';
import 'site_composition.dart';

/// P10 composition families exposed through the shared P8 Wizard runtime.
enum BuildingCompositionWizardFamily {
  cottage,
  residentialTower,
  residentialComplex,
}

/// Immutable P10 Wizard draft.
///
/// The draft owns only domain-backed generation input. It never owns a mutable
/// project copy, persistent identity or mutation session. Generate converts the
/// selected family into exactly one existing P10 [ReservedProjectCommand].
final class BuildingCompositionWizardParameters extends WizardParameters {
  BuildingCompositionWizardParameters._({
    required this.family,
    required this.compositionKey,
    this.buildingParameters,
    this.layout,
    Iterable<TowerApartmentRequest> towerApartments = const [],
    Iterable<SiteBuildingSlot> siteBuildings = const [],
    Iterable<SharedSiteAnchorRequest> sharedSiteAnchors = const [],
  })  : towerApartments = List.unmodifiable(towerApartments),
        siteBuildings = List.unmodifiable(siteBuildings),
        sharedSiteAnchors = List.unmodifiable(sharedSiteAnchors);

  factory BuildingCompositionWizardParameters.cottage({
    required String compositionKey,
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
  }) =>
      BuildingCompositionWizardParameters._(
        family: BuildingCompositionWizardFamily.cottage,
        compositionKey: compositionKey,
        buildingParameters: parameters,
        layout: layout,
      );

  factory BuildingCompositionWizardParameters.residentialTower({
    required String compositionKey,
    required BuildingGenerationParameters parameters,
    required BuildingCompositionLayout layout,
    required Iterable<TowerApartmentRequest> apartments,
  }) =>
      BuildingCompositionWizardParameters._(
        family: BuildingCompositionWizardFamily.residentialTower,
        compositionKey: compositionKey,
        buildingParameters: parameters,
        layout: layout,
        towerApartments: apartments,
      );

  factory BuildingCompositionWizardParameters.residentialComplex({
    required String compositionKey,
    required Iterable<SiteBuildingSlot> buildings,
    Iterable<SharedSiteAnchorRequest> sharedSiteAnchors = const [],
  }) =>
      BuildingCompositionWizardParameters._(
        family: BuildingCompositionWizardFamily.residentialComplex,
        compositionKey: compositionKey,
        siteBuildings: buildings,
        sharedSiteAnchors: sharedSiteAnchors,
      );

  final BuildingCompositionWizardFamily family;
  final String compositionKey;
  final BuildingGenerationParameters? buildingParameters;
  final BuildingCompositionLayout? layout;
  final List<TowerApartmentRequest> towerApartments;
  final List<SiteBuildingSlot> siteBuildings;
  final List<SharedSiteAnchorRequest> sharedSiteAnchors;
}

final class BuildingCompositionWizardProviderException implements Exception {
  const BuildingCompositionWizardProviderException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// P10.11 adapter into the one shared P8/P9 Wizard state machine.
///
/// Cottage, tower and multi-building Site generation deliberately retain their
/// existing production commands. Therefore Preview reserves identities once,
/// Apply commits the exact frozen candidate, stale confirmation fails closed and
/// the accepted generation occupies one canonical Undo boundary.
final class BuildingCompositionWizardProvider
    extends TypedWizardProvider<BuildingCompositionWizardParameters> {
  const BuildingCompositionWizardProvider();

  static final WizardFamilyId familyId =
      WizardFamilyId('p10-building-composition');

  @override
  WizardProviderDescriptor get descriptor => WizardProviderDescriptor(
        templateId: TemplateId('p10-building-composition'),
        templateVersion: 1,
        generatorVersion: 'p10.11.v1',
        familyId: familyId,
        displayName: 'Residential building composition',
        supportedScopes: const {WizardTargetScope.site},
      );

  @override
  BuildingCompositionWizardParameters typedDefaultsFor(
    WizardTargetContext target,
  ) {
    final levels = const BuildingLevelStackGenerator().residentialParameters(
      upperResidentialLevels: 1,
      includeRoof: true,
      groundHeightMm: 3200,
      residentialHeightMm: 3200,
      roofHeightMm: 2800,
    );
    return BuildingCompositionWizardParameters.cottage(
      compositionKey: 'cottage.main',
      parameters: BuildingGenerationParameters(
        kind: BuildingCompositionKind.detachedHouse,
        siteId: target.siteId,
        displayName: 'Cottage',
        placement: BuildingSitePlacement(
          xMm: 0,
          yMm: 0,
          orientation: ProjectEngineeringNorth.fromDegrees(0),
        ),
        levelStack: levels,
        commonCore: CommonCoreParameters.v2(
          stairCount: 1,
          liftCount: 0,
          serviceShaftCount: 0,
          electricalRiserCount: 1,
          telecomRiserCount: 1,
          corridorWidthMm: 1800,
          includeTechnicalRoom: true,
          serviceSpacePolicy: const CommonServiceSpacePolicy(
            includeCommonHall: true,
            includeElevatorHall: false,
            includeElectricalRoomCandidate: true,
            includeTelecomRoomCandidate: true,
            includeUtilityRoomCandidate: true,
          ),
        ),
        serviceAnchors: ServiceAnchorParameters(
          kinds: const {
            BuildingServiceAnchorKind.electricalEntry,
            BuildingServiceAnchorKind.telecomEntry,
          },
        ),
      ),
      layout: CottageCompositionLayout(
        footprintWidthMm: 18000,
        footprintDepthMm: 12000,
        commonCore: CommonCoreLayoutParameters(
          originXmm: 1000,
          originYmm: 3500,
          corridorLengthMm: 16000,
        ),
      ),
    );
  }

  @override
  WizardParameterValidation validateTypedParameters(
    BuildingCompositionWizardParameters parameters,
    WizardTargetContext target,
  ) {
    final issues = <WizardValidationIssue>[];
    void blocker(String code, String message) => issues.add(
          WizardValidationIssue(
            code: code,
            message: message,
            severity: WizardIssueSeverity.blocker,
          ),
        );

    if (target is! SiteWizardTarget) {
      blocker(
        'p10.wizard.target.unsupported',
        'Building composition requires a Site target.',
      );
      return WizardParameterValidation(issues);
    }
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$')
        .hasMatch(parameters.compositionKey.trim())) {
      blocker(
        'p10.wizard.composition-key.invalid',
        'Composition key must be a stable semantic key.',
      );
    }

    switch (parameters.family) {
      case BuildingCompositionWizardFamily.cottage:
        final building = parameters.buildingParameters;
        if (building == null || parameters.layout == null) {
          blocker('p10.wizard.cottage.incomplete', 'Cottage input is incomplete.');
        } else {
          if (building.siteId != target.siteId) {
            blocker('p10.wizard.site-mismatch', 'Cottage belongs to another Site.');
          }
          if (building.kind != BuildingCompositionKind.detachedHouse) {
            blocker('p10.wizard.cottage.kind', 'Cottage requires detached-house parameters.');
          }
        }
      case BuildingCompositionWizardFamily.residentialTower:
        final building = parameters.buildingParameters;
        if (building == null ||
            parameters.layout == null ||
            parameters.towerApartments.isEmpty) {
          blocker('p10.wizard.tower.incomplete', 'Tower input is incomplete.');
        } else {
          if (building.siteId != target.siteId) {
            blocker('p10.wizard.site-mismatch', 'Tower belongs to another Site.');
          }
          if (building.kind != BuildingCompositionKind.residentialTower) {
            blocker('p10.wizard.tower.kind', 'Tower requires residential-tower parameters.');
          }
        }
      case BuildingCompositionWizardFamily.residentialComplex:
        if (parameters.siteBuildings.isEmpty) {
          blocker(
            'p10.wizard.site.empty',
            'Residential-complex composition requires building slots.',
          );
        }
        for (final slot in parameters.siteBuildings) {
          if (slot.parameters.siteId != target.siteId) {
            blocker(
              'p10.wizard.site-mismatch',
              'A residential-complex slot belongs to another Site.',
            );
            break;
          }
        }
    }
    return WizardParameterValidation(issues);
  }

  @override
  ReservedProjectCommand generateTyped(
    BuildingCompositionWizardParameters parameters,
    WizardGenerationContext context,
  ) {
    final validation = validateTypedParameters(parameters, context.target);
    if (validation.hasBlockers) {
      throw const BuildingCompositionWizardProviderException(
        'p10.wizard.parameters.invalid',
      );
    }
    if (context.target is! SiteWizardTarget) {
      throw const BuildingCompositionWizardProviderException(
        'p10.wizard.target.unsupported',
      );
    }

    return switch (parameters.family) {
      BuildingCompositionWizardFamily.cottage =>
        CottageCompositionCommand.create(
          project: context.project,
          compositionKey: parameters.compositionKey,
          parameters: parameters.buildingParameters!,
          layout: parameters.layout!,
        ),
      BuildingCompositionWizardFamily.residentialTower =>
        ResidentialTowerCompositionCommand.create(
          project: context.project,
          compositionKey: parameters.compositionKey,
          parameters: parameters.buildingParameters!,
          layout: parameters.layout!,
          requests: parameters.towerApartments,
        ),
      BuildingCompositionWizardFamily.residentialComplex =>
        SiteCompositionCommand.create(
          project: context.project,
          compositionKey: parameters.compositionKey,
          slots: parameters.siteBuildings,
          anchors: parameters.sharedSiteAnchors,
        ),
    };
  }
}
