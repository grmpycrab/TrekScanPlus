import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../models/member.dart';
import '../../../models/trek_type.dart';
import '../../../services/pricing_service.dart';

class GroupCreationProvider extends ChangeNotifier {
  // ── Navigation ────────────────────────────────────────────────────────────
  int _step = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  int get step => _step;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ── Step 0: Group Setup ───────────────────────────────────────────────────
  String groupName = '';
  String affiliation = '';
  int maxSlots = 10;
  DateTime? trekDate;
  String trekType = TrekType.regular.value;
  String bookingClassification = 'regular';
  bool guideRequired = false;
  bool scientistRequired = false;
  String notes = '';

  // ── Step 1: Organizer Details ─────────────────────────────────────────────
  String organizerFirstName = '';
  String organizerLastName = '';
  String organizerGender = 'male';
  DateTime? organizerBirthDate;
  String organizerPhone = '';
  String organizerNationality = 'Filipino';
  String organizerAddress = '';
  String organizerCategory = 'outside_davao_oriental';
  bool organizerPorterRequested = false;

  // ── Step 2: Guest Members ─────────────────────────────────────────────────
  final List<Member> guestMembers = [];
  final List<bool> guestPorterRequested = [];

  // ── Documents: keyed by document field name → files ───────────────────────
  // Organizer documents (set during Step 1).
  final Map<String, List<PlatformFile>> _organizerDocuments = {};
  // Per-guest documents, index-parallel to [guestMembers].
  final List<Map<String, List<PlatformFile>>> _guestDocuments = [];

