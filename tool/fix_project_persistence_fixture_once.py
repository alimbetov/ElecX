from pathlib import Path

p = Path('test/editor_project_persistence_test.dart')
text = p.read_text()
replacements = [
    (
        """      position: const SurfacePointMm(500, 1200),
""",
        """      position: const SurfacePointMm(200, 1200),
""",
        'persistence source fixture',
    ),
    (
        """      position: const SurfacePointMm(2600, 1200),
""",
        """      position: const SurfacePointMm(1600, 2400),
""",
        'persistence target fixture',
    ),
]
for old, new, label in replacements:
    if text.count(old) != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {text.count(old)}')
    text = text.replace(old, new, 1)
p.write_text(text)
