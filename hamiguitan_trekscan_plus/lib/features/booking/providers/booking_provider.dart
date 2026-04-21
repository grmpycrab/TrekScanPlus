// ignore_for_file: unintended_html_in_doc_comment

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../models/booking_model.dart';
import '../../../models/member.dart';
import '../../../services/user_service.dart';
import '../../../utils/app_logger.dart';
import '../models/booking_form_state.dart';

/// Provider for managing booking form state and logic
/// Handles form validation, member management, and draft bookings
class BookingProvider extends ChangeNotifier {
  BookingFormState _state = BookingFormState();
  List<BookingModel> _draftBookings = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPrimaryContactInitialized = false;

  // Getters
  BookingFormState get state => _state;
  List<BookingModel> get draftBookings => _draftBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPrimaryContactInitialized => _isPrimaryContactInitialized;

  /// Update climb/trek type
  void setClimbType(String type) {
    _state = _state.copyWith(climbType: type);
    _updateEstimatedPrice();
    notifyListeners();
  }

  /// Update hometown
  void setHometown(String hometown) {
    _state = _state.copyWith(hometown: hometown);
    notifyListeners();
  }

  /// Update primary contact category (also updates member's category)
  void setPrimaryContactCategory(String category) {
    _state = _state.copyWith(primaryContactCategory: category);

    // Update primary contact's category
    if (_state.bookingMembers.isNotEmpty &&
        _state.bookingMembers[0].isPrimaryContact) {
      final updated = List<Member>.from(_state.bookingMembers);
      updated[0] = updated[0].copyWith(category: category);
      _state = _state.copyWith(bookingMembers: updated);
    }

    _updateEstimatedPrice();
    notifyListeners();
  }

  /// Update contact number
  void setContactNumber(String number) {
    _state = _state.copyWith(contactNumber: number);
    notifyListeners();
  }

  /// Update affiliation
  void setAffiliation(String affiliation) {
    _state = _state.copyWith(affiliation: affiliation);
    notifyListeners();
  }

  /// Set trek date
  void setTrekDate(DateTime date) {
    _state = _state.copyWith(selectedDate: date);
    notifyListeners();
  }

  /// Set files to upload
  void setPickedFiles(List<PlatformFile> files) {
    _state = _state.copyWith(pickedFiles: files);
    notifyListeners();
  }

  /// Set files for a specific document type of a specific member
  /// Structure: memberIndex -> documentFieldName -> List<PlatformFile>
  void setMemberDocumentFiles(
    int memberIndex,
    String documentFieldName,
    List<PlatformFile> files,
  ) {
    final updatedMemberDocuments =
        Map<String, Map<String, List<PlatformFile>>>.from(
          _state.memberDocuments,
        );
    final memberKey = memberIndex.toString();
    final memberDocs = Map<String, List<PlatformFile>>.from(
      updatedMemberDocuments[memberKey] ?? {},
    );
    memberDocs[documentFieldName] = files;
    updatedMemberDocuments[memberKey] = memberDocs;
    _state = _state.copyWith(memberDocuments: updatedMemberDocuments);
    notifyListeners();
  }

  /// Get files for a specific document type of a specific member
  List<PlatformFile> getMemberDocumentFiles(
    int memberIndex,
    String documentFieldName,
  ) {
    return _state.memberDocuments[memberIndex.toString()]?[documentFieldName] ??
        [];
  }

  /// Remove file from a specific document type of a specific member
  void removeMemberDocumentFile(
    int memberIndex,
    String documentFieldName,
    PlatformFile file,
  ) {
    final updatedMemberDocuments =
        Map<String, Map<String, List<PlatformFile>>>.from(
          _state.memberDocuments,
        );
    final memberKey = memberIndex.toString();
    final memberDocs = updatedMemberDocuments[memberKey];

    if (memberDocs != null && memberDocs.containsKey(documentFieldName)) {
      final docFiles = List<PlatformFile>.from(memberDocs[documentFieldName]!);
      docFiles.remove(file);

      if (docFiles.isEmpty) {
        memberDocs.remove(documentFieldName);
        if (memberDocs.isEmpty) {
          updatedMemberDocuments.remove(memberKey);
        }
      } else {
        memberDocs[documentFieldName] = docFiles;
      }

      _state = _state.copyWith(memberDocuments: updatedMemberDocuments);
      notifyListeners();
    }
  }

  /// Clear all member documents
  void clearMemberDocuments() {
    _state = _state.copyWith(memberDocuments: {});
    notifyListeners();
  }

  /// Add a new member to booking
  void addMember(Member member) {
    final updated = [..._state.bookingMembers, member];
    _state = _state.copyWith(bookingMembers: updated);
    _updateEstimatedPrice();
    notifyListeners();
  }

  /// Remove a member by index
  void removeMember(int index) {
    if (index >= 0 && index < _state.bookingMembers.length) {
      final updated = List<Member>.from(_state.bookingMembers);
      updated.removeAt(index);
      _state = _state.copyWith(bookingMembers: updated);
      _updateEstimatedPrice();
      notifyListeners();
    }
  }

  /// Update a member at specific index
  void updateMember(int index, Member member) {
    if (index >= 0 && index < _state.bookingMembers.length) {
      final updated = List<Member>.from(_state.bookingMembers);
      updated[index] = member;
      _state = _state.copyWith(bookingMembers: updated);
      _updateEstimatedPrice();
      notifyListeners();
    }
  }

