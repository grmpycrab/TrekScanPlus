import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/validators.dart';

class BookAClimbScreen extends StatefulWidget {
  const BookAClimbScreen({super.key});

  @override
  State<BookAClimbScreen> createState() => _BookAClimbScreenState();
}

class _BookAClimbScreenState extends State<BookAClimbScreen> {
  final _formKey = GlobalKey<FormState>();
  String _climbType = 'General';

  List<String> _uploadedFiles = [];

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoundedTextField(
                  'Full Name',
                  controller: _fullNameController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoundedTextField(
                        'Contact Number',
                        keyboardType: TextInputType.phone,
                        validator: (value) => Validators.validPhone(value),
                        controller: _contactController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoundedTextField(
                        'Age',
                        keyboardType: TextInputType.number,
                        validator: (value) => Validators.validAge(value),
                        controller: _ageController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRoundedTextField(
                  'Email',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
                const SizedBox(height: 12),
                _buildRoundedTextField(
                  'Affiliation',
                  controller: _affiliationController,
                ),
                const SizedBox(height: 12),
                _buildRoundedTextField(
                  'Number of Porters',
                  keyboardType: TextInputType.number,
                  controller: _portersController,
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
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _showReviewDialog(context);
                      }
                    },
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    TextEditingController? controller,
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

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: _climbType,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text(
              'Upload Docx, PDF, or Image',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: _pickFiles,
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
    );
  }
}
