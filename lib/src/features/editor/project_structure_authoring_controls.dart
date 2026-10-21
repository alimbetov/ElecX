import 'package:flutter/material.dart';

/// Discoverable P5C primary authoring controls for the Project Navigator.
///
/// This widget contains no project mutation logic. The host resolves action
/// availability from the shared application/session state and wires these
/// callbacks to the canonical P3/P4 command path.
class ProjectStructureAuthoringControls extends StatelessWidget {
  const ProjectStructureAuthoringControls({
    required this.onAddBuilding,
    required this.onAddLevel,
    required this.onAddRoom,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onAddBuilding;
  final VoidCallback? onAddLevel;
  final VoidCallback? onAddRoom;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      _AuthoringButton(
        icon: Icons.apartment_outlined,
        label: '+ Building',
        tooltip: 'Add building to the active site',
        onPressed: onAddBuilding,
      ),
      _AuthoringButton(
        icon: Icons.layers_outlined,
        label: '+ Level',
        tooltip: 'Add level to the active building',
        onPressed: onAddLevel,
      ),
      _AuthoringButton(
        icon: Icons.crop_square,
        label: '+ Room',
        tooltip: 'Add room to the active level',
        onPressed: onAddRoom,
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: controls,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        controls.first,
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: controls[1]),
            const SizedBox(width: 6),
            Expanded(child: controls[2]),
          ],
        ),
      ],
    );
  }
}

class _AuthoringButton extends StatelessWidget {
  const _AuthoringButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
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
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}
