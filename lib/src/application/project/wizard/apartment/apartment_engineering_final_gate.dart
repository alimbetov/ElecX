import 'apartment_circuit_installation_method_evidence.dart';
import 'apartment_engineering_requirements.dart';

final class ApartmentEngineeringFinalGateResult {
  ApartmentEngineeringFinalGateResult({
    required this.requirements,
    required Iterable<String> blockerCodes,
  }) : blockerCodes = List.unmodifiable(blockerCodes.toSet().toList()..sort());

  final ApartmentEngineeringDesignRequirements requirements;
  final List<String> blockerCodes;

  bool get accepted => blockerCodes.isEmpty;
}

/// Final fail-closed readiness gate after D1-D7 engineering closure.
///
/// The gate adds no engineering facts. It only validates that the latest
/// requirement schema is present, every non-advisory requirement is resolved,
/// and the two facts introduced by D6/D7 exist before equipment configuration
/// can be considered ready.
abstract final class ApartmentEngineeringFinalGateService {
  static ApartmentEngineeringFinalGateResult evaluate(
    ApartmentEngineeringDesignRequirements requirements,
  ) {
    final blockers = <String>[];

    if (requirements.requirementsVersion !=
        apartmentEngineeringRequirementsVersionV6) {
      blockers.add('requirements-version-not-final');
    }

    final circuit = _singleRequirementOrNull(
      requirements,
      ApartmentEngineeringRequirementDomain.circuit,
    );
    final protection = _singleRequirementOrNull(
      requirements,
      ApartmentEngineeringRequirementDomain.protection,
    );
    if (circuit == null) {
      blockers.add('missing-circuit-requirement');
    } else {
      if (!circuit.isResolved) {
        blockers.add('circuit-requirement-unresolved');
      }
      if (!circuit.factEvidence.containsKey('circuit.installationMethod')) {
        blockers.add('installation-method-evidence-missing');
      }
    }
    if (protection == null) {
      blockers.add('missing-protection-requirement');
    } else {
      if (!protection.isResolved) {
        blockers.add('protection-requirement-unresolved');
      }
      if (!protection.factEvidence.containsKey('protection.coordination')) {
        blockers.add('protection-coordination-evidence-missing');
      }
    }

    for (final requirement in requirements.blockingUnresolvedRequirements) {
      blockers.add(
          'unresolved:${requirement.domain.name}:${requirement.requirementId}');
    }
    if (!requirements.readyForEquipmentConfiguration) {
      blockers.add('requirements-not-ready-for-equipment-configuration');
    }

    return ApartmentEngineeringFinalGateResult(
      requirements: requirements,
      blockerCodes: blockers,
    );
  }

  static ApartmentEngineeringRequirement? _singleRequirementOrNull(
    ApartmentEngineeringDesignRequirements requirements,
    ApartmentEngineeringRequirementDomain domain,
  ) {
    final matches = requirements.requirements
        .where((item) => item.domain == domain)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }
}
