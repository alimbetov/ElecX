import 'package:elecx/src/application/project/engineering/engineering_evidence_review_gate.dart';
import 'package:elecx/src/engine/power_evidence_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

PowerEvidenceSourcePin _pin({
  String revision = 'r1',
  String digest = _digest,
}) =>
    PowerEvidenceSourcePin(
      sourceId: 'reviewed-document',
      revision: revision,
      contentSha256: digest,
      approvalId: 'review-01',
    );

EngineeringEvidenceReviewRecord _record({
  String revision = 'r1',
  String digest = _digest,
  bool approved = true,
  bool revoked = false,
  String jurisdiction = 'KZ',
  String scope = 'POWER-AC',
}) =>
    EngineeringEvidenceReviewRecord(
      sourceId: 'reviewed-document',
      revision: revision,
      contentSha256: digest,
      approvalId: 'review-01',
      jurisdiction: jurisdiction,
      applicationScope: scope,
      isApproved: approved,
      isRevoked: revoked,
    );

final class _Registry implements TrustedEngineeringEvidenceRegistry {
  _Registry(this.record, {this.revision = 'registry-v1'});

  final EngineeringEvidenceReviewRecord? record;

  @override
  final String revision;

  @override
  EngineeringEvidenceReviewRecord? lookup(String sourceId) =>
      sourceId == record?.sourceId ? record : null;
}

EngineeringEvidenceReviewResult _evaluate({
  EngineeringEvidenceReviewRecord? record,
  bool missing = false,
  String registryRevision = 'registry-v1',
  String jurisdiction = 'KZ',
  String scope = 'POWER-AC',
  Iterable<PowerEvidenceSourcePin>? pins,
}) =>
    EngineeringEvidenceReviewGate.evaluate(
      requiredSources: pins ?? [_pin()],
      registry: _Registry(
        missing ? null : (record ?? _record()),
        revision: registryRevision,
      ),
      jurisdiction: jurisdiction,
      applicationScope: scope,
    );

void main() {
  group('P12A.8 trusted evidence preflight', () {
    test('exact reviewed pins qualify only the evidence preflight', () {
      final result = _evaluate();
      expect(result.isQualified, isTrue);
      expect(result.registryRevision, 'registry-v1');
      expect(result.issues, isEmpty);
    });

    test('missing, revoked and unapproved reviews fail closed', () {
      expect(
        _evaluate(missing: true).issues,
        contains(EngineeringEvidenceReviewIssue.missingSource),
      );
      expect(
        _evaluate(record: _record(revoked: true)).issues,
        contains(EngineeringEvidenceReviewIssue.revokedSource),
      );
      expect(
        _evaluate(record: _record(approved: false)).issues,
        contains(EngineeringEvidenceReviewIssue.unapprovedSource),
      );
    });

    test('digest and normative revision mismatch fail closed', () {
      expect(
        _evaluate(record: _record(revision: 'r2')).issues,
        contains(EngineeringEvidenceReviewIssue.mismatchedIdentity),
      );
      expect(
        _evaluate(record: _record(digest: List.filled(64, 'b').join())).issues,
        contains(EngineeringEvidenceReviewIssue.mismatchedIdentity),
      );
    });

    test('jurisdiction and application scope are strict', () {
      expect(
        _evaluate(record: _record(jurisdiction: 'OTHER')).issues,
        contains(EngineeringEvidenceReviewIssue.wrongJurisdiction),
      );
      expect(
        _evaluate(record: _record(scope: 'POWER-DC')).issues,
        contains(EngineeringEvidenceReviewIssue.wrongApplicationScope),
      );
    });

    test('empty registry revision and duplicate sources fail closed', () {
      expect(
        _evaluate(registryRevision: ' ').issues,
        contains(EngineeringEvidenceReviewIssue.invalidRegistryRevision),
      );
      expect(
        _evaluate(pins: [_pin(), _pin()]).issues,
        contains(EngineeringEvidenceReviewIssue.mismatchedIdentity),
      );
    });

    test('empty required sources never qualify', () {
      expect(
        _evaluate(pins: []).issues,
        contains(EngineeringEvidenceReviewIssue.missingRequiredSources),
      );
    });

    test('review issue order is deterministic', () {
      final result = _evaluate(
        record: _record(
          approved: false,
          revoked: true,
          jurisdiction: 'OTHER',
          scope: 'POWER-DC',
        ),
      );
      expect(result.issues, [
        EngineeringEvidenceReviewIssue.unapprovedSource,
        EngineeringEvidenceReviewIssue.revokedSource,
        EngineeringEvidenceReviewIssue.wrongJurisdiction,
        EngineeringEvidenceReviewIssue.wrongApplicationScope,
      ]);
    });
  });
}