  // ── Init ──────────────────────────────────────────────────────────────────
  void prefillFromAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final displayName = (user.displayName ?? '').trim();
    final spaceIdx = displayName.indexOf(' ');
    if (spaceIdx > 0) {
      organizerFirstName = displayName.substring(0, spaceIdx);
      organizerLastName = displayName.substring(spaceIdx + 1);
    } else if (displayName.isNotEmpty) {
      organizerFirstName = displayName;
    }
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      organizerPhone = user.phoneNumber!;
    }
    notifyListeners();
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void nextStep() {
    _step++;
    _errorMessage = null;
    notifyListeners();
  }

  void prevStep() {
    if (_step > 0) _step--;
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void setSubmitting(bool v) {
    _isSubmitting = v;
    notifyListeners();
  }

  // ── Step 0 setters ────────────────────────────────────────────────────────
  void setTrekType(String v) {
    trekType = v;
    if (v == 'government_official') bookingClassification = 'government_official';
    notifyListeners();
  }

  void setBookingClassification(String v) {
    bookingClassification = v;
    notifyListeners();
  }

  void setGuideRequired(bool v) {
    guideRequired = v;
    notifyListeners();
  }

  void setScientistRequired(bool v) {
    scientistRequired = v;
    notifyListeners();
  }

  void setTrekDate(DateTime v) {
    trekDate = v;
    notifyListeners();
  }

  // ── Step 1 setters ────────────────────────────────────────────────────────
  void setOrganizerGender(String v) {
    organizerGender = v;
    notifyListeners();
  }

  void setOrganizerBirthDate(DateTime v) {
    organizerBirthDate = v;
    notifyListeners();
  }

  void setOrganizerCategory(String v) {
    organizerCategory = v;
    notifyListeners();
  }

  void setOrganizerPorterRequested(bool v) {
    organizerPorterRequested = v;
    notifyListeners();
  }

  // ── Step 2: Guest members ─────────────────────────────────────────────────
  int get totalSlotsFilled => 1 + guestMembers.length;
  int get remainingSlots => (maxSlots - totalSlotsFilled).clamp(0, maxSlots);
  bool get canAddGuest => totalSlotsFilled < maxSlots;

  /// Number of porters automatically allocated for this group
  /// (1 porter per every 5 trekkers, floor division).
  /// Porter positions count toward total site capacity on trek day.
  int get porterCount => totalSlotsFilled ~/ 5;

  void addGuestMember(Member m, {bool porterRequested = false}) {
    guestMembers.add(m);
    guestPorterRequested.add(porterRequested);
    notifyListeners();
  }

  void removeGuestMember(int index) {
    if (index >= 0 && index < guestMembers.length) {
      guestMembers.removeAt(index);
      guestPorterRequested.removeAt(index);
      if (index < _guestDocuments.length) _guestDocuments.removeAt(index);
      notifyListeners();
    }
  }

  void updateGuestMember(int index, Member m, {bool? porterRequested}) {
    if (index >= 0 && index < guestMembers.length) {
      guestMembers[index] = m;
      if (porterRequested != null) guestPorterRequested[index] = porterRequested;
      notifyListeners();
    }
  }

  // ── Document management ───────────────────────────────────────────────────

  void setOrganizerDocumentFiles(String fieldName, List<PlatformFile> files) {
    _organizerDocuments[fieldName] = files;
    notifyListeners();
  }

  List<PlatformFile> getOrganizerDocumentFiles(String fieldName) =>
      _organizerDocuments[fieldName] ?? [];

  void setGuestDocumentFiles(
    int guestIndex,
    String fieldName,
    List<PlatformFile> files,
  ) {
    while (_guestDocuments.length <= guestIndex) {
      _guestDocuments.add({});
    }
    _guestDocuments[guestIndex][fieldName] = files;
    notifyListeners();
  }

  List<PlatformFile> getGuestDocumentFiles(int guestIndex, String fieldName) {
    if (guestIndex >= _guestDocuments.length) return [];
    return _guestDocuments[guestIndex][fieldName] ?? [];
  }

  /// All (file, memberName) pairs to be uploaded when the group is submitted.
  List<(PlatformFile, String)> get allDocumentFilesForUpload {
    final pairs = <(PlatformFile, String)>[];
    final organizerName =
        '$organizerFirstName $organizerLastName'.trim();
    for (final files in _organizerDocuments.values) {
      for (final f in files) {
        pairs.add((f, organizerName));
      }
    }
    for (var i = 0; i < guestMembers.length; i++) {
      final guestName = guestMembers[i].fullName;
      final docs =
          i < _guestDocuments.length ? _guestDocuments[i] : <String, List<PlatformFile>>{};
      for (final files in docs.values) {
        for (final f in files) {
          pairs.add((f, guestName));
        }
      }
    }
    return pairs;
  }

  // ── Derived ───────────────────────────────────────────────────────────────
  bool get isOffSeasonDate {
    if (trekDate == null) return false;
    final m = trekDate!.month;
    return m >= 7 && m <= 9;
  }

  Member buildOrganizerMember() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final birthDateStr = organizerBirthDate != null
        ? '${organizerBirthDate!.year}-'
            '${organizerBirthDate!.month.toString().padLeft(2, '0')}-'
            '${organizerBirthDate!.day.toString().padLeft(2, '0')}'
        : '';
    return Member(
      firstName: organizerFirstName.trim(),
      lastName: organizerLastName.trim(),
      gender: organizerGender,
      birthDate: birthDateStr,
      contactNumber: organizerPhone.trim(),
      nationality: organizerNationality.trim(),
      homeAddress: organizerAddress.trim(),
      category: organizerCategory,
      isPrimaryContact: true,
      hasAccount: true,
      userId: uid.isEmpty ? null : uid,
      memberStatus: 'complete',
      createdAt: Timestamp.now(),
    );
  }

  // ── Pricing ───────────────────────────────────────────────────────────────
  double get organizerMemberCost =>
      PricingService.instance.calculateMemberPrice(organizerCategory);

  double get organizerPorterCost =>
      organizerPorterRequested ? PricingService.instance.porterPrice : 0;

  double get organizerTotal => organizerMemberCost + organizerPorterCost;

  double guestMemberCost(int i) =>
      PricingService.instance.calculateMemberPrice(guestMembers[i].category);

  double guestPorterCost(int i) =>
      (i < guestPorterRequested.length && guestPorterRequested[i])
          ? PricingService.instance.porterPrice
          : 0;

  double guestTotal(int i) => guestMemberCost(i) + guestPorterCost(i);

  double get guideCost =>
      guideRequired ? PricingService.instance.guidePrice : 0;

  double get scientistCost =>
      scientistRequired ? PricingService.instance.scientistPrice : 0;

  double get grandTotal {
    double t = organizerTotal;
    for (int i = 0; i < guestMembers.length; i++) {
      t += guestTotal(i);
    }
    return t + guideCost + scientistCost;
  }
}
