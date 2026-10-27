enum OvercurrentDeviceKind { mcb, mccb, fuse, rcbo }

enum OvercurrentTripCurve { b, c, d, manufacturerSpecific }

/// Catalog-level protective-device evidence used by automatic selection.
final class OvercurrentProtectiveDeviceSpec {
  const OvercurrentProtectiveDeviceSpec({
    required this.id,
    required this.kind,
    required this.ratedCurrentA,
    required this.breakingCapacityKa,
    required this.poleCount,
    required this.sourceId,
    required this.sourceRevision,
    this.tripCurve,
  })  : assert(id != ''),
        assert(ratedCurrentA > 0),
        assert(breakingCapacityKa > 0),
        assert(poleCount > 0),
        assert(sourceId != ''),
        assert(sourceRevision != '');

  final String id;
  final OvercurrentDeviceKind kind;
  final double ratedCurrentA;
  final double breakingCapacityKa;
  final int poleCount;
  final OvercurrentTripCurve? tripCurve;
  final String sourceId;
  final String sourceRevision;
}

final class OvercurrentProtectionRequest {
  OvercurrentProtectionRequest({
    required this.designCurrentA,
    required this.cableAmpacityA,
    required this.prospectiveShortCircuitCurrentA,
    required Iterable<OvercurrentProtectiveDeviceSpec> candidates,
    this.allowedKinds = const {
      OvercurrentDeviceKind.mcb,
      OvercurrentDeviceKind.mccb,
      OvercurrentDeviceKind.fuse,
      OvercurrentDeviceKind.rcbo,
    },
  }) : candidates = List.unmodifiable(candidates) {
    if (designCurrentA <= 0) {
      throw ArgumentError.value(designCurrentA, 'designCurrentA');
    }
    if (cableAmpacityA <= 0) {
      throw ArgumentError.value(cableAmpacityA, 'cableAmpacityA');
    }
    if (prospectiveShortCircuitCurrentA <= 0) {
      throw ArgumentError.value(
        prospectiveShortCircuitCurrentA,
        'prospectiveShortCircuitCurrentA',
      );
    }
    if (allowedKinds.isEmpty) {
      throw ArgumentError('At least one overcurrent device kind is required.');
    }
  }

  final double designCurrentA;
  final double cableAmpacityA;
  final double prospectiveShortCircuitCurrentA;
  final List<OvercurrentProtectiveDeviceSpec> candidates;
  final Set<OvercurrentDeviceKind> allowedKinds;
}

enum OvercurrentSelectionStatus { selected, noCompliantCandidate }

final class OvercurrentProtectionSelectionResult {
  const OvercurrentProtectionSelectionResult({
    required this.status,
    required this.selected,
    required this.rejections,
  });

  final OvercurrentSelectionStatus status;
  final OvercurrentProtectiveDeviceSpec? selected;
  final Map<String, List<String>> rejections;

  bool get isSelected =>
      status == OvercurrentSelectionStatus.selected && selected != null;
}
