from pathlib import Path

# This runs after apply_f03_host_geometry_once.py and normalizes all reachable
# call sites onto one canonical guarded opening API.
guard = Path('lib/src/features/editor/electrical_host_geometry_guard.dart')
text = guard.read_text()
text = text.replace(
    '      if (!_insideOrBoundary(component.position, context.boundary)) return false;\n',
    '''      if (!_insideOrBoundary(component.position, context.boundary)) {
        return false;
      }
''',
)
if 'extension ElectricalHostGeometryGuardedMutations' not in text:
    text += r'''

extension ElectricalHostGeometryGuardedMutations on EditorController {
  bool updateSelectedOpeningGuarded({
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
    bool Function(ArchitecturalOpening candidate)? canCommit,
  }) =>
      updateSelectedOpening(
        type: type,
        offsetFromStartMm: offsetFromStartMm,
        widthMm: widthMm,
        heightMm: heightMm,
        sillHeightMm: sillHeightMm,
        canCommit: canCommit ??
            (candidate) => ElectricalHostGeometryGuard.openingCandidateAllowed(
                  this,
                  candidate,
                ),
      );

  bool addOpeningGuarded(
    ArchitecturalOpeningType type, {
    bool Function(ArchitecturalOpening candidate)? canCommit,
  }) =>
      addOpening(
        type,
        canCommit: canCommit ??
            (candidate) => ElectricalHostGeometryGuard.openingCandidateAllowed(
                  this,
                  candidate,
                ),
      );
}
'''
guard.write_text(text)

production_files = [
    Path('lib/src/features/editor/adaptive_spatial_editor_screen.dart'),
    Path('lib/src/features/editor/boundary_bottom_editor.dart'),
    Path('lib/src/features/editor/engineering_inspector.dart'),
    Path('lib/src/features/editor/plan_geometry_editor_actions.dart'),
    Path('lib/src/features/editor/editable_spatial_canvas.dart'),
]
for path in production_files:
    text = path.read_text()
    if 'addOpening(' not in text and 'updateSelectedOpening(' not in text:
        continue
    if "electrical_host_geometry_guard.dart" not in text:
        anchor = "import 'editor_controller.dart';\n"
        if anchor not in text:
            raise SystemExit(f'import anchor missing in {path}')
        text = text.replace(
            anchor,
            anchor + "import 'electrical_host_geometry_guard.dart';\n",
            1,
        )
    text = text.replace('controller.addOpening(', 'controller.addOpeningGuarded(')
    text = text.replace(
        'controller.updateSelectedOpening(',
        'controller.updateSelectedOpeningGuarded(',
    )
    if path.name == 'plan_geometry_editor_actions.dart':
        text = text.replace('return updateSelectedOpening(', 'return updateSelectedOpeningGuarded(')
    path.write_text(text)

# Existing focused opening tests should exercise the guarded public path too.
for name in [
    'editor_project_persistence_test.dart',
    'opening_editor_test.dart',
    'opening_parameter_editing_test.dart',
]:
    path = Path('test') / name
    text = path.read_text()
    if "electrical_host_geometry_guard.dart" not in text:
        anchor = "import 'package:elecx/src/features/editor/editor_controller.dart';\n"
        if anchor not in text:
            # Insert after the last import if a focused test does not directly import controller.
            lines = text.splitlines(keepends=True)
            last = max(i for i, line in enumerate(lines) if line.startswith('import '))
            lines.insert(
                last + 1,
                "import 'package:elecx/src/features/editor/electrical_host_geometry_guard.dart';\n",
            )
            text = ''.join(lines)
        else:
            text = text.replace(
                anchor,
                anchor + "import 'package:elecx/src/features/editor/electrical_host_geometry_guard.dart';\n",
                1,
            )
    text = text.replace('.addOpening(', '.addOpeningGuarded(')
    text = text.replace('.updateSelectedOpening(', '.updateSelectedOpeningGuarded(')
    path.write_text(text)

# The new P1 regression can also use the canonical guarded convenience method.
p1 = Path('test/p1_lifecycle_acceptance_test.dart')
text = p1.read_text().replace('controller.addOpening(\n', 'controller.addOpeningGuarded(\n')
p1.write_text(text)
