import 'dart:convert';

import '../../../domain/canonical_power_selection.dart';
import '../../../domain/project_identity.dart';
import '../../../domain/semantic_sha256.dart';
import 'canonical_residual_protection_assignment.dart';
import 'engineering_evidence_review_gate.dart';
import 'power_electrical_safety_gate.dart';
import 'power_fault_envelope_gate.dart';

/// Device-specific, manufacturer-reviewed residual-current evidence.
/// No default operating time, threshold or RCD type is inferred.
final class ReviewedResidualDeviceCharacteristic {
  ReviewedResidualDeviceCharacteristic({
    required this.protectionCatalogId,
    required this.deviceType,
    required this.ratedResidualCurrentMa,
    required this.measuredOperatingResidualCurrentMa,
    required this.measuredTripTimeMs,
    required this.testResidualCurrentMa,
    required this.sourceId,
    this.manufacturerId,
    this.manufacturerDocumentRevision,
  }) {
    if (protectionCatalogId.trim().isEmpty ||
        deviceType.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        !ratedResidualCurrentMa.isFinite ||
        !measuredOperatingResidualCurrentMa.isFinite ||
        !measuredTripTimeMs.isFinite ||
        !testResidualCurrentMa.isFinite ||
        ratedResidualCurrentMa <= 0 ||
        measuredOperatingResidualCurrentMa <= 0 ||
        measuredTripTimeMs <= 0 ||
        testResidualCurrentMa <= 0) {
      throw ArgumentError('Complete positive RCD characteristic required.');
    }
  }

  final String protectionCatalogId;
  final String deviceType;
  final double ratedResidualCurrentMa;
  final double measuredOperatingResidualCurrentMa;
  final double measuredTripTimeMs;
  final double testResidualCurrentMa;
  final String sourceId;
  final String? manufacturerId;
  final String? manufacturerDocumentRevision;

  bool get hasReviewedManufacturerIdentity =>
      manufacturerId != null &&
      manufacturerId!.trim().isNotEmpty &&
      manufacturerDocumentRevision != null &&
      manufacturerDocumentRevision!.trim().isNotEmpty;

  String fingerprintFor(CircuitId circuitId) => semanticSha256Hex(jsonEncode([
        'p12a8.reviewed-residual-characteristic.v1',
        circuitId.value,
        protectionCatalogId,
        canonical,
      ]));

  List<Object?> get canonical => [
        protectionCatalogId,
        deviceType,
        ratedResidualCurrentMa,
        measuredOperatingResidualCurrentMa,
        measuredTripTimeMs,
        testResidualCurrentMa,
        sourceId,
        manufacturerId,
        manufacturerDocumentRevision,
      ];
}

/// A verified manufacturer coordination statement for *one device pair*.
/// Time ordering alone is not proof of selective discrimination.
final class ReviewedProtectionCoordination {
  ReviewedProtectionCoordination({
    required this.downstreamProtectionCatalogId,
    required this.upstreamProtectionCatalogId,
    required this.coveredFaultCurrentKa,
    required this.sourceId,
    this.manufacturerId,
    this.coordinationDocumentRevision,
    this.coordinationTableId,
  }) {
    if (downstreamProtectionCatalogId.trim().isEmpty ||
        upstreamProtectionCatalogId.trim().isEmpty ||
        downstreamProtectionCatalogId == upstreamProtectionCatalogId ||
        sourceId.trim().isEmpty ||
        !coveredFaultCurrentKa.isFinite ||
        coveredFaultCurrentKa <= 0) {
      throw ArgumentError('Distinct reviewed coordination pair required.');
    }
  }

  final String downstreamProtectionCatalogId;
  final String upstreamProtectionCatalogId;
  final double coveredFaultCurrentKa;
  final String sourceId;

  /// Exact manufacturer coordination table and revision, not a generic
  /// statement that two product families are usually compatible.
  final String? manufacturerId;
  final String? coordinationDocumentRevision;
  final String? coordinationTableId;

  bool get hasReviewedManufacturerTable =>
      manufacturerId != null &&
      manufacturerId!.trim().isNotEmpty &&
      coordinationDocumentRevision != null &&
      coordinationDocumentRevision!.trim().isNotEmpty &&
      coordinationTableId != null &&
      coordinationTableId!.trim().isNotEmpty;

