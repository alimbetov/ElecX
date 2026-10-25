import '../../../../domain/apartment_topology.dart';
import '../wizard_contracts.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

/// Raw typed P9 user intent after presentation has converted localized input
/// into engineering units. This object intentionally permits invalid ranges so
/// validation can report all actionable issues together instead of throwing on
/// the first field.
final class ApartmentRequestInput {
  const ApartmentRequestInput({
    required this.habitableRoomCount,
    required this.approximateAreaDm2,
    required this.bathroomCount,
    required this.separateWcCount,
    required this.balconyCount,
    required this.balconyKind,
    required this.kitchenMode,
    required this.corridorMode,
    required this.exteriorExposurePreference,
    this.areaBasis = ApartmentAreaBasis.interiorNetExcludingExteriorAppendages,
    this.preferredFamily,
    this.preferDayNightSeparation = false,
  });

  static const productionDefaults = ApartmentRequestInput(
    habitableRoomCount: 2,
    approximateAreaDm2: 6000,
    bathroomCount: 1,
    separateWcCount: 0,
    balconyCount: 0,
    balconyKind: ApartmentBalconyKind.either,
    kitchenMode: ApartmentKitchenMode.separate,
    corridorMode: ApartmentCorridorMode.auto,
    exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
  );

  final int habitableRoomCount;
  final int approximateAreaDm2;
  final ApartmentAreaBasis areaBasis;
  final int bathroomCount;
  final int separateWcCount;
  final int balconyCount;
  final ApartmentBalconyKind balconyKind;
  final ApartmentKitchenMode kitchenMode;
  final ApartmentCorridorMode corridorMode;
  final ApartmentExteriorExposurePreference exteriorExposurePreference;
  final ApartmentTopologyFamily? preferredFamily;
  final bool preferDayNightSeparation;
}

/// Transient exact card identity. It contains no canonical project entity IDs.
///
/// [candidateSetFingerprint] binds a production Wizard selection to the exact
/// ordered recommendation set from which it was chosen. Lower-level identity
/// tests may omit it, but the P9.9 provider requires it before preview handoff.
final class ApartmentCandidateSelection {
  ApartmentCandidateSelection({
    required String candidateFingerprint,
    required String templateIdValue,
    required this.templateVersion,
    required String variantSeedId,
    String? candidateSetFingerprint,
  })  : candidateFingerprint = _requireNonEmpty(
          candidateFingerprint,
          'candidateFingerprint',
        ),
        templateIdValue = _requireNonEmpty(templateIdValue, 'templateIdValue'),
        variantSeedId = _requireNonEmpty(variantSeedId, 'variantSeedId'),
        candidateSetFingerprint = candidateSetFingerprint == null
            ? null
            : _requireNonEmpty(
                candidateSetFingerprint,
                'candidateSetFingerprint',
              ) {
    if (templateVersion <= 0) {
      throw ArgumentError.value(
        templateVersion,
        'templateVersion',
        'Must be positive.',
      );
    }
  }

  final String candidateFingerprint;
  final String templateIdValue;
  final int templateVersion;
  final String variantSeedId;
  final String? candidateSetFingerprint;
}

/// P8 provider wrapper. User intent and card selection remain separate values.
final class ApartmentWizardParameters extends WizardParameters {
  const ApartmentWizardParameters({required this.request, this.selection});

  final ApartmentRequestInput request;
  final ApartmentCandidateSelection? selection;

  /// Replaces semantic input and invalidates selection exactly when normalized
  /// intent changes. Invalid new input always clears selection.
  ApartmentWizardParameters withRequest(ApartmentRequestInput nextRequest) {
    const normalizer = ApartmentRequestNormalizer();
    final current = normalizer.normalize(request);
    final next = normalizer.normalize(nextRequest);
    final canKeepSelection = current.request != null &&
        next.request != null &&
        current.request!.intentFingerprint == next.request!.intentFingerprint;
    return ApartmentWizardParameters(
      request: nextRequest,
      selection: canKeepSelection ? selection : null,
    );
  }

  ApartmentWizardParameters withSelection(
    ApartmentCandidateSelection? nextSelection,
  ) =>
      ApartmentWizardParameters(
        request: request,
        selection: nextSelection,
      );
}

