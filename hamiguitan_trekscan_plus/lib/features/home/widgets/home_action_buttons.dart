import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Expandable FAB group: main + button, calendar sub-button, create-post
/// sub-button. All expansion state is managed internally via [StatefulBuilder]
/// so the parent doesn't need to track it.
class HomeActionButtons extends StatefulWidget {
  const HomeActionButtons({
    super.key,
    required this.onCreatePost,
    required this.onShowCalendar,
  });

  final VoidCallback onCreatePost;
  final VoidCallback onShowCalendar;

  @override
  State<HomeActionButtons> createState() => _HomeActionButtonsState();
}

class _HomeActionButtonsState extends State<HomeActionButtons> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildSubButton(
          heroTag: 'calendar_fab',
          colors: colors,
          label: 'View Calendar',
          child: Image.asset(
            'assets/icons/calendar.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() => _expanded = false);
            widget.onShowCalendar();
          },
        ),
        _buildSubButton(
          heroTag: 'create_post_fab',
          colors: colors,
          label: 'Create Post',
          child: const Icon(Icons.edit, color: Colors.white),
          onPressed: () {
            setState(() => _expanded = false);
            widget.onCreatePost();
          },
        ),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: () => setState(() => _expanded = !_expanded),
          backgroundColor: colors.primary,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _expanded ? Icons.close : Icons.add,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubButton({
    required String heroTag,
    required AppTheme colors,
    required String label,
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, animation) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnim, child: c),
        );
      },
      child: _expanded
          ? Container(
              key: ValueKey('${heroTag}_row'),
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    offset: _expanded ? Offset.zero : const Offset(0.25, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: _expanded ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    heroTag: heroTag,
                    onPressed: onPressed,
                    backgroundColor: colors.primary,
                    child: child,
                  ),
                ],
              ),
            )
          : SizedBox.shrink(key: ValueKey('${heroTag}_empty')),
    );
  }
}
