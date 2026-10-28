import 'apartment_equipment_selection.dart';
import 'apartment_verified_product_catalog.dart';
import 'p9_canonical_serialization.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

final class ApartmentEquipmentCandidateDecision {
  ApartmentEquipmentCandidateDecision({
    required this.variant,
    required this.slot,
    required this.state,
    required Iterable<String> reasonCodes,
    this.rank,
  }) : reasonCodes = List.unmodifiable(reasonCodes.toList()..sort());

  final ApartmentVerifiedProductVariant variant;
  final ApartmentEquipmentConfigurationSlot slot;
  final ApartmentEquipmentCandidateState state;
  final List<String> reasonCodes;
  final int? rank;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('variant', variant.variantFingerprint),
        MapEntry('slot', slot.name),
        MapEntry('state', state.name),
        MapEntry('rank', rank?.toString() ?? ''),
        for (final reason in reasonCodes) MapEntry('reason', reason),
      ]);
}

final class ApartmentEngineeringEquipmentConfiguration {
  ApartmentEngineeringEquipmentConfiguration({
    required this.requirementsFingerprint,
    required this.catalogFingerprint,
    required this.intentFingerprint,
    required this.normativeProfileId,
    required this.normativeProfileVersion,
    required this.currencyCode,
    required Map<ApartmentEquipmentConfigurationSlot,
            ApartmentVerifiedProductVariant>
        selectedVariants,
    required Iterable<ApartmentEquipmentCandidateDecision> decisions,
    this.configurationVersion = apartmentEquipmentConfigurationVersion,
  })  : selectedVariants = Map.unmodifiable(selectedVariants),
        decisions = List.unmodifiable(
          decisions.toList()
            ..sort((left, right) =>
                left.variant.variantId.compareTo(right.variant.variantId)),
        ) {
    if (configurationVersion.trim().isEmpty ||
        requirementsFingerprint.trim().isEmpty ||
        catalogFingerprint.trim().isEmpty ||
        intentFingerprint.trim().isEmpty ||
        normativeProfileId.trim().isEmpty ||
        normativeProfileVersion.trim().isEmpty ||
        selectedVariants.length !=
            ApartmentEquipmentConfigurationSlot.values.length) {
      throw ArgumentError('P9.5-E configuration envelope is incomplete.');
    }
    for (final slot in ApartmentEquipmentConfigurationSlot.values) {
      if (!this.selectedVariants.containsKey(slot)) {
        throw ArgumentError('P9.5-E configuration is missing ${slot.name}.');
      }
    }
  }

  final String configurationVersion;
  final String requirementsFingerprint;
  final String catalogFingerprint;
  final String intentFingerprint;
  final String normativeProfileId;
  final String normativeProfileVersion;
  final String currencyCode;
  final Map<ApartmentEquipmentConfigurationSlot,
      ApartmentVerifiedProductVariant> selectedVariants;
  final List<ApartmentEquipmentCandidateDecision> decisions;

  ApartmentVerifiedProductVariant selectedFor(
    ApartmentEquipmentConfigurationSlot slot,
  ) =>
      selectedVariants[slot]!;

  List<ApartmentEquipmentCandidateDecision> alternativesFor(
    ApartmentEquipmentConfigurationSlot slot,
  ) =>
      List.unmodifiable(
        decisions.where(
          (decision) =>
              decision.slot == slot &&
              decision.state == ApartmentEquipmentCandidateState.alternative,
        ),
      );

  List<ApartmentEquipmentCandidateDecision> get rejectedCandidates =>
      List.unmodifiable(
        decisions.where(
          (decision) =>
              decision.state ==
                  ApartmentEquipmentCandidateState.engineeringRejected ||
              decision.state ==
                  ApartmentEquipmentCandidateState.normativeRejected,
        ),
      );

  int get totalPriceMinor => selectedVariants.values.fold(
        0,
        (total, variant) => total + variant.price.amountMinor,
      );

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('configurationVersion', configurationVersion),
        MapEntry('requirementsFingerprint', requirementsFingerprint),
        MapEntry('catalogFingerprint', catalogFingerprint),
        MapEntry('intentFingerprint', intentFingerprint),
        MapEntry('normativeProfileId', normativeProfileId),
        MapEntry('normativeProfileVersion', normativeProfileVersion),
        MapEntry('currencyCode', currencyCode),
        for (final slot in ApartmentEquipmentConfigurationSlot.values)
          MapEntry(
            'selected.${slot.name}',
            selectedVariants[slot]!.variantFingerprint,
          ),
        for (final decision in decisions)
          MapEntry('decision', decision.stableSerialization),
      ]);

  String get configurationFingerprint => p9Sha256Hex(stableSerialization);
}

final class ApartmentEquipmentConfigurationResult {
  ApartmentEquipmentConfigurationResult({
    required this.configuration,
    Iterable<P9Failure> failures = const [],
  }) : failures = List.unmodifiable(failures);

  final ApartmentEngineeringEquipmentConfiguration? configuration;
  final List<P9Failure> failures;

  bool get accepted =>
      configuration != null && failures.every((failure) => !failure.isBlocker);
}
