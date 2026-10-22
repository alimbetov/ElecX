import 'package:flutter/foundation.dart';

import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
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
  final EditorP2Session _p2;
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
  void undo(EditorDocumentHistory history) =>
      history._restoreArchitecture(before);

  @override
  void redo(EditorDocumentHistory history) =>
      history._restoreArchitecture(after);
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