  /// Apply primary contact's home address to all other members
  void applyPrimaryAddressToAll() {
    if (_state.bookingMembers.isEmpty ||
        !_state.bookingMembers[0].isPrimaryContact) {
      return;
    }

    final primaryAddress = _state.bookingMembers[0].homeAddress;
    final updated = _state.bookingMembers.asMap().entries.map((entry) {
      final index = entry.key;
      final member = entry.value;

      // Skip primary contact, update others
      if (index == 0) {
        return member;
      }

      return member.copyWith(homeAddress: primaryAddress);
    }).toList();

    _state = _state.copyWith(bookingMembers: updated);
    notifyListeners();
  }

  /// Initialize form with authenticated user as primary contact
  /// Skips if already initialized to avoid redundant calls
  Future<void> initializePrimaryContact() async {
    // Skip if already initialized
    if (_isPrimaryContactInitialized) {
      return;
    }

    try {
      _setLoading(true);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _setError('No authenticated user found');
        return;
      }

      final userData = await UserService.instance.getUserOnce(currentUser.uid);
      final firstName =
          userData?['firstName'] as String? ??
          currentUser.displayName?.split(' ').first ??
          '';
      final lastName =
          userData?['lastName'] as String? ??
          currentUser.displayName?.split(' ').last ??
          '';

      final primaryContact = Member(
        firstName: firstName,
        lastName: lastName,
        gender: userData?['gender'] as String? ?? 'Not specified',
        birthDate: userData?['birthDate'] as String? ?? '',
        contactNumber: _state.contactNumber,
        nationality: userData?['nationality'] as String? ?? '',
        homeAddress: userData?['homeAddress'] as String? ?? '',
        category: _state.primaryContactCategory,
        isPrimaryContact: true,
        hasAccount: true,
        userId: currentUser.uid,
        createdAt: Timestamp.now(),
      );

      _state = _state.copyWith(bookingMembers: [primaryContact]);
      _isPrimaryContactInitialized = true;
      _setLoading(false);
      _clearError();
    } catch (e) {
      _setError('Failed to initialize primary contact: $e');
      AppLogger.e('Error initializing primary contact: $e');
    }
  }

  /// Reinitialize primary contact (useful for refresh scenarios)
  Future<void> reinitializePrimaryContact() async {
    _isPrimaryContactInitialized = false;
    await initializePrimaryContact();
  }

  /// Prefill contact number from user settings
  Future<void> prefillContactNumber() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || _state.contactNumber.isNotEmpty) return;

      final userData = await UserService.instance.getUserOnce(currentUser.uid);
      final phoneNumber = userData?['phoneNumber'] as String? ?? '';

      if (phoneNumber.isNotEmpty) {
        _state = _state.copyWith(contactNumber: phoneNumber);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('Error prefilling contact number: $e');
    }
  }

  /// Load draft bookings from local storage
  Future<void> loadDraftBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final key = 'draft_bookings_${currentUser.uid}';
      final jsonString = prefs.getString(key);

      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonData = jsonDecode(jsonString) as List;
        _draftBookings = jsonData
            .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('Error loading draft bookings: $e');
    }
  }

  /// Save draft bookings to local storage
  Future<void> saveDraftBooking(BookingModel booking) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Add to draft list
      _draftBookings.add(booking);

      final key = 'draft_bookings_${currentUser.uid}';
      final jsonData = _draftBookings.map((b) => b.toMap()).toList();
      await prefs.setString(key, jsonEncode(jsonData));

      notifyListeners();
    } catch (e) {
      AppLogger.e('Error saving draft booking: $e');
      _setError('Failed to save draft booking');
    }
  }

  /// Remove draft booking
  Future<void> removeDraftBooking(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      _draftBookings.removeWhere((b) => b.id == bookingId);

      final key = 'draft_bookings_${currentUser.uid}';
      if (_draftBookings.isEmpty) {
        await prefs.remove(key);
      } else {
        final jsonData = _draftBookings.map((b) => b.toMap()).toList();
        await prefs.setString(key, jsonEncode(jsonData));
      }

      notifyListeners();
    } catch (e) {
      AppLogger.e('Error removing draft booking: $e');
    }
  }

  /// Reset form to initial state
  void resetForm() {
    _state = BookingFormState();
    _clearError();
    notifyListeners();
  }

  /// Load existing booking for editing
  void loadBookingForEdit(BookingModel booking) {
    _state = _state.copyWith(
      climbType: booking.trekType.toLowerCase(),
      hometown: booking.hometown,
      contactNumber: booking.phoneNumber,
      affiliation: booking.affiliation,
      primaryContactCategory: booking.members.isNotEmpty
          ? booking.members[0].category
          : 'student',
      selectedDate: booking.trekDate.toDate(),
      bookingMembers: booking.members,
      pickedFiles: [],
      memberDocuments: {}, // Clear member documents when loading for edit
    );
    _clearError();
    notifyListeners();
  }

  /// Create a booking model from current state
  BookingModel createBookingFromState() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return BookingModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: currentUser?.uid ?? '',
      status: 'draft',
      submissionStatus: 'draft',
      affiliation: _state.affiliation,
      phoneNumber: _state.contactNumber,
      hometown: _state.hometown,
      trekType: _state.climbType.toLowerCase(),
      trekDate: Timestamp.fromDate(_state.selectedDate ?? DateTime.now()),
      members: _state.bookingMembers,
      attachments: [],
      adminNotes: '',
      createdAt: Timestamp.now(),
    );
  }

  // Private helper methods

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _updateEstimatedPrice() {
    // This will be called when members or category changes
    // Integration with PricingService happens at UI level
    notifyListeners();
  }
}
