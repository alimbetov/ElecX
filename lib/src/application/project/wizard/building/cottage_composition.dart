import '../../composition_provenance_command.dart';
import 'p10_generation_evidence.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import 'building_generation_parameters.dart';
import 'building_level_stack_generator.dart';
import 'building_shell_composition.dart';

typedef CottageCompositionLayout = BuildingCompositionLayout;
typedef CottageSlabProposal = BuildingSlabProposal;
typedef CottageCompositionPlan = BuildingShellCompositionPlan;

final class CottageCompositionException implements Exception {
  const CottageCompositionException(this.code);

  final String code;

  @override
  String toString() => code;
}

final class CottageCompositionGenerator {
  const CottageCompositionGenerator();

  CottageCompositionPlan generate({
    required String compositionKey,
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
  }) {
    final key = compositionKey.trim();
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(key)) {
      throw ArgumentError.value(
        compositionKey,
        'compositionKey',
        'Expected a stable semantic key.',
      );
    }
    if (parameters.kind != BuildingCompositionKind.detachedHouse) {
      throw const CottageCompositionException('p10.cottage.kind-not-detached');
    }
    if (!parameters.commonCore.isCurrentContract) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-v2-required',
      );
    }
    if (parameters.typicalFloor != null) {
      throw const CottageCompositionException(
        'p10.cottage.typical-floor-not-supported',
      );
    }
    if (parameters.placement.orientation.milliDegreesClockwiseFromPositiveY !=
        0) {
      throw const CottageCompositionException(
        'p10.cottage.rotated-site-placement-deferred',
      );
    }

    final levels = parameters.levelStack.levels;
    final basementCount =
        levels.where((level) => level.kind == ProjectLevelKind.basement).length;
    final technicalCount = levels
        .where((level) => level.kind == ProjectLevelKind.technical)
        .length;
    final occupiableCount = levels
        .where(
          (level) =>
              level.kind == ProjectLevelKind.ground ||
              level.kind == ProjectLevelKind.residential,
        )
        .length;
    if (basementCount > 1) {
      throw const CottageCompositionException(
        'p10.cottage.multiple-basements-not-supported',
      );
    }
    if (technicalCount > 1) {
      throw const CottageCompositionException(
        'p10.cottage.multiple-technical-levels-not-supported',
      );
    }
    if (occupiableCount < 1 || occupiableCount > 4) {
      throw const CottageCompositionException(
        'p10.cottage.occupiable-level-count-out-of-range',
      );
    }

    final servedLevels =
        levels.where((level) => level.kind != ProjectLevelKind.roof).toList();
    if (servedLevels.length > 1 && parameters.commonCore.stairCount < 1) {
      throw const CottageCompositionException(
        'p10.cottage.internal-stair-required',
      );
    }
    final coreCount = parameters.commonCore.stairCount +
        parameters.commonCore.liftCount +
        parameters.commonCore.serviceShaftCount +
        parameters.commonCore.electricalRiserCount +
        parameters.commonCore.telecomRiserCount;
    if (servedLevels.length < 2 && coreCount > 0) {
      throw const CottageCompositionException(
        'p10.cottage.single-level-core-not-supported',
      );
    }

    _validateLayout(parameters: parameters, layout: layout);
    final levelStack = const BuildingLevelStackGenerator().generate(
      buildingGenerationKey: key,
      parameters: parameters.levelStack,
    );
    final slabs = <CottageSlabProposal>[];
    for (var index = 0; index < levels.length - 1; index++) {
      final below = levels[index];
      final above = levels[index + 1];
      slabs.add(
        CottageSlabProposal(
          semanticKey: 'slab:${below.generationKey}:${above.generationKey}',
          belowLevelGenerationKey: below.generationKey,
          aboveLevelGenerationKey: above.generationKey,
        ),
      );
    }
    return CottageCompositionPlan(
      compositionKey: key,
      generatorVersion: 'p10.cottage.v1',
      parameters: parameters,
      layout: layout,
      levelStack: levelStack,
      commonCoreLevelGenerationKeys:
          servedLevels.map((level) => level.generationKey),
      slabs: slabs,
    );
  }

  void _validateLayout({
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
  }) {
    final placement = parameters.placement;
    final left = placement.xMm;
    final right = left + layout.footprintWidthMm;
    final bottom = placement.yMm;
    final top = bottom + layout.footprintDepthMm;
    final core = layout.commonCore;
    if (core.originXmm < left ||
        core.originXmm + core.corridorLengthMm > right ||
        core.originYmm < bottom ||
        core.originYmm + parameters.commonCore.corridorWidthMm > top) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-outside-footprint',
      );
    }
    final topSpaceCount =
        (parameters.commonCore.serviceSpacePolicy.includeCommonHall ? 1 : 0) +
            (parameters.commonCore.serviceSpacePolicy.includeElevatorHall &&
                    parameters.commonCore.liftCount > 0
                ? 1
                : 0) +
            parameters.commonCore.stairCount +
            parameters.commonCore.liftCount +
            parameters.commonCore.serviceShaftCount +
            parameters.commonCore.electricalRiserCount +
            parameters.commonCore.telecomRiserCount;
    final bottomSpaceCount = (parameters.commonCore.includeTechnicalRoom
            ? 1
            : 0) +
        (parameters.commonCore.serviceSpacePolicy.includeElectricalRoomCandidate
            ? 1
            : 0) +
        (parameters.commonCore.serviceSpacePolicy.includeTelecomRoomCandidate
            ? 1
            : 0) +
        (parameters
                .commonCore.serviceSpacePolicy.includeFireControlRoomCandidate
            ? 1
            : 0) +
        (parameters.commonCore.serviceSpacePolicy.includeUtilityRoomCandidate
            ? 1
            : 0);
    if (topSpaceCount * core.coreModuleWidthMm > core.corridorLengthMm ||
        bottomSpaceCount * core.candidateRoomWidthMm > core.corridorLengthMm) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-layout-overflow',
      );
    }
    if (topSpaceCount > 0 &&
        core.originYmm +
                parameters.commonCore.corridorWidthMm +
                core.coreDepthMm >
            top) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-outside-footprint',
      );
    }
    if (bottomSpaceCount > 0 &&
        core.originYmm - core.candidateRoomDepthMm < bottom) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-outside-footprint',
      );
    }
  }
}

