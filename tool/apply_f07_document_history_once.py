from pathlib import Path

# 1) CommandHistory: expose mutation kind + labels so the document journal can
# observe committed commands without recording selection/preview replaceState.
p = Path('lib/src/engine/command_history.dart')
text = p.read_text()
text = text.replace(
    "abstract interface class EditorCommand<T> {",
    "enum CommandHistoryMutationKind { execute, undo, redo }\n\nabstract interface class EditorCommand<T> {",
    1,
)
text = text.replace(
    "  int _mutationRevision = 0;\n",
    "  int _mutationRevision = 0;\n  CommandHistoryMutationKind? _lastMutationKind;\n",
    1,
)
text = text.replace(
    "  int get mutationRevision => _mutationRevision;\n",
    "  int get mutationRevision => _mutationRevision;\n  CommandHistoryMutationKind? get lastMutationKind => _lastMutationKind;\n  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;\n  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;\n",
    1,
)
text = text.replace(
    "    _mutationRevision++;\n    return _state;\n  }\n\n  T undo()",
    "    _mutationRevision++;\n    _lastMutationKind = CommandHistoryMutationKind.execute;\n    return _state;\n  }\n\n  T undo()",
    1,
)
text = text.replace(
    "    _mutationRevision++;\n    return _state;\n  }\n\n  T redo()",
    "    _mutationRevision++;\n    _lastMutationKind = CommandHistoryMutationKind.undo;\n    return _state;\n  }\n\n  T redo()",
    1,
)
text = text.replace(
    "    _mutationRevision++;\n    return _state;\n  }\n\n  void replaceState",
    "    _mutationRevision++;\n    _lastMutationKind = CommandHistoryMutationKind.redo;\n    return _state;\n  }\n\n  void replaceState",
    1,
)
p.write_text(text)

# 2) Controller restore hook for architecture snapshots. This is deliberately
# narrow: document history restores persisted architecture + edit counters,
# while transient viewport/tool state is cancelled rather than journaled.
p = Path('lib/src/features/editor/editor_controller.dart')
text = p.read_text()
anchor = "  @override\n  void dispose() {\n"
method = r'''  void restoreDocumentArchitecture({
    required BuildingLevel level,
    required List<ArchitecturalOpening> openings,
    required int roomSequence,
    required int openingSequence,
    String? selectedSpaceId,
    String? selectedOpeningId,
  }) {
    requestEditCancellation();
    this.level = level;
    this.openings = List<ArchitecturalOpening>.of(openings);
    this.roomSequence = roomSequence;
    this.openingSequence = openingSequence;
    this.selectedSpaceId = selectedSpaceId != null &&
            level.spaces.any((space) => space.id == selectedSpaceId)
        ? selectedSpaceId
        : null;
    this.selectedOpeningId = selectedOpeningId != null &&
            this.openings.any((opening) => opening.id == selectedOpeningId)
        ? selectedOpeningId
        : null;
    activeSurface = null;
    viewMode = EditorViewMode.plan;
    tool = EditorTool.select;
    draftStart = null;
    routeSegments.clear();
    notifyListeners();
  }

'''
if anchor not in text:
    raise SystemExit('controller dispose anchor not found')
text = text.replace(anchor, method + anchor, 1)
p.write_text(text)

