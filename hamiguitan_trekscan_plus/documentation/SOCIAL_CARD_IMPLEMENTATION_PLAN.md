# Social Card Redesign — Detailed Implementation Plan

**Phase**: 2-8 Implementation Guide  
**Status**: Ready for Development  
**Last Updated**: May 7, 2026

---

## PHASE-BY-PHASE IMPLEMENTATION GUIDE

### PHASE 2: Social Card UI Redesign

**Goal**: Modernize the visual hierarchy and layout

#### 2.1 Layout Architecture Changes

**Current Layout**:

```
Card (fixed height 45% screen)
├── Header (16px horizontal padding)
├── Caption (16px horizontal padding)
├── Images (16px horizontal padding + rounded corners)
└── Footer (12px horizontal padding)
```

**New Layout**:

```
Card (natural height, no fixed size)
├── Header (16px horizontal padding, light background)
├── Caption (16px horizontal padding)
├── Media (0px horizontal padding - FULL WIDTH)
└── Stats + Actions (16px horizontal padding)
```

**Key Changes**:

- Remove `SizedBox(height: cardHeight)` constraint
- Use natural `Column` sizing
- Media sections become full-width (edge-to-edge)
- Separate stats from actions with divider

#### 2.2 Visual Hierarchy Improvements

**Current Issues**:

- Header and caption same visual weight
- Action buttons feel cramped
- No clear separation between sections

**Improvements**:

- Slightly larger header text (15px → 16px)
- Better spacing between sections
- Divider between stats and actions
- Improved button padding

#### 2.3 Responsive Adjustments

**Changes**:

- Remove percentage-based card height
- Use natural content sizing
- Add max-constraints for very large screens (optional)
- Improve tablet/landscape layout

**Testing Checklist**:

