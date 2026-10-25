import 'package:flutter/material.dart';

import '../../application/project/project_mutation_reservation.dart';
import '../../application/project/wizard/apartment/apartment_candidate_set_service.dart';
import '../../application/project/wizard/apartment/apartment_wizard_exploration.dart';
import '../../application/project/wizard/apartment/apartment_wizard_parameters.dart';
import '../../application/project/wizard/apartment/apartment_wizard_provider.dart';
import '../../application/project/wizard/wizard_contracts.dart';
import '../../application/project/wizard/wizard_diff.dart';
import '../../application/project/wizard/wizard_preview_scene.dart';
import '../../application/project/wizard/wizard_session.dart';
import '../../domain/apartment_topology.dart';
import '../../domain/apartment_topology/apartment_vector_scene.dart';
import 'project_wizard_localizations.dart';
import 'wizard_candidate_carousel.dart';
import 'wizard_diff_panel.dart';

enum _ApartmentWizardPage { parameters, candidates, preview, changes }

/// P9.9/P9.10 production presentation adapter.
///
/// Apartment exploration owns only transient request/candidate selection state.
/// Once the user asks for the canonical Preview, the existing P8 [WizardSession]
/// becomes the sole lifecycle authority for reservation, stale checks, Apply,
/// cancellation and the exact frozen candidate committed to project history.
final class ApartmentWizardScreen extends StatefulWidget {
  const ApartmentWizardScreen({
    required this.session,
    this.candidateSetService = const ApartmentCandidateSetService(),
    super.key,
  });

  final WizardSession session;
  final ApartmentCandidateSetService candidateSetService;

  static Future<ReservedProjectMutationCommitResult?> show({
    required BuildContext context,
    required WizardSession session,
    ApartmentCandidateSetService candidateSetService =
        const ApartmentCandidateSetService(),
  }) =>
      Navigator.of(context).push<ReservedProjectMutationCommitResult>(
        MaterialPageRoute<ReservedProjectMutationCommitResult>(
          builder: (_) => ApartmentWizardScreen(
            session: session,
            candidateSetService: candidateSetService,
          ),
        ),
      );

  @override
  State<ApartmentWizardScreen> createState() => _ApartmentWizardScreenState();
}

final class _ApartmentWizardScreenState extends State<ApartmentWizardScreen> {
  late final ApartmentWizardExplorationController _exploration;
  late final TextEditingController _roomsController;
  late final TextEditingController _areaController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _wcController;
  late final TextEditingController _balconiesController;
  late ApartmentKitchenMode _kitchenMode;
  late ApartmentCorridorMode _corridorMode;
  late ApartmentBalconyKind _balconyKind;
  late bool _preferDayNight;

  final PreviewViewportState _previewViewport = PreviewViewportState();
  List<WizardCandidateCard> _candidateCards = const [];
  String? _selectedCandidateId;
  WizardPreviewScene? _canonicalScene;
  WizardDiffModel? _diff;
  _ApartmentWizardPage _compactPage = _ApartmentWizardPage.parameters;
  bool _applyInProgress = false;

  WizardSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    if (_session.status == WizardSessionStatus.idle) {
      _session.begin();
    }
    if (_session.status == WizardSessionStatus.selectingFamily) {
      _session.selectFamily(ApartmentWizardProvider.familyId);
    }
    final initial = _session.parameters is ApartmentWizardParameters
        ? _session.parameters! as ApartmentWizardParameters
        : const ApartmentWizardParameters(
            request: ApartmentRequestInput.productionDefaults,
          );
    _exploration = ApartmentWizardExplorationController(
      initialParameters: initial,
    );
    final request = initial.request;
    _roomsController =
        TextEditingController(text: request.habitableRoomCount.toString());
    _areaController = TextEditingController(
      text: (request.approximateAreaDm2 / 100).toStringAsFixed(1),
    );
    _bathroomsController =
        TextEditingController(text: request.bathroomCount.toString());
    _wcController =
        TextEditingController(text: request.separateWcCount.toString());
    _balconiesController =
        TextEditingController(text: request.balconyCount.toString());
    _kitchenMode = request.kitchenMode;
    _corridorMode = request.corridorMode;
    _balconyKind = request.balconyKind;
    _preferDayNight = request.preferDayNightSeparation;
  }

  @override
  void dispose() {
    _roomsController.dispose();
    _areaController.dispose();
    _bathroomsController.dispose();
    _wcController.dispose();
    _balconiesController.dispose();
    _previewViewport.dispose();
    super.dispose();
  }

  ApartmentRequestInput? _draftRequest() {
    final rooms = int.tryParse(_roomsController.text.trim());
    final areaM2 =
        double.tryParse(_areaController.text.trim().replaceAll(',', '.'));
    final bathrooms = int.tryParse(_bathroomsController.text.trim());
    final wc = int.tryParse(_wcController.text.trim());
    final balconies = int.tryParse(_balconiesController.text.trim());
    if (rooms == null ||
        areaM2 == null ||
        bathrooms == null ||
        wc == null ||
        balconies == null) {
      return null;
    }
    final previous = _exploration.parameters.request;
    return ApartmentRequestInput(
      habitableRoomCount: rooms,
      approximateAreaDm2: (areaM2 * 100).round(),
      bathroomCount: bathrooms,
      separateWcCount: wc,
      balconyCount: balconies,
      balconyKind: balconies == 0 ? ApartmentBalconyKind.none : _balconyKind,
      kitchenMode: _kitchenMode,
      corridorMode: _corridorMode,
      exteriorExposurePreference: previous.exteriorExposurePreference,
      areaBasis: previous.areaBasis,
      preferredFamily: previous.preferredFamily,
      preferDayNightSeparation: _preferDayNight,
    );
  }

  void _onDraftChanged() {
    _discardPreparedPreviewForEditing();
    setState(() {
      _candidateCards = const [];
      _selectedCandidateId = null;
      _canonicalScene = null;
      _diff = null;
      _compactPage = _ApartmentWizardPage.parameters;
    });
  }

  void _generateCandidates() {
    final l10n = ProjectWizardLocalizations.of(context);
    final request = _draftRequest();
    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.apartmentNumericError)),
      );
      return;
    }
    final target = _session.target;
    if (target is! LevelWizardTarget) {
      return;
    }

    _discardPreparedPreviewForEditing();
    _exploration.updateRequest(request);
    ApartmentGenerationTicket ticket;
    try {
      ticket = _exploration.beginGeneration();
    } catch (_) {
      setState(() {});
      return;
    }
    final result = widget.candidateSetService.generate(
      input: request,
      target: target,
      project: _session.mutations.project,
    );
    _exploration.publishGeneration(ticket, result);
    final set = _exploration.candidateSet;
    if (set == null || set.candidates.isEmpty) {
      setState(() {
        _candidateCards = const [];
        _selectedCandidateId = null;
        _canonicalScene = null;
        _diff = null;
      });
      return;
    }

    final first = set.candidates.first;
    _exploration.selectCandidate(first.candidateFingerprint);
    setState(() {
      _candidateCards = [
        for (final card in set.candidates)
          WizardCandidateCard(
            id: card.candidateFingerprint,
            title: _candidateTitle(card),
            scene: _explorationScene(card),
          ),
      ];
      _selectedCandidateId = first.candidateFingerprint;
      _canonicalScene = null;
      _diff = null;
      _compactPage = _ApartmentWizardPage.candidates;
    });
  }

  void _selectCandidate(String candidateFingerprint) {
    if (_selectedCandidateId == candidateFingerprint) return;
    _discardPreparedPreviewForEditing();
    _exploration.selectCandidate(candidateFingerprint);
    setState(() {
      _selectedCandidateId = candidateFingerprint;
      _canonicalScene = null;
      _diff = null;
      _previewViewport.resetView();
    });
  }

  void _preparePreview() {
    if (_selectedCandidateId == null) return;
    _discardPreparedPreviewForEditing();
    final parameters = _exploration.parameters;
    if (!_session.updateParameters(parameters) &&
        _session.status != WizardSessionStatus.editingParameters) {
      return;
    }
    if (!_session.generatePreview() || _session.preview == null) {
      setState(() {});
      return;
    }
    final preview = _session.preview!;
    final scene = const ApartmentWizardPreviewProjector().project(preview);
    final diff = const WizardDiffProjector().project(
      before: _session.mutations.project,
      preview: preview,
    );
    _previewViewport.resetView();
    setState(() {
      _canonicalScene = scene;
      _diff = diff;
      _compactPage = _ApartmentWizardPage.preview;
    });
  }

  void _refreshStale() {
    if (!_session.rebaseToCurrent()) return;
    _preparePreview();
  }

  void _apply() {
    if (_applyInProgress || !_session.canConfirm) return;
    setState(() => _applyInProgress = true);
    final committed = _session.confirm();
    final result = _session.commitResult;
    if (!committed || result == null) {
      if (mounted) setState(() => _applyInProgress = false);
      return;
    }
    Navigator.of(context).pop<ReservedProjectMutationCommitResult>(result);
  }

  void _cancel() {
    _session.cancel();
    _exploration.discardTransientState();
    Navigator.of(context).pop<ReservedProjectMutationCommitResult>();
  }

  void _back() {
    switch (_session.status) {
      case WizardSessionStatus.previewReady:
      case WizardSessionStatus.previewBlocked:
      case WizardSessionStatus.failed:
      case WizardSessionStatus.selectingVariant:
        _session.back();
        setState(() {
          _canonicalScene = null;
          _diff = null;
          _compactPage = _ApartmentWizardPage.candidates;
          _previewViewport.resetView();
        });
        return;
      case WizardSessionStatus.idle:
      case WizardSessionStatus.selectingFamily:
      case WizardSessionStatus.editingParameters:
      case WizardSessionStatus.generating:
      case WizardSessionStatus.committing:
      case WizardSessionStatus.completed:
      case WizardSessionStatus.cancelled:
        break;
    }
    if (_exploration.status ==
        ApartmentWizardExplorationStatus.candidateSelected) {
      _exploration.back();
      setState(() => _compactPage = _ApartmentWizardPage.candidates);
    } else if (_exploration.status !=
        ApartmentWizardExplorationStatus.editingParameters) {
      _exploration.back();
      setState(() => _compactPage = _ApartmentWizardPage.parameters);
    } else {
      _cancel();
    }
  }

  void _discardPreparedPreviewForEditing() {
    switch (_session.status) {
      case WizardSessionStatus.previewReady:
      case WizardSessionStatus.previewBlocked:
      case WizardSessionStatus.failed:
      case WizardSessionStatus.selectingVariant:
        _session.back();
      case WizardSessionStatus.idle:
      case WizardSessionStatus.selectingFamily:
      case WizardSessionStatus.editingParameters:
      case WizardSessionStatus.generating:
      case WizardSessionStatus.committing:
      case WizardSessionStatus.completed:
      case WizardSessionStatus.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ProjectWizardLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.apartmentTitle),
          leading: IconButton(
            tooltip: l10n.cancel,
            onPressed: _cancel,
            icon: const Icon(Icons.close),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final effectiveWidth =
                constraints.maxWidth / (textScale > 1 ? textScale : 1);
            if (effectiveWidth >= 1100) return _expandedLayout();
            if (effectiveWidth >= 760) return _mediumLayout();
            return _compactLayout();
          },
        ),
        bottomNavigationBar: _actionBar(),
      ),
    );
  }

  Widget _expandedLayout() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 340, child: _parametersPanel()),
          const VerticalDivider(width: 1),
          Expanded(flex: 5, child: _primaryPanel()),
          const VerticalDivider(width: 1),
          Expanded(flex: 4, child: _changesPanel()),
        ],
      );

  Widget _mediumLayout() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 320, child: _parametersPanel()),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(flex: 5, child: _primaryPanel()),
                const Divider(height: 1),
                Expanded(flex: 4, child: _changesPanel()),
              ],
            ),
          ),
        ],
      );

  Widget _compactLayout() {
    final l10n = ProjectWizardLocalizations.of(context);
    final pages = _ApartmentWizardPage.values;
    return Column(
      children: [
        NavigationBar(
          selectedIndex: pages.indexOf(_compactPage),
          onDestinationSelected: (index) =>
              setState(() => _compactPage = pages[index]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.tune),
              label: l10n.parameters,
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              label: l10n.candidates,
            ),
            NavigationDestination(
              icon: const Icon(Icons.preview_outlined),
              label: l10n.preview,
            ),
            NavigationDestination(
              icon: const Icon(Icons.difference_outlined),
              label: l10n.changes,
            ),
          ],
        ),
        Expanded(
          child: IndexedStack(
            index: pages.indexOf(_compactPage),
            children: [
              _parametersPanel(),
              _candidatesPanel(),
              _previewPanel(),
              _changesPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _primaryPanel() =>
      _canonicalScene == null ? _candidatesPanel() : _previewPanel();

  Widget _parametersPanel() {
    final l10n = ProjectWizardLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.parameters, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _integerField(
          key: 'apartment-rooms',
          controller: _roomsController,
          label: l10n.apartmentRooms,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('apartment-area'),
          controller: _areaController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _onDraftChanged(),
          decoration: InputDecoration(
            labelText: l10n.apartmentArea,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _integerField(
          key: 'apartment-bathrooms',
          controller: _bathroomsController,
          label: l10n.apartmentBathrooms,
        ),
        const SizedBox(height: 12),
        _integerField(
          key: 'apartment-wc',
          controller: _wcController,
          label: l10n.apartmentSeparateWc,
        ),
        const SizedBox(height: 12),
        _integerField(
          key: 'apartment-balconies',
          controller: _balconiesController,
          label: l10n.apartmentBalconies,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ApartmentBalconyKind>(
          initialValue: _balconyKind,
          decoration: InputDecoration(
            labelText: l10n.apartmentBalconyKind,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final value in ApartmentBalconyKind.values)
              DropdownMenuItem(value: value, child: Text(value.code)),
          ],
          onChanged: (value) {
            if (value == null) return;
            _balconyKind = value;
            _onDraftChanged();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ApartmentKitchenMode>(
          initialValue: _kitchenMode,
          decoration: InputDecoration(
            labelText: l10n.apartmentKitchenMode,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final value in ApartmentKitchenMode.values)
              DropdownMenuItem(value: value, child: Text(value.code)),
          ],
          onChanged: (value) {
            if (value == null) return;
            _kitchenMode = value;
            _onDraftChanged();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ApartmentCorridorMode>(
          initialValue: _corridorMode,
          decoration: InputDecoration(
            labelText: l10n.apartmentCorridorMode,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final value in ApartmentCorridorMode.values)
              DropdownMenuItem(value: value, child: Text(value.code)),
          ],
          onChanged: (value) {
            if (value == null) return;
            _corridorMode = value;
            _onDraftChanged();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _preferDayNight,
          title: Text(l10n.apartmentDayNight),
          onChanged: (value) {
            _preferDayNight = value;
            _onDraftChanged();
          },
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('apartment-generate-candidates'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _generateCandidates,
          icon: const Icon(Icons.auto_fix_high),
          label: Text(l10n.generateVariants),
        ),
        const SizedBox(height: 12),
        ..._validationMessages(),
        if (_session.blockReason == WizardPreviewBlockReason.staleBaseVersion)
          _messageCard(
            icon: Icons.sync_problem,
            title: l10n.projectChanged,
            message: l10n.stalePreview,
            action: TextButton.icon(
              onPressed: _refreshStale,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refreshPreview),
            ),
          ),
        if (_session.failure != null)
          _messageCard(
            icon: Icons.error_outline,
            title: l10n.generationFailed,
            message: _session.failure.toString(),
          ),
      ],
    );
  }

  Widget _integerField({
    required String key,
    required TextEditingController controller,
    required String label,
  }) =>
      TextField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => _onDraftChanged(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _candidatesPanel() {
    final l10n = ProjectWizardLocalizations.of(context);
    if (_candidateCards.isEmpty || _selectedCandidateId == null) {
      return _emptyPanel(
        icon: Icons.grid_view_outlined,
        title: l10n.noCandidates,
        subtitle: l10n.apartmentPreviewEmptyHint,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.apartmentSelectedVariant,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: WizardCandidateCarousel(
              candidates: _candidateCards,
              selectedId: _selectedCandidateId!,
              onSelected: _selectCandidate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPanel() {
    final l10n = ProjectWizardLocalizations.of(context);
    final scene = _canonicalScene;
    if (scene == null || _selectedCandidateId == null) {
      return _emptyPanel(
        icon: Icons.preview_outlined,
        title: l10n.previewEmpty,
        subtitle: l10n.apartmentPreviewEmptyHint,
      );
    }
    final card = WizardCandidateCard(
      id: _selectedCandidateId!,
      title: l10n.apartmentCanonicalPreview,
      scene: scene,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: WizardCandidateCarousel(
        candidates: [card],
        selectedId: card.id,
        onSelected: (_) {},
        viewportState: _previewViewport,
      ),
    );
  }

  Widget _changesPanel() {
    final l10n = ProjectWizardLocalizations.of(context);
    final diff = _diff;
    if (diff == null) {
      return _emptyPanel(
        icon: Icons.difference_outlined,
        title: l10n.changesEmpty,
        subtitle: l10n.changesEmptyHint,
      );
    }
    return WizardDiffPanel(model: diff);
  }

  Widget _actionBar() {
    final l10n = ProjectWizardLocalizations.of(context);
    final hasCandidates =
        _candidateCards.isNotEmpty && _selectedCandidateId != null;
    final hasPreview = _canonicalScene != null && _diff != null;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              TextButton.icon(
                key: const ValueKey('apartment-wizard-back'),
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.back),
              ),
              const Spacer(),
              if (!hasPreview && hasCandidates)
                FilledButton.icon(
                  key: const ValueKey('apartment-prepare-preview'),
                  onPressed: _preparePreview,
                  icon: const Icon(Icons.preview_outlined),
                  label: Text(l10n.preparePreview),
                ),
              if (hasPreview)
                FilledButton.icon(
                  key: const ValueKey('apartment-apply'),
                  onPressed:
                      _session.canConfirm && !_applyInProgress ? _apply : null,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyAll),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _validationMessages() {
    final l10n = ProjectWizardLocalizations.of(context);
    return [
      for (final issue in _session.validation.issues)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _messageCard(
            icon: issue.severity == WizardIssueSeverity.blocker
                ? Icons.error_outline
                : Icons.warning_amber_outlined,
            title: issue.severity == WizardIssueSeverity.blocker
                ? l10n.fixRequired
                : l10n.warning,
            message: l10n.validationMessage(issue.code, issue.message),
          ),
        ),
    ];
  }

  String _candidateTitle(ApartmentCandidateCard card) {
    final score = (card.rankedCandidate.finalScoreBp / 100).toStringAsFixed(1);
    return '${card.rankedCandidate.candidate.family.code} · $score%';
  }

  WizardPreviewScene _explorationScene(ApartmentCandidateCard card) {
    final source = card.scene;
    final elements = <WizardPreviewElement>[];
    for (final element in source.elements) {
      if (element is ApartmentVectorPolygonElement) {
        elements.add(
          WizardPreviewPolygon(
            key: 'candidate:${element.generationKey}',
            role: WizardPreviewRole.spaceRegion,
            points: [
              for (final point in element.points)
                WizardPreviewPoint(
                  point.xUnits.toDouble(),
                  point.yUnits.toDouble(),
                ),
            ],
          ),
        );
      } else if (element is ApartmentVectorLineElement) {
        elements.add(
          WizardPreviewLine(
            key: 'candidate:${element.generationKey}',
            role: WizardPreviewRole.boundary,
            x1: element.start.xUnits.toDouble(),
            y1: element.start.yUnits.toDouble(),
            x2: element.end.xUnits.toDouble(),
            y2: element.end.yUnits.toDouble(),
          ),
        );
      } else if (element is ApartmentVectorMarkerElement) {
        final x = element.anchor.xUnits.toDouble();
        final y = element.anchor.yUnits.toDouble();
        elements.add(
          WizardPreviewLine(
            key: 'candidate-marker:${element.generationKey}',
            role: element.role == ApartmentVectorRole.entryMarker
                ? WizardPreviewRole.entryMarker
                : WizardPreviewRole.opening,
            x1: x - 4,
            y1: y,
            x2: x + 4,
            y2: y,
          ),
        );
      } else if (element is ApartmentVectorLabelAnchorElement) {
        elements.add(
          WizardPreviewText(
            key: 'candidate-label:${element.generationKey}',
            role: WizardPreviewRole.label,
            x: element.anchor.xUnits.toDouble(),
            y: element.anchor.yUnits.toDouble(),
            text: element.semanticLabelKey,
          ),
        );
      }
    }
    return WizardPreviewScene(
      width: source.widthUnits.toDouble(),
      height: source.heightUnits.toDouble(),
      semanticLabel: source.semanticLabelKey,
      elements: elements,
    );
  }

  Widget _emptyPanel({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(message),
                    if (action != null) ...[
                      const SizedBox(height: 8),
                      action,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
