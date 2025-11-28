import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/calendar_config_service.dart';
import '../../services/validators.dart';
import '../../services/user_service.dart';
import '../../models/climb.dart';
import '../../components/climb_card.dart';
import '../../components/app_dialogue_handler.dart';
import '../../theme/color.dart';

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
  String _climbType = 'General';
  String _hometown = 'Inside San Isidro';
  bool _isSenior = false;
  bool _hasScrolledToBooking = false;

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
  // affiliation and porters only.
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _portersController = TextEditingController();
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
      debugPrint('Error prefilling phone number: $e');
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
      debugPrint('Error checking buffer period: $e');
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
      debugPrint('Error checking date availability: $e');
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

  /// Create booking and upload files sequentially using BookingService.
  /// Attachments will be stored in Firestore as the booking is created.
  /// Returns the created bookingId.
  Future<String> _submitBookingToFirebase(
    Climb climb,
    List<PlatformFile> files,
    Map<String, String> meta, {
    void Function(
      int uploadedCount,
      int totalCount,
      String? fileName,
      double? filePercent,
    )?
    onProgress,
  }) async {
    // Ensure Firebase initialized (user must generate firebase_options.dart with FlutterFire CLI)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    // Build BookingModel from the form + current user info
    final now = DateTime.now();
    final currentUser = FirebaseAuth.instance.currentUser;
    final booking = BookingModel(
      userId: currentUser?.uid ?? meta['userId'] ?? '',
      affiliation: meta['affiliation'] ?? '',
      trekDate: Timestamp.fromDate(_selectedDate ?? now),
      numberOfPorters: int.tryParse(meta['porters'] ?? '') ?? 0,
      trekType: meta['trekType'] ?? _climbType.toLowerCase(),
      hometown:
          meta['hometown'] ?? _hometown.toLowerCase().replaceAll(' ', '_'),
      isSenior: meta['isSenior'] == 'true' || _isSenior,
      phoneNumber: meta['contact'] ?? '',
      notes: meta['notes'],
    );

    final bookingService = BookingService.instance;

    // If no files, just create booking
    if (files.isEmpty) {
      return await bookingService.createBooking(booking);
    }

    // Create booking first to get its ID
    final bookingId = await bookingService.createBooking(booking);

    // Upload files sequentially with progress reporting
    int uploadedCount = 0;
    for (final f in files) {
      try {
        await bookingService.uploadAttachment(
          bookingId,
          f,
          onProgress: (sent, total) {
            final percent = total > 0 ? sent / total : 0.0;
            onProgress?.call(uploadedCount, files.length, f.name, percent);
          },
        );
        uploadedCount++;
        onProgress?.call(uploadedCount, files.length, f.name, 1.0);
      } catch (e) {
        debugPrint('Error uploading file ${f.name}: $e');
        debugPrint(StackTrace.current.toString());
        // Continue with next file rather than failing entire booking
        continue;
      }
    }

    return bookingId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF252B30),
        elevation: 0,
        centerTitle: true,
        // Prevent the automatic leading (back) button so the top-left
        // area no longer navigates back (avoids reported black-screen bug).
        automaticallyImplyLeading: false,
        title: const Text(
          'Book a Climb',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: Colors.blueGrey[800],
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueGrey[700],
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
        backgroundColor: Colors.blueGrey[700],
        onPressed: _showBookingForm,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  List<dynamic> _filterBookings(String type) {
    // Filter from _bookings which contains maps with climb and booking
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (type == 'upcoming') {
      return _bookings.where((item) {
        if (item is Map<String, dynamic> && item.containsKey('climb')) {
          final climb = item['climb'] as Climb;
          return !climb.date.isBefore(todayDate);
        }
        return false;
      }).toList();
    } else if (type == 'previous') {
      return _bookings.where((item) {
        if (item is Map<String, dynamic> && item.containsKey('climb')) {
          final climb = item['climb'] as Climb;
          return climb.date.isBefore(todayDate);
        }
        return false;
      }).toList();
    }
    return _bookings;
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
                  Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create a booking',
                    style: TextStyle(color: Colors.grey[500]),
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
      debugPrint('Error refreshing bookings: $e');
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
      debugPrint('Error fetching user display name: $e');
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

  void _confirmCancelModel(Climb booking) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Cancel Booking',
      message: 'Are you sure you want to cancel this booking?',
      confirmText: 'Cancel Booking',
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
          debugPrint('Error cancelling booking: $e');
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
    if (booking.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit a pending local booking yet.'),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final affiliationController = TextEditingController(
      text: booking.affiliation,
    );
    final phoneController = TextEditingController(text: booking.phoneNumber);
    final portersController = TextEditingController(
      text: booking.numberOfPorters.toString(),
    );
    final notesController = TextEditingController(text: booking.notes ?? '');

    // Convert database format to display format
    String hometownValue = booking.hometown;
    if (hometownValue == 'inside_san_isidro') {
      hometownValue = 'Inside San Isidro';
    } else if (hometownValue == 'inside_davao_oriental') {
      hometownValue = 'Inside Davao Oriental';
    } else if (hometownValue == 'outside_davao_oriental') {
      hometownValue = 'Outside Davao Oriental';
    }

    bool isSeniorValue = booking.isSenior;

    // Convert trek type from database format
    String trekTypeValue = booking.trekType;
    if (trekTypeValue == 'recreational' ||
        trekTypeValue.toLowerCase() == 'general') {
      trekTypeValue = 'General';
    } else if (trekTypeValue == 'research') {
      trekTypeValue = 'Research';
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

              final porters = int.tryParse(portersController.text.trim());
              if (porters == null || porters < 0) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid number of porters.'),
                  ),
                );
                return;
              }

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
                // Update booking details
                await BookingService.instance.updateBooking(
                  booking.id!,
                  affiliation: affiliationController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  numberOfPorters: porters,
                  trekType: trekTypeValue.toLowerCase(),
                  hometown: hometownValue.toLowerCase().replaceAll(' ', '_'),
                  isSenior: isSeniorValue,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                  resubmitDeclined: isDeclined, // Reset to pending if declined
                );

                // Delete removed attachments
                for (final attachment in existingAttachments) {
                  if (attachmentsToDelete.contains(attachment.fileName)) {
                    try {
                      await BookingService.instance.deleteAttachment(
                        booking.id!,
                        attachment,
                      );
                    } catch (e) {
                      debugPrint(
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
                      booking.id!,
                      file,
                    );
                  } catch (e) {
                    debugPrint('Error uploading file ${file.name}: $e');
                    debugPrint(StackTrace.current.toString());
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
                  color: Colors.white,
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
                                ? Colors.red[50]
                                : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: booking.status.toLowerCase() == 'rejected'
                                  ? Colors.red[300]!
                                  : Colors.orange[300]!,
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
                                    ? Colors.red[700]
                                    : Colors.orange[700],
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
                                            ? Colors.red[900]
                                            : Colors.orange[900],
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
                                          color: Colors.orange[800],
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
                                            ? Colors.red[700]
                                            : Colors.orange[700],
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
                              TextFormField(
                                controller: portersController,
                                decoration: const InputDecoration(
                                  labelText: 'Number of Porters',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Number of porters is required';
                                  }
                                  final porters = int.tryParse(value);
                                  if (porters == null || porters < 0) {
                                    return 'Enter a valid whole number';
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
                                    color: Colors.blueGrey[700],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dropdownColor: Colors.white,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'General',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.hiking,
                                            size: 20,
                                            color: Colors.blueGrey,
                                          ),
                                          SizedBox(width: 12),
                                          Text('General'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Research',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.science,
                                            size: 20,
                                            color: Colors.blueGrey,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Research'),
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
                              // Hometown Dropdown
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
                                  value: hometownValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Hometown',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.blueGrey[700],
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Inside San Isidro',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_city,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Inside San Isidro'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Inside Davao Oriental',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.map,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Inside Davao Oriental'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Outside Davao Oriental',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.public,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Outside Davao Oriental'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => hometownValue = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Senior Citizen Dropdown
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
                                child: DropdownButtonFormField<bool>(
                                  value: isSeniorValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Senior Citizen (60+)',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.blueGrey[700],
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: false,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 12),
                                          Text('No'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: true,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.elderly,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Yes'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => isSeniorValue = val);
                                    }
                                  },
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
                                    color: Colors.black54,
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
                                          ? Colors.red[50]
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isMarkedForDelete
                                            ? Colors.red[300]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.insert_drive_file,
                                          size: 20,
                                          color: isMarkedForDelete
                                              ? Colors.red[700]
                                              : Colors.blueGrey[700],
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
                                                  : Colors.black87,
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
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...newFiles.map((file) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.upload_file,
                                          size: 20,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            file.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
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
                                    backgroundColor: Colors.blueGrey[700],
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
                            backgroundColor: Colors.blueGrey[700],
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
                                  style: TextStyle(color: Colors.white),
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

    final scaffoldContext = context; // Capture outer context for SnackBar

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          // Store setModalState so _pickFiles can use it
          _setModalState = setModalState;
          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Colors.white,
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
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black12,
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
                                                    color: Colors.black54,
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
                            _buildRoundedTextField(
                              'Number of Porters',
                              controller: _portersController,
                              keyboardType: TextInputType.number,
                              validator: Validators.validPorters,
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
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.black26),
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
                                  backgroundColor: Colors.blueGrey[700],
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
                                    color: Colors.white,
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent),
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
    final porters = int.tryParse(_portersController.text.trim()) ?? 0;
    final availability = await _checkDateAvailability(_selectedDate!, porters);

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

      await AppDialogueHandler.showError(
        context: context,
        title: 'Date Fully Booked',
        message:
            'Sorry, ${_formatSelectedDate()} is fully booked.\n\n'
            'Current status:\n'
            '• Slots used: $slotsUsed/$maxSlots\n'
            '• Slots remaining: $remaining\n'
            '• Your booking needs: $slotsNeeded slots (1 person + $porters porter${porters != 1 ? 's' : ''})\n\n'
            'Please select another date or reduce the number of porters.',
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
              title: const Text('Review Your Submission'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show user and booking details in the review
                    _reviewRow('Full Name', user?.displayName ?? 'Guest'),
                    _reviewRow('Email', user?.email ?? ''),
                    _reviewRow('Contact Number', _contactController.text),
                    _reviewRow('Affiliation', _affiliationController.text),
                    _reviewRow('Number of Porters', _portersController.text),
                    _reviewRow('Purpose of Trek', _climbType),
                    _reviewRow('Hometown', _hometown),
                    _reviewRow('Senior Citizen', _isSenior ? 'Yes' : 'No'),
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
                              style: TextStyle(color: Colors.black38),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          // Check for duplicate bookings on the same date
                          try {
                            final hasDuplicate = await BookingService.instance
                                .hasExistingBookingOnDate(
                                  user!.uid,
                                  _selectedDate!,
                                );

                            if (hasDuplicate) {
                              if (mounted) {
                                await AppDialogueHandler.showError(
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

                          // create local object for immediate insertion
                          final newClimb = Climb(
                            name: user.displayName ?? 'Guest',
                            date: _selectedDate ?? DateTime.now(),
                            type: _climbType,
                            status: 'Pending',
                            documents: _pickedFiles.map((f) => f.name).toList(),
                          );

                          // show loading state inside dialog
                          dialogSetState(() => isSubmitting = true);

                          // We'll show a progress indicator inside the dialog by
                          // updating the StatefulBuilder's state via dialogSetState.
                          try {
                            await _submitBookingToFirebase(
                              newClimb,
                              _pickedFiles,
                              {
                                'contact': _contactController.text,
                                'affiliation': _affiliationController.text,
                                'porters': _portersController.text,
                                'trekType': _climbType.toLowerCase(),
                                'hometown': _hometown,
                                'isSenior': _isSenior.toString(),
                              },
                              onProgress: (uploaded, total, fileName, percent) {
                                // Update the dialog-scoped progress variables
                                uploadedCount = uploaded;
                                filePercent = percent ?? 0.0;
                                currentFile = fileName;
                                dialogSetState(() {});
                              },
                            );

                            // show snack on the main scaffold
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Booking submitted to server.'),
                                ),
                              );
                            }

                            // update main UI list if we aren't already subscribed
                            // to the Firestore stream (avoid duplicate entries).
                            if (mounted) {
                              setState(() {
                                if (_bookingSub == null) {
                                  // In this case we don't have the bookingId in the
                                  // newClimb instance; the Firestore stream will
                                  // populate attachments once uploads complete.
                                  _bookings.insert(0, newClimb);
                                }
                              });
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
                                _portersController.clear();
                                _pickedFiles = [];
                                _climbType = 'General';
                                _hometown = 'Inside San Isidro';
                                _isSenior = false;
                                _selectedDate = null;
                              });
                            }
                          } catch (e) {
                            // show error on main scaffold
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Saved locally (upload failed): $e',
                                  ),
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
                          'Proceed',
                          style: TextStyle(color: Colors.white),
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
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
            icon: Icon(Icons.arrow_drop_down, color: Colors.blueGrey[700]),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem(
                value: 'General',
                child: Row(
                  children: [
                    Icon(Icons.hiking, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 12),
                    Text('General'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Research',
                child: Row(
                  children: [
                    Icon(Icons.science, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 12),
                    Text('Research'),
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
          'Hometown',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<String>(
            value: _hometown,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            icon: Icon(Icons.arrow_drop_down, color: Colors.blueGrey[700]),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem(
                value: 'Inside San Isidro',
                child: Row(
                  children: [
                    Icon(Icons.location_city, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Inside San Isidro'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Inside Davao Oriental',
                child: Row(
                  children: [
                    Icon(Icons.map, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Inside Davao Oriental'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Outside Davao Oriental',
                child: Row(
                  children: [
                    Icon(Icons.public, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Outside Davao Oriental'),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _hometown = val);
            },
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Senior Citizen (60+)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<bool>(
            value: _isSenior,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            icon: Icon(Icons.arrow_drop_down, color: Colors.blueGrey[700]),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 12),
                    Text('No'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.elderly, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 12),
                    Text('Yes'),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _isSenior = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsArea(Function(VoidCallback fn) setModalState) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.upload_file, color: Colors.white),
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
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No files uploaded.',
                    style: TextStyle(
                      color: Colors.red[700],
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
                              color: Colors.blueGrey,
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
                                color: Colors.red,
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
    _portersController.dispose();
    _affiliationController.dispose();
    super.dispose();
  }
}
