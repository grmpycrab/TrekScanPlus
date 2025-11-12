import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
// dart:io not required here anymore
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
              // Map BookingModel -> Climb for display
              _bookings = bookings
                  .map(
                    (b) => Climb(
                      name:
                          FirebaseAuth.instance.currentUser?.displayName ??
                          'You',
                      date: b.trekDate.toDate(),
                      type: b.trekType,
                      status: b.status,
                      documents: b.attachments.map((a) => a.fileName).toList(),
                    ),
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

  Future<void> _submitBookingToFirebase(
    Climb climb,
    List<PlatformFile> files,
    Map<String, String> meta,
  ) async {
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

    // Use BookingService to create booking first, then upload attachments in background
    final bookingService = BookingService.instance;
    final String bookingId = await bookingService.createBooking(booking);

    // Start uploads as fire-and-forget so UI isn't blocked by platform/plugin issues
    for (final f in files) {
      bookingService
          .uploadAttachment(bookingId, f)
          .then((meta) {
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('Uploaded ${meta.fileName}')),
              );
            }
          })
          .catchError((e) {
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('Failed to upload ${f.name}: $e')),
              );
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF252B30),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Book a Climb',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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

  List<Climb> _filterBookings(String type) {
    // Normalize to Climb instances in case some entries are Map<String,String>
    final climbs = _asClimbs();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (type == 'upcoming') {
      return climbs.where((b) => !b.date.isBefore(todayDate)).toList();
    } else if (type == 'previous') {
      return climbs.where((b) => b.date.isBefore(todayDate)).toList();
    }
    return climbs;
  }

  Widget _buildBookingsList(List<Climb> bookings) {
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
          final booking = bookings[index];
          return ClimbCard(
            climb: booking,
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
              (b) => Climb(
                name: FirebaseAuth.instance.currentUser?.displayName ?? 'You',
                date: b.trekDate.toDate(),
                type: b.trekType,
                status: b.status,
                documents: b.attachments.map((a) => a.fileName).toList(),
              ),
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
                        (b) => Climb(
                          name:
                              FirebaseAuth.instance.currentUser?.displayName ??
                              'You',
                          date: b.trekDate.toDate(),
                          type: b.trekType,
                          status: b.status,
                          documents: b.attachments
                              .map((a) => a.fileName)
                              .toList(),
                        ),
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
    // Convert and *mutate* the internal _bookings list so that returned Climb
    // instances stay in sync with the source and can be updated (e.g. cancel).
    final List<Climb> list = [];
    for (var i = 0; i < _bookings.length; i++) {
      final e = _bookings[i];
      if (e is Climb) {
        list.add(e);
        continue;
      }
      if (e is Map) {
        try {
          final map = Map<String, String>.from(
            e.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
          final converted = Climb.fromMap(map);
          // replace the map entry with the Climb instance so later updates
          // (like setting status) affect the stored object
          _bookings[i] = converted;
          list.add(converted);
          continue;
        } catch (_) {
          final fallback = Climb(name: '', date: DateTime(1970));
          _bookings[i] = fallback;
          list.add(fallback);
          continue;
        }
      }
      final fallback = Climb(name: '', date: DateTime(1970));
      _bookings[i] = fallback;
      list.add(fallback);
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                booking.status = 'Cancelled';
              });
              Navigator.pop(context);
            },
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
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
                            );

                            // show snack on the main scaffold
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Booking submitted to server.'),
                              ),
                            );
                          } catch (e) {
                            // show error on main scaffold
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Saved locally (upload failed): $e',
                                ),
                              ),
                            );
                          }

                          // update main UI list if we aren't already subscribed
                          // to the Firestore stream (avoid duplicate entries).
                          if (mounted) {
                            setState(() {
                              if (_bookingSub == null) {
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
