from pathlib import Path

path = Path('lib/src/features/editor/plan_geometry_editor_actions.dart')
text = path.read_text()
old = "if (polygon == null || polygon.isEmpty) return true;"
new = "if (polygon.isEmpty) return true;"
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one polygon nullability anchor, found {count}')
path.write_text(text.replace(old, new, 1))
