import '../apartment_topology.dart';
import 'apartment_topology_draft.dart';

/// One deterministic P9.4 area allocation for an expanded semantic space.
final class FittedSpaceArea {
  const FittedSpaceArea({
    required this.semanticKey,
    required this.participation,
    required this.areaDm2,
    required this.minAreaDm2,
    required this.preferredAreaDm2,
    required this.maxAreaDm2,
  });

  final String semanticKey;
  final SpaceAreaParticipation participation;
  final int areaDm2;
  final int minAreaDm2;
  final int preferredAreaDm2;
  final int maxAreaDm2;
}

/// Pure P9.4 output. Geometry and canonical project identities are still absent.
final class AreaFittedTopologyDraft {
  AreaFittedTopologyDraft({
    required this.draft,
    required this.requestedInteriorAreaDm2,
    required Iterable<FittedSpaceArea> spaces,
    required this.allocatedInteriorAreaDm2,
    required this.exteriorAppendageAreaDm2,
    required this.interiorResidualDm2,
    required this.areaPolicyVersion,
    required this.allocatorVersion,
    required this.areaFitFingerprint,
  }) : spaces = List.unmodifiable(spaces);

  final ApartmentTopologyDraft draft;
  final int requestedInteriorAreaDm2;
  final List<FittedSpaceArea> spaces;
  final int allocatedInteriorAreaDm2;
  final int exteriorAppendageAreaDm2;
  final int interiorResidualDm2;
  final String areaPolicyVersion;
  final String allocatorVersion;
  final String areaFitFingerprint;
}
