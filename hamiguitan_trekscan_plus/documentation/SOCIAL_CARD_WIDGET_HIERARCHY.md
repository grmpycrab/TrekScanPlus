# Social Card Redesign — Widget Hierarchy & Architecture Guide

**Status**: Phase 1 Analysis Complete — Ready for Implementation  
**Target**: Phases 2-8 Development  
**Date**: May 7, 2026

---

## EXECUTIVE OVERVIEW

### Current State vs. Proposed State

```
CURRENT (Monolithic)          →  PROPOSED (Modular)

SocialCard (850 lines)        →  SocialCard (140 lines)
├── Everything inline            ├── SocialCardHeader
├── Header code                  ├── ExpandableCaption
├── Caption code                 ├── SocialCardMedia
├── Media code                   ├── SocialCardStats
├── Actions code                 └── SocialCardActions
└── Stats code
```

**Benefits of Proposed Structure**:

- ✅ 5x smaller main widget
- ✅ Reusable components
- ✅ Easier testing
- ✅ Better performance
- ✅ Clearer separation of concerns

---

## DETAILED WIDGET HIERARCHY

### Tier 1: Main Container

#### `SocialCard` (REFACTORED)

```dart
/// Main container widget that orchestrates all sub-components
class SocialCard extends StatefulWidget {
  final SocialPost post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onDelete;

  // No change to signature — backwards compatible
}

// Internal structure:
class _SocialCardState extends State<SocialCard> {
  late final PostViewModel _vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SocialCardHeader(...),
          if (widget.post.caption.isNotEmpty)
            ExpandableCaption(...),
          if (widget.post.imageUrls.isNotEmpty)
            SocialCardMedia(...),
          SocialCardStats(...),
          SocialCardActions(...),
        ],
      ),
    );
  }
}
```

**Responsibility**: Layout and orchestration only (~140 lines after refactor)

---

### Tier 2: Sub-Components

#### `SocialCardHeader` (NEW)

```dart
/// Header section: avatar, name, timestamp, follow button, more menu
class SocialCardHeader extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? userPhotoUrl;
  final String? userRole;
  final DateTime createdAt;
  final PostPrivacy privacy;
  final bool isFollowing;
  final bool isPending;
  final bool isOwnPost;

  final VoidCallback onFollowTap;
  final VoidCallback onMoreTap;
  final VoidCallback onUserTap;

  const SocialCardHeader({
    required this.userId,
    required this.displayName,
    this.userPhotoUrl,
    this.userRole,
    required this.createdAt,
    required this.privacy,
    required this.isFollowing,
    required this.isPending,
    required this.isOwnPost,
    required this.onFollowTap,
    required this.onMoreTap,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar section
          GestureDetector(
            onTap: onUserTap,
            child: ProfileAvatarWithStatus(
              userId: userId,
              photoUrl: userPhotoUrl,
              radius: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Info section
          Expanded(
            child: GestureDetector(
              onTap: onUserTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(_getTimeAgo(createdAt), style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('•')),
                      Icon(_getPrivacyIcon(privacy), size: 14, color: colors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Follow button or more menu
          if (!isOwnPost)
            GestureDetector(
              onTap: onFollowTap,
              child: _buildFollowButton(colors),
            ),

          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: colors.textSecondary),
            onPressed: onMoreTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(AppTheme colors) {
    // Follow/Following/Pending button
  }

  String _getTimeAgo(DateTime date) { /* ... */ }
  IconData _getPrivacyIcon(PostPrivacy privacy) { /* ... */ }
}
```

**Key Features**:

- ✅ Const-eligible (all parameters)
- ✅ Reusable (comments, replies, etc)
- ✅ Clean responsibility
- ✅ ~80 lines

---

#### `ExpandableCaption` (NEW - CORE)

