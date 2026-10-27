import 'overcurrent_protection.dart';

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

/// Explicit D6 policy for one circuit.
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
