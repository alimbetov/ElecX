import 'component_catalog_engineering_metadata.dart';
import 'power_starter_generation.dart';

/// A catalog record can qualify a board type for preview, but does not prove
/// board busbar rating, short-circuit capacity, enclosure IP rating, or any
/// protective-device/cable engineering selection.
enum PowerBoardCatalogStatus {
  qualifiedForPreview,
  snapshotMismatch,
  componentMissing,
  incompatible,
  missingSourceFacts,
}

enum PowerBoardEngineeringIssue {
  catalogBoardNotQualified,
  boardElectricalRatingsNotProven,
}

/// A deterministic read-only catalog qualification overlay on a POWER preview.
///
/// No persistent canonical IDs are allocated, no ProjectChangeSet is produced,
/// and a catalog identity/provenance match is never treated as engineering
/// approval or proof of board capacity.
final class PowerBoardCatalogQualification {
  PowerBoardCatalogQualification({
    required this.candidate,
    required this.status,
    required this.fingerprint,
    required this.requestedComponentTypeId,
    this.record,
  }) {
    if ((status == PowerBoardCatalogStatus.qualifiedForPreview) !=
        (record != null)) {
      throw ArgumentError(
        'Only qualified preview results may expose a board catalog record.',
      );
    }
  }

  final PowerStarterCandidate candidate;
  final PowerBoardCatalogStatus status;
  final String fingerprint;
  final String requestedComponentTypeId;
  final ComponentCatalogEngineeringRecord? record;

  bool get hasQualifiedBoardType =>
      status == PowerBoardCatalogStatus.qualifiedForPreview;

  /// Board electrical design ratings do not exist in V2 catalog metadata.
  /// Capacity therefore always remains unresolved in this stage.
  List<PowerBoardEngineeringIssue> get engineeringIssues => List.unmodifiable([
        if (!hasQualifiedBoardType)
          PowerBoardEngineeringIssue.catalogBoardNotQualified,
        PowerBoardEngineeringIssue.boardElectricalRatingsNotProven,
      ]);

  List<PowerStarterIssue> get remainingStarterIssues => List.unmodifiable([
        for (final issue in candidate.issues)
          if (!hasQualifiedBoardType ||
              issue.code != PowerStarterIssueCode.boardCatalogSelectionRequired)
            issue,
      ]);

  bool get readyToApply => false;
}
