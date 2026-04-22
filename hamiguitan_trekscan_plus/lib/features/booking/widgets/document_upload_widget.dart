import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/color.dart';

/// Widget for uploading and managing documents
/// Displays file picker and list of selected/existing files
/// Also shows previously selected files from metadata if current files not available
class DocumentUploadWidget extends StatelessWidget {
  final List<PlatformFile> pickedFiles;
  final List<Map<String, dynamic>>? previouslySelectedFiles;
  final VoidCallback onPickFiles;
  final Function(PlatformFile) onRemoveFile;

  const DocumentUploadWidget({
    super.key,
    required this.pickedFiles,
    this.previouslySelectedFiles,
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
                  style: TextStyle(color: SharedColors.white),
                ),
                onPressed: onPickFiles,
              ),
            ),
            const SizedBox(height: 12),
            if (pickedFiles.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pickedFiles
                    .map((file) => _buildFileItem(file))
                    .toList(),
              )
            else if (previouslySelectedFiles != null &&
                previouslySelectedFiles!.isNotEmpty)
              _buildPreviousFilesList()
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  /// Build list of previously selected files (for draft reference)
  Widget _buildPreviousFilesList() {
    if (previouslySelectedFiles == null || previouslySelectedFiles!.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            border: Border.all(color: AppColors.infoBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previously selected files (please re-select)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...previouslySelectedFiles!.map((fileData) {
                final fileName = fileData['name'] as String? ?? 'Unknown';
                final fileSize = fileData['size'] as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(fileSize / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.iconGrey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// Build empty state when no files selected
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedLight,
        border: Border.all(color: AppColors.red200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'No files uploaded.',
          style: const TextStyle(
            color: AppColors.statusRejectedDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
              color: AppColors.statusRejectedDark,
              onPressed: () => onRemoveFile(file),
              tooltip: 'Remove file',
            ),
          ),
        ],
      ),
    );
  }
}