# 3) Unified document journal.
Path('lib/src/features/editor/editor_document_history.dart').write_text(r'''import 'package:flutter/foundation.dart';

import '../../domain/project_model.dart';
import '../../engine/command_history.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class EditorDocumentHistory extends ChangeNotifier {
  EditorDocumentHistory(this.controller)
      : _architecture = _ArchitectureSnapshot.capture(controller),
        _p2 = controller.p2,
        _p2Revision = controller.p2.history.mutationRevision {
    controller.addListener(_onArchitectureChanged);
    _p2.addListener(_onP2Changed);
  }

  final EditorController controller;
  final List<_DocumentEntry> _undo = <_DocumentEntry>[];
  final List<_DocumentEntry> _redo = <_DocumentEntry>[];
  late _ArchitectureSnapshot _architecture;
  late EditorP2Session _p2;
  int _p2Revision;
  bool _replaying = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  void _onArchitectureChanged() {
    if (_replaying) return;
    final next = _ArchitectureSnapshot.capture(controller);
    if (!_architecture.sameDocumentIdentity(next)) {
      _push(_ArchitectureEntry(before: _architecture, after: next));
    }
    _architecture = next;
  }

  void _onP2Changed() {
    if (_replaying) return;
    final revision = _p2.history.mutationRevision;
    if (revision == _p2Revision) return;

    // Local undo/redo outside this journal destroys global chronological
    // ordering. Fail closed by resetting the global journal rather than
    // presenting an incorrect Undo operation.
    if (_p2.history.lastMutationKind != CommandHistoryMutationKind.execute ||
        revision != _p2Revision + 1) {
      _undo.clear();
      _redo.clear();
      _p2Revision = revision;
      notifyListeners();
      return;
    }

    _p2Revision = revision;
    _push(_P2Entry(label: _p2.history.undoLabel ?? 'Electrical edit'));
  }

  void _push(_DocumentEntry entry) {
    _undo.add(entry);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
    notifyListeners();
  }

  bool undo() {
    if (_undo.isEmpty || _p2.isManipulating) return false;
    final entry = _undo.removeLast();
    _replaying = true;
    try {
      entry.undo(this);
      _redo.add(entry);
      _refreshBaselines();
    } finally {
      _replaying = false;
    }
    notifyListeners();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty || _p2.isManipulating) return false;
    final entry = _redo.removeLast();
    _replaying = true;
    try {
      entry.redo(this);
      _undo.add(entry);
      _refreshBaselines();
    } finally {
      _replaying = false;
    }
    notifyListeners();
    return true;
  }

  void _refreshBaselines() {
    _architecture = _ArchitectureSnapshot.capture(controller);
    _p2Revision = _p2.history.mutationRevision;
  }

  void _restoreArchitecture(_ArchitectureSnapshot snapshot) {
    controller.restoreDocumentArchitecture(
      level: snapshot.level,
      openings: snapshot.openings,
      roomSequence: snapshot.roomSequence,
      openingSequence: snapshot.openingSequence,
      selectedSpaceId: snapshot.selectedSpaceId,
      selectedOpeningId: snapshot.selectedOpeningId,
    );
  }

  void _undoP2() => _p2.undo();
  void _redoP2() => _p2.redo();

  @override
  void dispose() {
    controller.removeListener(_onArchitectureChanged);
    _p2.removeListener(_onP2Changed);
    super.dispose();
  }
}

sealed class _DocumentEntry {
  const _DocumentEntry();
  String get label;
  void undo(EditorDocumentHistory history);
  void redo(EditorDocumentHistory history);
}

final class _ArchitectureEntry extends _DocumentEntry {
  const _ArchitectureEntry({required this.before, required this.after});
  final _ArchitectureSnapshot before;
  final _ArchitectureSnapshot after;

  @override
  String get label => 'Edit architecture';

  @override
  void undo(EditorDocumentHistory history) => history._restoreArchitecture(before);

  @override
  void redo(EditorDocumentHistory history) => history._restoreArchitecture(after);
}

final class _P2Entry extends _DocumentEntry {
  const _P2Entry({required this.label});

  @override
  final String label;

  @override
  void undo(EditorDocumentHistory history) => history._undoP2();

  @override
  void redo(EditorDocumentHistory history) => history._redoP2();
}

final class _ArchitectureSnapshot {
  const _ArchitectureSnapshot({
    required this.level,
    required this.openings,
    required this.roomSequence,
    required this.openingSequence,
    required this.selectedSpaceId,
    required this.selectedOpeningId,
  });

  factory _ArchitectureSnapshot.capture(EditorController controller) =>
      _ArchitectureSnapshot(
        level: controller.level,
        openings: controller.openings,
        roomSequence: controller.roomSequence,
        openingSequence: controller.openingSequence,
        selectedSpaceId: controller.selectedSpaceId,
        selectedOpeningId: controller.selectedOpeningId,
      );

  final BuildingLevel level;
  final List<ArchitecturalOpening> openings;
  final int roomSequence;
  final int openingSequence;
  final String? selectedSpaceId;
  final String? selectedOpeningId;

  bool sameDocumentIdentity(_ArchitectureSnapshot other) =>
      identical(level, other.level) && identical(openings, other.openings);
}

final Expando<EditorDocumentHistory> _documentHistories =
    Expando<EditorDocumentHistory>('ElecX document history');

extension EditorDocumentHistoryAccess on EditorController {
  EditorDocumentHistory get documentHistory =>
      _documentHistories[this] ??= EditorDocumentHistory(this);

  void disposeDocumentHistory() {
    _documentHistories[this]?.dispose();
    _documentHistories[this] = null;
  }
}
''')

