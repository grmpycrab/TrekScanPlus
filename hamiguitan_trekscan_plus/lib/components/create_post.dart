import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/social_model.dart';
import '../services/social_sharing_service.dart';
import '../theme/color.dart';

class CreatePostSheet extends StatefulWidget {
  final VoidCallback? onPostCreated;

  const CreatePostSheet({super.key, this.onPostCreated});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _captionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<File> _selectedImages = [];
  PostPrivacy _privacy = PostPrivacy.public; // Default to public
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 4 images allowed')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        final remainingSlots = 4 - _selectedImages.length;
        final newFiles = result.paths
            .take(remainingSlots)
            .map((path) => File(path!))
            .toList();
        _selectedImages.addAll(newFiles);
      });
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final socialService = SocialSharingService.instance;

      // Create post first to get ID
      final postId = await socialService.createPost(
        caption: _captionController.text.trim(),
        imageUrls: [], // Will be updated after upload
        privacy: _privacy,
      );

      // Upload images in parallel for faster processing
      final uploadFutures = _selectedImages.map(
        (imageFile) => socialService.uploadImage(imageFile, postId),
      );
      final imageUrls = await Future.wait(uploadFutures);

      // Update post with image URLs
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'imageUrls': imageUrls,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        widget.onPostCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create post: $e')));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
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
              groupValue: _privacy,
              onChanged: (value) => setState(() => _privacy = value!),
            ),
            RadioListTile<PostPrivacy>(
              title: const Text('Followers Only'),
              subtitle: const Text('Only your followers can see this'),
              value: PostPrivacy.followers,
              groupValue: _privacy,
              onChanged: (value) => setState(() => _privacy = value!),
            ),
            RadioListTile<PostPrivacy>(
              title: const Text('Private'),
              subtitle: const Text('Only you can see this'),
              value: PostPrivacy.private,
              groupValue: _privacy,
              onChanged: (value) => setState(() => _privacy = value!),
            ),
            const SizedBox(height: 16),
            // Images section
            const Text(
              'Images (Max 4)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_selectedImages.isEmpty)
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickImages,
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
                      _selectedImages.length,
                      (index) => Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
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
                  if (_selectedImages.length < 4)
                    TextButton.icon(
                      onPressed: _isUploading ? null : _pickImages,
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
                onPressed: _isUploading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
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