  String fingerprintFor(CircuitId circuitId) => semanticSha256Hex(jsonEncode([
        'p12a8.reviewed-selectivity-pair.v1',
        circuitId.value,
        downstreamProtectionCatalogId,
        canonical,
      ]));

  List<Object?> get canonical => [
        downstreamProtectionCatalogId,
        upstreamProtectionCatalogId,
        coveredFaultCurrentKa,
        sourceId,
        manufacturerId,
        coordinationDocumentRevision,
        coordinationTableId,
      ];
}

/// Earthing/PE and earth-fault loop evidence is mandatory for ADS.
final class ReviewedEarthingDisconnectionEvidence {
  ReviewedEarthingDisconnectionEvidence({
    required this.earthingArrangement,
    required this.measuredFaultLoopImpedanceOhm,
    required this.protectiveConductorContinuityVerified,
    required this.sourceId,
  }) {
    if (earthingArrangement.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        !measuredFaultLoopImpedanceOhm.isFinite ||
        measuredFaultLoopImpedanceOhm <= 0) {
      throw ArgumentError('Valid earthing and loop evidence is required.');
    }
  }

  final String earthingArrangement;
  final double measuredFaultLoopImpedanceOhm;
  final bool protectiveConductorContinuityVerified;
  final String sourceId;

  String fingerprintFor(
    CircuitId circuitId,
    String protectionCatalogId,
  ) =>
      semanticSha256Hex(jsonEncode([
        'p12a8.reviewed-earthing-and-ads.v1',
        circuitId.value,
        protectionCatalogId,
        earthingArrangement,
        measuredFaultLoopImpedanceOhm,
        protectiveConductorContinuityVerified,
        sourceId,
      ]));
}

enum PowerProtectionDeviceCheck {
  trustedResidualCharacteristic,
  residualCurrentThreshold,
  residualTripTime,
  trustedSelectivityPair,
  selectivityFaultCoverage,
  earthingAndPeContinuity,
  automaticDisconnection,
}

final class PowerProtectionDeviceAssessment {
  PowerProtectionDeviceAssessment(
    Map<PowerProtectionDeviceCheck, PowerSafetyVerdict> values,
  ) : checks = Map.unmodifiable(values);

  final Map<PowerProtectionDeviceCheck, PowerSafetyVerdict> checks;

  PowerSafetyVerdict get verdict {
    if (checks.values.contains(PowerSafetyVerdict.fail)) {
      return PowerSafetyVerdict.fail;
    }
    if (checks.length != PowerProtectionDeviceCheck.values.length ||
        checks.values.contains(PowerSafetyVerdict.indeterminate)) {
      return PowerSafetyVerdict.indeterminate;
    }
    return PowerSafetyVerdict.pass;
  }

  /// Never authorizes a canonical project mutation.
  bool get readyToApply => false;
}

/// Numerical limits must be independently attested by the same normative
/// profile record. This is an explicit engineering policy, not an IEC default.
final class PowerProtectionDeviceLimits {
  PowerProtectionDeviceLimits({
    required this.maximumResidualOperatingCurrentMa,
    required this.maximumResidualTripTimeMs,
  }) {
    if (!maximumResidualOperatingCurrentMa.isFinite ||
        !maximumResidualTripTimeMs.isFinite ||
        maximumResidualOperatingCurrentMa <= 0 ||
        maximumResidualTripTimeMs <= 0) {
      throw ArgumentError('Positive reviewed protection limits required.');
    }
  }

  final double maximumResidualOperatingCurrentMa;
  final double maximumResidualTripTimeMs;

  String fingerprintFor(PowerSafetyRuleProfile profile) =>
      semanticSha256Hex(jsonEncode([
        'p12a8.protection-device-limits.v1',
        profile.fingerprint,
        canonical,
      ]));

  List<Object?> get canonical => [
        maximumResidualOperatingCurrentMa,
        maximumResidualTripTimeMs,
      ];
}

