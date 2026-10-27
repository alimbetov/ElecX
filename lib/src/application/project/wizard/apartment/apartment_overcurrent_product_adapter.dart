import '../../../../domain/overcurrent_protection.dart';
import '../../../../engine/overcurrent_protection_selection_engine.dart';
import 'apartment_equipment_selection.dart';
import 'apartment_verified_product_catalog.dart';

/// Bridges verified P9.5-B product variants to the shared electrical
/// overcurrent-selection engine instead of reimplementing Ib <= In <= Iz.
final class ApartmentOvercurrentProtectionProductEvaluator {
  const ApartmentOvercurrentProtectionProductEvaluator();

  List<String> rejectionReasonCodes({
    required ApartmentVerifiedProductVariant variant,
    required ApartmentEquipmentConfigurationIntent intent,
    required double cableAmpacityA,
  }) {
    final kind = switch (variant.kind) {
      ApartmentEquipmentProductKind.circuitBreaker => OvercurrentDeviceKind.mcb,
      ApartmentEquipmentProductKind.rcbo => OvercurrentDeviceKind.rcbo,
      _ => throw ArgumentError.value(
          variant.kind,
          'variant.kind',
          'Only protective-device variants may enter overcurrent evaluation.',
        ),
    };
    final spec = OvercurrentProtectiveDeviceSpec(
      id: variant.variantId,
      kind: kind,
      ratedCurrentA: variant.ratings.ratedCurrentA!,
      breakingCapacityKa: variant.ratings.breakingCapacityKA!,
      poleCount: variant.ratings.poleCount!,
      sourceId: variant.technicalSourceId,
      sourceRevision: variant.technicalSourceRevision,
    );
    final result = OvercurrentProtectionSelectionEngine.select(
      OvercurrentProtectionRequest(
        designCurrentA: intent.designCurrentA,
        cableAmpacityA: cableAmpacityA,
        prospectiveShortCircuitCurrentA:
            intent.prospectiveShortCircuitCurrentA,
        candidates: [spec],
        allowedKinds: {kind},
      ),
    );
    final reasons = result.rejections[variant.variantId] ?? const <String>[];
    return List.unmodifiable(
      reasons.map((reason) => 'p9.equipment.reject.$reason'),
    );
  }
}
