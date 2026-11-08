import 'package:flutter/material.dart';

import 'device_catalog_panel.dart';
import 'editor_controller.dart';
import 'room_circuit_overview.dart';
import 'room_circuit_panel.dart';

/// Keeps circuit actions reachable when room semantics and warnings grow.
/// The equipment catalog retains its own bounded scrolling viewport.
class EngineeringInspectorPanel extends StatelessWidget {
  const EngineeringInspectorPanel({
    required this.controller,
    this.semanticsInspector,
    super.key,
  });

  final EditorController controller;
  final Widget? semanticsInspector;

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
                  if (semanticsInspector != null) ...[
                    semanticsInspector!,
                    const Divider(height: 1),
                  ],
                  RoomCircuitOverviewPanel(controller: controller),
                  RoomCircuitPanel(controller: controller),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: DeviceCatalogPanel(controller: controller)),
        ],
      );
}