# 4) Keyboard shortcuts now operate the chronological document journal.
p = Path('lib/src/features/editor/editor_keyboard_scope.dart')
text = p.read_text()
text = text.replace(
    "import 'editor_controller.dart';\n",
    "import 'editor_controller.dart';\nimport 'editor_document_history.dart';\n",
    1,
)
text = text.replace(
    "    controller.p2.undo();",
    "    controller.documentHistory.undo();",
    1,
)
text = text.replace(
    "    controller.p2.redo();",
    "    controller.documentHistory.redo();",
    1,
)
p.write_text(text)

# 5) Acceptance: P2 -> architecture -> P2 must undo/redo in exact chronology;
# selection/viewport notifications must not pollute history.
Path('test/f07_document_history_test.dart').write_text(r'''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F07 document undo/redo follows architecture and electrical chronology', () {
    final controller = EditorController.demo();
    addTearDown(controller.disposeDocumentHistory);
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);
    final history = controller.documentHistory;

    controller.showWall(0);
    final surface = controller.activeSurface!;
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1000, 300),
    );
    expect(history.undoDepth, 1);

    controller.showPlan();
    controller.addRectangleRoom(
      const MmPoint(12000, 1000),
      const MmPoint(15000, 4000),
    );
    controller.selectSpace(controller.selectedSpaceId);
    expect(history.undoDepth, 2);
    final addedRoomId = controller.selectedSpaceId;
    expect(controller.level.spaces.any((space) => space.id == addedRoomId), isTrue);

    controller.showWall(0);
    controller.p2.select(component.id);
    expect(controller.p2.beginMoveSelectedComponent(), isTrue);
    expect(
      controller.p2.previewMoveSelectedComponent(const SurfacePointMm(1200, 400)),
      isTrue,
    );
    expect(controller.p2.commitMoveSelectedComponent(), isTrue);
    expect(history.undoDepth, 3);

    expect(history.undo(), isTrue);
    expect(controller.p2.selectedComponent!.position, component.position);
    expect(controller.level.spaces.any((space) => space.id == addedRoomId), isTrue);

    expect(history.undo(), isTrue);
    expect(controller.level.spaces.any((space) => space.id == addedRoomId), isFalse);
    expect(controller.p2.components.single.id, component.id);

    expect(history.undo(), isTrue);
    expect(controller.p2.components, isEmpty);
    expect(history.canUndo, isFalse);

    expect(history.redo(), isTrue);
    expect(controller.p2.components.single.id, component.id);
    expect(history.redo(), isTrue);
    expect(controller.level.spaces.any((space) => space.id == addedRoomId), isTrue);
    expect(history.redo(), isTrue);
    expect(controller.p2.components.single.position, const SurfacePointMm(1200, 400));
  });

  test('F07 transient selection and viewport changes do not create history', () {
    final controller = EditorController.demo();
    addTearDown(controller.disposeDocumentHistory);
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);
    final history = controller.documentHistory;

    controller.selectSpace('corridor-1');
    controller.setZoom(2);
    controller.setSnapEnabled(false);
    controller.showPlan();
    expect(history.undoDepth, 0);

    controller.showWall(0);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(600, 300),
    );
    expect(history.undoDepth, 1);
    controller.p2.select(component.id);
    controller.p2.clearSelection();
    expect(history.undoDepth, 1);
  });

  test('F07 local P2 undo outside journal fails closed by clearing timeline', () {
    final controller = EditorController.demo();
    addTearDown(controller.disposeDocumentHistory);
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);
    final history = controller.documentHistory;

    controller.showWall(0);
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(600, 300),
    );
    expect(history.canUndo, isTrue);

    controller.p2.undo();
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
  });
}
''')
