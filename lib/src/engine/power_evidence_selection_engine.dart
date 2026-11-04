import 'dart:convert';

import '../domain/cable_spec.dart';
import '../domain/electrical_circuit_calculation.dart';
import '../domain/power_board_catalog_qualification.dart';
import '../domain/semantic_sha256.dart';
import 'electrical_circuit_closure_engine.dart';

/// An immutable source pin supplied by an upstream evidence-review process.
///
/// This proves that the selector used a reviewed identity/revision/digest, not
/// that the external document is authentic. Authenticity and legal applicability
/// must be established by the trusted catalog/normative ingestion boundary.
final class PowerEvidenceSourcePin {
  PowerEvidenceSourcePin({
    required this.sourceId,
    required this.revision,
    required this.contentSha256,
    required this.approvalId,
  }) {
    if (sourceId.trim().isEmpty ||
        revision.trim().isEmpty ||
        approvalId.trim().isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentSha256)) {
      throw ArgumentError('Reviewed evidence requires source, revision, SHA-256 and approval.');
    }
  }

  final String sourceId;
  final String revision;
  final String contentSha256;
  final String approvalId;
}

/// Exact route and normative binding for one generated circuit.
///
/// A route length cannot be a hidden estimate. The explicit reviewed route
/// source is required even though this slice remains preview-only.
final class PowerCircuitEvidenceBinding {
  PowerCircuitEvidenceBinding({
    required this.generationKey,
    required this.policy,
    required this.routeLengthMm,
    required this.routeEvidenceSourceId,
    required this.faultCurrentEvidenceSourceId,
    required this.normativeMaxVoltageDropRatio,
    Iterable<String> approvedCorrectionFactorIds = const [],
  }) : approvedCorrectionFactorIds =
           Set.unmodifiable(approvedCorrectionFactorIds) {
    if (generationKey.trim().isEmpty ||
        routeEvidenceSourceId.trim().isEmpty ||
        faultCurrentEvidenceSourceId.trim().isEmpty ||
        !routeLengthMm.isFinite ||
        routeLengthMm <= 0 ||
        !normativeMaxVoltageDropRatio.isFinite ||
        normativeMaxVoltageDropRatio <= 0 ||
        normativeMaxVoltageDropRatio >= 1) {
      throw ArgumentError('Exact circuit route/fault/voltage-drop evidence is required.');
    }
  }

  final String generationKey;
  final ElectricalCircuitClosurePolicy policy;
  final double routeLengthMm;
  final String routeEvidenceSourceId;
  final String faultCurrentEvidenceSourceId;
  final double normativeMaxVoltageDropRatio;
  final Set<String> approvedCorrectionFactorIds;
}

final class PowerEvidenceSelectionRequest {
  PowerEvidenceSelectionRequest({
    required this.board,
    required this.normativeSource,
    required Iterable<PowerEvidenceSourcePin> approvedSources,
    required Iterable<PowerCircuitEvidenceBinding> bindings,
  }) : approvedSources = List.unmodifiable(approvedSources),
       bindings = List.unmodifiable(bindings) {
    final sourceIds = <String>{normativeSource.sourceId};
    for (final source in this.approvedSources) {
      if (!sourceIds.add(source.sourceId)) {
        throw ArgumentError('Duplicate evidence source '+source.sourceId);
      }
    }
    final keys = <String>{};
    for (final binding in this.bindings) {
      if (!keys.add(binding.generationKey)) {
        throw ArgumentError('Duplicate generation binding '+binding.generationKey);
      }
    }
  }

  final PowerBoardCatalogQualification board;
  final PowerEvidenceSourcePin normativeSource;
  final List<PowerEvidenceSourcePin> approvedSources;
  final List<PowerCircuitEvidenceBinding> bindings;
}

enum PowerEvidenceSelectionIssue {
  boardTypeNotQualified,
  circuitBindingMissing,
  unknownCircuitBinding,
  circuitIdentityMismatch,
  normativeRevisionMismatch,
  evidenceSourceUnapproved,
  evidenceSourceRevisionMismatch,
  routeLengthMismatch,
  voltageDropPolicyMismatch,
  correctionFactorNotApproved,
  noCompliantCable,
  noCompliantProtection,
  boardElectricalRatingsUnverified,
}

