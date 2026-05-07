import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Expandable caption with "See more" / "See less" behavior (Facebook-like).
///
/// Collapses long text to [maxLines] and shows a "See more" button if text overflows.
/// Supports emoji, hashtags, mentions, and line breaks. Smooth fade animation.
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
        // Measure if text overflows
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.text,
            style: widget.style ?? const TextStyle(fontSize: 14, height: 1.4),
          ),
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
                  style:
                      widget.style ??
                      const TextStyle(fontSize: 14, height: 1.4),
                ),
                secondChild: Text(
                  widget.text,
                  style:
                      widget.style ??
                      const TextStyle(fontSize: 14, height: 1.4),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
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
