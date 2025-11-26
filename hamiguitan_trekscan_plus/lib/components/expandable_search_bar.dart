import 'package:flutter/material.dart';
import '../theme/color.dart';

/// A reusable expandable search bar component that animates from right to left
/// Displays a title when collapsed and a search field when expanded
class ExpandableSearchBar extends StatefulWidget {
  final String title;
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onExpanded;
  final VoidCallback? onCollapsed;

  const ExpandableSearchBar({
    super.key,
    required this.title,
    this.hintText = 'Search...',
    required this.onSearchChanged,
    this.onExpanded,
    this.onCollapsed,
  });

  @override
  State<ExpandableSearchBar> createState() => _ExpandableSearchBarState();
}

class _ExpandableSearchBarState extends State<ExpandableSearchBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _searchController.addListener(() {
      widget.onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
        widget.onExpanded?.call();
        // Focus the text field after animation starts
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _searchFocusNode.requestFocus();
          }
        });
      } else {
        _animationController.reverse();
        _searchController.clear();
        _searchFocusNode.unfocus();
        widget.onCollapsed?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!_isExpanded)
          const Text(
            'Community Feed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_isExpanded)
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        const Spacer(),
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.close : Icons.search,
            color: AppColors.primary,
          ),
          onPressed: _toggleSearch,
        ),
      ],
    );
  }
}
