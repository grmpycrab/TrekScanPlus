import 'package:flutter/material.dart';
import '../models/social_model.dart';
import '../components/social_card.dart';
import '../utils/image_cache_manager.dart';

/// Optimized social feed item that handles image preloading and recycling
class SocialFeedItem extends StatefulWidget {
  final SocialPost post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onDelete;
  final int index;
  final bool shouldPreloadImages;

  const SocialFeedItem({
    super.key,
    required this.post,
    required this.index,
    this.onCommentTap,
    this.onDelete,
    this.shouldPreloadImages = false,
  });

  @override
  State<SocialFeedItem> createState() => _SocialFeedItemState();
}

class _SocialFeedItemState extends State<SocialFeedItem>
    with AutomaticKeepAliveClientMixin {
  bool _imagesPreloaded = false;

  @override
  bool get wantKeepAlive => true; // Keep the widget alive to avoid rebuilds

  @override
  void initState() {
    super.initState();
    if (widget.shouldPreloadImages && widget.post.imageUrls.isNotEmpty) {
      _preloadImages();
    }
  }

  @override
  void didUpdateWidget(SocialFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only preload if the post changed or if we should preload and haven't yet
    if (widget.shouldPreloadImages &&
        !_imagesPreloaded &&
        widget.post.imageUrls.isNotEmpty) {
      _preloadImages();
    }
  }

  void _preloadImages() {
    if (_imagesPreloaded) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ImageCacheManager.preloadImages(widget.post.imageUrls, context);
        setState(() {
          _imagesPreloaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SocialCard(
        post: widget.post,
        onCommentTap: widget.onCommentTap,
        onDelete: widget.onDelete,
      ),
    );
  }
}
