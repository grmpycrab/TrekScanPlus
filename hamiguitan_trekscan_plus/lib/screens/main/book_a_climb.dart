import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  // Demo bookings list shown on main screen. Replace with real data source.
  // Keep as dynamic for backward compatibility, but initialize with Climb
  // instances to avoid type-mismatch issues.
  final List<dynamic> _bookings = [
    Climb(
      name: 'John Doe',
      date: DateTime(2025, 11, 10),
      type: 'General',
      status: 'Pending',
    ),
    Climb(
      name: 'Jane Smith',
      date: DateTime(2025, 11, 15),
      type: 'Research',
      status: 'Approved',
    ),
  ];

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _affiliationController = TextEditingController();
  final TextEditingController _portersController = TextEditingController();

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

    final storage = FirebaseStorage.instance;
    final firestore = FirebaseFirestore.instance;

    // Upload files and collect URLs
    final List<String> fileUrls = [];
    for (final f in files) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = storage.ref('bookings/${timestamp}_${f.name}');
        if (f.path != null) {
          // On mobile platforms we can upload via file path
          final uploadTask = ref.putFile(File(f.path!));
          await uploadTask.whenComplete(() {});
        } else if (f.bytes != null) {
          final uploadTask = ref.putData(f.bytes!);
          await uploadTask.whenComplete(() {});
        } else {
          continue;
        }
        final url = await ref.getDownloadURL();
        fileUrls.add(url);
      } catch (e) {
        // Swallow individual file errors and continue
      }
    }

    // Create booking document in Firestore
    final doc = {
      ...climb.toMap(),
      'documents': fileUrls,
      'meta': meta,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Pending',
    };
    await firestore.collection('bookings').add(doc);
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
    if (bookings.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return ClimbCard(
          climb: booking,
          onCancel: (c) => _confirmCancelModel(c),
        );
      },
    );
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
                        _buildRoundedTextField(
                          'Full Name',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRoundedTextField(
                                'Contact Number',
                                controller: _contactController,
                                keyboardType: TextInputType.phone,
                                validator: (value) =>
                                    Validators.validPhone(value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRoundedTextField(
                                'Age',
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    Validators.validAge(value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildRoundedTextField(
                          'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Review Your Submission'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reviewRow('Full Name', _nameController.text),
                _reviewRow('Contact Number', _contactController.text),
                _reviewRow('Age', _ageController.text),
                _reviewRow('Email', _emailController.text),
                _reviewRow('Affiliation', _affiliationController.text),
                _reviewRow('Number of Porters', _portersController.text),
                _reviewRow('Climb Type', _climbType),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                // Create new Climb entry (local object)
                final newClimb = Climb(
                  name: _nameController.text.trim(),
                  date:
                      DateTime.now(), // TODO: replace with selected date once date-picker added
                  type: _climbType,
                  status: 'Pending',
                  documents: _pickedFiles.map((f) => f.name).toList(),
                );

                // Try to send to Firebase; if Firebase isn't configured the code
                // will catch the error and fall back to local insertion only.
                try {
                  await _submitBookingToFirebase(newClimb, _pickedFiles, {
                    'contact': _contactController.text,
                    'age': _ageController.text,
                    'email': _emailController.text,
                    'affiliation': _affiliationController.text,
                    'porters': _portersController.text,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking submitted to server.'),
                    ),
                  );
                } catch (e) {
                  // Firebase not available or upload failed — keep local booking and notify
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved locally (upload failed): $e'),
                    ),
                  );
                }

                // Always insert locally so user sees the booking immediately.
                setState(() {
                  _bookings.insert(0, newClimb);
                });
                Navigator.of(context).pop();
                // Clear form for next use
                _nameController.clear();
                _contactController.clear();
                _ageController.clear();
                _emailController.clear();
                _affiliationController.clear();
                _portersController.clear();
                _pickedFiles = [];
                _climbType = 'General';
              },
              child: const Text(
                'Proceed',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
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
}