/// Immutable normalized P9.1 request consumed by P9.2+ pure stages.
final class NormalizedApartmentRequest {
  const NormalizedApartmentRequest({
    required this.schemaVersion,
    required this.habitableRoomCount,
    required this.interiorAreaDm2,
    required this.areaBasis,
    required this.bathroomCount,
    required this.separateWcCount,
    required this.balconyCount,
    required this.balconyKind,
    required this.kitchenMode,
    required this.corridorMode,
    required this.exteriorExposurePreference,
    required this.preferredFamily,
    required this.preferDayNightSeparation,
    required this.canonicalSerialization,
    required this.intentFingerprint,
  });

  final int schemaVersion;
  final int habitableRoomCount;
  final int interiorAreaDm2;
  final ApartmentAreaBasis areaBasis;
  final int bathroomCount;
  final int separateWcCount;
  final int balconyCount;
  final ApartmentBalconyKind balconyKind;
  final ApartmentKitchenMode kitchenMode;
  final ApartmentCorridorMode corridorMode;
  final ApartmentExteriorExposurePreference exteriorExposurePreference;
  final ApartmentTopologyFamily? preferredFamily;
  final bool preferDayNightSeparation;
  final String canonicalSerialization;
  final String intentFingerprint;
}

final class ApartmentRequestNormalizationResult {
  ApartmentRequestNormalizationResult({
    required this.request,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final NormalizedApartmentRequest? request;
  final List<P9Failure> failures;

  bool get hasBlockers => failures.any((failure) => failure.isBlocker);
  bool get isValid => request != null && !hasBlockers;
}

/// P9.1 fail-closed normalization and validation service.
final class ApartmentRequestNormalizer {
  const ApartmentRequestNormalizer();

  static const int schemaVersion = 1;
  static const int minHabitableRooms = 1;
  static const int maxHabitableRooms = 10;
  static const int minInteriorAreaDm2 = 1500;
  static const int maxInteriorAreaDm2 = 50000;
  static const int minBathroomCount = 1;
  static const int maxBathroomCount = 6;
  static const int minSeparateWcCount = 0;
  static const int maxSeparateWcCount = 4;
  static const int minBalconyCount = 0;
  static const int maxBalconyCount = 6;

  ApartmentRequestNormalizationResult normalize(ApartmentRequestInput input) {
    final failures = <P9Failure>[];

    _validateRange(
      failures,
      code: 'p9.parameters.room-count-out-of-range',
      field: 'habitableRoomCount',
      value: input.habitableRoomCount,
      min: minHabitableRooms,
      max: maxHabitableRooms,
    );
    _validateRange(
      failures,
      code: 'p9.parameters.area-out-of-range',
      field: 'approximateAreaDm2',
      value: input.approximateAreaDm2,
      min: minInteriorAreaDm2,
      max: maxInteriorAreaDm2,
    );
    _validateRange(
      failures,
      code: 'p9.parameters.bathroom-count-out-of-range',
      field: 'bathroomCount',
      value: input.bathroomCount,
      min: minBathroomCount,
      max: maxBathroomCount,
    );
    _validateRange(
      failures,
      code: 'p9.parameters.wc-count-out-of-range',
      field: 'separateWcCount',
      value: input.separateWcCount,
      min: minSeparateWcCount,
      max: maxSeparateWcCount,
    );
    _validateRange(
      failures,
      code: 'p9.parameters.balcony-count-out-of-range',
      field: 'balconyCount',
      value: input.balconyCount,
      min: minBalconyCount,
      max: maxBalconyCount,
    );

    if (input.balconyCount > 0 &&
        input.balconyKind == ApartmentBalconyKind.none) {
      failures.add(
        P9Failure(
          code: 'p9.parameters.invalid-balcony-kind',
          stage: P9FailureStage.parameters,
          severity: P9FailureSeverity.blocker,
          facts: {
            'balconyCount': input.balconyCount,
            'balconyKind': input.balconyKind.code,
          },
        ),
      );
    }
    if (input.separateWcCount > 0 && input.bathroomCount < 1) {
      failures.add(
        P9Failure(
          code: 'p9.parameters.invalid-combination',
          stage: P9FailureStage.parameters,
          severity: P9FailureSeverity.blocker,
          facts: {
            'bathroomCount': input.bathroomCount,
            'separateWcCount': input.separateWcCount,
            'reason': 'separateWcRequiresBathroom',
          },
        ),
      );
    }

    if (failures.any((failure) => failure.isBlocker)) {
      return ApartmentRequestNormalizationResult(
        request: null,
        failures: failures,
      );
    }

    final normalizedBalconyKind =
        input.balconyCount == 0 ? ApartmentBalconyKind.none : input.balconyKind;
    final canonicalSerialization = _serialize(
      habitableRoomCount: input.habitableRoomCount,
      interiorAreaDm2: input.approximateAreaDm2,
      areaBasis: input.areaBasis,
      bathroomCount: input.bathroomCount,
      separateWcCount: input.separateWcCount,
      balconyCount: input.balconyCount,
      balconyKind: normalizedBalconyKind,
      kitchenMode: input.kitchenMode,
      corridorMode: input.corridorMode,
      exteriorExposurePreference: input.exteriorExposurePreference,
      preferredFamily: input.preferredFamily,
      preferDayNightSeparation: input.preferDayNightSeparation,
    );
    final fingerprint = p9Sha256Hex(canonicalSerialization);

    return ApartmentRequestNormalizationResult(
      request: NormalizedApartmentRequest(
        schemaVersion: schemaVersion,
        habitableRoomCount: input.habitableRoomCount,
        interiorAreaDm2: input.approximateAreaDm2,
        areaBasis: input.areaBasis,
        bathroomCount: input.bathroomCount,
        separateWcCount: input.separateWcCount,
        balconyCount: input.balconyCount,
        balconyKind: normalizedBalconyKind,
        kitchenMode: input.kitchenMode,
        corridorMode: input.corridorMode,
        exteriorExposurePreference: input.exteriorExposurePreference,
        preferredFamily: input.preferredFamily,
        preferDayNightSeparation: input.preferDayNightSeparation,
        canonicalSerialization: canonicalSerialization,
        intentFingerprint: fingerprint,
      ),
      failures: failures,
    );
  }

  List<P9Failure> validateTarget(WizardTargetContext target) {
    if (target is LevelWizardTarget) {
      return const [];
    }
    return [
      P9Failure(
        code: 'p9.parameters.unsupported-target',
        stage: P9FailureStage.parameters,
        severity: P9FailureSeverity.blocker,
        facts: {'actualScope': target.scope.name, 'requiredScope': 'level'},
      ),
    ];
  }

  void _validateRange(
    List<P9Failure> failures, {
    required String code,
    required String field,
    required int value,
    required int min,
    required int max,
  }) {
    if (value >= min && value <= max) {
      return;
    }
    failures.add(
      P9Failure(
        code: code,
        stage: P9FailureStage.parameters,
        severity: P9FailureSeverity.blocker,
        facts: {'field': field, 'value': value, 'min': min, 'max': max},
        suggestions: [
          P9Suggestion(
            field: field,
            currentValue: value,
            suggestedValue: value < min ? min : max,
            reasonCode: 'nearestAllowedValue',
          ),
        ],
      ),
    );
  }

  String _serialize({
    required int habitableRoomCount,
    required int interiorAreaDm2,
    required ApartmentAreaBasis areaBasis,
    required int bathroomCount,
    required int separateWcCount,
    required int balconyCount,
    required ApartmentBalconyKind balconyKind,
    required ApartmentKitchenMode kitchenMode,
    required ApartmentCorridorMode corridorMode,
    required ApartmentExteriorExposurePreference exteriorExposurePreference,
    required ApartmentTopologyFamily? preferredFamily,
    required bool preferDayNightSeparation,
  }) =>
      <String>[
        'p9.apartment.request',
        'schemaVersion=$schemaVersion',
        'habitableRoomCount=$habitableRoomCount',
        'approximateAreaDm2=$interiorAreaDm2',
        'areaBasis=${areaBasis.code}',
        'bathroomCount=$bathroomCount',
        'separateWcCount=$separateWcCount',
        'balconyCount=$balconyCount',
        'balconyKind=${balconyKind.code}',
        'kitchenMode=${kitchenMode.code}',
        'corridorMode=${corridorMode.code}',
        'exteriorExposurePreference=${exteriorExposurePreference.code}',
        'preferredFamily=${preferredFamily?.code ?? '-'}',
        'preferDayNightSeparation=$preferDayNightSeparation',
      ].join('\n');
}

String _requireNonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}