import 'package:flutter/material.dart';
import 'social_card_media_grid.dart';

/// Media section dispatcher: handles all image layout patterns.
class SocialCardMedia extends StatelessWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const SocialCardMedia({
    super.key,
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return SocialCardMediaGrid(imageUrls: imageUrls, onImageTap: onImageTap);
  }
}
