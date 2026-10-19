import 'route_medium.dart';

enum ConductorMaterial { copper, aluminum, optical, other }

enum CableShielding { none, foil, braid, foilAndBraid, armor, other }

enum CableSegregationClass { power, data, control, safety, optical, coaxial, other }

final class CableSpec {
  const CableSpec({
    required this.id,
    required this.name,
    required this.medium,
    required this.outerDiameterMm,
    required this.segregationClass,
    this.conductorMaterial = ConductorMaterial.other,
    this.conductorCount,
    this.conductorCrossSectionMm2,
    this.pairCount,
    this.fiberCount,
    this.shielding = CableShielding.none,
    this.ratedVoltageV,
    this.category,
  })  : assert(outerDiameterMm > 0),
        assert(conductorCount == null || conductorCount > 0),
        assert(conductorCrossSectionMm2 == null || conductorCrossSectionMm2 > 0),
        assert(pairCount == null || pairCount > 0),
        assert(fiberCount == null || fiberCount > 0);

  final String id;
  final String name;
  final RouteMediumProfile medium;

  /// Overall cable diameter used by physical fill/capacity calculations.
  final double outerDiameterMm;
  final CableSegregationClass segregationClass;

  /// Electrical conductor properties. They intentionally stay separate from
  /// [outerDiameterMm]: conductor cross-section is not cable occupancy area.
  final ConductorMaterial conductorMaterial;
  final int? conductorCount;
  final double? conductorCrossSectionMm2;

  /// Communication-media capacity.
  final int? pairCount;
  final int? fiberCount;
  final CableShielding shielding;
  final int? ratedVoltageV;
  final String? category;

  bool get isPower => segregationClass == CableSegregationClass.power;
  bool get isData => segregationClass == CableSegregationClass.data;

  double get occupiedCircularAreaMm2 =>
      3.141592653589793 * outerDiameterMm * outerDiameterMm / 4;
}
