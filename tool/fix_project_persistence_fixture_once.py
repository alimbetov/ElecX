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

p = Path('lib/src/features/editor/editor_building_workspace.dart')
text = p.read_text()
old = """  Map<int, List<ArchitecturalOpening>> get openingsByLevel =>
      Map.unmodifiable({
        for (final entry in _openingsByLevel.entries)
          entry.key: List.unmodifiable(entry.value),
      });
"""
new = """  Map<int, List<ArchitecturalOpening>> get openingsByLevel =>
      Map<int, List<ArchitecturalOpening>>.unmodifiable({
        for (final entry in _openingsByLevel.entries)
          entry.key: List<ArchitecturalOpening>.unmodifiable(entry.value),
      });
"""
if text.count(old) != 1:
    raise RuntimeError(
        f'openingsByLevel typed snapshot: expected 1 match, got {text.count(old)}')
p.write_text(text.replace(old, new, 1))