/// No canonical mutation or durable IDs. A successful pairing can be reviewed
/// but board capacity/protection coordination still requires further evidence.
final class PowerEvidenceSelectionPreview {
  PowerEvidenceSelectionPreview({
    required this.fingerprint,
    required this.board,
    required Iterable<PowerEvidenceSelectionIssue> issues,
    required this.closure,
  }) : issues = List.unmodifiable(issues);

  final String fingerprint;
  final PowerBoardCatalogQualification board;
  final List<PowerEvidenceSelectionIssue> issues;
  final ElectricalCircuitClosureResult? closure;

  bool get readyForEngineeringReview =>
      board.hasQualifiedBoardType &&
      closure?.isFullyClosed == true &&
      !issues.any((issue) => issue !=
          PowerEvidenceSelectionIssue.boardElectricalRatingsUnverified);

  bool get readyToApply => false;
}

/// Qualifies all supplied evidence *before* executing existing P9.5-D3
/// cable/overcurrent calculations. Missing or mismatched evidence fails closed;
/// there are no assumed Kazakhstan/IEC table values, cable lengths or currents.
abstract final class PowerEvidenceSelectionEngine {
  static PowerEvidenceSelectionPreview evaluate(
    PowerEvidenceSelectionRequest request,
  ) {
    final candidate = request.board.candidate;
    final issues = <PowerEvidenceSelectionIssue>{};
    if (!request.board.hasQualifiedBoardType) {
      issues.add(PowerEvidenceSelectionIssue.boardTypeNotQualified);
    }

    final sources = {
      request.normativeSource.sourceId: request.normativeSource,
      for (final item in request.approvedSources) item.sourceId: item,
    };
    final bindings = {for (final b in request.bindings) b.generationKey: b};
    final generatedKeys = candidate.circuits.map((c) => c.generationKey).toSet();
    if (generatedKeys.difference(bindings.keys.toSet()).isNotEmpty) {
      issues.add(PowerEvidenceSelectionIssue.circuitBindingMissing);
    }
    if (bindings.keys.toSet().difference(generatedKeys).isNotEmpty) {
      issues.add(PowerEvidenceSelectionIssue.unknownCircuitBinding);
    }

    for (final proposal in candidate.circuits) {
      final binding = bindings[proposal.generationKey];
      if (binding == null) continue;
      final policy = binding.policy;
      if (policy.circuitId != proposal.calculated.id) {
        issues.add(PowerEvidenceSelectionIssue.circuitIdentityMismatch);
      }
      if (policy.sourceId != request.normativeSource.sourceId ||
          policy.sourceRevision != request.normativeSource.revision) {
        issues.add(PowerEvidenceSelectionIssue.normativeRevisionMismatch);
      }
      void requireSource(String id, [String? revision]) {
        final pin = sources[id];
        if (pin == null) {
          issues.add(PowerEvidenceSelectionIssue.evidenceSourceUnapproved);
        } else if (revision != null && pin.revision != revision) {
          issues.add(PowerEvidenceSelectionIssue.evidenceSourceRevisionMismatch);
        }
      }

      requireSource(binding.routeEvidenceSourceId);
      requireSource(binding.faultCurrentEvidenceSourceId);
      for (final cable in policy.cableCandidates) {
        requireSource(cable.sourceId, cable.sourceRevision);
        if ((cable.routeLengthMm - binding.routeLengthMm).abs() > 0.000001) {
          issues.add(PowerEvidenceSelectionIssue.routeLengthMismatch);
        }
        if ((cable.maxVoltageDropRatio -
                    binding.normativeMaxVoltageDropRatio).abs() >
                0.000000001) {
          issues.add(PowerEvidenceSelectionIssue.voltageDropPolicyMismatch);
        }
        final impedanceId = cable.impedanceEvidence?.sourceKey;
        if (impedanceId != null) requireSource(impedanceId);
        for (final section in cable.ampacitySections) {
          if (section.sourceKey != null) requireSource(section.sourceKey!);
          for (final factor in section.factors) {
            if (!binding.approvedCorrectionFactorIds.contains(factor.id)) {
              issues.add(PowerEvidenceSelectionIssue.correctionFactorNotApproved);
            }
          }
        }
      }
      for (final device in policy.protectionCandidates) {
        requireSource(device.sourceId, device.sourceRevision);
      }
    }

    ElectricalCircuitClosureResult? closure;
    if (issues.isEmpty) {
      closure = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: ElectricalCircuitCalculationResult(
            circuits: [
              for (final item in candidate.circuits) item.calculated,
            ],
          ),
          policies: [
            for (final item in candidate.circuits)
              bindings[item.generationKey]!.policy,
          ],
        ),
      );
      for (final outcome in closure.outcomes) {
        switch (outcome.status) {
          case ElectricalCircuitClosureStatus.closed:
            break;
          case ElectricalCircuitClosureStatus.noCompliantCable:
            issues.add(PowerEvidenceSelectionIssue.noCompliantCable);
          case ElectricalCircuitClosureStatus.noCompliantProtection:
            issues.add(PowerEvidenceSelectionIssue.noCompliantProtection);
        }
      }
    }
    // V2 board metadata lacks electrical capacity and fault-rating evidence.
    issues.add(PowerEvidenceSelectionIssue.boardElectricalRatingsUnverified);

    final orderedBindings = request.bindings.toList()
      ..sort((a, b) => a.generationKey.compareTo(b.generationKey));
    final orderedPins = sources.values.toList()
      ..sort((a, b) => a.sourceId.compareTo(b.sourceId));
    final fingerprint = semanticSha256Hex(jsonEncode([
      'p12a7.evidence-selection.v1',
      request.board.fingerprint,
      for (final pin in orderedPins)
        [pin.sourceId, pin.revision, pin.contentSha256, pin.approvalId],
      for (final binding in orderedBindings) _bindingFingerprint(binding),
      for (final issue in PowerEvidenceSelectionIssue.values)
        if (issues.contains(issue)) issue.name,
      if (closure != null)
        for (final outcome in closure.outcomes)
          [
            outcome.circuitId,
            outcome.status.name,
            outcome.selectedCable?.cable.id,
            outcome.selectedProtection?.id,
          ],
    ]));

    return PowerEvidenceSelectionPreview(
      fingerprint: fingerprint,
      board: request.board,
      issues: [
        for (final issue in PowerEvidenceSelectionIssue.values)
          if (issues.contains(issue)) issue,
      ],
      closure: closure,
    );
  }

  static List<Object?> _bindingFingerprint(PowerCircuitEvidenceBinding b) {
    final p = b.policy;
    final cables = p.cableCandidates.toList()
      ..sort((a, c) => a.cable.id.compareTo(c.cable.id));
    final devices = p.protectionCandidates.toList()
      ..sort((a, c) => a.id.compareTo(c.id));
    return [
      b.generationKey,
      b.routeLengthMm,
      b.routeEvidenceSourceId,
      b.faultCurrentEvidenceSourceId,
      b.normativeMaxVoltageDropRatio,
      b.approvedCorrectionFactorIds.toList()..sort(),
      p.circuitId,
      p.sourceId,
      p.sourceRevision,
      p.minimumConductorCount,
      p.allowedConductorMaterials.map((m) => m.name).toList()..sort(),
      p.minimumCableRatedVoltageV,
      p.prospectiveShortCircuitCurrentA,
      p.allowedProtectionKinds.map((m) => m.name).toList()..sort(),
      p.minimumProtectionPoleCount,
      for (final c in cables)
        [
          c.cable.id,
          c.cable.conductorCount,
          c.cable.conductorCrossSectionMm2,
          c.cable.ratedVoltageV,
          c.cable.conductorMaterial.name,
          c.routeLengthMm,
          c.maxVoltageDropRatio,
          c.sourceId,
          c.sourceRevision,
          c.impedanceEvidence?.sourceKey,
          c.impedanceEvidence?.resistanceOhmPerKm,
          c.impedanceEvidence?.reactanceOhmPerKm,
          for (final section in c.ampacitySections.toList()
            ..sort((a, b) => a.sectionId.compareTo(b.sectionId)))
            [
              section.sectionId,
              section.baseAmpacityA,
              section.sourceKey,
              for (final factor in section.factors.toList()
                ..sort((a, b) => a.id.compareTo(b.id)))
                [factor.id, factor.factor],
            ],
        ],
      for (final d in devices)
        [
          d.id,
          d.sourceId,
          d.sourceRevision,
          d.kind.name,
          d.ratedCurrentA,
          d.breakingCapacityKa,
          d.poleCount,
          d.tripCurve?.name,
        ],
    ];
  }
}
