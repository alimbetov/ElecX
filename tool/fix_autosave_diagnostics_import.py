from pathlib import Path

path = Path('lib/src/features/editor/project_save_diagnostics.dart')
text = path.read_text()
anchor = "import 'editor_building_workspace.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'Expected one diagnostics import anchor, found {text.count(anchor)}')
path.write_text(text.replace(anchor, anchor + "import 'editor_p2_session.dart';\n", 1))
