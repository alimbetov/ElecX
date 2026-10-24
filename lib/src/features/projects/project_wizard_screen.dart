import 'package:flutter/material.dart';

import '../../application/project/project_mutation_reservation.dart';
import '../../application/project/wizard/basic_building_wizard_provider.dart';
import '../../application/project/wizard/wizard_contracts.dart';
import '../../application/project/wizard/wizard_diff.dart';
import '../../application/project/wizard/wizard_preview_scene.dart';
import '../../application/project/wizard/wizard_session.dart';
import 'project_wizard_localizations.dart';
import 'wizard_candidate_carousel.dart';

final class ProjectWizardScreen extends StatefulWidget {
  const ProjectWizardScreen({
    required this.session,
    this.initialBuildingName,
    super.key,
  });

  final WizardSession session;
  final String? initialBuildingName;

  static Future<ReservedProjectMutationCommitResult?> show({
    required BuildContext context,
    required WizardSession session,
    String? initialBuildingName,
  }) =>
      Navigator.of(context).push<ReservedProjectMutationCommitResult>(
        MaterialPageRoute<ReservedProjectMutationCommitResult>(
          builder: (_) => ProjectWizardScreen(
            session: session,
            initialBuildingName: initialBuildingName,
          ),
        ),
      );

  @override
  State<ProjectWizardScreen> createState() => _ProjectWizardScreenState();
}

