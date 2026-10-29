import 'package:flutter/material.dart';

import '../../application/project/project_mutation_reservation.dart';
import '../../application/project/wizard/building/building_composition_wizard_command.dart';
import '../../application/project/wizard/building/building_composition_wizard_preview.dart';
import '../../application/project/wizard/building/building_composition_wizard_provider.dart';
import '../../application/project/wizard/building/site_composition.dart';
import '../../application/project/wizard/wizard_contracts.dart';
import '../../application/project/wizard/wizard_session.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_service_anchor.dart';
import '../../domain/project_site_layout.dart';
import 'building_composition_wizard_draft.dart';
import 'building_composition_wizard_localizations.dart';
import 'project_wizard_localizations.dart';
import 'wizard_candidate_carousel.dart';
import 'wizard_diff_panel.dart';

/// Site-only P10 presentation. Startup remains the P8 ProjectWizardScreen.
/// Parameters, presentation and the reserved preview share one WizardSession;
/// this route never constructs an ID factory, history or persistence owner.
final class BuildingCompositionWizardScreen extends StatefulWidget {
  const BuildingCompositionWizardScreen({required this.session, super.key});
  final WizardSession session;
  static Future<ReservedProjectMutationCommitResult?> show(
          {required BuildContext context, required WizardSession session}) =>
      Navigator.of(context).push<ReservedProjectMutationCommitResult>(
          MaterialPageRoute(
              builder: (_) =>
                  BuildingCompositionWizardScreen(session: session)));
  @override
  State<BuildingCompositionWizardScreen> createState() =>
      _BuildingCompositionWizardScreenState();
}

