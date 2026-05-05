import 'package:flutter/foundation.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../utils/app_logger.dart';

class SettingsViewModel extends ChangeNotifier {
  bool _isLoggingOut = false;
  String? _error;

  bool get isLoggingOut => _isLoggingOut;
  String? get error => _error;

  Future<bool> logout() async {
    _isLoggingOut = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseAuthService.instance.signOut();
      // AuthGate reacts to auth state change — no manual navigation needed.
      return true;
    } catch (e) {
      AppLogger.e('SettingsViewModel: logout failed: $e');
      _error = 'Unable to logout. Please try again.';
      return false;
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