final class CottageCompositionCommand implements CompositionProvenanceSource {
  @override
  CompositionGenerationEvidence get generationEvidence => p10GenerationEvidence(
      plan.generatorVersion,
      plan.semanticFingerprint,
      {plan.compositionKey: plan.parameters});

  CottageCompositionCommand._(this._delegate);
  factory CottageCompositionCommand.create({
    required ProjectAggregateRoot project,
    required String compositionKey,
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
    CottageCompositionGenerator generator = const CottageCompositionGenerator(),
    bool allowExistingBuildings = false,
  }) {
    _requireCottageSite(project, parameters.siteId,
        allowExistingBuildings: allowExistingBuildings);
    CottageCompositionPlan generate() => generator.generate(
        compositionKey: compositionKey, parameters: parameters, layout: layout);
    return CottageCompositionCommand._(BuildingShellCompositionCommand(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
        plan: generate(),
        revalidatePlan: () => generate().semanticFingerprint,
        commandType: 'p10.cottage.compose',
        allowExistingBuildings: allowExistingBuildings));
  }
  final BuildingShellCompositionCommand _delegate;
  ProjectId get projectId => _delegate.projectId;
  SiteId get siteId => _delegate.siteId;
  LocalProjectVersion get baseVersion => _delegate.baseVersion;
  CottageCompositionPlan get plan => _delegate.plan;
  String get buildingSlot => _delegate.buildingSlot;
  @override
  String get commandType => _delegate.commandType;
  @override
  String get normalizedIntentKey => _delegate.normalizedIntentKey;
  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      _delegate.reserveIdentities(factory);
  @override
  void validateReservation(
          {required ProjectAggregateRoot current,
          required MutationIdentityReservation reservation}) =>
      _delegate.validateReservation(current: current, reservation: reservation);
  @override
  ProjectCommandCandidate buildCandidate(
          {required ProjectAggregateRoot current,
          required MutationIdentityReservation reservation}) =>
      _delegate.buildCandidate(current: current, reservation: reservation);
  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
          {required ProjectAggregateRoot before,
          required ProjectAggregateRoot candidate,
          required MutationIdentityReservation reservation}) =>
      _delegate.semanticOperations(
          before: before, candidate: candidate, reservation: reservation);
}

void _requireCottageSite(ProjectAggregateRoot project, SiteId requestedSiteId,
    {bool allowExistingBuildings = false}) {
  if (project.siteId != requestedSiteId) {
    throw const CottageCompositionException('p10.cottage.foreign-site');
  }
  final site = project.stores.sites[requestedSiteId];
  if (site == null) {
    throw const CottageCompositionException('p10.cottage.site-missing');
  }
  if (!allowExistingBuildings && site.buildingIds.isNotEmpty) {
    throw const CottageCompositionException('p10.cottage.site-not-empty');
  }
}
