from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, got {count}: {old[:120]!r}')
    path.write_text(text.replace(old, new, 1))

# Make composed site replaceable without mutating nested value objects.
site = Path('lib/src/domain/site_outdoor_model.dart')
replace_once(
    site,
    "  final ProjectSite site;\n  final List<OutdoorZone> outdoorZones;\n  final List<SiteBuildingConnection> connections;\n}\n",
    "  final ProjectSite site;\n  final List<OutdoorZone> outdoorZones;\n  final List<SiteBuildingConnection> connections;\n\n  ComposedProjectSite copyWith({\n    ProjectSite? site,\n    List<OutdoorZone>? outdoorZones,\n    List<SiteBuildingConnection>? connections,\n  }) => ComposedProjectSite(\n    site: site ?? this.site,\n    outdoorZones: outdoorZones ?? this.outdoorZones,\n    connections: connections ?? this.connections,\n  );\n}\n",
)

# Project north is project/site state, not widget state.
workspace = Path('lib/src/features/editor/editor_building_workspace.dart')
replace_once(
    workspace,
    "  final ComposedProjectSite site;\n",
    "  ComposedProjectSite site;\n",
)
replace_once(
    workspace,
    "  void selectLevel(int levelNumber) {\n",
    "  void updateProjectNorth(ProjectNorth value) {\n    if (site.site.projectNorth.northAzimuthDegrees ==\n        value.northAzimuthDegrees) {\n      return;\n    }\n    site = site.copyWith(\n      site: site.site.copyWith(projectNorth: value),\n    );\n    notifyListeners();\n  }\n\n  void selectLevel(int levelNumber) {\n",
)

# Make the compass editable from the shared plan/site canvas.
screen = Path('lib/src/features/editor/unified_workspace_editor_screen.dart')
replace_once(
    screen,
    "  void _openMiniMap() {\n",
    "  Future<void> _editProjectNorth() async {\n    final current = workspace.site.site.projectNorth;\n    final input = TextEditingController(\n      text: current.northAzimuthDegrees.toStringAsFixed(1),\n    );\n    final value = await showDialog<double>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        title: const Text('Ориентация проекта'),\n        content: TextField(\n          controller: input,\n          autofocus: true,\n          keyboardType: const TextInputType.numberWithOptions(decimal: true),\n          decoration: const InputDecoration(\n            labelText: 'Азимут севера',\n            suffixText: '°',\n            helperText: '0° = север вверх по плану, угол по часовой стрелке',\n          ),\n          onSubmitted: (text) {\n            final parsed = double.tryParse(text.replaceAll(',', '.'));\n            if (parsed != null && parsed >= 0 && parsed < 360) {\n              Navigator.of(dialogContext).pop(parsed);\n            }\n          },\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(),\n            child: const Text('Отмена'),\n          ),\n          FilledButton(\n            onPressed: () {\n              final parsed = double.tryParse(input.text.replaceAll(',', '.'));\n              if (parsed == null || parsed < 0 || parsed >= 360) return;\n              Navigator.of(dialogContext).pop(parsed);\n            },\n            child: const Text('Применить'),\n          ),\n        ],\n      ),\n    );\n    input.dispose();\n    if (value == null || !mounted) return;\n    workspace.updateProjectNorth(\n      current.copyWith(northAzimuthDegrees: value),\n    );\n  }\n\n  void _openMiniMap() {\n",
)
replace_once(
    screen,
    "                  child: ProjectCompassOverlay(\n                    projectNorth: workspace.site.site.projectNorth,\n                  ),\n",
    "                  child: ProjectCompassOverlay(\n                    projectNorth: workspace.site.site.projectNorth,\n                    onTap: _editProjectNorth,\n                  ),\n",
)

# Regression: project north is updated at workspace/site level and not lost by level switches.
test = Path('test/editor_building_workspace_test.dart')
replace_once(
    test,
    "  test('next and previous level traverse physical level order', () {\n",
    "  test('project north updates site state and survives level switches', () {\n    final editor = EditorController.demo();\n    final workspace = EditorBuildingWorkspace.demo(editor);\n    addTearDown(workspace.dispose);\n    addTearDown(editor.dispose);\n\n    workspace.updateProjectNorth(\n      workspace.site.site.projectNorth.copyWith(northAzimuthDegrees: 37.5),\n    );\n    expect(workspace.site.site.projectNorth.northAzimuthDegrees, 37.5);\n\n    workspace.selectLevel(7);\n    workspace.selectLevel(-1);\n    expect(workspace.site.site.projectNorth.northAzimuthDegrees, 37.5);\n  });\n\n  test('next and previous level traverse physical level order', () {\n",
)
