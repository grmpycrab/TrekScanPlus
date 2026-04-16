import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/color.dart';

/// Widget for uploading and managing documents
/// Displays file picker and list of selected/existing files
class DocumentUploadWidget extends StatelessWidget {
  final List<PlatformFile> pickedFiles;
  final VoidCallback onPickFiles;
  final Function(PlatformFile) onRemoveFile;

  const DocumentUploadWidget({
    super.key,
    required this.pickedFiles,
    required this.onPickFiles,
    required this.onRemoveFile,
  });

  @override
  Widget build(BuildContext context) {
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
                onPressed: onPickFiles,
              ),
            ),
            const SizedBox(height: 12),
            if (pickedFiles.isEmpty) _buildEmptyState() else _buildFilesList(),
          ],
        ),
      ),
    );
  }

  /// Build empty state when no files selected
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
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
    );
  }

  /// Build list of selected files with remove buttons
  Widget _buildFilesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: pickedFiles.map((file) => _buildFileItem(file)).toList(),
    );
  }

  /// Build individual file item with remove button
  Widget _buildFileItem(PlatformFile file) {
    return Padding(
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
              file.name,
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
              onPressed: () => onRemoveFile(file),
              tooltip: 'Remove file',
            ),
          ),
        ],
      ),
    );
  }
}
