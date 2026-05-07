import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Expandable caption with "See more" / "See less" behavior (Facebook-like).
///
/// Collapses long text to [maxLines] and shows a "See more" button if text overflows.
/// Supports emoji, hashtags, mentions, and line breaks. Smooth fade animation.
///
/// Phase 3 Polish:
/// - Enhanced animation timing (250ms for smoother fade)
/// - Better text wrapping & word breaking for long captions
/// - Improved edge case handling (emojis, special characters)
/// - Optimized padding for visual consistency
class ExpandableCaption extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final VoidCallback? onExpand;

  const ExpandableCaption({
    super.key,
    required this.text,
    this.maxLines = 3,
    this.style,
    this.onExpand,
  });

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure if text overflows (handles emoji, special chars, line breaks)
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.text,
            style: widget.style ?? const TextStyle(fontSize: 14, height: 1.4),
          ),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(
          maxWidth: constraints.maxWidth - 32,
        ); // Account for padding

        final shouldShowMore = textPainter.didExceedMaxLines;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated text expansion with smoother timing (250ms)
              AnimatedCrossFade(
                firstChild: Text(
                  widget.text,
                  maxLines: widget.maxLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style:
                      widget.style ??
                      const TextStyle(fontSize: 14, height: 1.4),
                ),
                secondChild: Text(
                  widget.text,
                  softWrap: true,
                  style:
                      widget.style ??
                      const TextStyle(fontSize: 14, height: 1.4),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),

              // See more / See less button (only if text overflows)
              if (shouldShowMore)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _isExpanded = !_isExpanded);
                      // Track expansion for analytics
                      if (_isExpanded) {
                        widget.onExpand?.call();
                      }
                    },
                    child: Text(
                      _isExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        color: colors.primary,
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
