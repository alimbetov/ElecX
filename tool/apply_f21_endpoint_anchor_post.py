from pathlib import Path

p = Path('test/f21_endpoint_anchor_invariant_test.dart')
text = p.read_text()
anchor = "import 'package:elecx/src/domain/surfaces.dart';\n"
if anchor not in text:
    raise SystemExit('F21 test import anchor not found')
text = text.replace(
    anchor,
    anchor + "import 'package:elecx/src/engine/selection_engine.dart';\n",
    1,
)
p.write_text(text)
