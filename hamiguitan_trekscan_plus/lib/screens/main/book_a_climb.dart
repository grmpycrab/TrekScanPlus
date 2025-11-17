import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/validators.dart';
import '../../models/climb.dart';
import '../../components/climb_card.dart';

class BookAClimbScreen extends StatefulWidget {
  const BookAClimbScreen({super.key});

  @override
  State<BookAClimbScreen> createState() => _BookAClimbScreenState();
}

class _BookAClimbScreenState extends State<BookAClimbScreen> {
  final _formKey = GlobalKey<FormState>();
  String _climbType = 'General';

  // Store picked PlatformFile objects so we can upload bytes/paths to Firebase
  List<PlatformFile> _pickedFiles = [];

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

  @override
  void initState() {
    super.initState();
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
          .listen((bookings) {
            setState(() {
              // Map BookingModel -> {climb, booking} for display
              _bookings = bookings
                  .map(
                    (b) => {
                      'climb': Climb(
                        id: b.id,
                        name:
                            FirebaseAuth.instance.currentUser?.displayName ??
                            'You',
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
          });
    });
  }

  String _formatSelectedDate() {
    if (_selectedDate == null) return 'Select date';
    return '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      setState(() {
        _pickedFiles = result.files;
      });
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
        print('ERROR uploading ${f.name}: $e');
        print('ERROR Stack trace: ${StackTrace.current}');
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
                  name: FirebaseAuth.instance.currentUser?.displayName ?? 'You',
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
                            name:
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                'You',
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
      print('Error refreshing bookings: $e');
    }
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

  void _confirmCancelModel(Climb booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () async {
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
                  // Show error to user
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to cancel booking: $e')),
                    );
                  }
                }
              } else {
                // No id (likely local-only); just update locally
                if (mounted) {
                  setState(() => booking.status = 'Cancelled');
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  void _showEditBookingSheet(BookingModel booking) {
    if (booking.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit a pending local booking yet.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final affiliationController =
        TextEditingController(text: booking.affiliation);
    final portersController =
        TextEditingController(text: booking.numberOfPorters.toString());
    final notesController = TextEditingController(text: booking.notes ?? '');
    bool isSaving = false;

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

              setModalState(() => isSaving = true);

              try {
                // Update booking details
                await BookingService.instance.updateBooking(
                  booking.id!,
                  affiliation: affiliationController.text.trim(),
                  numberOfPorters: porters,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
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
                      print('Error deleting attachment ${attachment.fileName}: $e');
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
                    print('Error uploading file ${file.name}: $e');
                    // Continue with other uploads
                  }
                }

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking details updated.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setModalState(() => isSaving = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update booking: $e'),
                    ),
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
                              TextFormField(
                                controller: notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Additional Notes (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                              ),
                              const SizedBox(height: 16),
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
                                  final isMarkedForDelete =
                                      attachmentsToDelete.contains(attachment.fileName);
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
                                                attachmentsToDelete
                                                    .remove(attachment.fileName);
                                              } else {
                                                attachmentsToDelete
                                                    .add(attachment.fileName);
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
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
  void _showBookingForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                                    border: Border.all(color: Colors.black12),
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
                          validator: (value) => Validators.validPhone(value),
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
                        _buildDocumentsArea(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
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
      ),
    );
  }

  void _showReviewDialog() {
    if (!_formKey.currentState!.validate()) return;
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
                    _reviewRow('Climb Type', _climbType),
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
                          // create local object for immediate insertion
                          final newClimb = Climb(
                            name: user?.displayName ?? 'Guest',
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

                            // reset form state
                            _contactController.clear();
                            _affiliationController.clear();
                            _portersController.clear();
                            _pickedFiles = [];
                            _climbType = 'General';
                            _selectedDate = null;

                            // close the dialog (use rootNavigator to ensure dialog is dismissed)
                            Navigator.of(context, rootNavigator: true).pop();
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _climbType,
        decoration: const InputDecoration(border: InputBorder.none),
        items: const [
          DropdownMenuItem(value: 'General', child: Text('General')),
          DropdownMenuItem(value: 'Research', child: Text('Research')),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _climbType = val);
        },
      ),
    );
  }

  Widget _buildDocumentsArea() {
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
            const SizedBox(height: 8),
            if (_pickedFiles.isEmpty)
              const Text(
                'No files uploaded.',
                style: TextStyle(color: Colors.black38),
              )
            else
              ..._pickedFiles.map(
                (f) => Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(f.name, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
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
