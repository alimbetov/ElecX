from pathlib import Path

path = Path('test/project_hub_recovery_test.dart')
text = path.read_text()
anchor = "import 'package:elecx/src/features/editor/editor_project_document.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'Expected one recovery test import anchor, found {text.count(anchor)}')
path.write_text(text.replace(anchor, anchor + "import 'package:elecx/src/features/editor/editor_p2_session.dart';\n", 1))
