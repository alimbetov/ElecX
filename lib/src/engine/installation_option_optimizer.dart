import '../domain/cable_spec.dart';
import '../domain/installation_path.dart';
import '../domain/route_host.dart';
import 'installation_capacity_engine.dart';

final class InstallationOptionCandidate {
  const InstallationOptionCandidate({
    required this.id,
    required this.pathSpec,
    required this.host,
    required this.lengthMm,
    required this.channelId,
  });

  final String id;
  final InstallationPathSpec pathSpec;
  final RouteHostRef host;
  final double lengthMm;
  final String channelId;
}

final class InstallationOptionAssessment {
  const InstallationOptionAssessment({
    required this.candidate,
    required this.capacity,
    required this.totalInstallationCost,
  });

  final InstallationOptionCandidate candidate;
  final InstallationCapacityResult capacity;

  /// Cost of the installation path itself. Cable/equipment price is intentionally
  /// not included here because those belong to the equipment/cable catalog.
  /// Null means the candidate is feasible but not commercially comparable yet.
  final double? totalInstallationCost;

  bool get feasible => !capacity.hasErrors;
}

final class InstallationOptionResult {
  const InstallationOptionResult({
    required this.assessments,
    required this.recommended,
  });

  final List<InstallationOptionAssessment> assessments;
  final InstallationOptionAssessment? recommended;
}

abstract final class InstallationOptionOptimizer {
  static InstallationOptionResult evaluate({
    required String routeId,
    required CableSpec cable,
    required int quantity,
    required Iterable<InstallationOptionCandidate> candidates,
  }) {
    final assessments = <InstallationOptionAssessment>[];

    for (final candidate in candidates) {
      final section = InstallationPathSection(
        id: 'candidate:${candidate.id}',
        pathSpecId: candidate.pathSpec.id,
        host: candidate.host,
        lengthMm: candidate.lengthMm,
      );
      final capacity = InstallationCapacityEngine.evaluate(
        InstallationCapacityRequest(
          pathSpecs: [candidate.pathSpec],
          sections: [section],
          occupancies: [
            RouteOccupancy(
              routeId: routeId,
              pathSectionId: section.id,
              channelId: candidate.channelId,
              cable: cable,
              quantity: quantity,
            ),
          ],
        ),
      );
      final material = candidate.pathSpec.materialCostPerMeter;
      final labor = candidate.pathSpec.laborCostPerMeter;
      final cost = material == null || labor == null
          ? null
          : candidate.lengthMm / 1000 * (material + labor);
      assessments.add(
        InstallationOptionAssessment(
          candidate: candidate,
          capacity: capacity,
          totalInstallationCost: cost,
        ),
      );
    }

    final feasible = assessments.where((item) => item.feasible).toList();
    feasible.sort((a, b) {
      final ac = a.totalInstallationCost;
      final bc = b.totalInstallationCost;
      if (ac != null && bc != null) {
        final byCost = ac.compareTo(bc);
        if (byCost != 0) return byCost;
      } else if (ac != null) {
        return -1;
      } else if (bc != null) {
        return 1;
      }
      return a.candidate.lengthMm.compareTo(b.candidate.lengthMm);
    });

    return InstallationOptionResult(
      assessments: List.unmodifiable(assessments),
      recommended: feasible.isEmpty ? null : feasible.first,
    );
  }
}