/// All manufacturer values and applicability must be ingested and reviewed by
/// an independent registry. A caller-built device report is not authority.
abstract final class PowerProtectionDeviceGate {
  static PowerProtectionDeviceAssessment evaluate({
    required CanonicalPowerCircuitSelection selection,
    required PowerCircuitFaultEnvelope faultEnvelope,
    required PowerFaultEnvelopeAssessment faultAssessment,
    required ReviewedResidualDeviceCharacteristic residualDevice,
    CanonicalResidualProtectionAssignment? upstreamRcdAssignment,
    required ReviewedProtectionCoordination coordination,
    required ReviewedEarthingDisconnectionEvidence earthing,
    required PowerProtectionDeviceLimits limits,
    required PowerSafetyRuleProfile profile,
    required TrustedEngineeringEvidenceRegistry registry,
  }) {
    final checks = <PowerProtectionDeviceCheck, PowerSafetyVerdict>{
      for (final check in PowerProtectionDeviceCheck.values)
        check: PowerSafetyVerdict.indeterminate,
    };
    final pins = {for (final s in selection.sources) s.sourceId: s};
    final normativePin = pins[profile.normativeSourceId];
    final normative = registry.lookup(profile.normativeSourceId);
    final normativeFingerprint = limits.fingerprintFor(profile);
    if (selection.normativeSourceId != profile.normativeSourceId ||
        normativePin == null ||
        normative == null ||
        normative.sourceId != normativePin.sourceId ||
        normative.revision != normativePin.revision ||
        normative.contentSha256 != normativePin.sha256 ||
        normative.approvalId != normativePin.approvalId ||
        normative.isApproved != true ||
        normative.isRevoked != false ||
        normative.jurisdiction != profile.jurisdiction ||
        normative.applicationScope != profile.applicationScope ||
        normative.verifiedRuleProfileFingerprint != profile.fingerprint ||
        normative.verifiedProtectionLimitsFingerprint != normativeFingerprint ||
        registry.revision.trim().isEmpty) {
      return PowerProtectionDeviceAssessment(checks);
    }
    PowerSafetyVerdict reviewed(
      String sourceId,
      String purpose,
      String expectedFingerprint,
    ) {
      final pin = pins[sourceId];
      final record = registry.lookup(sourceId);
      if (pin == null ||
          record == null ||
          record.sourceId != pin.sourceId ||
          record.revision != pin.revision ||
          record.contentSha256 != pin.sha256 ||
          record.approvalId != pin.approvalId ||
          !record.isApproved ||
          record.isRevoked ||
          record.jurisdiction != profile.jurisdiction ||
          record.applicationScope != profile.applicationScope ||
          record.subjectCircuitId != selection.circuitId.value ||
          record.evidencePurpose != purpose ||
          record.verifiedCalculationFingerprint != expectedFingerprint ||
          registry.revision.trim().isEmpty) {
        return PowerSafetyVerdict.indeterminate;
      }
      return switch (record.verifiedSafetyFinding) {
        EngineeringVerifiedSafetyFinding.supported => PowerSafetyVerdict.pass,
        EngineeringVerifiedSafetyFinding.contradicted =>
          PowerSafetyVerdict.fail,
        _ => PowerSafetyVerdict.indeterminate,
      };
    }

    final residualFingerprint =
        residualDevice.fingerprintFor(selection.circuitId);
    final kind = selection.protectionRatings.deviceKind.trim().toLowerCase();
    final deviceType = residualDevice.deviceType.trim().toLowerCase();
    final selectedRcbo = kind == 'rcbo' &&
        residualDevice.hasReviewedManufacturerIdentity &&
        deviceType.startsWith('rcbo') &&
        residualDevice.protectionCatalogId == selection.protectionCatalogId;
    // Ordinary MCB circuits are protected by a separate upstream RCD only
    // when both the actual P11 circuit coverage and the upstream catalog
    // identity are independently attested. An in-memory assignment alone
    // is never authority to grant residual-current protection.
    final assignment = upstreamRcdAssignment;
    final assignmentRecord = assignment == null
        ? null
        : registry.lookup(assignment.evidenceSourceId);
    final upstreamRcd = kind == 'mcb' &&
        residualDevice.hasReviewedManufacturerIdentity &&
        deviceType.startsWith('rcd') &&
        assignment != null &&
        assignment.matches(selection) &&
        assignment.upstreamResidualCatalogId ==
            residualDevice.protectionCatalogId &&
        assignment.evidenceSourceId == residualDevice.sourceId &&
        pins.containsKey(assignment.evidenceSourceId) &&
        assignmentRecord?.verifiedResidualTopologyFingerprint ==
            assignment.fingerprint;
    final residualReview = (selectedRcbo || upstreamRcd)
        ? reviewed(
            residualDevice.sourceId, 'rcd-protection', residualFingerprint)
        : PowerSafetyVerdict.indeterminate;
    checks[PowerProtectionDeviceCheck.trustedResidualCharacteristic] =
        residualReview;
    if (residualReview == PowerSafetyVerdict.pass) {
      checks[PowerProtectionDeviceCheck.residualCurrentThreshold] =
          residualDevice.measuredOperatingResidualCurrentMa <=
                      residualDevice.ratedResidualCurrentMa &&
                  residualDevice.measuredOperatingResidualCurrentMa <=
                      limits.maximumResidualOperatingCurrentMa
              ? PowerSafetyVerdict.pass
              : PowerSafetyVerdict.fail;
      // The exact test stimulus is part of the signed source. A manufacturer
      // or competent engineer must validate its normative test applicability.
      checks[PowerProtectionDeviceCheck.residualTripTime] =
          residualDevice.measuredTripTimeMs <= limits.maximumResidualTripTimeMs
              ? PowerSafetyVerdict.pass
              : PowerSafetyVerdict.fail;
    }

    final coordinationFingerprint =
        coordination.fingerprintFor(selection.circuitId);
    final coordinationReview = registry.lookup(coordination.sourceId);
    final pairReview = coordination.hasReviewedManufacturerTable &&
            coordination.downstreamProtectionCatalogId ==
                selection.protectionCatalogId &&
            coordinationReview?.verifiedUpstreamProtectionCatalogId ==
                coordination.upstreamProtectionCatalogId
        ? reviewed(coordination.sourceId, 'selectivity-coordination',
            coordinationFingerprint)
        : PowerSafetyVerdict.indeterminate;
    checks[PowerProtectionDeviceCheck.trustedSelectivityPair] = pairReview;
    if (pairReview == PowerSafetyVerdict.pass) {
      final maxFault = faultEnvelope.scenarios
          .map((s) => s.maximumProspectiveFaultKa)
          .reduce((a, b) => a > b ? a : b);
      checks[PowerProtectionDeviceCheck.selectivityFaultCoverage] =
          coordination.coveredFaultCurrentKa >= maxFault
              ? PowerSafetyVerdict.pass
              : PowerSafetyVerdict.fail;
    }

    final earthingReview = reviewed(
      earthing.sourceId,
      'earthing-and-ads',
      earthing.fingerprintFor(
        selection.circuitId,
        selection.protectionCatalogId,
      ),
    );
    checks[PowerProtectionDeviceCheck.earthingAndPeContinuity] =
        earthingReview == PowerSafetyVerdict.pass &&
                !earthing.protectiveConductorContinuityVerified
            ? PowerSafetyVerdict.fail
            : earthingReview;

    // Automatic disconnection requires reviewed PE/earthing measurements and
    // *every* independently reviewed minimum-fault clearing scenario.
    checks[PowerProtectionDeviceCheck.automaticDisconnection] = checks[
                    PowerProtectionDeviceCheck.earthingAndPeContinuity] ==
                PowerSafetyVerdict.pass &&
            faultAssessment.verifiedEnvelopeFingerprint ==
                faultEnvelope.fingerprint &&
            faultAssessment.checks[
                    PowerFaultEnvelopeCheck.minimumFaultDisconnection] ==
                PowerSafetyVerdict.pass &&
            faultAssessment.checks[PowerFaultEnvelopeCheck.trustedEnvelope] ==
                PowerSafetyVerdict.pass &&
            faultAssessment
                    .checks[PowerFaultEnvelopeCheck.completeSupplyCoverage] ==
                PowerSafetyVerdict.pass &&
            faultAssessment.verdict == PowerSafetyVerdict.pass
        ? PowerSafetyVerdict.pass
        : PowerSafetyVerdict.indeterminate;
    return PowerProtectionDeviceAssessment(checks);
  }
}
