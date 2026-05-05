import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../models/user_model.dart';
import '../../../services/achievement_service.dart';
import '../../../services/e_certificate_service.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/station_service.dart';
import '../../../utils/app_logger.dart';

class ProfileViewModel extends ChangeNotifier {
  // ── Auth / identity ───────────────────────────────────────────────────────
  User? firebaseUser;
  bool isOwnProfile = true;

  // ── Achievement loading state ─────────────────────────────────────────────
  bool achievementsLoading = true;
  late AchievementService achievementService;

  // ── Initial user shell (replaced by stream in the screen) ─────────────────
  UserModel initialUser = UserModel(
    firstName: 'Loading',
    lastName: '...',
    email: '',
    birthDate: '01/01/1990',
    gender: 'Not specified',
  );

  // ── Services ─────────────────────────────────────────────────────────────
  final ECertificateService certificateService = ECertificateService.instance;

  /// Call once from the screen's [initState].
  /// [profileUserId] is the userId whose profile is being displayed,
  /// or null to display the currently signed-in user's profile.
  void initialize(String? profileUserId) {
    firebaseUser = FirebaseAuthService.instance.currentUser;
    isOwnProfile = profileUserId == null || profileUserId == firebaseUser?.uid;

    final displayUserId = profileUserId ?? firebaseUser?.uid;

    if (firebaseUser != null && isOwnProfile) {
      final display = firebaseUser!.displayName ?? '';
      final parts = display.isNotEmpty ? display.split(' ') : [];
      final first = parts.isNotEmpty
          ? parts.first
          : (firebaseUser!.email?.split('@').first ?? '');
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      initialUser = UserModel(
        firstName: first,
        lastName: last,
        email: firebaseUser!.email ?? '',
        birthDate: '01/01/1990',
        gender: 'Not specified',
        profileImage: firebaseUser!.photoURL,
      );
    }

    if (displayUserId != null) {
      _initializeAchievements(displayUserId);
    }

    if (isOwnProfile) {
      _initializeCertificates();
    }
  }

  Future<void> _initializeAchievements(String userId) async {
    try {
      if (isOwnProfile) {
        achievementService = AchievementService();
      } else {
        achievementService = AchievementService.forUser();
      }
      await achievementService.init(userId: userId);

      final unlocked = achievementService.getUnlockedAchievements().length;
      final total = achievementService.getAllAchievements().length;
      AppLogger.i(
        'ProfileViewModel: Loaded $unlocked/$total achievements for $userId',
      );
    } catch (e) {
      AppLogger.e(
        'ProfileViewModel: Error loading achievements for $userId: $e',
      );
    } finally {
      achievementsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeCertificates() async {
    if (firebaseUser == null) return;
    try {
      await certificateService.init(userId: firebaseUser!.uid);
      StationService.instance.setCurrentUser(firebaseUser!.uid);
      if (!StationService.instance.isLoaded) {
        await StationService.instance.loadStations();
      }
      final visited = StationService.instance.getVisitedStations();
      if (visited.isNotEmpty) {
        await certificateService.checkAndAwardCertificate(
          visited,
          totalDistance: StationService.instance.getTotalDistance(),
          totalTimeMinutes: StationService.instance.getTotalTimeMinutes(),
          trekStartDate: StationService.instance.getTrekStartDate(),
          trekEndDate: StationService.instance.getTrekEndDate(),
        );
      }
      notifyListeners();
    } catch (e, st) {
      AppLogger.e('ProfileViewModel: Error loading certificates: $e');
      AppLogger.e('Stack trace: $st');
    }
  }

  String getDisplayName(UserModel user) {
    if (user.firstName.isNotEmpty || user.lastName.isNotEmpty) {
      return '${user.firstName} ${user.lastName}'.trim();
    }
    return user.email.split('@').first;
  }
}
