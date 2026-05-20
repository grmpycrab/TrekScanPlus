// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

import '../../../models/booking_model.dart';
import '../../../models/member.dart';
import '../../../models/climb.dart';
import '../../../services/booking_service.dart';
import '../widgets/climb_card.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../providers/booking_provider.dart';
import '../widgets/trek_type_selector.dart';
import '../widgets/trek_date_picker.dart';
import '../widgets/category_selector.dart';
import '../widgets/document_upload_widget.dart';
import '../widgets/trekker_card.dart';
import '../widgets/member_edit_dialog.dart';
import '../services/date_validation_service.dart';
import '../models/document_requirements.dart';
import 'group_booking_entry_screen.dart';

/// Refactored main booking screen
/// Uses provider for state management and extracted widgets
class BookAClimbScreenRefactored extends StatefulWidget {
  final String? highlightBookingId;
  final DateTime? selectedDate;
  final bool autoShowBookingForm;
  final VoidCallback? onFormShown;

  const BookAClimbScreenRefactored({
    super.key,
    this.highlightBookingId,
    this.selectedDate,
    this.autoShowBookingForm = false,
    this.onFormShown,
  });

  @override
  State<BookAClimbScreenRefactored> createState() =>
      _BookAClimbScreenRefactoredState();
}

class _BookAClimbScreenRefactoredState
    extends State<BookAClimbScreenRefactored> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _affiliationController = TextEditingController();

  late BookingProvider _bookingProvider;
  late DateValidationService _dateValidationService;

  StreamSubscription<List<BookingModel>>? _bookingSub;
  StreamSubscription<User?>? _authSub;

  List<dynamic> _bookings = [];
  String _selectedStatusFilter = 'All';
  final String _selectedTypeFilter = 'All';
  bool _hasScrolledToBooking = false;

  @override
  void initState() {
    super.initState();
    _bookingProvider = BookingProvider();
    _dateValidationService = DateValidationService();
    _initializeProvider();
    _setupAuthListener();

    // If a date was selected from the home calendar, open the group booking entry
    if (widget.selectedDate != null && widget.autoShowBookingForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onFormShown?.call();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GroupBookingEntryScreen()),
        );
      });
    }
  }

  /// Initialize booking provider with user data
  Future<void> _initializeProvider() async {
    await _bookingProvider.prefillContactNumber();
    await _bookingProvider.initializePrimaryContact();
    await _bookingProvider.loadDraftBookings();
    _updateContactFromProvider();
  }

  /// Update text controllers from provider
  void _updateContactFromProvider() {
    _contactController.text = _bookingProvider.state.contactNumber;
    _affiliationController.text = _bookingProvider.state.affiliation;
  }

  /// Setup Firebase auth state listener
  void _setupAuthListener() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _bookingSub?.cancel();
      if (user == null) {
        setState(() => _bookings = []);
        return;
      }
      // Always load drafts when auth state changes or user logs in
      _loadDraftBookings();
      _subscribeToUserBookings(user.uid);
    });
  }

  /// Load draft bookings from provider
  Future<void> _loadDraftBookings() async {
    await _bookingProvider.loadDraftBookings();
    // Update UI with drafts immediately
    if (mounted) {
      setState(() {
        final draftBookings = _mapDraftBookingsToDisplay(
          _bookingProvider.draftBookings,
        );
        // Merge with existing Firebase bookings, keeping drafts
        _bookings = _bookings
            .where(
              (item) =>
                  (item is Map<String, dynamic> &&
                  ((item['isDraft'] as bool?) == false ||
                      (item['isDraft'] as bool?) == null)),
            )
            .toList();
        _bookings.addAll(draftBookings);
      });
    }
  }

  /// Subscribe to user's Firestore bookings
  void _subscribeToUserBookings(String userId) {
    // Drafts are already loaded via _loadDraftBookings() before this is called
    _bookingSub = BookingService.instance.streamBookingsForUser(userId).listen((
      bookings,
    ) {
      if (mounted) {
        setState(() {
          final firebaseBookings = _mapBookingsToDisplay(bookings);
          // Always reload fresh drafts from provider to ensure they're in sync
          final draftBookings = _mapDraftBookingsToDisplay(
            _bookingProvider.draftBookings,
          );
          // Combine Firebase bookings with drafts, avoiding duplicates
          _bookings = [...firebaseBookings, ...draftBookings];
        });
        _autoScrollIfNeeded();
      }
    });
  }

  /// Refresh bookings including drafts from provider
  void _refreshBookingsWithDrafts() {
    // Reload drafts fresh from provider (reads from SharedPreferences)
    _bookingProvider.loadDraftBookings().then((_) {
      if (mounted) {
        setState(() {
          final firebaseBookings = _bookings.where((item) {
            if (item is Map<String, dynamic>) {
              return (item['isDraft'] as bool?) == false ||
                  (item['isDraft'] as bool?) == null;
            }
            return false;
          }).toList();

          final draftBookings = _mapDraftBookingsToDisplay(
            _bookingProvider.draftBookings,
          );
          _bookings = [...firebaseBookings, ...draftBookings];
        });
      }
    });
  }

  /// Map draft BookingModel list to display format
  List<dynamic> _mapDraftBookingsToDisplay(List<BookingModel> drafts) {
    final user = FirebaseAuth.instance.currentUser;

    return drafts
        .map(
          (b) => {
            'climb': Climb(
              id: b.id,
              name: b.members.isNotEmpty
                  ? '${b.members[0].firstName} ${b.members[0].lastName}'
                  : user?.displayName ?? 'Draft',
              date: b.trekDate.toDate(),
              dateBooked: b.createdAt.toDate(),
              targetDate: b.trekDate.toDate(),
              dateApproved: b.updatedAt?.toDate(),
              type: b.trekType,
              status: 'draft',
              documents: b.attachments.map((a) => a.fileName).toList(),
              adminNotes: 'Draft booking - not yet submitted',
            ),
            'booking': b,
            'isDraft': true,
          },
        )
        .toList();
  }

  /// Map BookingModel list to display format
  List<dynamic> _mapBookingsToDisplay(List<BookingModel> bookings) {
    final user = FirebaseAuth.instance.currentUser;
    String userName = user?.displayName ?? 'You';

    return bookings
        .map(
          (b) => {
            'climb': Climb(
              id: b.id,
              name: userName,
              date: b.trekDate.toDate(),
              dateBooked: b.createdAt.toDate(),
              targetDate: b.trekDate.toDate(),
              dateApproved: b.updatedAt?.toDate(),
              type: b.trekType,
              status: b.status,
              documents: b.attachments.map((a) => a.fileName).toList(),
              adminNotes: b.adminNotes,
            ),
            'booking': b,
          },
        )
        .toList();
  }

  /// Auto-scroll to highlighted booking if needed
  void _autoScrollIfNeeded() {
    if (widget.highlightBookingId != null &&
        !_hasScrolledToBooking &&
        _bookings.isNotEmpty) {
      _scrollToBooking(widget.highlightBookingId!);
    }
  }

  /// Scroll to specific booking
  void _scrollToBooking(String bookingId) {
    _hasScrolledToBooking = true;
    final index = _bookings.indexWhere((item) {
      if (item is Map<String, dynamic>) {
        final booking = item['booking'] as BookingModel?;
        return booking?.id == bookingId;
      }
      return false;
    });

    if (index != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            index * 200.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChangeNotifierProvider<BookingProvider>.value(
      value: _bookingProvider,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'Book a Climb',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter bookings',
            ),
          ],
        ),
        body: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: colors.surface,
                child: TabBar(
                  labelColor: colors.text,
                  unselectedLabelColor: colors.textSecondary,
                  indicatorColor: colors.accent,
                  tabs: const [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Previous'),
                    Tab(text: 'All'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBookingsList(_filterBookings('upcoming')),
                    _buildBookingsList(_filterBookings('previous')),
                    _buildBookingsList(_filterBookings('all')),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: colors.primary,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GroupBookingEntryScreen()),
          ),
          child: const Icon(Icons.add, color: SharedColors.white),
        ),
      ),
    );
  }

  /// Filter bookings by type (upcoming, previous, or all)
  List<dynamic> _filterBookings(String type) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    List<dynamic> filtered;

    if (type == 'upcoming') {
      filtered = _bookings.where((item) {
        if (item is Map<String, dynamic>) {
          final climb = item['climb'] as Climb;
          return !climb.date.isBefore(today);
        }
        return false;
      }).toList();
    } else if (type == 'previous') {
      filtered = _bookings.where((item) {
        if (item is Map<String, dynamic>) {
          final climb = item['climb'] as Climb;
          return climb.date.isBefore(today);
        }
        return false;
      }).toList();
    } else {
      filtered = _bookings;
    }

    return _applyAdditionalFilters(filtered);
  }

  /// Apply status and type filters
  List<dynamic> _applyAdditionalFilters(List<dynamic> bookings) {
    return bookings.where((item) {
      if (item is Map<String, dynamic>) {
        final climb = item['climb'] as Climb;
        final booking = item['booking'] as BookingModel;

        if (_selectedStatusFilter != 'All' &&
            climb.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }

        if (_selectedTypeFilter != 'All' &&
            booking.trekType.toLowerCase() !=
                _selectedTypeFilter.toLowerCase()) {
          return false;
        }

        return true;
      }
      return false;
    }).toList();
  }

  /// Build bookings list view
  Widget _buildBookingsList(List<dynamic> bookings) {
    final colors = context.colors;
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshBookings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 240,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No bookings', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create a booking',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshBookings,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final item = bookings[index];
          if (item is Map<String, dynamic>) {
            final climb = item['climb'] as Climb;
            final booking = item['booking'] as BookingModel;
            final isDraft = (item['isDraft'] as bool?) ?? false;
            return ClimbCard(
              climb: climb,
              booking: booking,
              onCancel: isDraft ? _confirmCancelDraft : _confirmCancelBooking,
              onEditBooking: _showEditBookingSheet,
              onSubmitBooking: _submitDraftBooking,
              onArchive: isDraft
                  ? _confirmArchiveDraft
                  : _confirmArchiveBooking,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Refresh bookings from Firestore and load drafts
  Future<void> _refreshBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final bookings = await BookingService.instance
          .streamBookingsForUser(user.uid)
          .first;
      await _bookingProvider.loadDraftBookings();
      setState(() {
        final firebaseBookings = _mapBookingsToDisplay(bookings);
        final draftBookings = _mapDraftBookingsToDisplay(
          _bookingProvider.draftBookings,
        );
        _bookings = [...firebaseBookings, ...draftBookings];
      });
    } catch (e) {
      AppLogger.e('Error refreshing bookings: $e');
    }
  }

  /// Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter Bookings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedStatusFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'declined', child: Text('Declined')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatusFilter = value);
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Confirm and cancel booking
  Future<void> _confirmCancelBooking(Climb booking) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Cancel Booking',
      message: 'Are you sure you want to cancel this booking?',
      isDestructive: true,
    );

    if (confirmed == true && booking.id != null) {
      try {
        await BookingService.instance.cancelBooking(booking.id!);
      } catch (e) {
        AppLogger.e('Error cancelling booking: $e');
      }
    }
  }

  /// Confirm and delete draft booking
  Future<void> _confirmCancelDraft(Climb booking) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Delete Draft',
      message: 'Are you sure you want to delete this draft booking?',
      isDestructive: true,
    );

    if (confirmed == true && booking.id != null) {
      try {
        await _bookingProvider.removeDraftBooking(booking.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Draft deleted'),
              backgroundColor: context.colors.textSecondary,
            ),
          );
          setState(() {
            _bookings.removeWhere((item) {
              if (item is Map<String, dynamic>) {
                final b = item['booking'] as BookingModel?;
                return b?.id == booking.id;
              }
              return false;
            });
          });
        }
      } catch (e) {
        AppLogger.e('Error deleting draft: $e');
      }
    }
  }

  /// Archive a Firestore booking (hide from main list)
  Future<void> _confirmArchiveBooking(BookingModel booking) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Archive Booking',
      message:
          'This booking will be hidden from your main list. You can view it anytime in Settings → Archived Bookings.',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      try {
        await BookingService.instance.archiveBooking(booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Booking archived'),
              backgroundColor: context.colors.textSecondary,
            ),
          );
        }
      } catch (e) {
        AppLogger.e('Error archiving booking: $e');
      }
    }
  }

  /// Archive a local draft booking
  Future<void> _confirmArchiveDraft(BookingModel booking) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Archive Draft',
      message:
          'This draft will be hidden from your main list. You can view it in Settings → Archived Bookings.',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      try {
        await _bookingProvider.archiveDraftBooking(booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Draft archived'),
              backgroundColor: context.colors.textSecondary,
            ),
          );
          setState(() {
            _bookings.removeWhere((item) {
              if (item is Map<String, dynamic>) {
                final b = item['booking'] as BookingModel?;
                return b?.id == booking.id;
              }
              return false;
            });
          });
        }
      } catch (e) {
        AppLogger.e('Error archiving draft: $e');
      }
    }
  }

  /// Submit draft booking
  Future<void> _submitDraftBooking(BookingModel draft) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Submit Booking',
      message:
          'Are you sure you want to submit this booking? You won\'t be able to edit it after submission.',
    );

    if (confirmed != true) return;

    try {
      if (mounted) {
        AppDialogueHandler.showLoading(
          context: context,
          message: 'Submitting booking...',
        );
      }

      final submittedBooking = draft.copyWith(submissionStatus: 'submitted');

      // Create booking in Firestore first (to get the booking ID for file uploads)
      final firestoreBookingId = await BookingService.instance.createBooking(
        submittedBooking,
      );

      // Upload files if any exist for this draft — all in parallel
      final memberDocuments = _bookingProvider.state.memberDocuments;
      int uploadedCount = 0;
      int failedCount = 0;

      if (memberDocuments.isNotEmpty) {
        // Build (file, memberName) pairs so each upload knows which member it belongs to
        final allFilesWithMember = <(PlatformFile, String)>[
          for (final memberEntry in memberDocuments.entries)
            for (final files in memberEntry.value.values)
              for (final file in files)
                (
                  file,
                  () {
                    final idx = int.tryParse(memberEntry.key) ?? -1;
                    if (idx >= 0 && idx < draft.members.length) {
                      final m = draft.members[idx];
                      return '${m.firstName} ${m.lastName}'.trim();
                    }
                    return 'Member ${memberEntry.key}';
                  }(),
                ),
        ];

        // Upload all files concurrently
        final results = await Future.wait(
          allFilesWithMember.map(((PlatformFile, String) pair) async {
            final (file, memberName) = pair;
            try {
              await BookingService.instance.uploadAttachment(
                firestoreBookingId,
                file,
                memberName: memberName,
              );
              return true;
            } catch (e) {
              AppLogger.e('Error uploading file ${file.name}: $e');
              return false;
            }
          }),
        );

        uploadedCount = results.where((ok) => ok).length;
        failedCount = results.where((ok) => !ok).length;

        if (uploadedCount > 0) {
          AppLogger.i('Successfully uploaded $uploadedCount file(s)');
        }
      }

      // Remove from drafts after successful submission and upload
      await _bookingProvider.removeDraftBooking(draft.id);

      if (mounted) {
        Navigator.pop(context);
        // Remove from display
        setState(() {
          _bookings.removeWhere((item) {
            if (item is Map<String, dynamic>) {
              final b = item['booking'] as BookingModel?;
              return b?.id == draft.id;
            }
            return false;
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failedCount > 0
                  ? 'Booking submitted — $uploadedCount file(s) uploaded, $failedCount failed. Please re-attach failed files.'
                  : uploadedCount > 0
                  ? 'Booking submitted with $uploadedCount file(s)!'
                  : 'Booking submitted successfully!',
            ),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
            duration: Duration(seconds: failedCount > 0 ? 5 : 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      AppLogger.e('Error submitting draft booking: $e');
    }
  }

  /// Show edit booking sheet
  void _showEditBookingSheet(BookingModel booking) {
    final savedMetadata = _bookingProvider.getDraftBookingMetadata(booking.id);
    _bookingProvider.loadBookingForEdit(booking, savedMetadata);
    _updateContactFromProvider();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SharedColors.transparent,
      builder: (modalContext) => _BuildBookingFormModal(
        bookingProvider: _bookingProvider,
        contactController: _contactController,
        affiliationController: _affiliationController,
        formKey: _formKey,
        dateValidationService: _dateValidationService,
        isEditMode: true,
        existingBooking: booking,
        onEditComplete: _handleEditBookingComplete,
        onDraftSaved: null,
      ),
    );
  }

  /// Handle edit booking completion
  Future<void> _handleEditBookingComplete(BookingModel updatedBooking) async {
    try {
      if (mounted) {
        AppDialogueHandler.showLoading(
          context: context,
          message: 'Updating booking...',
        );
      }

      // Draft bookings are stored locally — update the draft instead of Firestore
      final isDraft =
          updatedBooking.id.startsWith('draft_') ||
          !RegExp(r'^[a-zA-Z0-9]{20}$').hasMatch(updatedBooking.id);

      if (isDraft) {
        // Update the local draft in SharedPreferences
        await _bookingProvider.updateDraftBooking(updatedBooking);

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          Navigator.pop(context); // Close form modal
          _refreshBookingsWithDrafts();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Draft updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Firestore booking: update fields + upload any newly added files
      await BookingService.instance.updateBooking(
        updatedBooking.id,
        affiliation: updatedBooking.affiliation,
        trekType: updatedBooking.trekType,
        hometown: updatedBooking.hometown,
        phoneNumber: updatedBooking.phoneNumber,
      );

      // Upload any new files that were added during editing
      final memberDocuments = _bookingProvider.state.memberDocuments;
      int uploadedCount = 0;

      if (memberDocuments.isNotEmpty) {
        final allFilesWithMember = <(PlatformFile, String)>[
          for (final memberEntry in memberDocuments.entries)
            for (final files in memberEntry.value.values)
              for (final file in files)
                (
                  file,
                  () {
                    final idx = int.tryParse(memberEntry.key) ?? -1;
                    if (idx >= 0 && idx < updatedBooking.members.length) {
                      final m = updatedBooking.members[idx];
                      return '${m.firstName} ${m.lastName}'.trim();
                    }
                    return 'Member ${memberEntry.key}';
                  }(),
                ),
        ];

        final results = await Future.wait(
          allFilesWithMember.map(((PlatformFile, String) pair) async {
            final (file, memberName) = pair;
            try {
              await BookingService.instance.uploadAttachment(
                updatedBooking.id,
                file,
                memberName: memberName,
              );
              return true;
            } catch (e) {
              AppLogger.e('Error uploading file ${file.name} during edit: $e');
              return false;
            }
          }),
        );

        uploadedCount = results.where((ok) => ok).length;
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close form modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadedCount > 0
                  ? 'Booking updated with $uploadedCount new file(s)!'
                  : 'Booking updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating booking: $e')));
      }
      AppLogger.e('Error updating booking: $e');
    }
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _authSub?.cancel();
    _contactController.dispose();
    _affiliationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Separate widget for booking form modal
class _BuildBookingFormModal extends StatefulWidget {
  final BookingProvider bookingProvider;
  final TextEditingController contactController;
  final TextEditingController affiliationController;
  final GlobalKey<FormState> formKey;
  final DateValidationService dateValidationService;
  final bool isEditMode;
  final BookingModel? existingBooking;
  final Function(BookingModel)? onEditComplete;
  final VoidCallback? onDraftSaved;

  const _BuildBookingFormModal({
    required this.bookingProvider,
    required this.contactController,
    required this.affiliationController,
    required this.formKey,
    required this.dateValidationService,
    this.isEditMode = false,
    this.existingBooking,
    this.onEditComplete,
    this.onDraftSaved,
  });

  @override
  State<_BuildBookingFormModal> createState() => _BuildBookingFormModalState();
}

class _BuildBookingFormModalState extends State<_BuildBookingFormModal> {
  final TextEditingController _hometownController = TextEditingController();
  late GlobalKey<FormState>
  _formKey; // Create unique form key per modal instance

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>(); // Initialize unique form key here
    // Initialize hometown controller with provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hometownController.text = widget.bookingProvider.state.hometown;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BookingProvider>.value(
      value: widget.bookingProvider,
      child: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          final state = provider.state;
          final colors = context.colors;
          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.isEditMode ? 'Edit Booking' : 'New Booking',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Trek Type Selector
                    TrekTypeSelector(
                      selectedType: state.climbType,
                      onChanged: provider.setClimbType,
                    ),
                    const SizedBox(height: 18),
                    // Trek Date Picker
                    TrekDatePicker(
                      selectedDate: state.selectedDate,
                      onDateSelected: provider.setTrekDate,
                      totalMembers: state.bookingMembers.isNotEmpty
                          ? state.bookingMembers.length
                          : 1,
                    ),
                    const SizedBox(height: 18),
                    // Home Address
                    TextFormField(
                      controller: _hometownController,
                      decoration: InputDecoration(
                        labelText: 'Home Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your home address';
                        }
                        return null;
                      },
                      onChanged: provider.setHometown,
                    ),
                    const SizedBox(height: 18),
                    // Category Selector
                    CategorySelector(
                      selectedCategory: state.primaryContactCategory,
                      onChanged: provider.setPrimaryContactCategory,
                    ),
                    const SizedBox(height: 24),
                    // Per-Trekker Document Upload
                    const Text(
                      'Trekker Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.bookingMembers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(12),
                          color: colors.background,
                        ),
                        child: Text(
                          'No trekkers added yet. Add members below to upload documents.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...state.bookingMembers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final member = entry.value;
                        return _buildTrekkerFileUploadSection(
                          context,
                          index,
                          member,
                          provider,
                          existingBooking: widget.existingBooking,
                        );
                      }),
                    const SizedBox(height: 24),
                    // Trekkers List
                    const Text(
                      'Trekkers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...state.bookingMembers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final member = entry.value;
                      return TrekkerCard(
                        member: member,
                        index: index,
                        isPrimary: member.isPrimaryContact,
                        onEdit: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => MemberEditDialog(
                              member: member,
                              memberIndex: index,
                              isPrimaryContact: member.isPrimaryContact,
                              onSave: (updatedMember) {
                                provider.updateMember(index, updatedMember);
                              },
                            ),
                          );
                        },
                        onRemove: () => provider.removeMember(index),
                      );
                    }),
                    const SizedBox(height: 12),
                    // Helper button to apply primary contact address to all members
                    if (state.bookingMembers.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextButton.icon(
                          onPressed: () {
                            provider.applyPrimaryAddressToAll();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Applied primary contact address to all members',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Use Same Address for All'),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final newMember = Member(
                          firstName: '',
                          lastName: '',
                          gender: 'male',
                          birthDate: '',
                          contactNumber: '',
                          nationality: '',
                          homeAddress: '',
                          category: 'student',
                          isPrimaryContact: false,
                          hasAccount: false,
                          createdAt: Timestamp.now(),
                        );
                        showDialog(
                          context: context,
                          builder: (dialogContext) => MemberEditDialog(
                            member: newMember,
                            memberIndex: provider.state.bookingMembers.length,
                            isPrimaryContact: false,
                            onSave: (savedMember) {
                              provider.addMember(savedMember);
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Member'),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // Validate trek date is selected
                          if (provider.state.selectedDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a trek date'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (widget.isEditMode &&
                              widget.existingBooking != null) {
                            // Update existing booking
                            final updatedBooking = widget.existingBooking!
                                .copyWith(
                                  trekType: provider.state.climbType,
                                  hometown: provider.state.hometown,
                                  phoneNumber: provider.state.contactNumber,
                                  affiliation: provider.state.affiliation,
                                  members: provider.state.bookingMembers,
                                  trekDate: Timestamp.fromDate(
                                    provider.state.selectedDate!,
                                  ),
                                  updatedAt: Timestamp.now(),
                                );
                            widget.onEditComplete?.call(updatedBooking);
                          } else {
                            // Create new draft booking
                            final booking = provider.createBookingFromState();
                            await provider.saveDraftBooking(booking);
                            if (mounted) {
                              Navigator.pop(context);
                              // Notify parent to show feedback and refresh
                              widget.onDraftSaved?.call();
                            }
                          }
                        }
                      },
                      child: Text(
                        widget.isEditMode ? 'Update Booking' : 'Save as Draft',
                        style: const TextStyle(
                          color: SharedColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _hometownController.dispose();
    super.dispose();
  }

  /// Get file requirements based on trekker category
  String _getFileRequirmentsForCategory(String category) {
    const requirements = {
      'student': 'Student ID/School Certificate required',
      'professional': 'Company ID/Employment Letter required',
      'retiree': 'Retirement Certificate/ID required',
      'person_with_disability': 'PWD ID/Medical Certificate required',
    };
    return requirements[category] ?? 'ID/Valid Document required';
  }

  /// Build file upload section for a single trekker
  Widget _buildTrekkerFileUploadSection(
    BuildContext context,
    int memberIndex,
    Member member,
    BookingProvider provider, {
    BookingModel? existingBooking,
  }) {
    final docRequirements = DocumentRequirements.getDocumentsForCategory(
      member.category,
    );
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          title: Text(
            '${member.firstName} ${member.lastName} - ${member.category.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _getFileRequirmentsForCategory(member.category),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show existing attachments if editing
                  if (existingBooking != null &&
                      existingBooking.attachments.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Previously Uploaded Files:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...existingBooking.attachments.map((attachment) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          attachment.fileName,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Add More Files (Optional):',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  // Show category-specific document uploads
                  if (docRequirements != null)
                    ...docRequirements.requiredDocs.map((docField) {
                      final docFiles = provider.getMemberDocumentFiles(
                        memberIndex,
                        docField.name,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              docField.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              docField.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DocumentUploadWidget(
                              pickedFiles: docFiles,
                              previouslySelectedFiles:
                                  provider
                                      .state
                                      .memberDocumentMetadata[memberIndex
                                      .toString()]?[docField.name],
                              onPickFiles: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  allowMultiple: true,
                                  type: FileType.custom,
                                  allowedExtensions: docField.extension,
                                  withData:
                                      true, // Load bytes into memory so files survive navigation
                                );
                                if (result != null && mounted) {
                                  provider.setMemberDocumentFiles(
                                    memberIndex,
                                    docField.name,
                                    result.files,
                                  );
                                }
                              },
                              onRemoveFile: (file) {
                                provider.removeMemberDocumentFile(
                                  memberIndex,
                                  docField.name,
                                  file,
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  if (docRequirements == null)
                    Center(
                      child: Text(
                        'No document requirements defined for ${member.category}',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