final class _BuildingCompositionWizardScreenState
    extends State<BuildingCompositionWizardScreen> {
  WizardSession get session => widget.session;
  BuildingCompositionWizardFamily family =
      BuildingCompositionWizardFamily.cottage;
  final List<BuildingCompositionFormDraft> buildings = [];
  final List<ExistingBuildingPlacementFormDraft> existing = [];
  final List<SharedSiteAnchorRequest> configuredShared = [];
  String compositionKey = 'site.wizard';
  final Map<String, String> sharedPoint = {'x': '', 'y': ''};
  bool shared = false, busy = false;
  int page = 0, epoch = 0, nextBuilding = 1;
  LevelId? selectedLevel;
  BuildingCompositionWizardPreview? projection;
  String? inputError;
  @override
  void initState() {
    super.initState();
    if (session.target is! SiteWizardTarget) {
      throw ArgumentError('P10 Wizard requires a Site target.');
    }
    if (session.status == WizardSessionStatus.idle) session.begin();
    if (session.status == WizardSessionStatus.selectingFamily) {
      session.selectFamily(BuildingCompositionWizardProvider.familyId);
    }
    final parameters = session.parameters;
    if (parameters is! BuildingCompositionWizardParameters) {
      throw ArgumentError('P10 provider is required.');
    }
    family = parameters.family;
    compositionKey = parameters.compositionKey;
    configuredShared.addAll(parameters.sharedSiteAnchors);
    final slots = family == BuildingCompositionWizardFamily.residentialComplex
        ? parameters.siteBuildings
        : [
            SiteBuildingSlot(
                key: parameters.compositionKey,
                parameters: parameters.buildingParameters!,
                layout: parameters.layout!,
                apartments: parameters.towerApartments)
          ];
    buildings.addAll(slots.map(BuildingCompositionFormDraft.new));
    for (final input in parameters.serviceAnchors) {
      final matches = buildings.where((b) => b.key == input.buildingKey);
      if (matches.isEmpty) continue;
      final draft = BuildingAnchorFormDraft()
        ..key = input.key
        ..side = input.side
        ..levelKey = input.levelKey
        ..spaceUsage = input.spaceUsage;
      draft.fields.addAll({
        'name': input.name,
        'x': '${input.sitePoint?.xMm ?? ''}',
        'y': '${input.sitePoint?.yMm ?? ''}',
        'offset': '${input.offsetMm}',
        'height': '${input.heightMm}'
      });
      matches.single.anchors[input.kind] = draft;
    }
    _syncExisting();
  }

  void _syncExisting() {
    final project = session.mutations.project;
    final unplaced = project.stores.buildings.values
        .where((b) => !project.engineeringMetadata.siteLayout.placements
            .containsKey(b.id))
        .toList();
    existing.removeWhere((e) => !unplaced.any((b) => b.id == e.id));
    for (final b in unplaced) {
      if (!existing.any((e) => e.id == b.id)) {
        existing.add(ExistingBuildingPlacementFormDraft(b.id, b.name));
      }
    }
  }

  @override
  void dispose() {
    session.cancel();
    super.dispose();
  }

  void _invalidate() {
    if (session.status == WizardSessionStatus.previewReady ||
        session.status == WizardSessionStatus.previewBlocked ||
        session.status == WizardSessionStatus.failed) {
      session.back();
    }
    projection = null;
    selectedLevel = null;
    inputError = null;
  }

  void _edit(VoidCallback change) {
    if (busy) return;
    setState(() {
      _invalidate();
      change();
    });
  }

  void _family(BuildingCompositionWizardFamily value) => _edit(() {
        family = value;
        buildings.clear();
        shared = false;
        configuredShared.clear();
        compositionKey = 'site.wizard';
        epoch++;
        final site = session.target.siteId;
        if (value == BuildingCompositionWizardFamily.residentialComplex) {
          buildings.addAll([
            buildingWizardPreset(site,
                key: 'tower.a', tower: true, x: 100000, y: 100000),
            buildingWizardPreset(site, key: 'cottage.b', x: 220000, y: 110000),
            buildingWizardPreset(site, key: 'cottage.c', x: 280000, y: 120000)
          ].map(BuildingCompositionFormDraft.new));
        } else {
          buildings.add(BuildingCompositionFormDraft(buildingWizardPreset(site,
              key: value == BuildingCompositionWizardFamily.cottage
                  ? 'cottage.main'
                  : 'tower.main',
              tower:
                  value == BuildingCompositionWizardFamily.residentialTower)));
        }
      });
  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (busy) return;
    if (session.blockReason == WizardPreviewBlockReason.staleBaseVersion) {
      if (!session.rebaseToCurrent()) return;
      _syncExisting();
    }
    setState(() {
      busy = true;
      projection = null;
      inputError = null;
      selectedLevel = null;
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    try {
      if (session.status == WizardSessionStatus.previewReady ||
          session.status == WizardSessionStatus.failed ||
          session.status == WizardSessionStatus.previewBlocked) {
        session.back();
      }
      final slots =
          buildings.map((b) => b.materialize(session.target.siteId)).toList();
      final l10n = BuildingCompositionWizardLocalizations(context);
      final services = [
        for (final b in buildings)
          for (final a in b.anchors.entries)
            a.value.materialize(b.key, a.key, l10n.anchor(a.key))
      ];
      final placements = {for (final b in existing) b.id: b.materialize()};
      final BuildingCompositionWizardParameters parameters;
      if (family == BuildingCompositionWizardFamily.residentialComplex) {
        parameters = BuildingCompositionWizardParameters.residentialComplex(
            compositionKey: compositionKey,
            buildings: slots,
            serviceAnchors: services,
            existingPlacements: placements,
            sharedSiteAnchors: [
              ...configuredShared,
              if (shared)
                SharedSiteAnchorRequest(
                    key: 'wizard.shared.service',
                    name: l10n.text('shared'),
                    kind: ProjectSiteAnchorKind.sharedServiceArea,
                    point: BoundaryPointMm(
                        xMm: integer(sharedPoint, 'x'),
                        yMm: integer(sharedPoint, 'y')),
                    buildingKeys: slots.map((s) => s.key))
            ]);
      } else if (family == BuildingCompositionWizardFamily.cottage) {
        parameters = BuildingCompositionWizardParameters.cottage(
            compositionKey: slots.single.key,
            parameters: slots.single.parameters,
            layout: slots.single.layout,
            serviceAnchors: services,
            existingPlacements: placements);
      } else {
        parameters = BuildingCompositionWizardParameters.residentialTower(
            compositionKey: slots.single.key,
            parameters: slots.single.parameters,
            layout: slots.single.layout,
            apartments: slots.single.apartments,
            serviceAnchors: services,
            existingPlacements: placements);
      }
      session.updateParameters(parameters);
      if (session.generatePreview()) {
        projection = const BuildingCompositionWizardPreviewProjector().project(
            before: session.mutations.project, preview: session.preview!);
        page = 1;
      }
    } on FormatException {
      inputError = 'invalid';
    } on ArgumentError {
      inputError = 'invalid';
    } catch (_) {
      inputError = 'failure';
    }
    if (mounted) setState(() => busy = false);
  }

  void _apply() {
    if (busy) return;
    if (session.confirm()) {
      Navigator.of(context).pop(session.commitResult);
    } else {
      setState(() => projection = null);
    }
  }

  void _cancel() {
    session.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p8 = ProjectWizardLocalizations.of(context),
        l10n = BuildingCompositionWizardLocalizations(context);
    final iconActions = MediaQuery.sizeOf(context).width < 600 &&
        MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) session.cancel();
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text(l10n.text('title')),
                leading: IconButton(
                    tooltip: p8.cancel,
                    onPressed: busy ? null : _cancel,
                    icon: const Icon(Icons.close))),
            body: Column(children: [
              if (busy) const LinearProgressIndicator(),
              if (session.failure != null ||
                  session.blockReason ==
                      WizardPreviewBlockReason.staleBaseVersion)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(
                            session.blockReason ==
                                    WizardPreviewBlockReason.staleBaseVersion
                                ? p8.stalePreview
                                : l10n.text('failure'),
                            key: const ValueKey('p10-wizard-error'),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)))),
              Expanded(child: LayoutBuilder(builder: (context, size) {
                final effective = size.maxWidth /
                    MediaQuery.textScalerOf(context).scale(1).clamp(1, 3);
                if (effective >= 1100) {
                  return Row(children: [
                    SizedBox(width: 400, child: _parameters()),
                    const VerticalDivider(width: 1),
                    Expanded(
                        child: Column(children: [
                      Expanded(child: _preview()),
                      const Divider(height: 1),
                      Expanded(child: _changes())
                    ]))
                  ]);
                }
                return Column(children: [
                  NavigationBar(
                      selectedIndex: page,
                      onDestinationSelected: (v) => setState(() => page = v),
                      labelBehavior:
                          MediaQuery.textScalerOf(context).scale(1) >= 1.8
                              ? NavigationDestinationLabelBehavior.alwaysHide
                              : NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: [
                        NavigationDestination(
                            icon: const Icon(Icons.tune), label: p8.parameters),
                        NavigationDestination(
                            icon: const Icon(Icons.preview_outlined),
                            label: p8.preview),
                        NavigationDestination(
                            icon: const Icon(Icons.difference_outlined),
                            label: p8.changes)
                      ]),
                  Expanded(
                      child: IndexedStack(
                          index: page,
                          children: [_parameters(), _preview(), _changes()]))
                ]);
              }))
            ]),
            bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: iconActions
                        ? Row(children: [
                            IconButton(
                                key: const ValueKey('p10-wizard-cancel'),
                                tooltip: p8.cancel,
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                onPressed: busy ? null : _cancel,
                                icon: const Icon(Icons.close)),
                            const Spacer(),
                            IconButton.filled(
                                key: const ValueKey('p10-wizard-apply'),
                                tooltip: p8.applyAll,
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                onPressed: !busy &&
                                        projection != null &&
                                        session.canConfirm
                                    ? _apply
                                    : null,
                                icon: const Icon(Icons.check)),
                          ])
                        : Row(children: [
                            TextButton(
                                key: const ValueKey('p10-wizard-cancel'),
                                style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48)),
                                onPressed: busy ? null : _cancel,
                                child: Text(p8.cancel)),
                            const Spacer(),
                            FilledButton.icon(
                                key: const ValueKey('p10-wizard-apply'),
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 48)),
                                onPressed: !busy &&
                                        projection != null &&
                                        session.canConfirm
                                    ? _apply
                                    : null,
                                icon: const Icon(Icons.check),
                                label: Text(p8.applyAll))
                          ])))));
  }

  Widget _parameters() {
    final p8 = ProjectWizardLocalizations.of(context),
        l10n = BuildingCompositionWizardLocalizations(context);
    return ListView(
        key: const ValueKey('p10-wizard-parameters'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<BuildingCompositionWizardFamily>(
              key: const ValueKey('p10-wizard-family'),
              initialValue: family,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.text('family')),
              items: [
                for (final f in BuildingCompositionWizardFamily.values)
                  DropdownMenuItem(value: f, child: Text(l10n.family(f)))
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      if (v != null) _family(v);
                    }),
          const SizedBox(height: 12),
          Text(l10n.text('architectureOnly')),
          if (existing.isNotEmpty)
            ExpansionTile(
                initiallyExpanded: true,
                title: Text(l10n.text('existing')),
                children: [
                  Text(l10n.text('existingHint')),
                  for (final b in existing)
                    Column(children: [
                      Text(b.name),
                      for (final key in ['x', 'y', 'width', 'depth'])
                        _field('existing-${b.id.value}', b.fields, key),
                      _rotation('existing-${b.id.value}', b.quarterTurns,
                          (v) => b.quarterTurns = v)
                    ])
                ]),
          for (final b in buildings) _building(b),
          if (family == BuildingCompositionWizardFamily.residentialComplex) ...[
            Wrap(spacing: 8, children: [
              for (final tower in [false, true])
                TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => _edit(() => buildings.add(
                            BuildingCompositionFormDraft(buildingWizardPreset(
                                session.target.siteId,
                                key: 'added.${nextBuilding++}',
                                tower: tower,
                                x: 400000 + nextBuilding * 100000,
                                y: 100000)))),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.text(tower ? 'addTower' : 'addCottage')))
            ]),
            SwitchListTile(
                title: Text(l10n.text('shared')),
                subtitle: Text(l10n.text('sharedHint')),
                value: shared,
                onChanged: busy ? null : (v) => _edit(() => shared = v)),
            for (final anchor in configuredShared)
              ListTile(
                  title: Text(anchor.name),
                  subtitle: Text('${anchor.point.xMm}, ${anchor.point.yMm} mm'),
                  trailing: IconButton(
                      tooltip: l10n.text('remove'),
                      onPressed: busy
                          ? null
                          : () => _edit(() => configuredShared.remove(anchor)),
                      icon: const Icon(Icons.remove_circle_outline))),
            if (shared) ...[
              for (final key in ['x', 'y']) _field('shared', sharedPoint, key)
            ],
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
              key: const ValueKey('p10-wizard-generate'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: busy ? null : _generate,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(session.blockReason ==
                      WizardPreviewBlockReason.staleBaseVersion
                  ? p8.refreshPreview
                  : p8.generate)),
          if (inputError != null) _message(l10n.text(inputError!)),
          if (session.validation.hasBlockers) _message(l10n.text('invalid')),
          if (session.failure != null) _message(l10n.text('failure')),
          if (session.blockReason == WizardPreviewBlockReason.staleBaseVersion)
            _message(p8.stalePreview),
        ]);
  }

  Widget _building(BuildingCompositionFormDraft b) {
    final l10n = BuildingCompositionWizardLocalizations(context);
    return Card(
        key: ValueKey('p10-building-${b.key}-$epoch'),
        child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(b.fields['name']!),
            subtitle: Text(l10n.family(b.tower
                ? BuildingCompositionWizardFamily.residentialTower
                : BuildingCompositionWizardFamily.cottage)),
            children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                        initialValue: b.tower ? 'p10.tower' : 'p10.cottage',
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: l10n.text('template')),
                        items: [
                          DropdownMenuItem(
                              value: b.tower ? 'p10.tower' : 'p10.cottage',
                              child: Text(
                                  l10n.text(b.tower ? 'tower' : 'cottage')))
                        ],
                        onChanged: busy ? null : (_) => {}),
                    for (final key in [
                      'name',
                      'x',
                      'y',
                      'width',
                      'depth',
                      'floors',
                      'basements',
                      'height'
                    ])
                      _field(b.key, b.fields, key),
                    _rotation(b.key, b.quarterTurns, (v) => b.quarterTurns = v),
                    _toggle(l10n.text('technical'), b.technical,
                        (v) => b.technical = v),
                    _toggle(l10n.text('roof'), b.roof, (v) => b.roof = v),
                    ExpansionTile(title: Text(l10n.text('cores')), children: [
                      for (final key in [
                        'stairs',
                        'lifts',
                        'shafts',
                        'electricalRisers',
                        'telecomRisers',
                        'corridorWidth'
                      ])
                        _field(b.key, b.fields, key),
                      _toggle(l10n.text('technicalRoom'), b.technicalRoom,
                          (v) => b.technicalRoom = v),
                      _toggle(l10n.text('commonHall'), b.commonHall,
                          (v) => b.commonHall = v)
                    ]),
                    ExpansionTile(title: Text(l10n.text('layout')), children: [
                      for (final key in [
                        'originX',
                        'originY',
                        'corridorLength'
                      ])
                        _field(b.key, b.fields, key)
                    ]),
                    if (b.tower)
                      ExpansionTile(title: Text(l10n.text('mix')), children: [
                        for (final a in b.apartments)
                          Column(key: ValueKey('${b.key}-${a.key}'), children: [
                            Text(a.name),
                            for (final key in ['rooms', 'area', 'bathrooms'])
                              _field('${b.key}-${a.key}', a.fields, key),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => _edit(() => b.apartments.remove(a)),
                                child: Text(l10n.text('remove')))
                          ]),
                        TextButton.icon(
                            onPressed:
                                busy ? null : () => _edit(b.addApartment),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.text('addApartment')))
                      ]),
                    ExpansionTile(
                        title: Text(l10n.text('services')),
                        children: [
                          Text(l10n.text('serviceHint')),
                          for (final kind
                              in ProjectServiceAnchorKind.values) ...[
                            CheckboxListTile(
                                title: Text(l10n.anchor(kind)),
                                value: b.anchors.containsKey(kind),
                                onChanged: busy
                                    ? null
                                    : (v) => _edit(() {
                                          if (v == true) {
                                            b.anchors[kind] =
                                                BuildingAnchorFormDraft()
                                                  ..fields['name'] =
                                                      l10n.anchor(kind);
                                          } else {
                                            b.anchors.remove(kind);
                                          }
                                        })),
                            if (b.anchors[kind]
                                case final BuildingAnchorFormDraft anchor) ...[
                              _field('${b.key}-${kind.name}', anchor.fields,
                                  'name'),
                              if (isServiceEntryKind(kind)) ...[
                                DropdownButtonFormField<BuildingWizardWallSide>(
                                    key: ValueKey('${b.key}-${kind.name}-side'),
                                    initialValue: anchor.side,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: l10n.text('side')),
                                    items: [
                                      for (final side
                                          in BuildingWizardWallSide.values)
                                        DropdownMenuItem(
                                            value: side,
                                            child: Text(l10n.side(side)))
                                    ],
                                    onChanged: busy
                                        ? null
                                        : (v) {
                                            if (v != null) {
                                              _edit(() => anchor.side = v);
                                            }
                                          }),
                                _field('${b.key}-${kind.name}', anchor.fields,
                                    'offset'),
                                _field('${b.key}-${kind.name}', anchor.fields,
                                    'height',
                                    label: l10n.text('anchorHeight')),
                              ] else ...[
                                for (final key in ['x', 'y'])
                                  _field('${b.key}-${kind.name}', anchor.fields,
                                      key)
                              ],
                            ],
                          ]
                        ]),
                    if (family ==
                        BuildingCompositionWizardFamily.residentialComplex)
                      TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => _edit(() => buildings.remove(b)),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.text('remove'))),
                  ]))
            ]));
  }

  Widget _field(String owner, Map<String, String> fields, String key,
          {String? label}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
              key: ValueKey('p10-$owner-$key'),
              initialValue: fields[key],
              enabled: !busy,
              keyboardType: key == 'name'
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
              decoration: InputDecoration(
                  labelText: label ??
                      BuildingCompositionWizardLocalizations(context).text(key),
                  border: const OutlineInputBorder()),
              onChanged: (v) => _edit(() => fields[key] = v)));
  Widget _rotation(String owner, int current, void Function(int) change) =>
      DropdownButtonFormField<int>(
          key: ValueKey('p10-$owner-rotation'),
          initialValue: current,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: BuildingCompositionWizardLocalizations(context)
                  .text('rotation')),
          items: [
            for (var i = 0; i < 4; i++)
              DropdownMenuItem(value: i, child: Text('${i * 90}°'))
          ],
          onChanged: busy
              ? null
              : (v) {
                  if (v != null) _edit(() => change(v));
                });
  Widget _toggle(String label, bool value, void Function(bool) change) =>
      SwitchListTile(
          title: Text(label),
          value: value,
          onChanged: busy ? null : (v) => _edit(() => change(v)));
  Widget _message(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Semantics(
          liveRegion: true,
          child: Text(text,
              style: TextStyle(color: Theme.of(context).colorScheme.error))));
  Widget _preview() {
    final preview = session.preview,
        p8 = ProjectWizardLocalizations.of(context);
    if (projection == null || preview == null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(p8.previewEmptyHint)));
    }
    final l10n = BuildingCompositionWizardLocalizations(context);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<LevelId?>(
              key: const ValueKey('p10-preview-level'),
              initialValue: selectedLevel,
              isExpanded: true,
              items: [
                DropdownMenuItem<LevelId?>(
                    value: null, child: Text(l10n.text('overview'))),
                for (final b in preview.candidate.stores.buildings.values)
                  for (final id in b.levelIds)
                    if (preview
                        .candidate.stores.levels[id]!.spaceIds.isNotEmpty)
                      DropdownMenuItem(
                          value: id,
                          child: Text(
                              '${b.name} · ${preview.candidate.stores.levels[id]!.name}'))
              ],
              onChanged: (v) => setState(() => selectedLevel = v))),
      Expanded(
          child: WizardPreviewCanvas(
              scene: const BuildingCompositionWizardSceneProjector()
                  .project(preview, levelId: selectedLevel)))
    ]);
  }

  Widget _changes() {
    final model = projection, p8 = ProjectWizardLocalizations.of(context);
    if (model == null) return Center(child: Text(p8.changesEmptyHint));
    final l10n = BuildingCompositionWizardLocalizations(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(
          l10n.summary(
              model.addedBuildings,
              model.addedLevels,
              model.addedApartments,
              model.addedVerticalCores,
              model.addedServiceAnchors),
          key: const ValueKey('p10-composition-summary')),
      for (final entry in model.serviceCounts.entries)
        ListTile(
            title: Text(l10n.anchor(entry.key)),
            trailing: Text('${entry.value}')),
      if (model.addedSharedAnchors > 0)
        ListTile(
            title: Text(l10n.text('shared')),
            trailing: Text('${model.addedSharedAnchors}')),
      ExpansionTile(
          key: const ValueKey('p10-diff-details'),
          title: Text(l10n.text('details')),
          children: [
            SizedBox(height: 500, child: WizardDiffPanel(model: model.diff))
          ])
    ]);
  }
}
