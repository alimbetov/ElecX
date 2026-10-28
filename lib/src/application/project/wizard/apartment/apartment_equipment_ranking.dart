import 'apartment_equipment_selection.dart';
import 'apartment_verified_product_catalog.dart';

final class ApartmentEquipmentRankedCandidate {
  const ApartmentEquipmentRankedCandidate({
    required this.variant,
    required this.rank,
  });

  final ApartmentVerifiedProductVariant variant;
  final int rank;
}

/// P9.5-D deterministic ordering. Price is a tie-breaker after engineering
/// closeness; variant fingerprint is the final stable tie-breaker.
final class ApartmentEquipmentDeterministicRanker {
  const ApartmentEquipmentDeterministicRanker();

  List<ApartmentEquipmentRankedCandidate> rank({
    required ApartmentEquipmentConfigurationSlot slot,
    required Iterable<ApartmentVerifiedProductVariant> variants,
    required ApartmentEquipmentConfigurationIntent intent,
    int requiredPanelModules = 1,
  }) {
    final sorted = variants.toList()
      ..sort(
        (left, right) => _compare(
          slot: slot,
          left: left,
          right: right,
          intent: intent,
          requiredPanelModules: requiredPanelModules,
        ),
      );
    return List.unmodifiable([
      for (var index = 0; index < sorted.length; index++)
        ApartmentEquipmentRankedCandidate(
          variant: sorted[index],
          rank: index + 1,
        ),
    ]);
  }

  int _compare({
    required ApartmentEquipmentConfigurationSlot slot,
    required ApartmentVerifiedProductVariant left,
    required ApartmentVerifiedProductVariant right,
    required ApartmentEquipmentConfigurationIntent intent,
    required int requiredPanelModules,
  }) {
    int result;
    switch (slot) {
      case ApartmentEquipmentConfigurationSlot.protection:
        result = _compareDouble(
          left.ratings.ratedCurrentA! - intent.designCurrentA,
          right.ratings.ratedCurrentA! - intent.designCurrentA,
        );
        if (result != 0) return result;
        result = _compareDouble(
          left.ratings.breakingCapacityKA! -
              intent.prospectiveShortCircuitCurrentKA,
          right.ratings.breakingCapacityKA! -
              intent.prospectiveShortCircuitCurrentKA,
        );
        if (result != 0) return result;
        result = _compareDouble(
          intent.maximumResidualCurrentMA - left.ratings.residualCurrentMA!,
          intent.maximumResidualCurrentMA - right.ratings.residualCurrentMA!,
        );
        if (result != 0) return result;
        break;
      case ApartmentEquipmentConfigurationSlot.conductor:
        result = _compareDouble(
          left.ratings.conductorCrossSectionMm2! -
              intent.minimumConductorCrossSectionMm2,
          right.ratings.conductorCrossSectionMm2! -
              intent.minimumConductorCrossSectionMm2,
        );
        if (result != 0) return result;
        result = _compareDouble(
          left.ratings.currentCapacityA! - intent.designCurrentA,
          right.ratings.currentCapacityA! - intent.designCurrentA,
        );
        if (result != 0) return result;
        break;
      case ApartmentEquipmentConfigurationSlot.panel:
        result = (left.ratings.moduleCapacity! - requiredPanelModules)
            .compareTo(right.ratings.moduleCapacity! - requiredPanelModules);
        if (result != 0) return result;
        break;
    }

    result = left.price.amountMinor.compareTo(right.price.amountMinor);
    if (result != 0) return result;
    return left.variantFingerprint.compareTo(right.variantFingerprint);
  }
}

int _compareDouble(double left, double right) => left.compareTo(right);
