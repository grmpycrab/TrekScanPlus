import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';
import '../../../utils/app_logger.dart';

/// Manages the create-post flow state: selected images, privacy, and upload.
///
/// The view calls [pickImages], [removeImage], [setPrivacy], and [submitPost].
/// It reads [selectedImages], [privacy], and [isUploading] to render UI.
class CreatePostViewModel extends ChangeNotifier {
  final SocialRepository _repository = SocialRepository.instance;

  final List<File> _selectedImages = [];
  PostPrivacy _privacy = PostPrivacy.public;
  bool _isUploading = false;

  List<File> get selectedImages => List.unmodifiable(_selectedImages);
  PostPrivacy get privacy => _privacy;
  bool get isUploading => _isUploading;

  Future<void> pickImages() async {
    if (_selectedImages.length >= 4) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      final remainingSlots = 4 - _selectedImages.length;
      final newFiles = result.paths
          .take(remainingSlots)
          .map((path) => File(path!))
          .toList();
      _selectedImages.addAll(newFiles);
      notifyListeners();
    }
  }

  void removeImage(int index) {
    _selectedImages.removeAt(index);
    notifyListeners();
  }

  void setPrivacy(PostPrivacy value) {
    _privacy = value;
    notifyListeners();
  }

  /// Uploads images and creates the post. Returns the new post ID.
  /// Throws on failure so the view can display an error message.
  Future<String> submitPost(String caption) async {
    _isUploading = true;
    notifyListeners();

    try {
      final postId = _repository.generatePostId();
      AppLogger.d('Generated post ID: $postId');

      AppLogger.i('Starting image upload for ${_selectedImages.length} images');
      final uploadFutures = _selectedImages.map(
        (imageFile) => _repository.uploadImage(imageFile, postId),
      );
      final imageUrls = await Future.wait(uploadFutures);
      AppLogger.i('Image upload complete. URLs: $imageUrls');

      if (imageUrls.isEmpty) throw Exception('No images were uploaded');

      final createdPostId = await _repository.createPost(
        caption: caption.trim(),
        imageUrls: imageUrls,
        privacy: _privacy,
      );
      AppLogger.i('Post created with ID: $createdPostId');
      return createdPostId;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
}
