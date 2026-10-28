import 'package:flutter/material.dart';

import '../../application/project/wizard/wizard_diff.dart';
import 'project_wizard_localizations.dart';

/// Provider-neutral semantic Diff presentation for the shared P8 Wizard.
///
/// Low-level boundary operations remain present in [WizardDiffModel] for
/// persistence/Undo reconciliation but are grouped under their owning Space in
/// the default UX. Presentation filtering never changes the semantic model.
final class WizardDiffPanel extends StatefulWidget {
  const WizardDiffPanel({required this.model, super.key});

  final WizardDiffModel model;

  @override
  State<WizardDiffPanel> createState() => _WizardDiffPanelState();
}

final class _WizardDiffPanelState extends State<WizardDiffPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = ProjectWizardLocalizations.of(context);
    final filtered = widget.model.filtered(query: _query);
    final groups = _groups(filtered);
    return ListView(
      key: const ValueKey('wizard-diff-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.changesCount(widget.model.entries.length),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wizard-diff-search'),
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: l10n.searchChanges,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(l10n.noMatchingChanges)),
          ),
        for (final group in groups) _groupCard(context, group),
      ],
    );
  }

  Widget _groupCard(BuildContext context, WizardDiffGroup group) {
    final l10n = ProjectWizardLocalizations.of(context);
    final boundaryEntries = group.entries
        .where(
          (entry) =>
              entry.category == WizardDiffEntityCategory.boundaryTopology,
        )
        .toList();
    final semanticEntries = group.entries
        .where(
          (entry) =>
              entry.category != WizardDiffEntityCategory.boundaryTopology,
        )
        .toList();
    final title = _groupTitle(group, semanticEntries, boundaryEntries);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(l10n.diffText(title)),
        subtitle: Text(
          l10n.groupedChangesCount(
            semanticEntries.length,
            boundaryEntries.length,
          ),
        ),
        children: [
          for (final entry in semanticEntries) _entryTile(context, entry),
          if (boundaryEntries.isNotEmpty)
            Semantics(
              label: l10n.boundaryTopologySummary(boundaryEntries.length),
              child: ListTile(
                key: ValueKey('wizard-boundary-group-${group.key}'),
                dense: true,
                leading: const Icon(Icons.polyline_outlined),
                title: Text(l10n.boundaryTopology),
                subtitle: Text(l10n.boundaryEdgeCount(boundaryEntries.length)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryTile(BuildContext context, WizardDiffEntry entry) {
    final l10n = ProjectWizardLocalizations.of(context);
    return ExpansionTile(
      key: ValueKey('wizard-diff-${entry.semanticKey}'),
      initiallyExpanded: entry.fields.length <= 4,
      leading: Icon(switch (entry.kind) {
        WizardDiffKind.add => Icons.add_circle_outline,
        WizardDiffKind.update => Icons.edit_outlined,
        WizardDiffKind.remove => Icons.remove_circle_outline,
      }),
      title: Text(l10n.diffText(entry.title)),
      subtitle:
          entry.context == null ? null : Text(l10n.diffText(entry.context!)),
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
    );
  }

  String _groupTitle(
    WizardDiffGroup group,
    List<WizardDiffEntry> semanticEntries,
    List<WizardDiffEntry> boundaryEntries,
  ) {
    if (group.key == 'relations') return 'Relationships';
    if (semanticEntries.isNotEmpty) return semanticEntries.first.title;
    if (boundaryEntries.isNotEmpty) {
      final context = boundaryEntries.first.context;
      if (context != null && context.isNotEmpty) return context;
      return boundaryEntries.first.title;
    }
    return group.key;
  }

  List<WizardDiffGroup> _groups(List<WizardDiffEntry> entries) {
    final grouped = <String, List<WizardDiffEntry>>{};
    for (final entry in entries) {
      final key = entry.groupKey ?? 'entry:${entry.semanticKey}';
      (grouped[key] ??= <WizardDiffEntry>[]).add(entry);
    }
    return [
      for (final entry in grouped.entries)
        WizardDiffGroup(key: entry.key, entries: entry.value),
    ];
  }
}
