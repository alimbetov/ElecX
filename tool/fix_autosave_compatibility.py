from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


editor = Path('lib/src/features/editor')

doc = editor / 'editor_project_document.dart'
replace_once(
    doc,
    """    final editor = workspace.editor;
    final blockingIssue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (blockingIssue != null) {
      throw EditorProjectSaveBlockedException(blockingIssue);
    }
    workspace.synchronizeActiveEditorState();
""",
    """    final editor = workspace.editor;
    // Keep the low-level persistence contract stable for callers that use
    // capture() directly. User-facing structured diagnostics run in the
    // editor preflight before capture.
    if (editor.p2.isManipulating) {
      throw StateError('Cannot save while a component transform is active.');
    }
    if (editor.routeSegments.isNotEmpty || editor.draftStart != null) {
      throw StateError('Cannot save an unfinished editor draft.');
    }
    final blockingIssue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (blockingIssue != null) {
      throw EditorProjectSaveBlockedException(blockingIssue);
    }
    workspace.synchronizeActiveEditorState();
""",
)

screen = editor / 'unified_workspace_editor_screen.dart'
replace_once(
    screen,
    """  Future<EditorProjectRecoveryStore> _recoveryStore() =>
      _recoveryStoreFuture ??= JsonFileEditorProjectRecoveryStore.openDefault();
""",
    """  bool get _recoveryEnabled =>
      widget.recoveryStore != null || widget.projectStore == null;

  Future<EditorProjectRecoveryStore?> _recoveryStoreOrNull() async {
    if (!_recoveryEnabled) return null;
    return _recoveryStoreFuture ??=
        JsonFileEditorProjectRecoveryStore.openDefault();
  }
""",
)
replace_once(
    screen,
    """  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (!_hasUnsavedChanges) return;
""",
    """  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (!_recoveryEnabled || !_hasUnsavedChanges) return;
""",
)
replace_once(
    screen,
    """      final store = await _recoveryStore();
      await store.save(
""",
    """      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.save(
""",
)
replace_once(
    screen,
    """  Future<void> _offerRecoveryIfNewer() async {
    try {
      final store = await _recoveryStore();
""",
    """  Future<void> _offerRecoveryIfNewer() async {
    if (!_recoveryEnabled) return;
    try {
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
""",
)
replace_once(
    screen,
    """  Future<void> _discardRecoveryBestEffort() async {
    _autosaveTimer?.cancel();
    try {
      final store = await _recoveryStore();
      await store.discard(_projectMetadata.projectId);
""",
    """  Future<void> _discardRecoveryBestEffort() async {
    _autosaveTimer?.cancel();
    if (!_recoveryEnabled) return;
    try {
      final store = await _recoveryStoreOrNull();
      if (store == null) return;
      await store.discard(_projectMetadata.projectId);
""",
)
