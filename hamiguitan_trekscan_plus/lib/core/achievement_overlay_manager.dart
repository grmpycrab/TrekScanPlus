import 'dart:collection';
import 'package:flutter/material.dart';
import '../config/app_router.dart';
import '../features/notification/widgets/achievement_notification.dart';
import '../models/achievement.dart';

/// Global singleton that inserts [AchievementUnlockOverlay] banners into the
/// app's navigator overlay without requiring a BuildContext at the call site.
///
/// Banners are queued — if one is already visible the next waits until it
/// dismisses itself.  Safe to call from any service layer code.
class AchievementOverlayManager {
  AchievementOverlayManager._();
  static final AchievementOverlayManager instance = AchievementOverlayManager._();

  final Queue<Achievement> _queue = Queue<Achievement>();
  bool _isShowing = false;
  OverlayEntry? _currentEntry;

  /// Enqueue an achievement banner. The banner slides in from the top,
  /// shows for 4 s, then slides out.  Multiple rapid unlocks stack cleanly.
  void show(Achievement achievement) {
    _queue.add(achievement);
    if (!_isShowing) _showNext();
  }

  void _showNext() {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      // Navigator not yet ready (e.g., called during app cold-start).
      // Drain the queue silently rather than accumulating stale banners.
      _queue.clear();
      _isShowing = false;
      return;
    }

    _isShowing = true;
    final achievement = _queue.removeFirst();

    // Use a `late` forward-reference so the onDismiss closure can call
    // entry.remove() before `entry` is assigned externally.
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: AchievementUnlockOverlay(
          achievement: achievement,
          onDismiss: () {
            entry.remove();
            _currentEntry = null;
            _showNext();
          },
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Forcibly remove any visible banner (e.g. on sign-out).
  void dismissAll() {
    _queue.clear();
    _currentEntry?.remove();
    _currentEntry = null;
    _isShowing = false;
  }
}
