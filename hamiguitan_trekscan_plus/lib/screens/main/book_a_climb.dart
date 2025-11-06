import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  List<String> _uploadedFiles = [];

  // Demo bookings list shown on main screen. Replace with real data source.
  // Keep as dynamic to tolerate older Map<String,String> entries (converted at runtime).
  final List<dynamic> _bookings = [
    {
      'name': 'John Doe',
      'date': '2025-11-10',
      'type': 'General',
      'status': 'Pending',
    },
    {
      'name': 'Jane Smith',
      'date': '2025-11-15',
      'type': 'Research',
      'status': 'Approved',
    },
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
        _uploadedFiles = result.files.map((f) => f.name).toList();
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
    return _bookings.map<Climb>((e) {
      if (e is Climb) return e;
      if (e is Map) {
        try {
          final map = Map<String, String>.from(
            e.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
          return Climb.fromMap(map);
        } catch (_) {
          return Climb(name: '', date: DateTime(1970));
        }
      }
      return Climb(name: '', date: DateTime(1970));
    }).toList();
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
                ...(_uploadedFiles.isEmpty
                    ? [
                        const Text(
                          'No files uploaded.',
                          style: TextStyle(color: Colors.black38),
                        ),
                      ]
                    : _uploadedFiles.map((f) => Text(f)).toList()),
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
              onPressed: () {
                // Create new Climb entry and add to bookings (in-memory)
                final newClimb = Climb(
                  name: _nameController.text.trim(),
                  date:
                      DateTime.now(), // defaulting to now; replace with date input later
                  type: _climbType,
                  status: 'Pending',
                  documents: List<String>.from(_uploadedFiles),
                );
                setState(() {
                  _bookings.insert(0, newClimb);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Submission proceeded!')),
                );
                // Clear form for next use
                _nameController.clear();
                _contactController.clear();
                _ageController.clear();
                _emailController.clear();
                _affiliationController.clear();
                _portersController.clear();
                _uploadedFiles = [];
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
            if (_uploadedFiles.isEmpty)
              const Text(
                'No files uploaded.',
                style: TextStyle(color: Colors.black38),
              )
            else
              ..._uploadedFiles.map(
                (f) => Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 14)),
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
