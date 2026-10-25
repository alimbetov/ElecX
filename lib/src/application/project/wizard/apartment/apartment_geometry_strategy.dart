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
/// New graph-aware work must be introduced as another strategy rather than
/// pushing geometry feasibility back into P9.4.
final class AccessSpineApartmentGeometryStrategyV1
    implements ApartmentGeometryStrategy {
  const AccessSpineApartmentGeometryStrategyV1();

  @override
  String get strategyId => 'p9.access-spine.v1';

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
