import 'package:flutter/foundation.dart';

import '../../domain/boundary_editing.dart';
import 'editor_controller.dart';

final class BoundaryEditSession extends ChangeNotifier {
  BoundaryEditProfile? _profile;
  String? _hoveredOpeningId;
  bool _draftDirty = false;
  bool Function()? _saveDraft;
  VoidCallback? _discardDraft;

  bool get active => _profile != null;
  BoundaryEditProfile? get profile => _profile;
  String? get hoveredOpeningId => _hoveredOpeningId;
  bool get draftDirty => _draftDirty;

  void enter([BoundaryEditProfile profile = BoundaryEditProfile.wall]) {
    _profile = profile;
    _hoveredOpeningId = null;
    notifyListeners();
  }

  void setProfile(BoundaryEditProfile profile) {
    if (_profile == profile) return;
    _profile = profile;
    _hoveredOpeningId = null;
    notifyListeners();
  }

  void hoverOpening(String? openingId) {
    if (_profile != BoundaryEditProfile.openings ||
        _hoveredOpeningId == openingId) {
      return;
    }
    _hoveredOpeningId = openingId;
    notifyListeners();
  }

  void attachDraft({
    required bool Function() save,
    required VoidCallback discard,
  }) {
    _saveDraft = save;
    _discardDraft = discard;
  }

  void detachDraft() {
    _saveDraft = null;
    _discardDraft = null;
    if (_draftDirty) {
      _draftDirty = false;
      notifyListeners();
    }
  }

  void markDraftDirty(bool value) {
    if (_draftDirty == value) return;
    _draftDirty = value;
    notifyListeners();
  }

  bool saveDraft() {
    final save = _saveDraft;
    if (save == null) return !_draftDirty;
    final saved = save();
    if (saved) markDraftDirty(false);
    return saved;
  }

  void discardDraft() {
    _discardDraft?.call();
    markDraftDirty(false);
  }

  void exit({bool force = false}) {
    if (_draftDirty && !force) return;
    if (_profile == null && _hoveredOpeningId == null) return;
    _profile = null;
    _hoveredOpeningId = null;
    notifyListeners();
  }
}

final Expando<BoundaryEditSession> _boundaryEditSessions =
    Expando<BoundaryEditSession>('ElecX boundary edit session');

extension BoundaryEditSessionAccess on EditorController {
  BoundaryEditSession get boundaryEditing =>
      _boundaryEditSessions[this] ??= BoundaryEditSession();
}
