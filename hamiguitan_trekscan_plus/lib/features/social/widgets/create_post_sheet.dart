import 'dart:io';
import 'package:flutter/material.dart';
import '../viewmodels/create_post_view_model.dart';
import '../models/social_model.dart';
import '../../../theme/app_theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 images allowed')),
      );
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
          const SnackBar(
            content: Text(
              'Post submitted for review! It will appear once approved.',
            ),
          ),
        );
        widget.onPostCreated?.call();
      }
    } catch (e) {
      AppLogger.e('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colors.borderSubtle),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Moderation notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.warningBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: colors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Posts are reviewed before going live.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Caption field
                    TextFormField(
                      controller: _captionController,
                      maxLines: 5,
                      maxLength: 500,
                      style: TextStyle(fontSize: 15, color: colors.text),
                      decoration: InputDecoration(
                        hintText: "What's on your mind?",
                        hintStyle: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: colors.inputFill,
                        counterStyle: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: colors.primary, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: colors.error, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: colors.error, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Caption cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Privacy label
                    Text(
                      'Who can see this?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Privacy selector — custom segmented row
                    Row(
                      children: [
                        _PrivacyChip(
                          label: 'Public',
                          icon: Icons.public_rounded,
                          selected: _vm.privacy == PostPrivacy.public,
                          colors: colors,
                          onTap: () => _vm.setPrivacy(PostPrivacy.public),
                        ),
                        const SizedBox(width: 8),
                        _PrivacyChip(
                          label: 'Followers',
                          icon: Icons.group_rounded,
                          selected: _vm.privacy == PostPrivacy.followers,
                          colors: colors,
                          onTap: () => _vm.setPrivacy(PostPrivacy.followers),
                        ),
                        const SizedBox(width: 8),
                        _PrivacyChip(
                          label: 'Private',
                          icon: Icons.lock_rounded,
                          selected: _vm.privacy == PostPrivacy.private,
                          colors: colors,
                          onTap: () => _vm.setPrivacy(PostPrivacy.private),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Photos section header
                    Row(
                      children: [
                        Text(
                          'Photos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_vm.selectedImages.length}/4',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_vm.selectedImages.isEmpty)
                      _PhotoPickerEmpty(
                        colors: colors,
                        onTap: _vm.isUploading ? null : _pickImages,
                      )
                    else
                      _PhotoGrid(
                        images: _vm.selectedImages,
                        colors: colors,
                        canAddMore: _vm.selectedImages.length < 4,
                        onAdd: _vm.isUploading ? null : _pickImages,
                        onRemove: (i) => _vm.removeImage(i),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Post button pinned at bottom
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _vm.isUploading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _vm.isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
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

// ── Privacy chip ──────────────────────────────────────────────────────────────

class _PrivacyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final AppTheme colors;
  final VoidCallback onTap;

  const _PrivacyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? null
                : Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty photo picker ────────────────────────────────────────────────────────

class _PhotoPickerEmpty extends StatelessWidget {
  final AppTheme colors;
  final VoidCallback? onTap;

  const _PhotoPickerEmpty({required this.colors, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: colors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Photos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Up to 4 images',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo grid (when images selected) ────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<File> images;
  final AppTheme colors;
  final bool canAddMore;
  final VoidCallback? onAdd;
  final void Function(int) onRemove;

  const _PhotoGrid({
    required this.images,
    required this.colors,
    required this.canAddMore,
    this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...List.generate(
          images.length,
          (i) => _ImageTile(
            image: images[i],
            colors: colors,
            onRemove: () => onRemove(i),
          ),
        ),
        if (canAddMore)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.add_rounded,
                color: colors.textSecondary,
                size: 28,
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File image;
  final AppTheme colors;
  final VoidCallback onRemove;

  const _ImageTile({
    required this.image,
    required this.colors,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            image,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
