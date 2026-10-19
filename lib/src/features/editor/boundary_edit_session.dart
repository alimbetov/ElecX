import 'package:flutter/foundation.dart';

import '../../domain/boundary_editing.dart';
import 'editor_controller.dart';

final class BoundaryEditSession extends ChangeNotifier {
  BoundaryEditProfile? _profile;
  String? _hoveredOpeningId;

  bool get active => _profile != null;
  BoundaryEditProfile? get profile => _profile;
  String? get hoveredOpeningId => _hoveredOpeningId;

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

  void exit() {
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
