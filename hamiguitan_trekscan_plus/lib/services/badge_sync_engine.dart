import 'dart:async';
import 'achievement_service.dart';
import 'badge_claim_service.dart';
import 'connectivity_service.dart';

/// Listens to network state changes and pushes offline-queued achievements
/// and staged badge-claim photos to Firestore / Storage when the device
/// regains a connection.
class BadgeSyncEngine {
  BadgeSyncEngine._internal();
  static final BadgeSyncEngine instance = BadgeSyncEngine._internal();

  bool _started = false;
  StreamSubscription<ConnectionStatus>? _sub;

  /// Call once during app initialisation (after ConnectivityService.start()).
  void start() {
    if (_started) return;
    _started = true;
    _sub = ConnectivityService.instance.statusStream.listen((status) {
      if (status == ConnectionStatus.online) _runSync();
    });
  }

  /// Manually invoke the sync loop (e.g. from the developer smoke-test panel).
  Future<void> triggerSync() => _runSync();

  Future<void> _runSync() async {
    await Future.wait([
      AchievementService().syncToFirebase(),
      BadgeClaimService.uploadStagedClaims(),
    ]);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
