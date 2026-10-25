import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_access_spine_geometry_generator.dart';
import 'apartment_geometry_generator.dart';
import 'apartment_wizard_parameters.dart';

/// Versioned P9.6 packing strategy boundary.
///
/// P9.4 fitted areas and P9.5 semantic constraints are strategy-independent.
/// Different bounded geometry solvers may be qualified against the same input
/// without changing upstream fingerprints or allocating canonical project IDs.
abstract interface class ApartmentGeometryStrategy {
  String get strategyId;

  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  });
}

/// Historical access-spine strategy retained as an explicit V1 implementation.
///
/// V1 accepts only hub-and-spoke semantic access: every non-hub interior space
/// must have a direct access edge to the distribution hub.
final class AccessSpineApartmentGeometryStrategyV1
    implements ApartmentGeometryStrategy {
  const AccessSpineApartmentGeometryStrategyV1();

  @override
  String get strategyId =>
      ApartmentAccessSpineGeometryGenerator.accessSpineV1AlgorithmVersion;

  @override
  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) =>
      const ApartmentAccessSpineGeometryGenerator().generate(
        fittedDraft: fittedDraft,
        semanticValidation: semanticValidation,
        template: template,
        request: request,
      );
}

/// Graph-aware P9.6 strategy.
///
/// V2 accepts bounded semantic access trees/graphs as long as every interior
/// space is reachable from the circulation hub. The packing engine is still
/// deterministic and does not invent extra access intents: actual doors/open
/// passages remain those provided by the P9.5 handoff and are independently
/// checked by the post-packing access validator.
final class GraphAwareApartmentGeometryStrategyV2
    implements ApartmentGeometryStrategy {
  const GraphAwareApartmentGeometryStrategyV2();

  @override
  String get strategyId =>
      ApartmentAccessSpineGeometryGenerator.graphAwareV2AlgorithmVersion;

  @override
  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) =>
      const ApartmentAccessSpineGeometryGenerator(
        accessTopologyPolicy: ApartmentAccessTopologyPolicy.graphReachable,
      ).generate(
        fittedDraft: fittedDraft,
        semanticValidation: semanticValidation,
        template: template,
        request: request,
      );
}
