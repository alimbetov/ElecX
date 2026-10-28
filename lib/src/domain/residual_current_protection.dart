enum ResidualCurrentApplicability {
  required,
  notRequired,
}

enum ResidualCurrentDeviceKind {
  rcd,
  rcbo,
}

enum ResidualCurrentType {
  ac,
  a,
  f,
  b,
}

enum ResidualCurrentSensitivityPreference {
  lowestAvailable,
  highestPermitted,
}

/// One source-pinned residual-current protective-device candidate.
///
/// Standalone RCD candidates must carry conditional short-circuit capability
/// and the exact upstream overcurrent devices that the manufacturer/source
/// allows as backup protection. RCBO candidates instead bind to the exact
/// D3-selected overcurrent device by [overcurrentDeviceId].
final class ResidualCurrentProtectiveDeviceSpec {
  ResidualCurrentProtectiveDeviceSpec({
    required this.id,
    required this.kind,
    required this.ratedCurrentA,
    required this.residualOperatingCurrentMa,
    required this.residualType,
    required this.poleCount,
    required this.overcurrentDeviceId,
    required this.conditionalShortCircuitCurrentA,
    required Iterable<String> compatibleBackupOvercurrentDeviceIds,
    required this.sourceId,
    required this.sourceRevision,
  }) : compatibleBackupOvercurrentDeviceIds = List.unmodifiable(
          compatibleBackupOvercurrentDeviceIds.toSet().toList()..sort(),
        ) {
    if (id.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Residual-current device identity/source must be non-empty.',
      );
    }
    if (!ratedCurrentA.isFinite || ratedCurrentA <= 0) {
      throw ArgumentError.value(ratedCurrentA, 'ratedCurrentA');
    }
    if (!residualOperatingCurrentMa.isFinite ||
        residualOperatingCurrentMa <= 0) {
      throw ArgumentError.value(
        residualOperatingCurrentMa,
        'residualOperatingCurrentMa',
      );
    }
    if (poleCount <= 0) {
      throw ArgumentError.value(poleCount, 'poleCount');
    }

    switch (kind) {
      case ResidualCurrentDeviceKind.rcd:
        if (overcurrentDeviceId != null) {
          throw ArgumentError(
            'Standalone RCD must not claim an integrated overcurrent device.',
          );
        }
        final conditional = conditionalShortCircuitCurrentA;
        if (conditional == null || !conditional.isFinite || conditional <= 0) {
          throw ArgumentError(
            'Standalone RCD requires positive conditional short-circuit current.',
          );
        }
        if (this.compatibleBackupOvercurrentDeviceIds.isEmpty ||
            this
                .compatibleBackupOvercurrentDeviceIds
                .any((value) => value.trim().isEmpty)) {
          throw ArgumentError(
            'Standalone RCD requires source-pinned compatible backup devices.',
          );
        }
      case ResidualCurrentDeviceKind.rcbo:
        if (overcurrentDeviceId == null ||
            overcurrentDeviceId!.trim().isEmpty) {
          throw ArgumentError(
            'RCBO candidate must bind to an exact D3 overcurrent device.',
          );
        }
        if (conditionalShortCircuitCurrentA != null ||
            this.compatibleBackupOvercurrentDeviceIds.isNotEmpty) {
          throw ArgumentError(
            'RCBO must not carry standalone-RCD backup coordination fields.',
          );
        }
    }
  }

  final String id;
  final ResidualCurrentDeviceKind kind;
  final double ratedCurrentA;
  final double residualOperatingCurrentMa;
  final ResidualCurrentType residualType;
  final int poleCount;
  final String? overcurrentDeviceId;
  final double? conditionalShortCircuitCurrentA;
  final List<String> compatibleBackupOvercurrentDeviceIds;
  final String sourceId;
  final String sourceRevision;
}

