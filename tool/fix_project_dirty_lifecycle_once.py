from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    p.write_text(text.replace(old, new, 1))

p = 'lib/src/features/projects/project_hub_screen.dart'

# A setState callback must be synchronous; an assignment expression returns
# the assigned Future and violates State.setState's contract in debug builds.
replace_once(
    p,
    '''  void _reloadProjects() {\n    if (!mounted) return;\n    setState(() => _projectsFuture = _loadProjects());\n  }\n''',
    '''  void _reloadProjects() {\n    if (!mounted) return;\n    final nextProjects = _loadProjects();\n    setState(() {\n      _projectsFuture = nextProjects;\n    });\n  }\n''',
    'synchronous project reload setState',
)

# showDialog completes before its reverse transition has necessarily detached
# the TextField. Avoid manually disposing a controller that the closing dialog
# can still read by using TextFormField.initialValue and local value state.
replace_once(
    p,
    '''  Future<void> _createProject() async {\n    final input = TextEditingController(text: 'Новый проект');\n    final name = await showDialog<String>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        key: const ValueKey('new-project-dialog'),\n        title: const Text('Новый проект'),\n        content: TextField(\n          key: const ValueKey('new-project-name'),\n          controller: input,\n          autofocus: true,\n          decoration: const InputDecoration(labelText: 'Название проекта'),\n          onSubmitted: (value) {\n            final normalized = value.trim();\n            if (normalized.isNotEmpty) {\n              Navigator.of(dialogContext).pop(normalized);\n            }\n          },\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(),\n            child: const Text('Отмена'),\n          ),\n          FilledButton(\n            key: const ValueKey('create-project-confirm'),\n            onPressed: () {\n              final normalized = input.text.trim();\n              if (normalized.isNotEmpty) {\n                Navigator.of(dialogContext).pop(normalized);\n              }\n            },\n            child: const Text('Создать'),\n          ),\n        ],\n      ),\n    );\n    input.dispose();\n    if (name == null || !mounted) return;\n''',
    '''  Future<void> _createProject() async {\n    var draftName = 'Новый проект';\n    final name = await showDialog<String>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        key: const ValueKey('new-project-dialog'),\n        title: const Text('Новый проект'),\n        content: TextFormField(\n          key: const ValueKey('new-project-name'),\n          initialValue: draftName,\n          autofocus: true,\n          decoration: const InputDecoration(labelText: 'Название проекта'),\n          onChanged: (value) => draftName = value,\n          onFieldSubmitted: (value) {\n            final normalized = value.trim();\n            if (normalized.isNotEmpty) {\n              Navigator.of(dialogContext).pop(normalized);\n            }\n          },\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(),\n            child: const Text('Отмена'),\n          ),\n          FilledButton(\n            key: const ValueKey('create-project-confirm'),\n            onPressed: () {\n              final normalized = draftName.trim();\n              if (normalized.isNotEmpty) {\n                Navigator.of(dialogContext).pop(normalized);\n              }\n            },\n            child: const Text('Создать'),\n          ),\n        ],\n      ),\n    );\n    if (name == null || !mounted) return;\n''',
    'dialog controller lifetime',
)
