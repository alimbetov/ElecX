from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old!r}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'lib/src/features/editor/manual_cable_draft_persistence.dart',
    "import '../../engine/port_snap_resolver.dart';\n",
    "import '../../engine/editor_layers.dart';\nimport '../../engine/port_snap_resolver.dart';\n",
)
replace_once(
    'test/f10_f11_f13_acceptance_test.dart',
    "import 'package:elecx/src/engine/editor_layers.dart';\n",
    "import 'package:elecx/src/engine/editor_layers.dart';\nimport 'package:elecx/src/engine/selection_engine.dart';\nimport 'package:flutter/services.dart';\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "            if (electricalVisible &&\n                controller.p2.selectedComponent case final component?)\n",
    "            if (electricalVisible)\n              if (controller.p2.selectedComponent case final component?)\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "            if (cableRoutesVisible &&\n                controller.routeSelection.selectedRouteId case final routeId?)\n",
    "            if (cableRoutesVisible)\n              if (controller.routeSelection.selectedRouteId case final routeId?)\n",
)
