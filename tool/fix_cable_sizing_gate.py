from pathlib import Path

p = Path('lib/src/features/editor/circuit_sizing_evidence.dart')
text = p.read_text()
text = text.replace(
    "    if (routeId.trim().isEmpty) throw ArgumentError('routeId must be non-empty.');\n",
    "    if (routeId.trim().isEmpty) {\n      throw ArgumentError('routeId must be non-empty.');\n    }\n",
)
p.write_text(text)

p = Path('lib/src/features/editor/editor_p2_session.dart')
text = p.read_text()
text = text.replace(
    "    if (bundle == null || bundle.cable.routeId != evidence.routeId) return false;\n",
    "    if (bundle == null || bundle.cable.routeId != evidence.routeId) {\n      return false;\n    }\n",
)
p.write_text(text)

p = Path('lib/src/features/editor/room_circuit_panel.dart')
text = p.read_text()
anchor = "import '../../domain/electrical_placement.dart';\n"
if "import '../../domain/electrical_routing.dart';\n" not in text:
    if anchor not in text:
        raise SystemExit('room panel routing import anchor missing')
    text = text.replace(
        anchor,
        anchor + "import '../../domain/electrical_routing.dart';\n",
        1,
    )
text = text.replace(
    "                      if (value != null) setLocalState(() => phaseSystem = value);\n",
    "                      if (value != null) {\n                        setLocalState(() => phaseSystem = value);\n                      }\n",
)
text = text.replace(
    "                      if (value != null) setLocalState(() => material = value);\n",
    "                      if (value != null) {\n                        setLocalState(() => material = value);\n                      }\n",
)
p.write_text(text)
