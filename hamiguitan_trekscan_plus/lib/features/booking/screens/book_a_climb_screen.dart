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
import '../../../components/climb_card.dart';
import '../../../components/app_dialogue_handler.dart';
import '../../../theme/color.dart';
import '../../../utils/app_logger.dart';
import '../providers/booking_provider.dart';
import '../widgets/trek_type_selector.dart';
import '../widgets/trek_date_picker.dart';
import '../widgets/category_selector.dart';
import '../widgets/document_upload_widget.dart';
import '../widgets/trekker_card.dart';
import '../services/date_validation_service.dart';
import '../models/document_requirements.dart';

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

    // If a date was selected from the home calendar, pre-fill it and auto-show form
    if (widget.selectedDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bookingProvider.setTrekDate(widget.selectedDate!);
        if (widget.autoShowBookingForm && mounted) {
          _showBookingForm();
          // Notify parent that form was shown
          widget.onFormShown?.call();
        }
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
          // Get fresh drafts from provider (already loaded)
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
    return ChangeNotifierProvider<BookingProvider>.value(
      value: _bookingProvider,
      child: Scaffold(
        backgroundColor: SharedColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'Book a Climb',
            style: TextStyle(
              color: SharedColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list, color: SharedColors.white),
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
                color: SharedColors.white,
                child: TabBar(
                  labelColor: AppColors.text,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.accent,
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
          backgroundColor: AppColors.primary,
          onPressed: _showBookingForm,
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
                  const Text(
                    'Tap the + button to create a booking',
                    style: TextStyle(color: Colors.grey),
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

  /// Show booking form in modal
  void _showBookingForm() {
    // Show modal immediately without blocking - improves perceived performance
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
        onDraftSaved: _handleDraftSaved,
      ),
    );

    // Initialize in background if needed (non-blocking)
    if (!_bookingProvider.isPrimaryContactInitialized) {
      _bookingProvider.initializePrimaryContact().then((_) {
        if (mounted) {
          _updateContactFromProvider();
        }
      });
    } else {
      _updateContactFromProvider();
    }
  }

  /// Handle draft saved - show feedback and refresh display
  void _handleDraftSaved() {
    if (!mounted) return;
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Booking saved as draft!'),
        backgroundColor: AppColors.statusApproved,
        duration: const Duration(seconds: 2),
      ),
    );
    // Refresh the bookings list to show draft
    _refreshBookingsWithDrafts();
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
              backgroundColor: AppColors.textSecondary,
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
      await BookingService.instance.createBooking(submittedBooking);
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
            content: const Text('Booking submitted successfully!'),
            backgroundColor: AppColors.statusApproved,
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
    }
  }

  /// Show edit booking sheet
  void _showEditBookingSheet(BookingModel booking) {
    _bookingProvider.loadBookingForEdit(booking);
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

      // Update the booking in Firestore
      await BookingService.instance.updateBooking(
        updatedBooking.id,
        affiliation: updatedBooking.affiliation,
        trekType: updatedBooking.trekType,
        hometown: updatedBooking.hometown,
        phoneNumber: updatedBooking.phoneNumber,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close form modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking updated successfully!'),
            backgroundColor: AppColors.statusApproved,
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
          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: const BoxDecoration(
              color: SharedColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                          ),
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
                      totalMembers: state.bookingMembers.length > 0
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
                    ...state.bookingMembers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final member = entry.value;
                      return _buildTrekkerFileUploadSection(
                        context,
                        index,
                        member,
                        provider,
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
                        onEdit: () {},
                        onRemove: () => provider.removeMember(index),
                      );
                    }),
                    const SizedBox(height: 12),
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
                        provider.addMember(newMember);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Member'),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
                          color: Colors.white,
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

    BookingProvider provider,
  ) {
    final docRequirements = DocumentRequirements.getDocumentsForCategory(
      member.category,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderBlack26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          title: Text(
            '${member.firstName} ${member.lastName} - ${member.category.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _getFileRequirmentsForCategory(member.category),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DocumentUploadWidget(
                              pickedFiles: docFiles,
                              onPickFiles: () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      allowMultiple: true,
                                      type: FileType.custom,
                                      allowedExtensions: docField.extension,
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
                        style: TextStyle(color: AppColors.textSecondary),
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
