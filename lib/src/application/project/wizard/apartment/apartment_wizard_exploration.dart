import 'apartment_candidate_set_service.dart';
import 'apartment_wizard_parameters.dart';

/// P9.9 apartment-specific exploration state layered beside the shared P8
/// [WizardSession].
///
/// This state stops at exact candidate selection. Preview, commit, completion,
/// cancellation and their failures remain authoritative in P8 WizardSession so
/// P9.9 cannot become a second transaction/lifecycle state machine.
enum ApartmentWizardExplorationStatus {
  editingParameters,
  generating,
  candidatesReady,
  candidateSelected,
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
  }) : _parameters = initialParameters ??
            const ApartmentWizardParameters(
              request: ApartmentRequestInput.productionDefaults,
            );

  ApartmentWizardParameters _parameters;
  ApartmentCandidateSet? _candidateSet;
  ApartmentWizardExplorationStatus _status =
      ApartmentWizardExplorationStatus.editingParameters;
  int _requestRevision = 0;
  ApartmentGenerationTicket? _inFlight;

  ApartmentWizardParameters get parameters => _parameters;
  ApartmentCandidateSet? get candidateSet => _candidateSet;
  ApartmentWizardExplorationStatus get status => _status;
  int get requestRevision => _requestRevision;
  ApartmentGenerationTicket? get inFlight => _inFlight;
  bool get generationInProgress => _inFlight != null;

  void updateRequest(ApartmentRequestInput request) {
    final previousSelection = _parameters.selection;
    final normalizedBefore = const ApartmentRequestNormalizer()
        .normalize(_parameters.request)
        .request;
    final normalizedAfter =
        const ApartmentRequestNormalizer().normalize(request).request;
    final sameIntent = normalizedBefore != null &&
        normalizedAfter != null &&
        normalizedBefore.intentFingerprint == normalizedAfter.intentFingerprint;

    _parameters = _parameters.withRequest(request);
    if (sameIntent) {
      return;
    }

    _requestRevision++;
    _candidateSet = null;
    _inFlight = null;
    _status = ApartmentWizardExplorationStatus.editingParameters;
    if (previousSelection != null && _parameters.selection != null) {
      throw StateError('Semantic request change must clear selection.');
    }
  }

  /// Starts one authoritative generation for the current semantic revision.
  /// Duplicate activation returns the same ticket instead of creating a second
  /// authoritative operation.
  ApartmentGenerationTicket beginGeneration() {
    final normalized =
        const ApartmentRequestNormalizer().normalize(_parameters.request);
    final request = normalized.request;
    if (request == null || normalized.hasBlockers) {
      throw StateError('Cannot generate candidates from invalid P9 request.');
    }
    final active = _inFlight;
    if (active != null && active.requestRevision == _requestRevision) {
      return active;
    }
    final ticket = ApartmentGenerationTicket(
      requestRevision: _requestRevision,
      intentFingerprint: request.intentFingerprint,
    );
    _inFlight = ticket;
    _status = ApartmentWizardExplorationStatus.generating;
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
        !_sameTicket(active, ticket) ||
        ticket.requestRevision != _requestRevision) {
      return false;
    }

    final normalized = const ApartmentRequestNormalizer()
        .normalize(_parameters.request)
        .request;
    if (normalized == null ||
        normalized.intentFingerprint != ticket.intentFingerprint) {
      _failAuthoritativeGeneration();
      return false;
    }

    final nextSet = result.candidateSet;
    if (!result.accepted || nextSet == null) {
      _inFlight = null;
      _candidateSet = null;
      _parameters = _parameters.withSelection(null);
      _status = ApartmentWizardExplorationStatus.failed;
      return true;
    }
    if (nextSet.request.intentFingerprint != ticket.intentFingerprint) {
      _failAuthoritativeGeneration();
      return false;
    }

    _inFlight = null;
    _candidateSet = nextSet;
    _parameters = _parameters.withSelection(null);
    _status = ApartmentWizardExplorationStatus.candidatesReady;
    return true;
  }

  void selectCandidate(String candidateFingerprint) {
    final set = _candidateSet;
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
    _parameters = _parameters.withSelection(set.selectionFor(selected));
    _status = ApartmentWizardExplorationStatus.candidateSelected;
  }

  ApartmentCandidateCard selectedCandidate() {
    final set = _candidateSet;
    final selection = _parameters.selection;
    if (set == null || selection == null) {
      throw StateError('p9.provider.selection-required');
    }
    if (selection.candidateSetFingerprint != set.candidateSetFingerprint) {
      throw StateError('p9.provider.candidate-set-stale');
    }
    final selected = set.resolveSelection(selection);
    if (selected == null) {
      throw StateError('p9.provider.selection-stale');
    }
    return selected;
  }

  /// Clears apartment-specific transient state when the outer P8 Wizard exits.
  /// P8 remains the sole owner of the cancelled/completed lifecycle status.
  void discardTransientState() {
    _inFlight = null;
    _candidateSet = null;
    _parameters = _parameters.withSelection(null);
    _status = ApartmentWizardExplorationStatus.editingParameters;
  }

  /// Apartment exploration Back never mutates request/candidate identity. Once
  /// P8 Preview starts, Back is handled by the shared WizardSession instead.
  void back() {
    switch (_status) {
      case ApartmentWizardExplorationStatus.candidateSelected:
        _status = ApartmentWizardExplorationStatus.candidatesReady;
        break;
      case ApartmentWizardExplorationStatus.candidatesReady:
      case ApartmentWizardExplorationStatus.failed:
        _status = ApartmentWizardExplorationStatus.editingParameters;
        break;
      case ApartmentWizardExplorationStatus.generating:
        _inFlight = null;
        _status = ApartmentWizardExplorationStatus.editingParameters;
        break;
      case ApartmentWizardExplorationStatus.editingParameters:
        break;
    }
  }

  void _failAuthoritativeGeneration() {
    _inFlight = null;
    _candidateSet = null;
    _parameters = _parameters.withSelection(null);
    _status = ApartmentWizardExplorationStatus.failed;
  }
}

bool _sameTicket(
  ApartmentGenerationTicket left,
  ApartmentGenerationTicket right,
) =>
    left.requestRevision == right.requestRevision &&
    left.intentFingerprint == right.intentFingerprint;
