import 'overcurrent_protection.dart';
import 'residual_current_protection.dart';

enum ProtectiveDeviceCoordinationApplicability {
  required,
  notRequired,
}

enum ProtectiveDeviceSelectivityKind {
  total,
  limited,
}

/// Manufacturer/source-pinned selectivity evidence for one exact protective
/// device pair.
///
/// [total] means the source explicitly declares total selectivity for the pair.
/// [limited] means selectivity is established only up to
/// [selectivityLimitA]. No trip-curve heuristics are inferred by P9.
final class ProtectiveDeviceSelectivityEvidence {
  ProtectiveDeviceSelectivityEvidence({
    required this.id,
    required this.downstreamDeviceId,
    required this.upstreamDeviceId,
    required this.kind,
    required this.selectivityLimitA,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (id.trim().isEmpty ||
        downstreamDeviceId.trim().isEmpty ||
        upstreamDeviceId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Coordination evidence identity/device/source must be non-empty.',
      );
    }
    if (downstreamDeviceId == upstreamDeviceId) {
      throw ArgumentError(
        'Coordination evidence requires distinct downstream/upstream devices.',
      );
    }

    switch (kind) {
      case ProtectiveDeviceSelectivityKind.total:
        if (selectivityLimitA != null) {
          throw ArgumentError(
            'Total-selectivity evidence must not carry a finite current limit.',
          );
        }
      case ProtectiveDeviceSelectivityKind.limited:
        final limit = selectivityLimitA;
        if (limit == null || !limit.isFinite || limit <= 0) {
          throw ArgumentError(
            'Limited-selectivity evidence requires a positive finite current limit.',
          );
        }
    }
  }

  final String id;
  final String downstreamDeviceId;
  final String upstreamDeviceId;
  final ProtectiveDeviceSelectivityKind kind;
  final double? selectivityLimitA;
  final String sourceId;
  final String sourceRevision;
}

/// Explicit overcurrent D6 policy for one circuit.
///
/// The policy binds the coordination decision to the exact D3-selected
/// downstream protective device. If coordination is required, the upstream
/// device and manufacturer/source selectivity evidence are also explicit.
final class ProtectiveDeviceCoordinationPolicy {
  ProtectiveDeviceCoordinationPolicy({
    required this.circuitId,
    required this.applicability,
    required this.rationaleCode,
    required this.evaluatedDownstreamDeviceId,
    required Iterable<String> applicabilityEvidenceIds,
    required this.upstreamDevice,
    required Iterable<ProtectiveDeviceSelectivityEvidence> selectivityEvidence,
    required this.sourceId,
    required this.sourceRevision,
  })  : applicabilityEvidenceIds = List.unmodifiable(
          applicabilityEvidenceIds.toSet().toList()..sort(),
        ),
        selectivityEvidence = List.unmodifiable(selectivityEvidence) {
    if (circuitId.trim().isEmpty ||
        rationaleCode.trim().isEmpty ||
        evaluatedDownstreamDeviceId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Coordination policy identity/rationale/source must be non-empty.',
      );
    }
    if (this.applicabilityEvidenceIds.isEmpty ||
        this.applicabilityEvidenceIds.any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
        'Coordination applicability requires source-pinned evidence ids.',
      );
    }

    final evidenceIds = <String>{};
    for (final evidence in this.selectivityEvidence) {
      if (!evidenceIds.add(evidence.id)) {
        throw ArgumentError(
          'Duplicate coordination evidence ${evidence.id}.',
        );
      }
    }

    switch (applicability) {
      case ProtectiveDeviceCoordinationApplicability.required:
        final upstream = upstreamDevice;
        if (upstream == null) {
          throw ArgumentError(
            'Required coordination policy needs an explicit upstream device.',
          );
        }
        _validateOvercurrentDevice(upstream, label: 'upstreamDevice');
        if (upstream.id == evaluatedDownstreamDeviceId) {
          throw ArgumentError(
            'Required coordination policy needs distinct downstream/upstream devices.',
          );
        }
        if (this.selectivityEvidence.isEmpty) {
          throw ArgumentError(
            'Required coordination policy needs source-pinned selectivity evidence.',
          );
        }
      case ProtectiveDeviceCoordinationApplicability.notRequired:
        if (upstreamDevice != null || this.selectivityEvidence.isNotEmpty) {
          throw ArgumentError(
            'Not-required coordination policy must not carry device-pair evidence.',
          );
        }
    }
  }

  final String circuitId;
  final ProtectiveDeviceCoordinationApplicability applicability;
  final String rationaleCode;
  final String evaluatedDownstreamDeviceId;
  final List<String> applicabilityEvidenceIds;
  final OvercurrentProtectiveDeviceSpec? upstreamDevice;
  final List<ProtectiveDeviceSelectivityEvidence> selectivityEvidence;
  final String sourceId;
  final String sourceRevision;
}

enum ResidualCurrentCoordinationApplicability {
  required,
  notRequired,
}