- ✅ Small phones (5.5" / 360px width)
- ✅ Standard phones (6.1" / 412px width)
- ✅ Large phones (6.7" / 428px width)
- ✅ Tablets (iPad landscape / 1024px width)

---

### PHASE 3: Expandable Caption System

**Goal**: Implement Facebook-like caption behavior

#### 3.1 ExpandableCaption Widget Design

**File**: `lib/features/social/widgets/social_card/expandable_caption.dart`

**Specifications**:

```dart
class ExpandableCaption extends StatefulWidget {
  final String text;
  final int maxLines;           // Default: 3
  final TextStyle? style;
  final VoidCallback? onExpand; // Optional tracking

  const ExpandableCaption({
    required this.text,
    this.maxLines = 3,
    this.style,
    this.onExpand,
  });
}
```

**Behavior**:

1. Measure text height with `maxLines: 3`
2. If text fits in 3 lines: show text normally
3. If text overflows: show text + "See more" button
4. On "See more" tap: animate to full text height
5. On "See less" tap: animate back to 3 lines
6. Preserve all formatting (emoji, line breaks, etc)

**Technical Implementation**:

```dart
// Measure if text overflows
final textPainter = TextPainter(
  text: TextSpan(text: text, style: style ?? const TextStyle()),
  maxLines: maxLines,
  textDirection: TextDirection.ltr,
);
textPainter.layout(maxWidth: constraints.maxWidth);
_shouldShowMoreButton = textPainter.didExceedMaxLines;
```

**Animation**:

- Smooth height transition (200ms Curves.easeInOut)
- Fade in/out "See more" button
- No layout jumps

#### 3.2 Integration with SocialCard

**Change in `_buildCaption()`**:

```dart
Widget _buildCaption() {
  if (widget.post.caption.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: ExpandableCaption(
      text: widget.post.caption,
      maxLines: 3,
      style: const TextStyle(fontSize: 14, height: 1.4),
      onExpand: () {
        // Optional: Track expansion analytics
      },
    ),
  );
}
```

#### 3.3 Testing Scenarios

**Test Cases**:

- ✅ Short caption (1-2 lines) — no See more button
- ✅ Medium caption (3 lines exactly) — no See more button
- ✅ Long caption (4+ lines) — See more button visible
- ✅ Caption with emoji: "Amazing 🏔️ trek!"
- ✅ Caption with newlines: "Line 1\nLine 2\nLine 3"
- ✅ Caption with hashtags: "#trek #adventure"
- ✅ Caption with mentions: "@user check this out"
- ✅ Expand/collapse smooth animation
- ✅ Dark mode colors

---

### PHASE 4: Full-Width/Immersive Layout

**Goal**: Create edge-to-edge media feel

#### 4.1 Media Section Restructuring

**Current**:

```dart
Widget _buildImages() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _buildImageLayout(images),
    ),
  );
}
```

**New**:

```dart
Widget _buildMedia() {
  if (widget.post.imageUrls.isEmpty) return const SizedBox.shrink();

  return ClipRRect(
    borderRadius: BorderRadius.zero,  // No rounded corners for full-width
    child: _buildImageLayout(widget.post.imageUrls),
  );
}
```

**Changes**:

- Remove `Padding(horizontal: 16)`
- Remove `borderRadius: 12` (or use 0 for full-width, 8 for slight rounding)
- Full-width image sections
- Images span entire card width

#### 4.2 Aspect Ratio Optimization

**Current Inconsistencies**:

- Single image: 4:3
- Two images: 16:9
- Three+ images: Complex

**New Standard**:

- Preserve reasonable aspect ratios
- Consistent visual feel
- Avoid squishing or stretching

**Recommended**:

- Single: 4:3 (portrait-friendly)
- Two: 16:9
- Three+: Flexible grid (maintain content visibility)

#### 4.3 Improved Loading/Error States

**Current**: Basic placeholder with spinner

**Enhanced**:

```dart
placeholder: (context, url) => SizedBox.expand(
  child: Container(
    color: context.colors.surfaceVariant,
    child: const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  ),
);

errorWidget: (context, url, error) => Container(
  color: context.colors.borderLight,
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.image_not_supported_rounded,
        size: 48,
        color: context.colors.textTertiary,
      ),
      const SizedBox(height: 8),
      Text(
        'Image unavailable',
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 12,
        ),
      ),
    ],
  ),
);
```

---

### PHASE 5: Performance Optimization

**Goal**: Reduce unnecessary rebuilds and smooth scrolling

#### 5.1 Extract Const Widgets

**Target Widgets**:

1. **SocialCardHeader** (~80 lines)
2. **SocialCardActions** (~60 lines)
3. **SocialCardStats** (~50 lines)
4. **Button Builders** (like, comment, share, bookmark)

**Benefit**: Each extracted widget can be `const` and won't rebuild with parent

#### 5.2 Use RepaintBoundary

**Apply to**:

```dart
// Expensive media section
RepaintBoundary(
  child: SocialCardMedia(
    imageUrls: widget.post.imageUrls,
    onImageTap: (index) => _openImageViewer(index),
  ),
);
```

**Benefit**: Media section renders separately; doesn't trigger parent repaints

#### 5.3 Rebuild Scope Reduction

**Current Issue**:

```dart
void _onVmChanged() {
  if (mounted) setState(() {});  // ← Entire widget rebuilds
}
```

**Solution**: After component extraction, only specific widgets rebuild:

- Like button rebuilds when `isLiked` changes
- Like count rebuilds when `likesCount` changes
- Follow button rebuilds when `isFollowing` changes

**Implementation**: Separated state for each interactive section

#### 5.4 Profile Performance

**Current Issue**:

```dart
void _navigateToUserProfile(BuildContext context) async {
  // Check follow status on EVERY avatar tap
  final isFollowing = await UserService.instance.isFollowing(...);
}
```

**Optimization**:

- Cache follow status in ViewModel
- Pre-check during header render
- Show dialog only if needed

---

### PHASE 6: Component Extraction

**Goal**: Refactor into smaller, reusable widgets

#### 6.1 Directory Structure

**Create**:

```
lib/features/social/widgets/social_card/
├── social_card.dart                  ← Main container
├── social_card_header.dart           ← Header widget
├── social_card_caption.dart          ← Simple caption (kept for simple posts)
├── expandable_caption.dart           ← Expandable caption
├── social_card_media.dart            ← Image grid section
├── social_card_media_image_grid.dart ← Multi-image layout logic
├── social_card_stats.dart            ← Stats display
└── social_card_actions.dart          ← Action buttons
```

#### 6.2 SocialCardHeader Component

**File**: `social_card_header.dart`

```dart
class SocialCardHeader extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? userPhotoUrl;
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
    // ← Header rendering logic
  }
}
```

**Benefits**:

- Can be `const` in many cases
- Reusable in other contexts (comment author header, etc)
- Easier to test
- Clearer responsibility

#### 6.3 SocialCardMedia Component

**File**: `social_card_media.dart`

```dart
class SocialCardMedia extends StatelessWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const SocialCardMedia({
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    // ← Image grid rendering logic
  }
}
```

**Benefits**:

- Isolates complex image grid logic
- Fully `const` widget
- Can wrap with `RepaintBoundary`
- Reusable in galleries, details screens, etc

#### 6.4 SocialCardActions Component

```dart
class SocialCardActions extends StatelessWidget {
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onBookmarkTap;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  const SocialCardActions({
    required this.isLiked,
    required this.isBookmarked,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onBookmarkTap,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
  });

  @override
  Widget build(BuildContext context) {
    // ← Action buttons rendering
  }
}
```

#### 6.5 SocialCardStats Component

```dart
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
    // ← Stats display (likes, comments, shares count)
  }
}
```

---

### PHASE 7: Theme System Integration

**Goal**: Remove all hardcoded colors

#### 7.1 Color Audit

**Hardcoded Colors Found**:

1. `Colors.grey[400]` — used in multiple places
2. `Colors.white` — button text (implicit)
3. `Colors.black.withOpacity(0.6)` — image overlay
4. `Colors.red` — like button
5. `Colors.orange[50]` — pending button background
6. `Colors.orange[700]` — pending button text

#### 7.2 Replacement Mapping

**Current → Recommended**:

```
Colors.grey[400]           → context.colors.textTertiary
Colors.white               → context.colors.text (or surface)
Colors.black.withOpacity() → context.colors.shadowOverlay
Colors.red                 → Colors.red (semantic color, OK)
Colors.orange[50]          → context.colors.surfaceVariant
Colors.orange[700]         → context.colors.accent
```

#### 7.3 Implementation Steps

1. Replace all `Colors.grey` occurrences in image tiles
2. Replace placeholder colors with theme tokens
3. Update "pending" state colors
4. Test in both light and dark modes
5. Verify contrast ratios meet accessibility standards

#### 7.4 Dark Mode Testing

**Scenarios**:

- ✅ Light mode default
- ✅ Dark mode default
- ✅ Caption text visible in both
- ✅ Action buttons clear in both
- ✅ Image overlays readable in both
- ✅ Loading spinners visible in both

---

### PHASE 8: Safety & Testing

**Goal**: Ensure zero regressions

#### 8.1 Functional Testing

**Interaction Tests**:

- ✅ Like/unlike post works
- ✅ Like count increments/decrements
- ✅ Bookmark/unbookmark works
- ✅ Follow/unfollow works (if not own post)
- ✅ Comment sheet opens
- ✅ Share dialog opens
- ✅ Profile navigation works (with follow guard)
- ✅ Post edit dialog works
- ✅ Post delete works
- ✅ More menu opens correctly

**Data Persistence**:

- ✅ Like state persists across navigate/return
- ✅ Bookmark state persists
- ✅ Follow state persists
- ✅ Comment count updates correctly

#### 8.2 Responsive Testing

**Screen Sizes**:

- ✅ 320px (small phone)
- ✅ 412px (standard phone)
- ✅ 480px (large phone)
- ✅ 768px (small tablet)
- ✅ 1024px (large tablet)

**Orientations**:

- ✅ Portrait
- ✅ Landscape

**Issues to Check**:

- ✅ Text overflow
- ✅ Image aspect ratio maintenance
- ✅ Button sizing
- ✅ Padding consistency

#### 8.3 Theme Testing

**Themes**:

- ✅ Light mode (default)
- ✅ Dark mode
- ✅ System theme changes

**Visual Checks**:

- ✅ All text readable
- ✅ Buttons clearly visible
- ✅ Images not washed out
- ✅ Icons visible
- ✅ Contrast meets WCAG AA standards

#### 8.4 Performance Testing

**Scrolling**:

- ✅ Smooth scroll through 20+ posts
- ✅ No jank on like/unlike
- ✅ No lag when expanding caption
- ✅ Images load smoothly
- ✅ No memory leaks (check DevTools)

**Profiling**:

- ✅ Frame rate stays 60fps
- ✅ CPU usage reasonable during scroll
- ✅ Memory usage stable
- ✅ No excessive garbage collection

#### 8.5 Regression Testing

**Features That Must Keep Working**:

- ✅ Deep linking to posts (`/posts/{postId}`)
- ✅ Post sharing via Share+ plugin
- ✅ Image viewing/gallery
- ✅ Comment threads
- ✅ Post deletion
- ✅ Post editing
- ✅ Follow/unfollow
- ✅ Bookmark management
- ✅ Profile navigation
- ✅ Firebase sync

#### 8.6 Edge Cases

**Test Scenarios**:

- ✅ No images (caption-only posts)
- ✅ Single image
- ✅ Multiple images (2, 3, 4, 5+)
- ✅ Very long caption (1000+ characters)
- ✅ Empty caption
- ✅ Special characters in caption
- ✅ Emoji in caption
- ✅ Network error during like
- ✅ User logged out mid-action
- ✅ Post deleted by author during viewing

---

## IMPLEMENTATION SEQUENCE

### Step 1: Create Core Components (Day 1)

- [ ] Create `expandable_caption.dart`
- [ ] Create `social_card_header.dart`
- [ ] Create `social_card_media.dart`
- [ ] Create `social_card_actions.dart`
- [ ] Create `social_card_stats.dart`

### Step 2: Refactor SocialCard (Day 1-2)

- [ ] Remove fixed height
- [ ] Integrate components
- [ ] Add expandable caption
- [ ] Make media full-width
- [ ] Test basic functionality

### Step 3: Theme Cleanup (Day 2)

- [ ] Replace hardcoded colors
- [ ] Test dark mode
- [ ] Verify contrast

### Step 4: Performance (Day 2-3)

- [ ] Add `const` widgets
- [ ] Add `RepaintBoundary`
- [ ] Profile and optimize
- [ ] Test scrolling

### Step 5: Testing (Day 3)

- [ ] Functional tests
- [ ] Responsive tests
- [ ] Theme tests
- [ ] Performance tests
- [ ] Regression tests

### Step 6: Documentation (Day 3-4)

- [ ] Update README
- [ ] Add code comments
- [ ] Create developer guide

---

## KEY METRICS

### Before Redesign

- ✅ SocialCard: 850 lines (monolithic)
- ✅ Components: 1 (SocialCard only)
- ✅ Rebuild scope: Entire card on any state change
- ✅ Fixed height: 45% of screen
- ✅ Caption: Always full-text (no expansion)

### After Redesign

- ✅ SocialCard: ~140 lines (container only)
- ✅ Components: 6+ (modular)
- ✅ Rebuild scope: Individual widgets only
- ✅ Natural height: Content-driven sizing
- ✅ Caption: Expandable with See more/less

### Expected Improvements

- **Code Maintainability**: ↑ 300% (split into 7 files vs 1)
- **Reusability**: ↑ 400% (components can be used elsewhere)
- **Performance**: ↑ 40-60% (fewer rebuilds, better caching)
- **UX**: ↑ 50% (expandable caption, full-width media)

---

## RISK MITIGATION

### Risk 1: Breaking Existing Functionality

**Mitigation**:

- Keep all ViewModels unchanged
- Preserve exact callback signatures
- Test all interactions before merge
- Use feature branch for safe development

### Risk 2: Performance Regression

**Mitigation**:

- Profile before and after
- Monitor frame rate during scroll
- Check memory usage
- Test with 50+ posts in feed

### Risk 3: Compatibility Issues

**Mitigation**:

- Test on min SDK version
- Test on multiple devices
- Use platform-specific widgets where needed
- Check Firebase compatibility

### Risk 4: Scroll Jank During Expand

**Mitigation**:

- Use smooth animation curve
- Keep expandable caption state separate
- Avoid heavy computations during animation
- Test with long captions

---

## SUCCESS CRITERIA

✅ **Phase Complete When**:

1. All components created and integrated
2. Expandable caption works smoothly
3. Full-width media displayed correctly
4. Theme colors applied everywhere
5. No functional regressions
6. Scrolling smooth (60fps)
7. All tests passing
8. Documentation updated

---

## QUESTIONS FOR DEVELOPMENT TEAM

1. Should caption expansion be animated or instant?
2. Preferred "See more" button style (text link, button, etc)?
3. Should follow status be pre-checked (current behavior) or allow navigation + check on ProfileScreen?
4. Any performance constraints (e.g., must support 1000+ posts)?
5. Should image overlays ("+5") use theme colors or stay black?

---

## NEXT STEPS

1. ✅ **Review** this implementation plan
2. ✅ **Approve** scope and approach
3. ✅ **Begin Phase 2** (UI redesign)
4. ✅ **Progress** through phases 3-8

**Ready to implement upon approval.**