/// Source-pinned normative applicability and selection policy for one circuit.
///
/// D5 intentionally has no residential defaults. 30 mA, Type A and even RCD
/// applicability are never inferred by this model. [evaluatedLoadIds] binds the
/// normative decision to the exact load set that exists in the D3/D4 circuit,
/// so a stale policy cannot be replayed after circuit composition changes.
final class ResidualCurrentProtectionPolicy {
  ResidualCurrentProtectionPolicy({
    required this.circuitId,
    required this.applicability,
    required this.rationaleCode,
    required Iterable<String> evaluatedLoadIds,
    required Iterable<String> applicabilityEvidenceIds,
    required Iterable<String> loadCharacteristicEvidenceIds,
    required this.maximumResidualOperatingCurrentMa,
    required Set<ResidualCurrentType> allowedTypes,
    required Iterable<ResidualCurrentType> preferredTypes,
    required Set<ResidualCurrentDeviceKind> allowedDeviceKinds,
    required Iterable<ResidualCurrentDeviceKind> preferredDeviceKinds,
    required this.minimumPoleCount,
    required this.sensitivityPreference,
    required Iterable<ResidualCurrentProtectiveDeviceSpec> candidates,
    required this.sourceId,
    required this.sourceRevision,
  })  : evaluatedLoadIds = List.unmodifiable(
          evaluatedLoadIds.toSet().toList()..sort(),
        ),
        applicabilityEvidenceIds = List.unmodifiable(
          applicabilityEvidenceIds.toSet().toList()..sort(),
        ),
        loadCharacteristicEvidenceIds = List.unmodifiable(
          loadCharacteristicEvidenceIds.toSet().toList()..sort(),
        ),
        allowedTypes = Set.unmodifiable(allowedTypes),
        preferredTypes = List.unmodifiable(preferredTypes),
        allowedDeviceKinds = Set.unmodifiable(allowedDeviceKinds),
        preferredDeviceKinds = List.unmodifiable(preferredDeviceKinds),
        candidates = List.unmodifiable(candidates) {
    if (circuitId.trim().isEmpty ||
        rationaleCode.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Residual-current policy identity/rationale/source must be non-empty.',
      );
    }
    if (this.evaluatedLoadIds.isEmpty ||
        this.evaluatedLoadIds.any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
        'Residual-current policy requires the exact non-empty circuit load set.',
      );
    }
    if (this.applicabilityEvidenceIds.isEmpty ||
        this.applicabilityEvidenceIds.any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
        'Residual-current applicability requires source-pinned evidence ids.',
      );
    }

    final candidateIds = <String>{};
    for (final candidate in this.candidates) {
      if (!candidateIds.add(candidate.id)) {
        throw ArgumentError(
          'Duplicate residual-current device candidate ${candidate.id}.',
        );
      }
    }

    switch (applicability) {
      case ResidualCurrentApplicability.required:
        final maximum = maximumResidualOperatingCurrentMa;
        if (maximum == null || !maximum.isFinite || maximum <= 0) {
          throw ArgumentError(
            'Required RCD/RCBO policy needs explicit maximum IΔn.',
          );
        }
        if (this.allowedTypes.isEmpty ||
            this.allowedDeviceKinds.isEmpty ||
            this.preferredTypes.isEmpty ||
            this.preferredDeviceKinds.isEmpty) {
          throw ArgumentError(
            'Required RCD/RCBO policy needs explicit allowed/preferred types and kinds.',
          );
        }
        if (this.loadCharacteristicEvidenceIds.isEmpty ||
            this
                .loadCharacteristicEvidenceIds
                .any((value) => value.trim().isEmpty)) {
          throw ArgumentError(
            'Required RCD/RCBO policy needs load-characteristic evidence.',
          );
        }
        if (minimumPoleCount == null || minimumPoleCount! <= 0) {
          throw ArgumentError(
            'Required RCD/RCBO policy needs a positive minimum pole count.',
          );
        }
        if (sensitivityPreference == null) {
          throw ArgumentError(
            'Required RCD/RCBO policy needs explicit IΔn selection preference.',
          );
        }
        _requireUniquePreferences(
          preferred: this.preferredTypes,
          allowed: this.allowedTypes,
          label: 'residual-current type',
        );
        _requireUniquePreferences(
          preferred: this.preferredDeviceKinds,
          allowed: this.allowedDeviceKinds,
          label: 'residual-current device kind',
        );
      case ResidualCurrentApplicability.notRequired:
        if (maximumResidualOperatingCurrentMa != null ||
            this.allowedTypes.isNotEmpty ||
            this.preferredTypes.isNotEmpty ||
            this.allowedDeviceKinds.isNotEmpty ||
            this.preferredDeviceKinds.isNotEmpty ||
            minimumPoleCount != null ||
            sensitivityPreference != null ||
            this.candidates.isNotEmpty ||
            this.loadCharacteristicEvidenceIds.isNotEmpty) {
          throw ArgumentError(
            'Not-required RCD policy must not carry device-selection constraints.',
          );
        }
    }
  }

  final String circuitId;
  final ResidualCurrentApplicability applicability;
  final String rationaleCode;
  final List<String> evaluatedLoadIds;
  final List<String> applicabilityEvidenceIds;
  final List<String> loadCharacteristicEvidenceIds;
  final double? maximumResidualOperatingCurrentMa;
  final Set<ResidualCurrentType> allowedTypes;
  final List<ResidualCurrentType> preferredTypes;
  final Set<ResidualCurrentDeviceKind> allowedDeviceKinds;
  final List<ResidualCurrentDeviceKind> preferredDeviceKinds;
  final int? minimumPoleCount;
  final ResidualCurrentSensitivityPreference? sensitivityPreference;
  final List<ResidualCurrentProtectiveDeviceSpec> candidates;
  final String sourceId;
  final String sourceRevision;
}

void _requireUniquePreferences<T>({
  required List<T> preferred,
  required Set<T> allowed,
  required String label,
}) {
  if (preferred.toSet().length != preferred.length) {
    throw ArgumentError('Duplicate preferred $label entries are not allowed.');
  }
  final outside = preferred.where((value) => !allowed.contains(value)).toList();
  if (outside.isNotEmpty) {
    throw ArgumentError('Preferred $label must be a subset of allowed values.');
  }
}
