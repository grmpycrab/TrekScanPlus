import 'package:flutter/material.dart';
import '../viewmodels/create_post_view_model.dart';
import '../models/social_model.dart';
import '../../../theme/color.dart';
import '../../../utils/app_logger.dart';

class CreatePostSheet extends StatefulWidget {
  final VoidCallback? onPostCreated;

  const CreatePostSheet({super.key, this.onPostCreated});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _captionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late CreatePostViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CreatePostViewModel();
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_vm.selectedImages.length >= 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 4 images allowed')));
      return;
    }
    await _vm.pickImages();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vm.selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    try {
      final createdPostId = await _vm.submitPost(_captionController.text);
      AppLogger.i('Post created with ID: $createdPostId');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        widget.onPostCreated?.call();
      }
    } catch (e) {
      AppLogger.e('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create post: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Post',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Caption field
            TextFormField(
              controller: _captionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Caption cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Privacy selector
            const Text(
              'Privacy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            RadioListTile<PostPrivacy>(
              title: const Text('Public'),
              subtitle: const Text('Anyone can see this post'),
              value: PostPrivacy.public,
              // ignore: deprecated_member_use
              groupValue: _vm.privacy,
              // ignore: deprecated_member_use
              onChanged: (value) => _vm.setPrivacy(value!),
            ),
            RadioListTile<PostPrivacy>(
              title: const Text('Followers Only'),
              subtitle: const Text('Only your followers can see this'),
              value: PostPrivacy.followers,
              // ignore: deprecated_member_use
              groupValue: _vm.privacy,
              // ignore: deprecated_member_use
              onChanged: (value) => _vm.setPrivacy(value!),
            ),
            RadioListTile<PostPrivacy>(
              title: const Text('Private'),
              subtitle: const Text('Only you can see this'),
              value: PostPrivacy.private,
              // ignore: deprecated_member_use
              groupValue: _vm.privacy,
              // ignore: deprecated_member_use
              onChanged: (value) => _vm.setPrivacy(value!),
            ),
            const SizedBox(height: 16),
            // Images section
            const Text(
              'Images (Max 4)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_vm.selectedImages.isEmpty)
              ElevatedButton.icon(
                onPressed: _vm.isUploading ? null : _pickImages,
                icon: const Icon(Icons.image),
                label: const Text('Pick Images'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      _vm.selectedImages.length,
                      (index) => Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_vm.selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _vm.removeImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_vm.selectedImages.length < 4)
                    TextButton.icon(
                      onPressed: _vm.isUploading ? null : _pickImages,
                      icon: const Icon(Icons.add),
                      label: const Text('Add More Images'),
                    ),
                ],
              ),
            const Spacer(),
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _vm.isUploading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _vm.isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
