// ignore_for_file: unnecessary_brace_in_string_interps
// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/booking_model.dart';
import '../../models/member.dart';
import '../../services/booking_service.dart';
import '../../services/calendar_config_service.dart';
import '../../services/validators.dart';
import '../../services/user_service.dart';
import '../../models/climb.dart';
import '../../features/booking/widgets/climb_card.dart';
import '../../components/member_form_card.dart';
import '../../components/app_dialogue_handler.dart';
import '../../theme/color.dart';
import '../../utils/app_logger.dart';

class BookAClimbScreen extends StatefulWidget {
  final String? highlightBookingId;
  final DateTime? selectedDate;
  final bool autoShowBookingForm;

  const BookAClimbScreen({
    super.key,
    this.highlightBookingId,
    this.selectedDate,
    this.autoShowBookingForm = false,
  });

  @override
  State<BookAClimbScreen> createState() => _BookAClimbScreenState();
}

class _BookAClimbScreenState extends State<BookAClimbScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  String _climbType = 'Regular Trek';
  String _hometown = '';
  String _primaryContactCategory = 'student';
  bool _hasScrolledToBooking = false;

  // Group members for booking
  List<Member> _bookingMembers = [];

  // Draft bookings (saved locally, not yet submitted)
  List<BookingModel> _draftBookings = [];

  // Filter states
  String _selectedStatusFilter = 'All';
  String _selectedTypeFilter = 'All';

  // Store picked PlatformFile objects so we can upload bytes/paths to Firebase
  List<PlatformFile> _pickedFiles = [];

  // Store setModalState to update UI when files are picked
  Function(VoidCallback)? _setModalState;

  // Bookings shown on main screen. This will be populated from Firestore
  // for the current authenticated user. Keep as dynamic to preserve
  // compatibility with the existing UI helper methods.
  List<dynamic> _bookings = [];

  StreamSubscription<List<BookingModel>>? _bookingSub;
  StreamSubscription<User?>? _authSub;

  // Controllers for text fields
  // Note: name/email are obtained from the authenticated user; do not request
  // them in the booking form per the solo-booking UX. Keep controllers for
  // affiliation only.
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _affiliationController = TextEditingController();
  DateTime? _selectedDate;
  bool _shouldShowBookingForm = false;

  @override
  void initState() {
    super.initState();
    // Set selected date if passed from calendar
    if (widget.selectedDate != null) {
      _selectedDate = widget.selectedDate;
      _shouldShowBookingForm = widget.autoShowBookingForm;
    }
    // Listen for auth state changes so we can (re)subscribe to bookings for
    // the signed-in user. This handles cases where the screen loads before
    // authentication completes.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      // cancel previous bookings subscription
      _bookingSub?.cancel();
      if (user == null) {
        setState(() => _bookings = []);
        return;
      }
      // Load draft bookings when user authenticates
      _loadDraftBookings();
      _bookingSub = BookingService.instance
          .streamBookingsForUser(user.uid)
          .listen((bookings) async {
            // Fetch user data to get firstName and lastName
            String userName = 'You';
            try {
              final userData = await UserService.instance.getUserOnce(user.uid);
              if (userData != null) {
                final firstName = userData['firstName'] as String? ?? '';
                final lastName = userData['lastName'] as String? ?? '';

                if (firstName.isNotEmpty && lastName.isNotEmpty) {
                  userName = '$firstName $lastName';
                } else if (firstName.isNotEmpty) {
                  userName = firstName;
                } else if (lastName.isNotEmpty) {
                  userName = lastName;
                } else {
                  // Fallback to displayName
                  userName = userData['displayName'] as String? ?? 'You';
                }
              }
            } catch (e) {
              // If we can't fetch from Firestore, use Firebase displayName
              userName = user.displayName ?? 'You';
            }

            setState(() {
              // Map BookingModel -> {climb, booking} for display
              _bookings = bookings
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
                        documents: b.attachments
                            .map((a) => a.fileName)
                            .toList(),
                        adminNotes: b.adminNotes,
                      ),
                      'booking': b,
                    },
                  )
                  .toList();
            });

            // Auto-scroll to highlighted booking
            if (widget.highlightBookingId != null &&
                !_hasScrolledToBooking &&
                bookings.isNotEmpty) {
              _scrollToBooking(widget.highlightBookingId!);
            }

            // Auto-show booking form if date was selected from calendar
            if (_shouldShowBookingForm && mounted) {
              _shouldShowBookingForm = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showBookingForm();
                }
              });
            }
          });
    });
  }

  String _formatSelectedDate() {
    if (_selectedDate == null) return 'Select date';
    return '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
  }

  /// Fetch and pre-fill phone number from user settings
  Future<void> _prefillPhoneNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userData = await UserService.instance.getUserOnce(user.uid);
      if (userData != null && _contactController.text.isEmpty) {
        final phoneNumber = userData['phoneNumber'] as String? ?? '';
        if (phoneNumber.isNotEmpty && mounted) {
          setState(() {
            _contactController.text = phoneNumber;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error prefilling phone number: $e');
    }
  }

  void _scrollToBooking(String bookingId) {
    _hasScrolledToBooking = true;

    // Find the index of the booking
    final index = _bookings.indexWhere((item) {
      if (item is Map<String, dynamic>) {
        final booking = item['booking'] as BookingModel?;
        return booking?.id == bookingId;
      }
      return false;
    });

    if (index != -1) {
      // Delay to ensure ListView is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final position = index * 200.0; // Approximate card height
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      _pickedFiles = result.files;
      // Update modal UI if modal is open, otherwise update widget state
      if (_setModalState != null) {
        _setModalState!(() {});
      } else {
        setState(() {});
      }
    }
  }

  /// Check if a date is within buffer period of existing bookings
  /// Returns the conflicting booking date if found, null otherwise
  Future<DateTime?> _checkBufferPeriod(DateTime date) async {
    try {
      // Check day before (26th conflicts with 27th)
      final dayBefore = date.subtract(const Duration(days: 1));
      final dayBeforeStart = DateTime(
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        0,
        0,
        0,
      );
      final dayBeforeEnd = DateTime(
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        23,
        59,
        59,
      );

      final beforeSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where(
            'trekDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayBeforeStart),
          )
          .where(
            'trekDate',
            isLessThanOrEqualTo: Timestamp.fromDate(dayBeforeEnd),
          )
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (beforeSnapshot.docs.isNotEmpty) {
        return dayBefore;
      }

      return null;
    } catch (e) {
      AppLogger.e('Error checking buffer period: $e');
      return null;
    }
  }

  /// Check if the selected date has available slots (max 30 slots per day)
  /// Returns a map with 'available' (bool) and 'slotsUsed' (int)
  Future<Map<String, dynamic>> _checkDateAvailability(
    DateTime date,
    int portersNeeded,
  ) async {
    try {
      // Get calendar configuration for this date
      final calendarService = CalendarConfigService();
      final dateConfig = await calendarService.getDateConfig(date);

      // Check if date is closed
      if (dateConfig.isClosed) {
        return {
          'available': false,
          'slotsUsed': 0,
          'slotsNeeded': 1, // Only count trekker, not porters
          'maxSlots': dateConfig.maxSlots,
          'remaining': 0,
          'isClosed': true,
          'closureReason': dateConfig.reason,
        };
      }

      // Check for trek down day (day after existing bookings)
      final conflictDate = await _checkBufferPeriod(date);
      if (conflictDate != null) {
        final conflictDateStr =
            '${conflictDate.year}-${conflictDate.month.toString().padLeft(2, '0')}-${conflictDate.day.toString().padLeft(2, '0')}';
        return {
          'available': false,
          'slotsUsed': 0,
          'slotsNeeded': 1, // Only count trekker, not porters
          'maxSlots': dateConfig.maxSlots,
          'remaining': 0,
          'isClosed': false,
          'isBufferDay': true,
          'conflictDate': conflictDateStr,
        };
      }

      // Use date-specific maxSlots from config
      final maxSlots = dateConfig.maxSlots;

      // Normalize date to start and end of day to catch all bookings for this date
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where(
            'trekDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('trekDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      // Calculate total slots used (only count approved bookings)
      // Pending bookings don't count until admin approves them
      // Note: Only count trekkers (users), not porters
      int slotsUsed = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String?)?.toLowerCase() ?? '';

        // Only count approved bookings - pending bookings don't reserve slots
        if (status == 'approved') {
          slotsUsed += 1; // 1 trekker per booking (porters excluded from count)
        }
      }

      // Calculate slots needed for this booking (only count the trekker)
      final slotsNeeded = 1;

      // Check if there's enough space
      final available = (slotsUsed + slotsNeeded) <= maxSlots;

      return {
        'available': available,
        'slotsUsed': slotsUsed,
        'slotsNeeded': slotsNeeded,
        'maxSlots': maxSlots,
        'remaining': maxSlots - slotsUsed,
        'isClosed': false,
      };
    } catch (e) {
      AppLogger.e('Error checking date availability: $e');
      // If error, allow booking (fail open)
      return {
        'available': true,
        'slotsUsed': 0,
        'slotsNeeded': 1, // Only count trekker, not porters
        'maxSlots': 30,
        'remaining': 30,
        'isClosed': false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SharedColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        // Prevent the automatic leading (back) button so the top-left
        // area no longer navigates back (avoids reported black-screen bug).
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: SharedColors.white,
              child: TabBar(
                labelColor: Color(0xFF37474F),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF455A64),
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
                  _buildBookingsList(_asClimbs()),
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
    );
  }

  List<dynamic> _filterBookings(String type) {
    // Combine submitted bookings and draft bookings
    List<dynamic> allBookings = List.from(_bookings);

    // Add draft bookings to the display list
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (final draft in _draftBookings) {
        String userName = user.displayName ?? 'You';
        allBookings.add({
          'climb': Climb(
            id: draft.id,
            name: userName,
            date: draft.trekDate.toDate(),
            dateBooked: draft.createdAt.toDate(),
            targetDate: draft.trekDate.toDate(),
            dateApproved: draft.updatedAt?.toDate(),
            type: draft.trekType,
            status: draft.status,
            documents: draft.attachments.map((a) => a.fileName).toList(),
            adminNotes: draft.adminNotes,
          ),
          'booking': draft,
        });
      }
    }

    // Filter by date type
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    List<dynamic> filteredList;

    if (type == 'upcoming') {
      filteredList = allBookings.where((item) {
        if (item is Map<String, dynamic> && item.containsKey('climb')) {
          final climb = item['climb'] as Climb;
          return !climb.date.isBefore(todayDate);
        }
        return false;
      }).toList();
    } else if (type == 'previous') {
      filteredList = allBookings.where((item) {
        if (item is Map<String, dynamic> && item.containsKey('climb')) {
          final climb = item['climb'] as Climb;
          return climb.date.isBefore(todayDate);
        }
        return false;
      }).toList();
    } else {
      filteredList = allBookings;
    }

    // Apply additional filters
    return _applyFilters(filteredList);
  }

  List<dynamic> _applyFilters(List<dynamic> bookings) {
    return bookings.where((item) {
      if (item is Map<String, dynamic> && item.containsKey('climb')) {
        final climb = item['climb'] as Climb;
        final booking = item['booking'] as BookingModel;

        // Status filter
        if (_selectedStatusFilter != 'All') {
          final status = climb.status.toLowerCase();
          final filterStatus = _selectedStatusFilter.toLowerCase();
          if (status != filterStatus) return false;
        }

        // Type filter
        if (_selectedTypeFilter != 'All') {
          final trekType = booking.trekType.toLowerCase();
          final filterType = _selectedTypeFilter.toLowerCase();
          if (trekType != filterType) return false;
        }

        return true;
      }
      return false;
    }).toList();
  }

  Widget _buildBookingsList(List<dynamic> bookings) {
    // Wrap lists in a RefreshIndicator so user can pull-to-refresh bookings
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
                  Text(
                    'No bookings',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
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
            final bookingModel = item['booking'] as BookingModel;
            return ClimbCard(
              climb: climb,
              booking: bookingModel,
              onCancel: (c) => _confirmCancelModel(c),
              onEditBooking: (b) => _showEditBookingSheet(b),
              onSubmitBooking: _submitDraftBooking,
            );
          }
          // Fallback
          return ClimbCard(
            climb: Climb(name: '', date: DateTime(1970)),
            onCancel: (c) => _confirmCancelModel(c),
          );
        },
      ),
    );
  }

  /// Submit a draft booking to Firebase
  Future<void> _submitDraftBooking(BookingModel draft) async {
    try {
      // Show confirmation dialog
      final confirmed = await AppDialogueHandler.showConfirmation(
        context: context,
        title: 'Submit Booking',
        message:
            'Are you sure you want to submit this booking? You won\'t be able to edit it after submission.',
      );

      if (confirmed != true) return;

      // Show loading dialog
      if (mounted) {
        AppDialogueHandler.showLoading(
          context: context,
          message: 'Submitting booking...',
        );
      }

      // Update submission status to 'submitted'
      final submittedBooking = draft.copyWith(submissionStatus: 'submitted');

      // Create booking in Firestore
      final bookingService = BookingService.instance;
      await bookingService.createBooking(submittedBooking);

      // Remove from draft list
      if (mounted) {
        setState(() {
          _draftBookings.removeWhere((b) => b.id == draft.id);
        });
        // Save updated drafts to persistent storage
        await _saveDraftBookings();
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking submitted successfully! Please wait for confirmation.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Load draft bookings from SharedPreferences
  Future<void> _loadDraftBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get draft bookings for current user
      final key = 'draft_bookings_${currentUser.uid}';
      final jsonString = prefs.getString(key);

      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonData = jsonDecode(jsonString) as List;
        final drafts = jsonData
            .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _draftBookings = drafts;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error loading draft bookings: $e');
    }
  }

  /// Save draft bookings to SharedPreferences
  Future<void> _saveDraftBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final key = 'draft_bookings_${currentUser.uid}';

      if (_draftBookings.isEmpty) {
        // Clear if no drafts
        await prefs.remove(key);
      } else {
        // Convert to JSON and save
        final jsonData = _draftBookings.map((b) => b.toMap()).toList();
        await prefs.setString(key, jsonEncode(jsonData));
      }
    } catch (e) {
      AppLogger.e('Error saving draft bookings: $e');
    }
  }

  Future<void> _refreshBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Get user's first and last name for display
      String userName = await _getUserDisplayName(user.uid);

      // Cancel current subscription and clear local state first
      _bookingSub?.cancel();
      setState(() => _bookings = []);

      // Fetch fresh data from Firestore
      final bookings = await BookingService.instance
          .streamBookingsForUser(user.uid)
          .first;

      if (!mounted) return;
      setState(() {
        _bookings = bookings
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
      });

      // Re-subscribe to live updates
      if (mounted && user == FirebaseAuth.instance.currentUser) {
        _bookingSub = BookingService.instance
            .streamBookingsForUser(user.uid)
            .listen((bookings) {
              if (mounted) {
                setState(() {
                  _bookings = bookings
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
                            documents: b.attachments
                                .map((a) => a.fileName)
                                .toList(),
                            adminNotes: b.adminNotes,
                          ),
                          'booking': b,
                        },
                      )
                      .toList();
                });
              }
            });
      }
    } catch (e) {
      AppLogger.e('Error refreshing bookings: $e');
    }
  }

  /// Get the user's display name from Firestore (firstName lastName or displayName)
  Future<String> _getUserDisplayName(String userId) async {
    try {
      final userData = await UserService.instance.getUserOnce(userId);
      if (userData != null) {
        final firstName = userData['firstName'] as String? ?? '';
        final lastName = userData['lastName'] as String? ?? '';

        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          return '$firstName $lastName';
        } else if (firstName.isNotEmpty) {
          return firstName;
        } else if (lastName.isNotEmpty) {
          return lastName;
        } else {
          // Fallback to displayName
          return userData['displayName'] as String? ?? 'You';
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching user display name: $e');
    }

    // Final fallback to Firebase displayName
    return FirebaseAuth.instance.currentUser?.displayName ?? 'You';
  }

  // Convert internal _bookings (dynamic) to a list of Climb objects.
  List<Climb> _asClimbs() {
    final List<Climb> list = [];
    for (var e in _bookings) {
      if (e is Map<String, dynamic> && e.containsKey('climb')) {
        list.add(e['climb'] as Climb);
      } else if (e is Climb) {
        list.add(e);
      } else {
        list.add(Climb(name: '', date: DateTime(1970)));
      }
    }
    return list;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Filter Bookings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
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
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'declined', child: Text('Declined')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(
                  value: 'changes required',
                  child: Text('Changes Required'),
                ),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStatusFilter = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Trek Type',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTypeFilter,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Types')),
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'research', child: Text('Research')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTypeFilter = value;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatusFilter = 'All';
                _selectedTypeFilter = 'All';
              });
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Apply',
              style: TextStyle(color: SharedColors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancelModel(Climb booking) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Cancel Booking',
      message: 'Are you sure you want to cancel this booking?',
      confirmText: 'Yes',
      cancelText: 'No',
      isDestructive: true,
    );

    if (confirmed == true) {
      // If booking has an id, persist cancellation to Firestore.
      if (booking.id != null) {
        try {
          await BookingService.instance.cancelBooking(booking.id!);
          // Let the Firestore stream update the UI. Optionally
          // update local model immediately for snappy feedback.
          if (mounted) {
            setState(() {
              booking.status = 'Cancelled';
            });
          }
        } catch (e) {
          AppLogger.e('Error cancelling booking: $e');
          if (mounted) {
            await AppDialogueHandler.showError(
              context: context,
              title: 'Cancellation Failed',
              message: 'Unable to cancel booking. Please try again.',
            );
          }
        }
      } else {
        // No id (likely local-only); just update locally
        if (mounted) {
          setState(() => booking.status = 'Cancelled');
        }
      }
    }
  }

  void _showEditBookingSheet(BookingModel booking) {
    // Check if this is a draft booking
    final isDraft = booking.isDraft;

    // Hometown is now a text input, store as-is
    String hometownValue = booking.hometown;

    final formKey = GlobalKey<FormState>();
    final affiliationController = TextEditingController(
      text: booking.affiliation,
    );
    final phoneController = TextEditingController(text: booking.phoneNumber);
    final notesController = TextEditingController(text: booking.notes ?? '');
    final hometownController = TextEditingController(text: hometownValue);

    // Get primary contact's category
    String primaryContactCategory =
        booking.members.isNotEmpty && booking.members[0].isPrimaryContact
        ? booking.members[0].category
        : 'student';

    // Convert trek type from database format
    String trekTypeValue = booking.trekType;
    if (trekTypeValue == 'regular_trek' || trekTypeValue == 'regular trek') {
      trekTypeValue = 'Regular Trek';
    } else if (trekTypeValue == 'research_trek' ||
        trekTypeValue == 'research trek') {
      trekTypeValue = 'Research Trek';
    } else if (trekTypeValue == 'benchmarking_trek' ||
        trekTypeValue == 'benchmarking trek') {
      trekTypeValue = 'Benchmarking Trek';
    } else if (trekTypeValue == 'special_trek' ||
        trekTypeValue == 'special trek') {
      trekTypeValue = 'Special Trek';
    }

    // Ensure the value matches a dropdown option
    if (![
      'Regular Trek',
      'Research Trek',
      'Benchmarking Trek',
      'Special Trek',
    ].contains(trekTypeValue)) {
      trekTypeValue = 'Regular Trek'; // Default fallback
    }

    bool isSaving = false;

    // Check if this is a declined or changes required booking
    final isDeclined =
        booking.status.toLowerCase() == 'declined' ||
        booking.status.toLowerCase() == 'rejected' ||
        booking.status.toLowerCase() == 'changes required' ||
        booking.status.toLowerCase() == 'changes_required';

    // Track existing attachments (can be marked for deletion)
    List<Attachment> existingAttachments = List.from(booking.attachments);
    Set<String> attachmentsToDelete = {};

    // Track new files to upload
    List<PlatformFile> newFiles = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handlePickFiles() async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
                type: FileType.custom,
                allowedExtensions: ['docx', 'pdf', 'jpg', 'jpeg', 'png'],
              );
              if (result != null) {
                setModalState(() {
                  newFiles.addAll(result.files);
                });
              }
            }

            Future<void> handleSave() async {
              if (!formKey.currentState!.validate()) return;

              // Validate that at least one file exists (current or new)
              final remainingExistingFiles = existingAttachments
                  .where((a) => !attachmentsToDelete.contains(a.fileName))
                  .length;
              final totalFiles = remainingExistingFiles + newFiles.length;

              if (totalFiles == 0) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please keep at least one document or upload a new one.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => isSaving = true);

              try {
                if (isDraft) {
                  // Update draft booking locally
                  final updatedDraft = booking.copyWith(
                    affiliation: affiliationController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    trekType: trekTypeValue.toLowerCase(),
                    hometown: hometownValue,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );

                  // Update primary contact's category
                  if (updatedDraft.members.isNotEmpty) {
                    final updatedMembers = List<Member>.from(
                      updatedDraft.members,
                    );
                    updatedMembers[0] = updatedMembers[0].copyWith(
                      category: primaryContactCategory,
                    );
                    updatedDraft.members = updatedMembers;
                  }

                  // Update in draft list
                  final draftIndex = _draftBookings.indexWhere(
                    (b) => b == booking,
                  );
                  if (draftIndex != -1) {
                    setState(() {
                      _draftBookings[draftIndex] = updatedDraft;
                    });
                    // Save updated drafts to persistent storage
                    await _saveDraftBookings();
                  }

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Draft booking updated successfully.'),
                      ),
                    );
                  }
                } else {
                  // Update submitted booking in Firestore
                  await BookingService.instance.updateBooking(
                    booking.id,
                    affiliation: affiliationController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    trekType: trekTypeValue.toLowerCase(),
                    hometown: hometownValue,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    resubmitDeclined: isDeclined,
                  );

                  // Update primary contact's category if it changed
                  if (primaryContactCategory !=
                      (booking.members.isNotEmpty
                          ? booking.members[0].category
                          : 'student')) {
                    await BookingService.instance.updatePrimaryContactCategory(
                      booking.id,
                      primaryContactCategory,
                    );
                  }

                  // Delete removed attachments
                  for (final attachment in existingAttachments) {
                    if (attachmentsToDelete.contains(attachment.fileName)) {
                      try {
                        await BookingService.instance.deleteAttachment(
                          booking.id,
                          attachment,
                        );
                      } catch (e) {
                        AppLogger.e(
                          'Error deleting attachment ${attachment.fileName}: $e',
                        );
                        // Continue with other deletions
                      }
                    }
                  }

                  // Upload new files
                  for (final file in newFiles) {
                    try {
                      await BookingService.instance.uploadAttachment(
                        booking.id,
                        file,
                      );
                    } catch (e) {
                      if (kDebugMode) {
                        AppLogger.e('⚠️ Error uploading file ${file.name}');
                      }
                      // Continue with other uploads
                    }
                  }

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isDeclined
                              ? 'Booking updated and resubmitted for review!'
                              : 'Booking details updated.',
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  setModalState(() => isSaving = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to update booking: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: const BoxDecoration(
                  color: SharedColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Edit Booking Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Show warning for declined bookings
                      if (isDeclined && booking.adminNotes != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: booking.status.toLowerCase() == 'rejected'
                                ? Color(0xFFFFEBEE)
                                : Color(0xFFFFE0B2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: booking.status.toLowerCase() == 'rejected'
                                  ? Colors.red.shade300
                                  : Color(0xFFFFB74D),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                booking.status.toLowerCase() == 'rejected'
                                    ? Icons.cancel
                                    : Icons.info,
                                color:
                                    booking.status.toLowerCase() == 'rejected'
                                    ? Colors.red.shade700
                                    : Color(0xFFF57C00),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      booking.status.toLowerCase() == 'rejected'
                                          ? 'Booking Rejected'
                                          : 'Changes Required',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            booking.status.toLowerCase() ==
                                                'rejected'
                                            ? Colors.red.shade900
                                            : Color(0xFFBF360C),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Only show admin notes if status is NOT rejected
                                    if (booking.status.toLowerCase() !=
                                            'rejected' &&
                                        booking.adminNotes != null &&
                                        booking.adminNotes!.isNotEmpty) ...[
                                      Text(
                                        '${booking.adminNotes}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      booking.status.toLowerCase() == 'rejected'
                                          ? 'Your booking has been rejected. You can submit a new booking.'
                                          : 'Update your booking and save to resubmit for review.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color:
                                            booking.status.toLowerCase() ==
                                                'rejected'
                                            ? Colors.red.shade700
                                            : Color(0xFFF57C00),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: affiliationController,
                                decoration: const InputDecoration(
                                  labelText: 'Affiliation',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Affiliation is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Number',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Contact number is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              // Trek Type Dropdown
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: trekTypeValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Trek Type',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Color(0xFF455A64),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dropdownColor: SharedColors.white,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Regular Trek',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.hiking,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Regular Trek'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Research Trek',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.science,
                                            size: 20,
                                            color: Colors.blueGrey,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Research Trek'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Benchmarking Trek',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.trending_up,
                                            size: 20,
                                            color: Colors.amber,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Benchmarking Trek'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Special Trek',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 20,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Special Trek'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => trekTypeValue = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Home Address Text Input
                              TextFormField(
                                controller: hometownController,
                                decoration: InputDecoration(
                                  labelText: 'Home Address',
                                  hintText: 'Enter your home address',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.location_on),
                                ),
                                onChanged: (val) {
                                  setModalState(() => hometownValue = val);
                                },
                              ),
                              const SizedBox(height: 12),
                              // Primary Contact Category
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: primaryContactCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Your Category',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'student',
                                      child: Text('Student'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'senior_citizen',
                                      child: Text('Senior Citizen'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'davao_oriental_resident',
                                      child: Text('Davao Oriental Resident'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ocfdo',
                                      child: Text('OCFDO Member'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'outside_davao_oriental',
                                      child: Text('Outside Davao Oriental'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'children_8_15',
                                      child: Text('Children (8-15)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'mfsm',
                                      child: Text('MFSM Member'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(
                                        () => primaryContactCategory = val,
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Group Members section
                              const Text(
                                'Group Members',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Display members
                              ..._bookingMembers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final member = entry.value;
                                return MemberFormCard(
                                  member: member,
                                  memberIndex: index,
                                  isPrimaryContact: member.isPrimaryContact,
                                  onMemberUpdated: (updatedMember) {
                                    setModalState(() {
                                      _bookingMembers[index] = updatedMember;
                                    });
                                  },
                                  onRemoveMember: () {
                                    setModalState(() {
                                      _bookingMembers.removeAt(index);
                                    });
                                  },
                                );
                              }),
                              // Add Member button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setModalState(() {
                                      _bookingMembers.add(
                                        Member(
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
                                        ),
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Member'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Documents section
                              const Text(
                                'Documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Existing attachments
                              if (existingAttachments.isNotEmpty) ...[
                                const Text(
                                  'Current Files:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...existingAttachments.map((attachment) {
                                  final isMarkedForDelete = attachmentsToDelete
                                      .contains(attachment.fileName);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isMarkedForDelete
                                          ? Color(0xFFFFEBEE)
                                          : Color(0xFFFAFAFA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isMarkedForDelete
                                            ? Colors.red.shade300
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.insert_drive_file,
                                          size: 20,
                                          color: isMarkedForDelete
                                              ? Colors.red.shade700
                                              : AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            attachment.fileName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              decoration: isMarkedForDelete
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isMarkedForDelete
                                                  ? Colors.grey
                                                  : AppColors.text,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isMarkedForDelete
                                                ? Icons.undo
                                                : Icons.delete_outline,
                                          ),
                                          color: isMarkedForDelete
                                              ? Colors.blue
                                              : Colors.red,
                                          onPressed: () {
                                            setModalState(() {
                                              if (isMarkedForDelete) {
                                                attachmentsToDelete.remove(
                                                  attachment.fileName,
                                                );
                                              } else {
                                                attachmentsToDelete.add(
                                                  attachment.fileName,
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],
                              // New files section
                              if (newFiles.isNotEmpty) ...[
                                const Text(
                                  'New Files to Upload:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...newFiles.map((file) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.green50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.green50,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.upload_file,
                                          size: 20,
                                          color: AppColors.green700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            file.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          color: Colors.red,
                                          onPressed: () {
                                            setModalState(() {
                                              newFiles.remove(file);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],
                              // Upload button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: handlePickFiles,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Add New Files'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(color: SharedColors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Opens the existing form inside a modal bottom sheet so main screen shows bookings
  void _showBookingForm() async {
    // Prefill phone number from user settings
    await _prefillPhoneNumber();

    if (!mounted) return;

    // Initialize members list with primary contact (current authenticated user)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _bookingMembers.isEmpty) {
      final userData = await UserService.instance.getUserOnce(currentUser.uid);
      final firstName =
          userData?['firstName'] as String? ??
          currentUser.displayName?.split(' ').first ??
          '';
      final lastName =
          userData?['lastName'] as String? ??
          currentUser.displayName?.split(' ').last ??
          '';

      _bookingMembers = [
        Member(
          firstName: firstName,
          lastName: lastName,
          gender: userData?['gender'] as String? ?? 'Not specified',
          birthDate: userData?['birthDate'] as String? ?? '',
          contactNumber: _contactController.text,
          nationality: userData?['nationality'] as String? ?? '',
          homeAddress: userData?['homeAddress'] as String? ?? '',
          category: _primaryContactCategory,
          isPrimaryContact: true,
          hasAccount: true,
          userId: currentUser.uid,
          createdAt: Timestamp.now(),
        ),
      ];
    }

    if (!mounted) return;

    final scaffoldContext = context; // Capture outer context for SnackBar

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SharedColors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          // Store setModalState so _pickFiles can use it
          _setModalState = setModalState;
          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.92,
            decoration: const BoxDecoration(
              color: SharedColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New Booking',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show the authenticated user's name/email (read-only)
                            Builder(
                              builder: (context) {
                                final user = FirebaseAuth.instance.currentUser;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Booking for',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.borderBlack12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user?.displayName ?? 'Guest',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  user?.email ?? '',
                                                  style: const TextStyle(
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Contact number (still editable)
                            _buildRoundedTextField(
                              'Contact Number',
                              controller: _contactController,
                              keyboardType: TextInputType.phone,
                              validator: Validators.validContactNumber,
                            ),
                            const SizedBox(height: 12),
                            const SizedBox(height: 12),
                            _buildRoundedTextField(
                              'Affiliation',
                              controller: _affiliationController,
                            ),
                            const SizedBox(height: 12),
                            // Date picker row
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SharedColors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.borderBlack12,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatSelectedDate()),
                                        TextButton(
                                          onPressed: () async {
                                            final now = DateTime.now();
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _selectedDate ?? now,
                                              firstDate: now,
                                              lastDate: DateTime(now.year + 2),
                                            );
                                            if (picked != null) {
                                              setState(
                                                () => _selectedDate = picked,
                                              );
                                              setModalState(() {});
                                            }
                                          },
                                          child: const Text('Pick Date'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown(),
                            const SizedBox(height: 18),
                            const Text(
                              'Documents',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            _buildDocumentsArea(setModalState),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () {
                                  // Validate form fields
                                  if (!_formKey.currentState!.validate()) {
                                    if (mounted) {
                                      AppDialogueHandler.showAlert(
                                        context: scaffoldContext,
                                        title: 'Missing Information',
                                        message:
                                            'Please fill in all required fields before submitting.',
                                      );
                                    }
                                    return;
                                  }

                                  // Validate files are selected
                                  if (_pickedFiles.isEmpty) {
                                    if (mounted) {
                                      AppDialogueHandler.showError(
                                        context: scaffoldContext,
                                        title: 'No Documents Uploaded',
                                        message:
                                            'Please upload at least one document (Docx, PDF, or Image) before submitting your booking.',
                                      );
                                    }
                                    return;
                                  }

                                  Navigator.pop(modalContext);
                                  _showReviewDialog();
                                },
                                child: const Text(
                                  'Submit',
                                  style: TextStyle(
                                    color: SharedColors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoundedTextField(
    String label, {
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: SharedColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderBlack12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderBlack26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showReviewDialog() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate date is selected
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a trek date.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if the selected date has available slots
    final totalMembers = _bookingMembers.length;
    final availability = await _checkDateAvailability(
      _selectedDate!,
      totalMembers,
    );

    // Check if date is closed
    if (availability['isClosed'] == true) {
      final closureReason = availability['closureReason'] as String?;

      if (!mounted) return;

      await AppDialogueHandler.showError(
        context: context,
        title: 'Date Closed',
        message:
            'Sorry, ${_formatSelectedDate()} is closed for bookings.\n\n'
            '${closureReason != null ? 'Reason: $closureReason\n\n' : ''}'
            'Please select another date.',
      );
      return;
    }

    // Check if date is in buffer period
    if (availability['isBufferDay'] == true) {
      final conflictDate = availability['conflictDate'] as String?;

      if (!mounted) return;

      await AppDialogueHandler.showError(
        context: context,
        title: 'Trek Down Day',
        message:
            'Sorry, ${_formatSelectedDate()} is not available.\n\n'
            'There is an approved booking on $conflictDate. This date is reserved for trekkers descending from their 3-day trek.\n\n'
            'Please select a different date.',
      );
      return;
    }

    if (!availability['available']) {
      final slotsUsed = availability['slotsUsed'];
      final slotsNeeded = availability['slotsNeeded'];
      final maxSlots = availability['maxSlots'];
      final remaining = availability['remaining'];

      if (!mounted) return;

      await AppDialogueHandler.showAlert(
        context: context,
        title: 'Date Fully Booked',
        message:
            'Sorry, ${_formatSelectedDate()} is fully booked.\n\n'
            'Current status:\n'
            '• Slots used: $slotsUsed/$maxSlots\n'
            '• Slots remaining: $remaining\n'
            '• Your booking needs: $slotsNeeded slots for ${_bookingMembers.length} member${_bookingMembers.length != 1 ? 's' : ''}\n\n'
            'Please select another date or reduce the number of group members.',
      );
      return;
    }

    // Show warning if date is near capacity
    final remaining = availability['remaining'] as int;
    if (remaining <= 5 && remaining > 0) {
      final shouldContinue = await AppDialogueHandler.showConfirmation(
        context: context,
        title: 'Limited Slots Available',
        message:
            'Only $remaining slot${remaining != 1 ? 's' : ''} remaining for ${_formatSelectedDate()}.\n\n'
            'Do you want to proceed with this booking?',
        confirmText: 'Proceed',
        cancelText: 'Choose Another Date',
      );

      if (shouldContinue != true) return;
    }

    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final user = FirebaseAuth.instance.currentUser;
            // Local dialog upload progress state
            int uploadedCount = 0;
            double filePercent = 0.0;
            String? currentFile;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Review Your Booking'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show user and booking details in the review
                    _reviewRow('Full Name', user?.displayName ?? 'Guest'),
                    _reviewRow('Email', user?.email ?? ''),
                    _reviewRow('Contact Number', _contactController.text),
                    _reviewRow('Affiliation', _affiliationController.text),
                    _reviewRow('Trek Type', _climbType),
                    _reviewRow('Hometown', _hometown),
                    _reviewRow(
                      'Total Members',
                      _bookingMembers.length.toString(),
                    ),
                    _reviewRow(
                      'Trek Date',
                      _selectedDate != null ? _formatSelectedDate() : 'Not set',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Documents:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...(_pickedFiles.isEmpty
                        ? [
                            const Text(
                              'No files uploaded.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ]
                        : _pickedFiles.map((f) => Text(f.name)).toList()),

                    // Upload progress area (visible while submitting)
                    if (isSubmitting) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Uploading ${uploadedCount}/${_pickedFiles.length}: ${currentFile ?? ''}',
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: filePercent),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                  ),
                  onPressed: isSubmitting || user == null
                      ? null
                      : () async {
                          // Check for duplicate bookings on the same date
                          try {
                            final hasDuplicate = await BookingService.instance
                                .hasExistingBookingOnDate(
                                  user.uid,
                                  _selectedDate!,
                                );

                            if (hasDuplicate) {
                              if (mounted) {
                                await AppDialogueHandler.showAlert(
                                  context: context,
                                  title: 'Duplicate Booking',
                                  message:
                                      'You already have a booking on ${_formatSelectedDate()}. '
                                      'Please choose a different date or cancel your existing booking.',
                                );
                              }
                              return;
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error checking bookings: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }

                          // create draft booking directly without intermediate Climb object
                          // show loading state inside dialog
                          dialogSetState(() => isSubmitting = true);

                          try {
                            // Create a draft booking with all the current form data
                            final now = DateTime.now();
                            final draftBooking = BookingModel(
                              userId: user.uid,
                              affiliation: _affiliationController.text,
                              trekDate: Timestamp.fromDate(
                                _selectedDate ?? now,
                              ),
                              trekType: _climbType.toLowerCase(),
                              hometown: _hometown,
                              phoneNumber: _contactController.text,
                              notes: 'Draft booking - not yet submitted',
                              members: _bookingMembers,
                            );

                            // Add to draft bookings list (saved locally)
                            if (mounted) {
                              setState(() {
                                _draftBookings.add(draftBooking);
                              });
                              // Save to persistent storage
                              await _saveDraftBookings();
                            }

                            // show snack on the main scaffold
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Booking saved locally. ${_bookingMembers.length} member${_bookingMembers.length != 1 ? 's' : ''} added. You can add more members or submit when ready.',
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }

                            // close the dialog first (use rootNavigator to ensure dialog is dismissed)
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }

                            // reset form state after dialog is closed
                            if (mounted) {
                              setState(() {
                                _contactController.clear();
                                _affiliationController.clear();
                                _pickedFiles = [];
                                _bookingMembers = [];
                                _climbType = 'Regular Trek';
                                _hometown = '';
                                _primaryContactCategory = 'student';
                                _selectedDate = null;
                              });
                            }
                          } catch (e) {
                            // show error on main scaffold
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error saving booking: $e'),
                                ),
                              );
                            }
                            // leave form data intact so user can retry
                            dialogSetState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(color: SharedColors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Purpose of Trek',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: SharedColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderBlack12),
            boxShadow: [
              BoxShadow(
                color: SharedColors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<String>(
            value: _climbType,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: SharedColors.white,
            items: const [
              DropdownMenuItem(
                value: 'Regular Trek',
                child: Row(
                  children: [
                    Icon(Icons.hiking, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Regular Trek'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Research Trek',
                child: Row(
                  children: [
                    Icon(Icons.science, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Research Trek'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Benchmarking Trek',
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Benchmarking Trek'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Special Trek',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Special Trek'),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _climbType = val);
            },
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Home Address',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your home address';
            }
            return null;
          },
          onChanged: (val) {
            setState(() => _hometown = val);
          },
          decoration: InputDecoration(
            hintText: 'Enter your home address',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            prefixIcon: const Icon(Icons.location_on),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your Category',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: SharedColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderBlack12),
            boxShadow: [
              BoxShadow(
                color: SharedColors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<String>(
            value: _primaryContactCategory,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: SharedColors.white,
            items: const [
              DropdownMenuItem(value: 'student', child: Text('Student')),
              DropdownMenuItem(
                value: 'senior_citizen',
                child: Text('Senior Citizen'),
              ),
              DropdownMenuItem(
                value: 'davao_oriental_resident',
                child: Text('Davao Oriental Resident'),
              ),
              DropdownMenuItem(value: 'ocfdo', child: Text('OCFDO Member')),
              DropdownMenuItem(
                value: 'outside_davao_oriental',
                child: Text('Outside Davao Oriental'),
              ),
              DropdownMenuItem(
                value: 'children_8_15',
                child: Text('Children (8-15)'),
              ),
              DropdownMenuItem(value: 'mfsm', child: Text('MFSM Member')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _primaryContactCategory = val);
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildDocumentsArea(Function(VoidCallback fn) setModalState) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderBlack26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.upload_file, color: SharedColors.white),
                label: const Text(
                  'Upload Docx, PDF, or Image',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: _pickFiles,
              ),
            ),
            const SizedBox(height: 12),
            if (_pickedFiles.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No files uploaded.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _pickedFiles
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.name,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: const Icon(Icons.close),
                                color: Colors.red.shade700,
                                onPressed: () {
                                  setModalState(() {
                                    _pickedFiles.remove(f);
                                  });
                                },
                                tooltip: 'Remove file',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _authSub?.cancel();
    _contactController.dispose();
    _affiliationController.dispose();
    super.dispose();
  }
}
