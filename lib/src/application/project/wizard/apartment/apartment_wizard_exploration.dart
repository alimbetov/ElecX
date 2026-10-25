import 'apartment_candidate_set_service.dart';
import 'apartment_wizard_parameters.dart';

/// P9.9 semantic exploration states layered beside the shared P8 WizardSession.
///
/// This controller owns no canonical project state and no preview/commit engine.
/// It only owns apartment-specific transient request/candidate/selection state.
enum ApartmentWizardExplorationStatus {
  editingParameters,
  generating,
  candidatesReady,
  candidateSelected,
  preparingPreview,
  previewReady,
  applying,
  completed,
  cancelled,
  failed,
}

final class ApartmentGenerationTicket {
  const ApartmentGenerationTicket({
    required this.requestRevision,
    required this.intentFingerprint,
  });

  final int requestRevision;
  final String intentFingerprint;
}

final class ApartmentWizardExplorationController {
  ApartmentWizardExplorationController({
    ApartmentWizardParameters? initialParameters,
  }) : parameters = initialParameters ??
            const ApartmentWizardParameters(
              request: ApartmentRequestInput.productionDefaults,
            );

  ApartmentWizardParameters parameters;
  ApartmentCandidateSet? candidateSet;
  ApartmentWizardExplorationStatus status =
      ApartmentWizardExplorationStatus.editingParameters;
  int requestRevision = 0;
  ApartmentGenerationTicket? _inFlight;

  ApartmentGenerationTicket? get inFlight => _inFlight;
  bool get generationInProgress => _inFlight != null;

  void updateRequest(ApartmentRequestInput request) {
    final previousSelection = parameters.selection;
    final next = parameters.withRequest(request);
    final normalizedBefore = const ApartmentRequestNormalizer()
        .normalize(parameters.request)
        .request;
    final normalizedAfter =
        const ApartmentRequestNormalizer().normalize(request).request;
    final sameIntent = normalizedBefore != null &&
        normalizedAfter != null &&
        normalizedBefore.intentFingerprint == normalizedAfter.intentFingerprint;

    parameters = next;
    if (sameIntent) {
      return;
    }

    requestRevision++;
    candidateSet = null;
    _inFlight = null;
    status = ApartmentWizardExplorationStatus.editingParameters;
    if (previousSelection != null && parameters.selection != null) {
      throw StateError('Semantic request change must clear selection.');
    }
  }

  /// Starts one authoritative generation for the current semantic revision.
  /// Duplicate activation returns the same ticket instead of creating a second
  /// authoritative operation.
  ApartmentGenerationTicket beginGeneration() {
    final normalized =
        const ApartmentRequestNormalizer().normalize(parameters.request);
    final request = normalized.request;
    if (request == null || normalized.hasBlockers) {
      throw StateError('Cannot generate candidates from invalid P9 request.');
    }
    final active = _inFlight;
    if (active != null && active.requestRevision == requestRevision) {
      return active;
    }
    final ticket = ApartmentGenerationTicket(
      requestRevision: requestRevision,
      intentFingerprint: request.intentFingerprint,
    );
    _inFlight = ticket;
    status = ApartmentWizardExplorationStatus.generating;
    return ticket;
  }

  /// Publishes a generation result only if its revision is still authoritative.
  /// A late result for an obsolete semantic request is ignored.
  bool publishGeneration(
    ApartmentGenerationTicket ticket,
    ApartmentCandidateSetGenerationResult result,
  ) {
    final active = _inFlight;
    if (active == null ||
        !identicalTicket(active, ticket) ||
        ticket.requestRevision != requestRevision) {
      return false;
    }
    final normalized = const ApartmentRequestNormalizer()
        .normalize(parameters.request)
        .request;
    if (normalized == null ||
        normalized.intentFingerprint != ticket.intentFingerprint) {
      _inFlight = null;
      return false;
    }

    _inFlight = null;
    final nextSet = result.candidateSet;
    if (!result.accepted || nextSet == null) {
      candidateSet = null;
      parameters = parameters.withSelection(null);
      status = ApartmentWizardExplorationStatus.failed;
      return true;
    }
    if (nextSet.request.intentFingerprint != ticket.intentFingerprint) {
      return false;
    }

    candidateSet = nextSet;
    parameters = parameters.withSelection(null);
    status = ApartmentWizardExplorationStatus.candidatesReady;
    return true;
  }

  void selectCandidate(String candidateFingerprint) {
    final set = candidateSet;
    if (set == null) {
      throw StateError('No current apartment candidate set.');
    }
    ApartmentCandidateCard? selected;
    for (final candidate in set.candidates) {
      if (candidate.candidateFingerprint == candidateFingerprint) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) {
      throw StateError('p9.provider.selection-not-found');
    }
    parameters = parameters.withSelection(selected.identity.toSelection());
    status = ApartmentWizardExplorationStatus.candidateSelected;
  }

  ApartmentCandidateCard selectedCandidate() {
    final set = candidateSet;
    final selection = parameters.selection;
    if (set == null || selection == null) {
      throw StateError('p9.provider.selection-required');
    }
    final selected = set.resolveSelection(selection);
    if (selected == null) {
      throw StateError('p9.provider.selection-stale');
    }
    return selected;
  }

  void markPreparingPreview() {
    selectedCandidate();
    status = ApartmentWizardExplorationStatus.preparingPreview;
  }

  void markPreviewReady() {
    selectedCandidate();
    status = ApartmentWizardExplorationStatus.previewReady;
  }

  void markApplying() {
    selectedCandidate();
    status = ApartmentWizardExplorationStatus.applying;
  }

  void markCompleted() {
    status = ApartmentWizardExplorationStatus.completed;
  }

  void cancel() {
    _inFlight = null;
    status = ApartmentWizardExplorationStatus.cancelled;
  }

  /// Semantic Back never mutates request/candidate identity. It only changes the
  /// current navigation state to the nearest recoverable step.
  void back() {
    switch (status) {
      case ApartmentWizardExplorationStatus.previewReady:
      case ApartmentWizardExplorationStatus.preparingPreview:
      case ApartmentWizardExplorationStatus.applying:
        status = parameters.selection == null
            ? ApartmentWizardExplorationStatus.candidatesReady
            : ApartmentWizardExplorationStatus.candidateSelected;
        break;
      case ApartmentWizardExplorationStatus.candidateSelected:
        status = ApartmentWizardExplorationStatus.candidatesReady;
        break;
      case ApartmentWizardExplorationStatus.candidatesReady:
      case ApartmentWizardExplorationStatus.failed:
        status = ApartmentWizardExplorationStatus.editingParameters;
        break;
      case ApartmentWizardExplorationStatus.generating:
        _inFlight = null;
        status = ApartmentWizardExplorationStatus.editingParameters;
        break;
      case ApartmentWizardExplorationStatus.editingParameters:
      case ApartmentWizardExplorationStatus.completed:
      case ApartmentWizardExplorationStatus.cancelled:
        break;
    }
  }
}

bool identicalTicket(
  ApartmentGenerationTicket left,
  ApartmentGenerationTicket right,
) =>
    left.requestRevision == right.requestRevision &&
    left.intentFingerprint == right.intentFingerprint;
