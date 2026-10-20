from pathlib import Path

p = Path('test/editor_project_persistence_test.dart')
text = p.read_text()
old = """      position: const SurfacePointMm(2600, 1200),
"""
new = """      position: const SurfacePointMm(1600, 2400),
"""
if text.count(old) != 1:
    raise RuntimeError(f'persistence target fixture: expected 1 match, got {text.count(old)}')
p.write_text(text.replace(old, new, 1))
