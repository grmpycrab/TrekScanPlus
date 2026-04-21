import 'package:file_picker/file_picker.dart';
import '../../../models/member.dart';

/// Represents the complete state of a booking form
class BookingFormState {
  final String climbType;
  final String hometown;
  final String primaryContactCategory;
  final String contactNumber;
  final String affiliation;
  final DateTime? selectedDate;
  final List<Member> bookingMembers;
  final List<PlatformFile> pickedFiles;
  // Map structure: memberIndex -> documentFieldName -> List<PlatformFile>
  final Map<String, Map<String, List<PlatformFile>>> memberDocuments;
  // Store file metadata for persistence: memberIndex -> documentFieldName -> List<{name, size}>
  final Map<String, Map<String, List<Map<String, dynamic>>>>
  memberDocumentMetadata;
  final String? notes;

  BookingFormState({
    this.climbType = 'regular',
    this.hometown = '',
    this.primaryContactCategory = 'student',
    this.contactNumber = '',
    this.affiliation = '',
    this.selectedDate,
    this.bookingMembers = const [],
    this.pickedFiles = const [],
    this.memberDocuments = const {},
    this.memberDocumentMetadata = const {},
    this.notes,
  });

  /// Create a copy with selective updates
  BookingFormState copyWith({
    String? climbType,
    String? hometown,
    String? primaryContactCategory,
    String? contactNumber,
    String? affiliation,
    DateTime? selectedDate,
    List<Member>? bookingMembers,
    List<PlatformFile>? pickedFiles,
    Map<String, Map<String, List<PlatformFile>>>? memberDocuments,
    Map<String, Map<String, List<Map<String, dynamic>>>>?
    memberDocumentMetadata,
    String? notes,
  }) {
    return BookingFormState(
      climbType: climbType ?? this.climbType,
      hometown: hometown ?? this.hometown,
      primaryContactCategory:
          primaryContactCategory ?? this.primaryContactCategory,
      contactNumber: contactNumber ?? this.contactNumber,
      affiliation: affiliation ?? this.affiliation,
      selectedDate: selectedDate ?? this.selectedDate,
      bookingMembers: bookingMembers ?? this.bookingMembers,
      pickedFiles: pickedFiles ?? this.pickedFiles,
      memberDocuments: memberDocuments ?? this.memberDocuments,
      memberDocumentMetadata:
          memberDocumentMetadata ?? this.memberDocumentMetadata,
      notes: notes ?? this.notes,
    );
  }

  /// Reset to initial state
  BookingFormState reset() => BookingFormState();

  /// Check if primary contact member exists
  Member? get primaryContact =>
      bookingMembers.isNotEmpty && bookingMembers[0].isPrimaryContact
      ? bookingMembers[0]
      : null;

  /// Total estimated slots needed (only trekkers, not porters)
  int get totalSlotsNeeded => bookingMembers.length;
}