/// Source/manufacturer evidence that one exact residual-current protective
/// device pair is coordinated/selective.
///
/// P9 deliberately does not infer this from IΔn ratios, device type, or a
/// selective/time-delay label. Those properties may be part of the cited
/// source, but the pair-level conclusion must be supplied explicitly.
final class ResidualCurrentSelectivityEvidence {
  ResidualCurrentSelectivityEvidence({
    required this.id,
    required this.downstreamDeviceId,
    required this.upstreamDeviceId,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (id.trim().isEmpty ||
        downstreamDeviceId.trim().isEmpty ||
        upstreamDeviceId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Residual-current coordination evidence identity/device/source must be non-empty.',
      );
    }
    if (downstreamDeviceId == upstreamDeviceId) {
      throw ArgumentError(
        'Residual-current coordination requires distinct downstream/upstream devices.',
      );
    }
  }

  final String id;
  final String downstreamDeviceId;
  final String upstreamDeviceId;
  final String sourceId;
  final String sourceRevision;
}

/// Explicit residual-current coordination policy for one circuit.
///
/// [evaluatedDownstreamDeviceId] is null only when D5 selected no local
/// residual-current device. If D5 selected an RCD/RCBO, even a not-required
/// upstream-coordination decision is bound to that exact device identity.
final class ResidualCurrentDeviceCoordinationPolicy {
  ResidualCurrentDeviceCoordinationPolicy({
    required this.circuitId,
    required this.applicability,
    required this.rationaleCode,
    required this.evaluatedDownstreamDeviceId,
    required Iterable<String> applicabilityEvidenceIds,
    required this.upstreamDevice,
    required Iterable<ResidualCurrentSelectivityEvidence> selectivityEvidence,
    required this.sourceId,
    required this.sourceRevision,
  })  : applicabilityEvidenceIds = List.unmodifiable(
          applicabilityEvidenceIds.toSet().toList()..sort(),
        ),
        selectivityEvidence = List.unmodifiable(selectivityEvidence) {
    if (circuitId.trim().isEmpty ||
        rationaleCode.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Residual-current coordination policy identity/rationale/source must be non-empty.',
      );
    }
    if (evaluatedDownstreamDeviceId != null &&
        evaluatedDownstreamDeviceId!.trim().isEmpty) {
      throw ArgumentError(
        'Residual-current downstream device id must be null or non-empty.',
      );
    }
    if (this.applicabilityEvidenceIds.isEmpty ||
        this.applicabilityEvidenceIds.any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
        'Residual-current coordination applicability needs evidence ids.',
      );
    }

    final evidenceIds = <String>{};
    for (final evidence in this.selectivityEvidence) {
      if (!evidenceIds.add(evidence.id)) {
        throw ArgumentError(
          'Duplicate residual-current coordination evidence ${evidence.id}.',
        );
      }
    }

    switch (applicability) {
      case ResidualCurrentCoordinationApplicability.required:
        final downstream = evaluatedDownstreamDeviceId;
        final upstream = upstreamDevice;
        if (downstream == null || upstream == null) {
          throw ArgumentError(
            'Required residual-current coordination needs exact downstream and upstream devices.',
          );
        }
        if (upstream.id == downstream) {
          throw ArgumentError(
            'Residual-current coordination needs distinct downstream/upstream devices.',
          );
        }
        if (this.selectivityEvidence.isEmpty) {
          throw ArgumentError(
            'Required residual-current coordination needs source-pinned pair evidence.',
          );
        }
      case ResidualCurrentCoordinationApplicability.notRequired:
        if (upstreamDevice != null || this.selectivityEvidence.isNotEmpty) {
          throw ArgumentError(
            'Not-required residual-current coordination must not carry pair evidence.',
          );
        }
    }
  }

  final String circuitId;
  final ResidualCurrentCoordinationApplicability applicability;
  final String rationaleCode;
  final String? evaluatedDownstreamDeviceId;
  final List<String> applicabilityEvidenceIds;
  final ResidualCurrentProtectiveDeviceSpec? upstreamDevice;
  final List<ResidualCurrentSelectivityEvidence> selectivityEvidence;
  final String sourceId;
  final String sourceRevision;
}

void _validateOvercurrentDevice(
  OvercurrentProtectiveDeviceSpec device, {
  required String label,
}) {
  if (device.id.trim().isEmpty ||
      device.sourceId.trim().isEmpty ||
      device.sourceRevision.trim().isEmpty) {
    throw ArgumentError('$label identity/source must be non-empty.');
  }
  if (!device.ratedCurrentA.isFinite || device.ratedCurrentA <= 0) {
    throw ArgumentError.value(device.ratedCurrentA, '$label.ratedCurrentA');
  }
  if (!device.breakingCapacityKa.isFinite || device.breakingCapacityKa <= 0) {
    throw ArgumentError.value(
      device.breakingCapacityKa,
      '$label.breakingCapacityKa',
    );
  }
  if (device.poleCount <= 0) {
    throw ArgumentError.value(device.poleCount, '$label.poleCount');
  }
}