final class _ProjectWizardScreenState extends State<ProjectWizardScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _floorsController;
  late final TextEditingController _basementsController;
  late final TextEditingController _heightController;
  bool _createGround = true;
  WizardDiffModel? _diff;
  WizardPreviewScene? _scene;
  String? _selectedCandidateId;
  int _compactPage = 0;

  WizardSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    if (_session.status == WizardSessionStatus.idle) {
      _session.begin();
    }
    if (_session.status == WizardSessionStatus.selectingFamily) {
      _session.selectFamily(BasicBuildingWizardProvider.familyId);
    }
    final defaults = _session.parameters is BasicBuildingWizardParameters
        ? _session.parameters! as BasicBuildingWizardParameters
        : const BasicBuildingWizardParameters(
            buildingName: 'Building',
            aboveGroundLevelCount: 1,
            basementLevelCount: 0,
            floorToFloorHeightMm: 3000,
          );
    _nameController = TextEditingController(
      text: widget.initialBuildingName?.trim().isNotEmpty == true
          ? widget.initialBuildingName!.trim()
          : defaults.buildingName,
    );
    _floorsController = TextEditingController(
      text: defaults.aboveGroundLevelCount.toString(),
    );
    _basementsController = TextEditingController(
      text: defaults.basementLevelCount.toString(),
    );
    _heightController = TextEditingController(
      text: defaults.floorToFloorHeightMm.toString(),
    );
    _createGround = defaults.createGroundLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floorsController.dispose();
    _basementsController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _invalidatePreparedPreview() {
    switch (_session.status) {
      case WizardSessionStatus.previewReady:
      case WizardSessionStatus.previewBlocked:
      case WizardSessionStatus.selectingVariant:
      case WizardSessionStatus.failed:
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
    _diff = null;
    _scene = null;
    _selectedCandidateId = null;
  }

  void _onDraftTextChanged(String _) {
    setState(_invalidatePreparedPreview);
  }

  void _generate() {
    final l10n = ProjectWizardLocalizations.of(context);
    final floors = int.tryParse(_floorsController.text.trim());
    final basements = int.tryParse(_basementsController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (floors == null || basements == null || height == null) {
      setState(_invalidatePreparedPreview);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.numericError)),
      );
      return;
    }
    final parameters = BasicBuildingWizardParameters(
      buildingName: _nameController.text,
      aboveGroundLevelCount: floors,
      basementLevelCount: basements,
      floorToFloorHeightMm: height,
      createGroundLevel: _createGround,
    );
    if (!_session.updateParameters(parameters) &&
        _session.status != WizardSessionStatus.editingParameters) {
      return;
    }
    final generated = _session.generatePreview();
    if (!generated || _session.preview == null) {
      setState(_invalidatePreparedPreview);
      return;
    }
    final preview = _session.preview!;
    final scene = const BasicBuildingWizardPreviewProjector().project(preview);
    final diff = const WizardDiffProjector().project(
      before: _session.mutations.project,
      preview: preview,
    );
    setState(() {
      _scene = scene;
      _diff = diff;
      _selectedCandidateId = preview.normalizedIntentKey;
      _compactPage = 1;
    });
  }

  void _refreshStale() {
    if (!_session.rebaseToCurrent()) return;
    _generate();
  }

  void _apply() {
    if (!_session.confirm()) {
      setState(() {});
      return;
    }
    final result = _session.commitResult;
    if (result == null) return;
    Navigator.of(context).pop<ReservedProjectMutationCommitResult>(result);
  }

  void _cancel() {
    _session.cancel();
    Navigator.of(context).pop<ReservedProjectMutationCommitResult>();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ProjectWizardLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.title),
        leading: IconButton(
          tooltip: l10n.cancel,
          onPressed: _cancel,
          icon: const Icon(Icons.close),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width >= 1400) {
            return _wideLayout(threeColumns: true);
          }
          if (width >= 900) {
            return _wideLayout(threeColumns: false);
          }
          return _compactLayout();
        },
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  Widget _wideLayout({required bool threeColumns}) {
    final parameters = _parametersPanel();
    final preview = _previewPanel();
    final changes = _changesPanel();
    if (threeColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 360, child: parameters),
          const VerticalDivider(width: 1),
          Expanded(flex: 5, child: preview),
          const VerticalDivider(width: 1),
          Expanded(flex: 4, child: changes),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 340, child: parameters),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 5, child: preview),
              const Divider(height: 1),
              Expanded(flex: 4, child: changes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactLayout() {
    final l10n = ProjectWizardLocalizations.of(context);
    return Column(
      children: [
        NavigationBar(
          selectedIndex: _compactPage,
          onDestinationSelected: (index) =>
              setState(() => _compactPage = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.tune),
              label: l10n.parameters,
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
            index: _compactPage,
            children: [
              _parametersPanel(),
              _previewPanel(),
              _changesPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _parametersPanel() {
    final l10n = ProjectWizardLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.parameters, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('wizard-building-name'),
          controller: _nameController,
          onChanged: _onDraftTextChanged,
          decoration: InputDecoration(
            labelText: l10n.buildingName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wizard-floor-count'),
          controller: _floorsController,
          onChanged: _onDraftTextChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.aboveGroundLevels,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wizard-basement-count'),
          controller: _basementsController,
          onChanged: _onDraftTextChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.basementLevels,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wizard-floor-height'),
          controller: _heightController,
          onChanged: _onDraftTextChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.floorHeight,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: _createGround,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) => setState(() {
            _createGround = value ?? true;
            _invalidatePreparedPreview();
          }),
          title: Text(l10n.createGround),
          subtitle: Text(l10n.createGroundHint),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('wizard-generate'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _generate,
          icon: const Icon(Icons.auto_fix_high),
          label: Text(l10n.generate),
        ),
        const SizedBox(height: 12),
        ..._validationMessages(),
        if (_session.failure != null)
          _messageCard(
            icon: Icons.error_outline,
            title: l10n.generationFailed,
            message: _session.failure.toString(),
          ),
        if (_session.blockReason == WizardPreviewBlockReason.staleBaseVersion)
          _messageCard(
            icon: Icons.sync_problem,
            title: l10n.projectChanged,
            message: l10n.stalePreview,
            action: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _refreshStale,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refreshPreview),
            ),
          ),
      ],
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

  Widget _previewPanel() {
    final l10n = ProjectWizardLocalizations.of(context);
    final scene = _scene;
    if (scene == null || _selectedCandidateId == null) {
      return _emptyPanel(
        icon: Icons.preview_outlined,
        title: l10n.previewEmpty,
        subtitle: l10n.previewEmptyHint,
      );
    }
    final localizedScene = WizardPreviewScene(
      width: scene.width,
      height: scene.height,
      semanticLabel: l10n.previewSemanticLabel(
        _nameController.text.trim(),
        scene.elements.whereType<WizardPreviewLine>().length + 1,
      ),
      elements: scene.elements,
    );
    final card = WizardCandidateCard(
      id: _selectedCandidateId!,
      title: _nameController.text.trim(),
      scene: localizedScene,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: WizardCandidateCarousel(
        candidates: [card],
        selectedId: card.id,
        onSelected: (id) => setState(() => _selectedCandidateId = id),
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
    return ListView(
      key: const ValueKey('wizard-diff-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.changesCount(diff.entries.length),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        for (final entry in diff.entries)
          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Icon(switch (entry.kind) {
                WizardDiffKind.add => Icons.add_circle_outline,
                WizardDiffKind.update => Icons.edit_outlined,
                WizardDiffKind.remove => Icons.remove_circle_outline,
              }),
              title: Text(l10n.diffText(entry.title)),
              subtitle: entry.context == null
                  ? null
                  : Text(l10n.diffText(entry.context!)),
              children: [
                for (final field in entry.fields)
                  ListTile(
                    dense: true,
                    title: Text(l10n.diffField(field.field)),
                    subtitle: Text(
                      '${field.beforeValue ?? '—'} → ${field.afterValue ?? '—'}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionBar() {
    final l10n = ProjectWizardLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              TextButton(
                key: const ValueKey('wizard-cancel'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _cancel,
                child: Text(l10n.cancel),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const ValueKey('wizard-apply'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _session.canConfirm ? _apply : null,
                icon: const Icon(Icons.check),
                label: Text(l10n.applyAll),
              ),
            ],
          ),
        ),
      ),
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
