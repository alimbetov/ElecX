import 'package:flutter/material.dart';

import 'component_connection_actions.dart';
import 'device_catalog_panel.dart';
import 'editor_controller.dart';
import 'room_circuit_overview.dart';
import 'room_circuit_panel.dart';

/// Keeps circuit actions reachable when room semantics and warnings grow.
/// The equipment catalog retains its own bounded scrolling viewport.
class EngineeringInspectorPanel extends StatefulWidget {
  const EngineeringInspectorPanel({
    required this.controller,
    this.semanticsInspector,
    super.key,
  });

  final EditorController controller;
  final Widget? semanticsInspector;

  @override
  State<EngineeringInspectorPanel> createState() =>
      _EngineeringInspectorPanelState();
}

class _EngineeringInspectorPanelState extends State<EngineeringInspectorPanel> {
  // Presentation only; switching projects must not change the engineering
  // graph or mark the project dirty.
  bool _roomSemanticsExpanded = false;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              key: const ValueKey('engineering-context-scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.semanticsInspector != null) ...[
                    ListTile(
                      key: const ValueKey('room-semantics-toggle'),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.meeting_room_outlined, size: 20),
                      title: const Text('Room Semantic'),
                      trailing: Icon(
                        _roomSemanticsExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onTap: () => setState(() {
                        _roomSemanticsExpanded = !_roomSemanticsExpanded;
                      }),
                    ),
                    if (_roomSemanticsExpanded)
                      widget.semanticsInspector!,
                    const Divider(height: 1),
                  ],
                  ComponentConnectionActions(controller: widget.controller),
                  RoomCircuitOverviewPanel(controller: widget.controller),
                  RoomCircuitPanel(controller: widget.controller),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: DeviceCatalogPanel(controller: widget.controller)),
        ],
      );
}
