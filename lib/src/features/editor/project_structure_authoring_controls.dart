import 'dart:async';

import 'package:flutter/material.dart';

typedef ProjectStructureAuthoringAction = FutureOr<void> Function();

/// Discoverable P5C primary authoring controls for the Project Navigator.
///
/// This widget contains no project mutation logic. The host resolves action
/// availability from the shared application/session state and wires these
/// callbacks to the canonical P3/P4 command path.
///
/// Only one authoring action may be in flight at a time. This closes the
/// double-click / double-tap race where two async request resolvers or
/// persistence-publication callbacks could otherwise overlap and commit two
/// structures from one user intent.
class ProjectStructureAuthoringControls extends StatefulWidget {
  const ProjectStructureAuthoringControls({
    required this.onAddBuilding,
    required this.onAddLevel,
    required this.onAddRoom,
    this.onStartWizard,
    this.wizardLabel = 'Wizard',
    this.wizardTooltip = 'Create project structure with Wizard',
    this.compact = false,
    super.key,
  });

  final ProjectStructureAuthoringAction? onAddBuilding;
  final ProjectStructureAuthoringAction? onAddLevel;
  final ProjectStructureAuthoringAction? onAddRoom;
  final ProjectStructureAuthoringAction? onStartWizard;
  final String wizardLabel;
  final String wizardTooltip;
  final bool compact;

  @override
  State<ProjectStructureAuthoringControls> createState() =>
      _ProjectStructureAuthoringControlsState();
}

class _ProjectStructureAuthoringControlsState
    extends State<ProjectStructureAuthoringControls> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final wizardControl = widget.onStartWizard == null
        ? null
        : _AuthoringButton(
            icon: Icons.auto_awesome_outlined,
            label: widget.wizardLabel,
            tooltip: widget.wizardTooltip,
            key: const ValueKey('project-wizard-start'),
            onPressed: _enabledAction(widget.onStartWizard),
          );
    final structuralControls = <Widget>[
      _AuthoringButton(
        icon: Icons.apartment_outlined,
        label: '+ Building',
        tooltip: 'Add building to the active site',
        onPressed: _enabledAction(widget.onAddBuilding),
      ),
      _AuthoringButton(
        icon: Icons.layers_outlined,
        label: '+ Level',
        tooltip: 'Add level to the active building',
        onPressed: _enabledAction(widget.onAddLevel),
      ),
      _AuthoringButton(
        icon: Icons.crop_square,
        label: '+ Room',
        tooltip: 'Add room to the active level',
        onPressed: _enabledAction(widget.onAddRoom),
      ),
    ];

    if (widget.compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (wizardControl != null) wizardControl,
          ...structuralControls,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wizardControl != null) ...[
          wizardControl,
          const SizedBox(height: 6),
        ],
        structuralControls.first,
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: structuralControls[1]),
            const SizedBox(width: 6),
            Expanded(child: structuralControls[2]),
          ],
        ),
      ],
    );
  }

  VoidCallback? _enabledAction(ProjectStructureAuthoringAction? action) {
    if (_busy || action == null) return null;
    return () => _run(action);
  }

  Future<void> _run(ProjectStructureAuthoringAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _AuthoringButton extends StatelessWidget {
  const _AuthoringButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}