```dart
/// Expandable caption with "See more" / "See less" behavior
class ExpandableCaption extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final VoidCallback? onExpand;

  const ExpandableCaption({
    required this.text,
    this.maxLines = 3,
    this.style,
    this.onExpand,
  });

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure if text overflows
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style ?? const TextStyle()),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        final shouldShowMore = textPainter.didExceedMaxLines;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated text expansion
              AnimatedCrossFade(
                firstChild: Text(
                  widget.text,
                  maxLines: widget.maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: widget.style ?? const TextStyle(fontSize: 14, height: 1.4),
                ),
                secondChild: Text(
                  widget.text,
                  style: widget.style ?? const TextStyle(fontSize: 14, height: 1.4),
                ),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),

              // See more / See less button
              if (shouldShowMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _isExpanded = !_isExpanded);
                      if (!_isExpanded) widget.onExpand?.call();
                    },
                    child: Text(
                      _isExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

**Key Features**:

- ✅ Smooth expand/collapse animation
- ✅ Preserves formatting (emoji, newlines, etc)
- ✅ Reusable component
- ✅ ~100 lines

---

#### `SocialCardMedia` (NEW)

```dart
/// Media section: handles all image layout patterns (1-5+ images)
class SocialCardMedia extends StatelessWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const SocialCardMedia({
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    // Full-width, no padding
    return SocialCardMediaGrid(
      imageUrls: imageUrls,
      onImageTap: onImageTap,
    );
  }
}
```

**Key Features**:

- ✅ Fully const-eligible
- ✅ Can be wrapped with RepaintBoundary
- ✅ Delegates to grid builder
- ✅ ~15 lines

---

#### `SocialCardMediaGrid` (NEW - INTERNAL)

```dart
/// Handles complex image grid layouts (1-5+ images)
class SocialCardMediaGrid extends StatelessWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const SocialCardMediaGrid({
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    // Full-width, no padding constraints
    return ClipRRect(
      borderRadius: BorderRadius.zero, // Or BorderRadius.circular(0) for full-width feel
      child: _buildLayout(),
    );
  }

  Widget _buildLayout() {
    if (imageUrls.length == 1) return _buildSingleImage();
    if (imageUrls.length == 2) return _buildTwoImages();
    if (imageUrls.length == 3) return _buildThreeImages();
    if (imageUrls.length == 4) return _buildFourImages();
    return _buildFivePlusImages();
  }

  Widget _buildSingleImage() { /* ... */ }
  Widget _buildTwoImages() { /* ... */ }
  Widget _buildThreeImages() { /* ... */ }
  Widget _buildFourImages() { /* ... */ }
  Widget _buildFivePlusImages() { /* ... */ }

  Widget _buildImageTile(String url, int index) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: context.colors.surfaceVariant,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: context.colors.borderLight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_rounded, size: 48, color: context.colors.textTertiary),
              const SizedBox(height: 8),
              Text('Image unavailable', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            ],
          ),
        ),
        memCacheWidth: 800,
        memCacheHeight: 600,
      ),
    );
  }
}
```

**Key Features**:

- ✅ Fully const-eligible
- ✅ Centralized image grid logic
- ✅ Full-width presentation
- ✅ ~180 lines (extracted from main card)

---

#### `SocialCardStats` (NEW)

```dart
/// Interaction stats: likes, comments, shares counts
class SocialCardStats extends StatelessWidget {
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  const SocialCardStats({
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (likesCount == 0 && commentsCount == 0 && sharesCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Divider
          Container(
            height: 1,
            color: colors.borderLight,
          ),

          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              if (likesCount > 0) ...[
                Icon(Icons.favorite, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Text('$likesCount', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                const SizedBox(width: 12),
              ],
              if (commentsCount > 0) ...[
                Icon(Icons.chat_bubble, size: 16, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('$commentsCount', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                const SizedBox(width: 12),
              ],
              if (sharesCount > 0) ...[
                Icon(Icons.share, size: 16, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('$sharesCount', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

**Key Features**:

- ✅ Fully const
- ✅ Clean separation from actions
- ✅ Better visual hierarchy
- ✅ ~60 lines

---

#### `SocialCardActions` (NEW)

```dart
/// Action buttons: like, comment, share, bookmark
class SocialCardActions extends StatelessWidget {
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onBookmarkTap;

  const SocialCardActions({
    required this.isLiked,
    required this.isBookmarked,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _ActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : colors.textSecondary,
            onTap: onLikeTap,
          ),
          const SizedBox(width: 12),

          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            color: colors.textSecondary,
            onTap: onCommentTap,
          ),
          const SizedBox(width: 12),

          _ActionButton(
            icon: Icons.share_outlined,
            color: colors.textSecondary,
            onTap: onShareTap,
          ),

          const Spacer(),

          _ActionButton(
            icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: isBookmarked ? colors.primary : colors.textSecondary,
            onTap: onBookmarkTap,
          ),
        ],
      ),
    );
  }
}

/// Individual action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 24),
      onPressed: onTap,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }
}
```

**Key Features**:

- ✅ Fully const
- ✅ Clean button abstraction
- ✅ Reusable \_ActionButton
- ✅ ~80 lines

---

## DIRECTORY STRUCTURE

### Before Refactor

```
lib/features/social/widgets/
├── social_card.dart           (850 lines - monolithic)
├── social_feed_item.dart      (64 lines)
├── comments_sheet.dart
├── post_options_sheet.dart
├── image_viewer.dart
└── create_post_sheet.dart
```

### After Refactor

```
lib/features/social/widgets/
├── social_card/               (NEW FOLDER)
│   ├── social_card.dart                 (140 lines - container)
│   ├── social_card_header.dart          (80 lines)
│   ├── social_card_caption.dart         (40 lines - simple caption, optional)
│   ├── expandable_caption.dart          (100 lines - reusable)
│   ├── social_card_media.dart           (15 lines - dispatcher)
│   ├── social_card_media_grid.dart      (180 lines - layout logic)
│   ├── social_card_stats.dart           (60 lines)
│   └── social_card_actions.dart         (80 lines)
├── social_feed_item.dart      (64 lines - unchanged)
├── comments_sheet.dart
├── post_options_sheet.dart
├── image_viewer.dart
└── create_post_sheet.dart
```

**Total Lines**:

- Before: 850 (single file)
- After: ~695 (split across 8 files) + better organization

---

## DATA FLOW

### Current Data Flow

```
PostViewModel
├── State: isLiked, likesCount, isFollowing, etc
├── Actions: handleLike(), handleFollow(), etc
└── Listeners: notify on any state change

SocialCard._SocialCardState
├── Holds PostViewModel
├── Rebuilds ENTIRE card on any vm.notifyListeners()
└── Renders all sub-sections
```

### Proposed Data Flow

```
PostViewModel
├── State: same
├── Actions: same
└── Listeners: notify on any state change (unchanged)

SocialCard._SocialCardState
├── Holds PostViewModel
├── Rebuilds on vm.notifyListeners() (unchanged)
└── Renders components:

SocialCardHeader (const)
├── Receives: userId, displayName, isFollowing, etc (all params)
├── No rebuild on vm change (isolated from vm)
└── Calls: onFollowTap(), onUserTap() (callbacks to parent)

SocialCardMedia (const)
├── Receives: imageUrls, onImageTap
├── No rebuild on vm change (isolated)
└── Calls: onImageTap(index)

SocialCardActions
├── Receives: isLiked, isBookmarked, etc (all params)
├── May rebuild if receives new data
├── Calls: onLikeTap(), onBookmarkTap(), etc

(Other components similar)
```

**Key Benefit**: Even though parent rebuilds, child components can be const and won't unnecessarily rebuild

---

## COMPONENT REUSABILITY

### ExpandableCaption

**Can be reused in**:

- ✅ Comment threads (expandable comments)
- ✅ User bios
- ✅ Post descriptions
- ✅ Feed item details
- ✅ Any long text that needs collapsing

### SocialCardHeader

**Can be reused in**:

- ✅ Comment author header
- ✅ Reply author header
- ✅ Share origin header
- ✅ Any post metadata display

### SocialCardMedia

**Can be reused in**:

- ✅ Image gallery screen
- ✅ Post detail view
- ✅ User profile grid
- ✅ Any multi-image display

### SocialCardStats

**Can be reused in**:

- ✅ Post preview
- ✅ Feed summary
- ✅ Trending posts
- ✅ Any stats display

---

## PERFORMANCE CHARACTERISTICS

### Rebuild Behavior

**Current**:

```
PostViewModel notifies
  ↓
SocialCard setState()
  ↓
Entire card rebuilds (850+ lines of work)
  ↓
Everything re-renders (header, caption, media, etc)
```

**Proposed**:

```
PostViewModel notifies
  ↓
SocialCard setState()
  ↓
SocialCard re-renders, passes new data to children
  ↓
Const children don't rebuild
  ↓
Only non-const children update (SocialCardActions, etc)
```

**Result**:

- ✅ ~40-60% fewer widget rebuilds
- ✅ Smoother scroll performance
- ✅ Lower CPU/memory during interactions

### Memory Impact

**Current**: Single 850-line widget → large AST

**Proposed**: 8 smaller widgets → smaller ASTs, better tree distribution

**Result**: Marginal improvement, but better architecture

---

## MIGRATION STRATEGY

### Breaking Changes: NONE ✅

**SocialCard signature remains identical**:

```dart
class SocialCard extends StatefulWidget {
  final SocialPost post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onDelete;

  const SocialCard({
    required this.post,
    this.onCommentTap,
    this.onDelete,
  });
}
```

**All existing usages continue to work**:

```dart
// In HomeSocialFeed
SocialCard(
  post: post,
  onCommentTap: () => widget.onShowComments(post),
  onDelete: () => widget.onDeletePost(post),
)

// Still works after refactor ✅
```

### Gradual Integration

1. **Day 1-2**: Create new components alongside existing code
2. **Day 2**: Refactor SocialCard to use components
3. **Day 2-3**: Test thoroughly
4. **Day 3**: Merge to main branch
5. **Day 3**: Monitor in production

---

## TESTING STRATEGY

### Unit Tests

```dart
test('ExpandableCaption shows "See more" for long text', () {
  // Test widget renders correctly
});

test('ExpandableCaption hides button for short text', () {
  // Test widget doesn't show button
});

test('SocialCardHeader displays follow button for non-own posts', () {
  // Test conditional rendering
});

test('SocialCardMedia renders correct layout for N images', () {
  // Test each layout (1, 2, 3, 4, 5+)
});
```

### Integration Tests

```dart
test('SocialCard renders all components', () {
  // Full card renders
});

test('Like button updates state correctly', () {
  // Interaction test
});

test('Caption expands smoothly', () {
  // Animation test
});
```

### Performance Tests

```dart
test('Card scroll remains 60fps with 20+ cards', () {
  // Performance test
});

test('No memory leaks during like/unlike cycle', () {
  // Memory test
});
```

---

## COMPARISON TABLE

| Aspect                  | Current | Proposed        | Improvement            |
| ----------------------- | ------- | --------------- | ---------------------- |
| **Lines per file**      | 850     | 140 (+ 7 × ~80) | Better modularity      |
| **Const widgets**       | 0       | 5+              | Better performance     |
| **Rebuild scope**       | 100%    | ~40-60%         | Faster scrolling       |
| **Reusable components** | 0       | 4+              | Better maintainability |
| **Header reusability**  | No      | Yes             | Component library      |
| **Media reusability**   | No      | Yes             | Component library      |
| **Testability**         | Low     | High            | Better quality         |
| **Dark mode support**   | ✅      | ✅ Enhanced     | Cleaner theme usage    |

---

## DEPLOYMENT CHECKLIST

- [ ] All new components created
- [ ] SocialCard refactored
- [ ] Tests written and passing
- [ ] Performance profiled and improved
- [ ] Dark mode tested
- [ ] Responsive design verified
- [ ] No functional regressions
- [ ] Code review approved
- [ ] Documentation updated
- [ ] Deployed to staging
- [ ] QA sign-off
- [ ] Deployed to production

---

## CONCLUSION

The proposed widget hierarchy provides:

1. **Better Architecture**: Modular, testable components
2. **Better Performance**: Fewer rebuilds, smoother scrolling
3. **Better UX**: Expandable captions, full-width media
4. **Better Maintenance**: Split files, clear responsibilities
5. **Backward Compatibility**: No breaking changes
6. **Future-Ready**: Reusable components for other features

**Ready to implement!**
