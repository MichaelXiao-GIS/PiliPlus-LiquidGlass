import 'package:flutter/services.dart';

/// Keeps a route's status-only preference separate from full-screen playback.
/// Full screen still hides both system bars; leaving full screen reapplies the
/// visible route's status preference instead of briefly exposing the Duo panel.
class SystemBarVisibility {
  SystemBarVisibility({this.visibleMode = SystemUiMode.edgeToEdge});

  final SystemUiMode visibleMode;
  final Set<Object> _statusOwners = {};
  bool _barsVisible = true;
  bool get barsVisible => _barsVisible;

  Future<void>? setBarsVisible(bool visible) {
    if (_barsVisible == visible) return null;
    _barsVisible = visible;
    return reapply();
  }

  Future<void>? suppressStatusBar(Object owner, bool suppress) {
    final wasHidden = _statusOwners.isNotEmpty;
    if (suppress) {
      _statusOwners.add(owner);
    } else {
      _statusOwners.remove(owner);
    }
    if (!_barsVisible || wasHidden == _statusOwners.isNotEmpty) return null;
    return reapply();
  }

  Future<void> reapply() {
    if (!_barsVisible) {
      return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (_statusOwners.isNotEmpty) {
      return SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.bottom],
      );
    }
    return SystemChrome.setEnabledSystemUIMode(
      visibleMode,
      overlays: SystemUiOverlay.values,
    );
  }
}
