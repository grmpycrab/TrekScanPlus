import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Expandable FAB group with an externally-observable expanded state.
///
/// [expandedNotifier] is owned by the parent (HomeScreen) so the parent can
/// show a backdrop overlay and collapse the FAB when the overlay is tapped.
class HomeActionButtons extends StatefulWidget {
  const HomeActionButtons({
    super.key,
    required this.onCreatePost,
    required this.onShowCalendar,
    required this.expandedNotifier,
  });

  final VoidCallback onCreatePost;
  final VoidCallback onShowCalendar;

  /// Shared state between the FAB and the parent's backdrop overlay.
  final ValueNotifier<bool> expandedNotifier;

  @override
  State<HomeActionButtons> createState() => _HomeActionButtonsState();
}

class _HomeActionButtonsState extends State<HomeActionButtons> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    widget.expandedNotifier.addListener(_onNotifierChanged);
  }

  @override
  void didUpdateWidget(HomeActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expandedNotifier != widget.expandedNotifier) {
      oldWidget.expandedNotifier.removeListener(_onNotifierChanged);
      widget.expandedNotifier.addListener(_onNotifierChanged);
    }
  }

  @override
  void dispose() {
    widget.expandedNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _onNotifierChanged() {
    // Parent collapsed us (e.g. backdrop tap)
    if (!widget.expandedNotifier.value && _expanded) {
      setState(() => _expanded = false);
    }
  }

  void _toggle() {
    final next = !_expanded;
    setState(() => _expanded = next);
    widget.expandedNotifier.value = next;
  }

  void _collapse() {
    setState(() => _expanded = false);
    widget.expandedNotifier.value = false;
  }

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
            _collapse();
            widget.onShowCalendar();
          },
        ),
        _buildSubButton(
          heroTag: 'create_post_fab',
          colors: colors,
          label: 'Create Post',
          child: const Icon(Icons.edit, color: Colors.white),
          onPressed: () {
            _collapse();
            widget.onCreatePost();
          },
        ),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggle,
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
                          color: colors.surface,
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.text,
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
