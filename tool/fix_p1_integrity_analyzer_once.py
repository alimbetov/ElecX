from pathlib import Path

path = Path('lib/src/features/editor/plan_geometry_editor_actions.dart')
text = path.read_text()
old = """      final context = contextFor(component.surface);\n      if (context == null || !containsPoint(component.position, context)) {\n        return false;\n      }\n"""
new = """      final context = contextFor(component.surface);\n      if (!containsPoint(component.position, context)) {\n        return false;\n      }\n"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one analyzer anchor, found {count}')
path.write_text(text.replace(old, new, 1))
