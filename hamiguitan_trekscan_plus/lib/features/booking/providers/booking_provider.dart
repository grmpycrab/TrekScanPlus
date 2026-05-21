// ignore_for_file: unintended_html_in_doc_comment

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../../models/booking_model.dart';
import '../../../models/member.dart';
import '../../../core/services/user_service.dart';
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
  // Store file metadata for draft bookings: bookingId -> memberIndex -> documentFieldName -> file metadata
  Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>
  _draftBookingMetadata = {};

  // Getters
  BookingFormState get state => _state;
  List<BookingModel> get draftBookings => _draftBookings;

  /// Returns only archived draft bookings (for the Archived Bookings screen)
  List<BookingModel> get archivedDraftBookings =>
      _allDraftBookings.where((b) => b.isArchived).toList();

  List<BookingModel> _allDraftBookings = [];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPrimaryContactInitialized => _isPrimaryContactInitialized;

  /// Get file metadata for a specific draft booking
  Map<String, Map<String, List<Map<String, dynamic>>>> getDraftBookingMetadata(
    String bookingId,
  ) {
    return _draftBookingMetadata[bookingId] ?? {};
  }

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
  /// Also stores metadata for persistence across sessions
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

    // Also store file metadata for persistence
    final updatedMetadata =
        Map<String, Map<String, List<Map<String, dynamic>>>>.from(
          _state.memberDocumentMetadata,
        );
    final memberMetadata = Map<String, List<Map<String, dynamic>>>.from(
      updatedMetadata[memberKey] ?? {},
    );
    memberMetadata[documentFieldName] = files
        .map(
          (f) => {
            'name': f.name,
            'size': f.size,
            'path': f.path,
            'extension': f.extension,
          },
        )
        .toList();
    updatedMetadata[memberKey] = memberMetadata;

    _state = _state.copyWith(
      memberDocuments: updatedMemberDocuments,
      memberDocumentMetadata: updatedMetadata,
    );
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
    final updatedMetadata =
        Map<String, Map<String, List<Map<String, dynamic>>>>.from(
          _state.memberDocumentMetadata,
        );
    final memberKey = memberIndex.toString();
    final memberDocs = updatedMemberDocuments[memberKey];

    if (memberDocs != null && memberDocs.containsKey(documentFieldName)) {
      final docFiles = List<PlatformFile>.from(memberDocs[documentFieldName]!);
      docFiles.remove(file);

      if (docFiles.isEmpty) {
        memberDocs.remove(documentFieldName);
        updatedMetadata[memberKey]?.remove(documentFieldName);
        if (memberDocs.isEmpty) {
          updatedMemberDocuments.remove(memberKey);
          updatedMetadata.remove(memberKey);
        }
      } else {
        memberDocs[documentFieldName] = docFiles;
        // Update metadata to match
        final memberMetadata = Map<String, List<Map<String, dynamic>>>.from(
          updatedMetadata[memberKey] ?? {},
        );
        memberMetadata[documentFieldName] = docFiles
            .map(
              (f) => {
                'name': f.name,
                'size': f.size,
                'path': f.path,
                'extension': f.extension,
              },
            )
            .toList();
        updatedMetadata[memberKey] = memberMetadata;
      }

      _state = _state.copyWith(
        memberDocuments: updatedMemberDocuments,
        memberDocumentMetadata: updatedMetadata,
      );
      notifyListeners();
    }
  }

  /// Clear all member documents
  void clearMemberDocuments() {
    _state = _state.copyWith(memberDocuments: {}, memberDocumentMetadata: {});
    notifyListeners();
  }

  /// Add a new member to booking
  void addMember(Member member) {
    final updated = [..._state.bookingMembers, member];
    _state = _state.copyWith(bookingMembers: updated);
    _updateEstimatedPrice();
    notifyListeners();
  }

  /// Remove a member by index, shifting document-map keys for members that
  /// followed the removed one so indices stay consistent with the member list.
  void removeMember(int index) {
    if (index < 0 || index >= _state.bookingMembers.length) return;

    final updatedMembers = List<Member>.from(_state.bookingMembers)
      ..removeAt(index);

    // Re-index both document maps: drop the removed entry, shift keys > index.
    Map<String, V> reindex<V>(Map<String, V> source) {
      final result = <String, V>{};
      for (final entry in source.entries) {
        final key = int.tryParse(entry.key);
        if (key == null || key == index) continue;
        result[(key > index ? key - 1 : key).toString()] = entry.value;
      }
      return result;
    }

    _state = _state.copyWith(
      bookingMembers: updatedMembers,
      memberDocuments: reindex(_state.memberDocuments),
      memberDocumentMetadata: reindex(_state.memberDocumentMetadata),
    );
    _updateEstimatedPrice();
    notifyListeners();
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
        _setLoading(false);
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
      _clearError();
    } catch (e) {
      _setError('Failed to initialize primary contact: $e');
      AppLogger.e('Error initializing primary contact: $e');
    } finally {
      _setLoading(false);
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
  /// Also loads previously selected file metadata
  Future<void> loadDraftBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final key = 'draft_bookings_${currentUser.uid}';
      final metadataKey = 'draft_bookings_metadata_${currentUser.uid}';
      final jsonString = prefs.getString(key);
      final metadataJsonString = prefs.getString(metadataKey);

      // Load metadata with proper type reconstruction
      if (metadataJsonString != null && metadataJsonString.isNotEmpty) {
        try {
          final metadataJson = jsonDecode(metadataJsonString) as Map;
          _draftBookingMetadata = {};

          // Properly reconstruct nested map structure from JSON
          metadataJson.forEach((bookingId, memberDocsJson) {
            if (memberDocsJson is Map) {
              final memberDocs =
                  <String, Map<String, List<Map<String, dynamic>>>>{};
              memberDocsJson.forEach((memberIndex, docFieldsJson) {
                if (docFieldsJson is Map) {
                  final docFields = <String, List<Map<String, dynamic>>>{};
                  docFieldsJson.forEach((docFieldName, filesJson) {
                    if (filesJson is List) {
                      docFields[docFieldName] = filesJson
                          .cast<Map<String, dynamic>>()
                          .toList();
                    }
                  });
                  memberDocs[memberIndex] = docFields;
                }
              });
              _draftBookingMetadata[bookingId as String] = memberDocs;
            }
          });
        } catch (e) {
          AppLogger.e('Error loading draft booking metadata: $e');
        }
      }

      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonData = jsonDecode(jsonString) as List;
        _draftBookings = jsonData.map((item) {
          final map = item as Map<String, dynamic>;

          // Convert ISO date strings back to Timestamp objects
          if (map['trekDate'] is String) {
            try {
              map['trekDate'] = Timestamp.fromDate(
                DateTime.parse(map['trekDate']),
              );
            } catch (e) {
              AppLogger.e('Error parsing trekDate: $e');
            }
          }
          if (map['createdAt'] is String) {
            try {
              map['createdAt'] = Timestamp.fromDate(
                DateTime.parse(map['createdAt']),
              );
            } catch (e) {
              AppLogger.e('Error parsing createdAt: $e');
            }
          }

          // Convert member timestamps
          if (map['members'] is List) {
            map['members'] = (map['members'] as List).map((member) {
              if (member is Map<String, dynamic>) {
                if (member['createdAt'] is String) {
                  try {
                    member['createdAt'] = Timestamp.fromDate(
                      DateTime.parse(member['createdAt']),
                    );
                  } catch (e) {
                    AppLogger.e('Error parsing member createdAt: $e');
                  }
                }
                if (member['updatedAt'] is String) {
                  try {
                    member['updatedAt'] = Timestamp.fromDate(
                      DateTime.parse(member['updatedAt']),
                    );
                  } catch (e) {
                    AppLogger.e('Error parsing member updatedAt: $e');
                  }
                }
              }
              return member;
            }).toList();
          }

          return BookingModel.fromJson(map);
        }).toList();
        // Exclude archived drafts from the active list
        _draftBookings = _draftBookings.where((b) => !b.isArchived).toList();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('Error loading draft bookings: $e');
    }
  }

  /// Load all drafts including archived ones (for the Archived Bookings screen)
  Future<void> loadAllDraftBookings() async {
    await loadDraftBookings();
    _allDraftBookings = List.from(_draftBookings);
    // Also load archived ones from persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final key = 'draft_bookings_${currentUser.uid}';
      final jsonString = prefs.getString(key);
      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonData = jsonDecode(jsonString) as List;
        final all = jsonData.map((item) {
          final map = item as Map<String, dynamic>;
          if (map['trekDate'] is String) {
            map['trekDate'] = Timestamp.fromDate(
              DateTime.parse(map['trekDate']),
            );
          }
          if (map['createdAt'] is String) {
            map['createdAt'] = Timestamp.fromDate(
              DateTime.parse(map['createdAt']),
            );
          }
          return BookingModel.fromJson(map);
        }).toList();
        _allDraftBookings = all;
      }
    } catch (e) {
      AppLogger.e('Error loading all draft bookings: $e');
    }
  }

  /// Save draft bookings to local storage
  /// Also saves file metadata so user can see previously selected files
  Future<void> saveDraftBooking(BookingModel booking) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      _draftBookings.add(booking);
      _draftBookingMetadata[booking.id] = _state.memberDocumentMetadata;
      await _persistDraftState(currentUser.uid);
      notifyListeners();
    } catch (e) {
      AppLogger.e('Error saving draft booking: $e');
      _setError('Failed to save draft booking');
    }
  }

  /// Update an existing draft booking in local storage
  Future<void> updateDraftBooking(BookingModel updatedBooking) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final index = _draftBookings.indexWhere((b) => b.id == updatedBooking.id);
      if (index >= 0) {
        _draftBookings[index] = updatedBooking;
      } else {
        _draftBookings.add(updatedBooking);
      }

      _draftBookingMetadata[updatedBooking.id] = _state.memberDocumentMetadata;
      await _persistDraftState(currentUser.uid);
      notifyListeners();
    } catch (e) {
      AppLogger.e('Error updating draft booking: $e');
    }
  }

  /// Remove draft booking
  Future<void> removeDraftBooking(String bookingId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      _draftBookings.removeWhere((b) => b.id == bookingId);
      _draftBookingMetadata.remove(bookingId);

      if (_draftBookings.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('draft_bookings_${currentUser.uid}');
        await prefs.remove('draft_bookings_metadata_${currentUser.uid}');
      } else {
        await _persistDraftState(currentUser.uid);
      }

      notifyListeners();
    } catch (e) {
      AppLogger.e('Error removing draft booking: $e');
    }
  }

  /// Archive a local draft booking (mark isArchived = true, persist)
  Future<void> archiveDraftBooking(String bookingId) async {
    await updateDraftBooking(
      _draftBookings
          .firstWhere((b) => b.id == bookingId)
          .copyWith(isArchived: true),
    );
  }

  /// Reset form to initial state
  void resetForm() {
    _state = BookingFormState();
    _clearError();
    notifyListeners();
  }

  /// Load existing booking for editing
  /// Preserves file metadata so user can see previously selected files
  void loadBookingForEdit(
    BookingModel booking, [
    Map<String, Map<String, List<Map<String, dynamic>>>>? savedMetadata,
  ]) {
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
      // Preserve existing in-memory files so they survive Edit→Submit flow.
      // Only clear memberDocuments if there are no current files already loaded.
      memberDocuments: _state.memberDocuments.isNotEmpty
          ? _state.memberDocuments
          : {},
      memberDocumentMetadata:
          savedMetadata ??
          {}, // Preserve metadata to show user which files were selected
    );
    _clearError();
    notifyListeners();
  }

  /// Create a booking model from current state
  BookingModel createBookingFromState() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return BookingModel(
      id: const Uuid().v4(),
      userId: currentUser?.uid ?? '',
      status: 'draft',
      submissionStatus: 'draft',
      affiliation: _state.affiliation,
      phoneNumber: _state.contactNumber,
      hometown: _state.hometown,
      trekType: _state.climbType.toLowerCase(),
      trekDate: Timestamp.fromDate(_state.selectedDate ?? DateTime.now()),
      notes: _state.notes,
      members: _state.bookingMembers,
      attachments: [],
      adminNotes: '',
      createdAt: Timestamp.now(),
    );
  }

  // Private helper methods

  /// Serializes a single [BookingModel] map so all [Timestamp] fields are
  /// converted to ISO-8601 strings, making the result safe for JSON encoding.
  Map<String, dynamic> _serializeBookingToJsonMap(BookingModel booking) {
    final map = booking.toMap();

    void convertTimestamp(Map<String, dynamic> m, String key) {
      if (m[key] is Timestamp) {
        m[key] = (m[key] as Timestamp).toDate().toIso8601String();
      }
    }

    convertTimestamp(map, 'trekDate');
    convertTimestamp(map, 'createdAt');
    convertTimestamp(map, 'updatedAt');

    if (map['members'] is List) {
      map['members'] = (map['members'] as List).map((member) {
        if (member is Map<String, dynamic>) {
          convertTimestamp(member, 'createdAt');
          convertTimestamp(member, 'updatedAt');
        }
        return member;
      }).toList();
    }

    return map;
  }

  /// Persists the current [_draftBookings] list and [_draftBookingMetadata]
  /// to [SharedPreferences] for the given [userId].
  Future<void> _persistDraftState(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = _draftBookings
        .map(_serializeBookingToJsonMap)
        .toList();
    await prefs.setString(
      'draft_bookings_$userId',
      jsonEncode(jsonData),
    );
    await prefs.setString(
      'draft_bookings_metadata_$userId',
      jsonEncode(_draftBookingMetadata),
    );
  }

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
