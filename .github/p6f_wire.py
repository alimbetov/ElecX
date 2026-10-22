from pathlib import Path

path = Path('lib/src/features/editor/unified_workspace_editor_screen.dart')
text = path.read_text()

anchor = "import 'canonical_editor_workspace_adapter.dart';\n"
extra = anchor + "import 'canonical_space_semantics_adapter.dart';\n"
assert anchor in text and "canonical_space_semantics_adapter.dart" not in text
text = text.replace(anchor, extra, 1)
anchor = "import 'room_surface_navigator.dart';\n"
extra = anchor + "import 'space_semantics_inspector.dart';\nimport 'space_semantics_inspector_editing.dart';\n"
assert anchor in text and "space_semantics_inspector.dart" not in text
text = text.replace(anchor, extra, 1)

anchor = "  CompassProjectionState _compassProjectionState() {\n"
block = """  bool get _canEditSpaceSemantics {
    final resolved = _canonicalResolvedRuntime;
    final config = widget.canonicalRuntime;
    if (resolved == null || config?.onSpaceSemanticsCommitted == null) {
      return false;
    }
    if (!_canonicalProjectMatchesScreen) return false;

    final canonicalProject = resolved.session.project;
    final editing = resolved.session.spaceSemanticsEditing;
    return editing.canEdit &&
        editing.projectId == canonicalProject.id &&
        editing.version == canonicalProject.version &&
        resolved.persistenceOwnerProjectId == canonicalProject.id;
  }

""" + anchor
assert anchor in text and "_canEditSpaceSemantics" not in text
text = text.replace(anchor, block, 1)

anchor = "  Widget _projectNavigator({required bool compact}) {\n"
method = """  Widget? _spaceSemanticsInspector({required bool compact}) {
    final resolved = _canonicalResolvedRuntime;
    final config = widget.canonicalRuntime;
    if (resolved == null || config == null || !_canonicalProjectMatchesScreen) {
      return null;
    }
    final spaceId = resolved.session.navigation.selectedSpaceId;
    if (spaceId == null) return null;

    late final CanonicalSpaceSemanticsProjection projection;
    try {
      projection = CanonicalSpaceSemanticsAdapter(
        workspace: workspace,
        binding: resolved.binding,
      ).resolve(project: resolved.session.project, spaceId: spaceId);
    } on CanonicalSpaceSemanticsException {
      return null;
    } catch (error, stackTrace) {
      _reportCanonicalCutoverError(error, stackTrace);
      return null;
    }

    final editing = resolved.session.spaceSemanticsEditing;
    final coordinator = SpaceSemanticsInspectorEditingCoordinator(editing);
    final onUsageChanged = _canEditSpaceSemantics
        ? (usage) {
            try {
              final result = coordinator.setUsage(projection, usage);
              if (result == null) return;
              try {
                config.onSpaceSemanticsCommitted?.call(editing, result);
              } finally {
                _refresh();
              }
            } catch (error, stackTrace) {
              _reportCanonicalCutoverError(error, stackTrace);
            }
          }
        : null;

    return ConstrainedBox(
      key: const ValueKey('space-semantics-production-inspector'),
      constraints: BoxConstraints(maxHeight: compact ? 360 : 320),
      child: SingleChildScrollView(
        child: SpaceSemanticsInspector(
          projection: projection,
          onUsageChanged: onUsageChanged,
        ),
      ),
    );
  }

""" + anchor
assert anchor in text and "Widget? _spaceSemanticsInspector" not in text
text = text.replace(anchor, method, 1)

old = """                      child: SafeArea(
                        child: Column(
                          children: [
                            RoomCircuitOverviewPanel(controller: controller),
"""
new = """                      child: SafeArea(
                        child: Column(
                          children: [
                            if (_spaceSemanticsInspector(compact: true)
                                case final semanticsInspector?) ...[
                              semanticsInspector,
                              const Divider(height: 1),
                            ],
                            RoomCircuitOverviewPanel(controller: controller),
"""
assert old in text
text = text.replace(old, new, 1)

old = """                            canvas: canvas,
                            navigator: _projectNavigator(compact: false),
                          )
"""
new = """                            canvas: canvas,
                            navigator: _projectNavigator(compact: false),
                            semanticsInspector:
                                _spaceSemanticsInspector(compact: false),
                          )
"""
assert old in text
text = text.replace(old, new, 1)

old = """    required this.canvas,
    required this.navigator,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final Widget canvas;
  final Widget navigator;
"""
new = """    required this.canvas,
    required this.navigator,
    required this.semanticsInspector,
  });

  final EditorBuildingWorkspace workspace;
  final EditorShellState shell;
  final Widget canvas;
  final Widget navigator;
  final Widget? semanticsInspector;
"""
assert old in text
text = text.replace(old, new, 1)

old = """            child: _CatalogPanel(
              controller: workspace.editor,
              onCollapse: shell.toggleInspector,
            ),
"""
new = """            child: _CatalogPanel(
              controller: workspace.editor,
              onCollapse: shell.toggleInspector,
              semanticsInspector: semanticsInspector,
            ),
"""
assert old in text
text = text.replace(old, new, 1)

old = """class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({required this.controller, required this.onCollapse});

  final EditorController controller;
  final VoidCallback onCollapse;
"""
new = """class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({
    required this.controller,
    required this.onCollapse,
    required this.semanticsInspector,
  });

  final EditorController controller;
  final VoidCallback onCollapse;
  final Widget? semanticsInspector;
"""
assert old in text
text = text.replace(old, new, 1)

old = """          const Divider(height: 1),
          RoomCircuitOverviewPanel(controller: controller),
"""
new = """          const Divider(height: 1),
          if (semanticsInspector != null) ...[
            semanticsInspector!,
            const Divider(height: 1),
          ],
          RoomCircuitOverviewPanel(controller: controller),
"""
assert old in text
text = text.replace(old, new, 1)

path.write_text(text)
