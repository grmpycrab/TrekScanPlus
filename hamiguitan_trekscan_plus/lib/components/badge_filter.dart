import 'package:flutter/material.dart';

class BadgeFilterBottomSheet extends StatefulWidget {
  final Set<String> selectedRarities;
  final Set<String> selectedCategories;
  final Set<String> selectedDifficulties;
  final Function(Set<String>, Set<String>, Set<String>) onFiltersChanged;

  const BadgeFilterBottomSheet({
    super.key,
    required this.selectedRarities,
    required this.selectedCategories,
    required this.selectedDifficulties,
    required this.onFiltersChanged,
  });

  @override
  State<BadgeFilterBottomSheet> createState() => _BadgeFilterBottomSheetState();
}

class _BadgeFilterBottomSheetState extends State<BadgeFilterBottomSheet> {
  late Set<String> _tempRarities;
  late Set<String> _tempCategories;
  late Set<String> _tempDifficulties;

  @override
  void initState() {
    super.initState();
    _tempRarities = Set.from(widget.selectedRarities);
    _tempCategories = Set.from(widget.selectedCategories);
    _tempDifficulties = Set.from(widget.selectedDifficulties);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Badges',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    _buildFilterSection(
                      title: 'Rarity',
                      items: [
                        'common',
                        'uncommon',
                        'rare',
                        'epic',
                        'legendary',
                      ],
                      selectedItems: _tempRarities,
                      onChanged: (item, isSelected) {
                        setState(() {
                          if (isSelected) {
                            _tempRarities.add(item);
                          } else {
                            _tempRarities.remove(item);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterSection(
                      title: 'Difficulty',
                      items: ['easy', 'medium', 'hard'],
                      selectedItems: _tempDifficulties,
                      onChanged: (item, isSelected) {
                        setState(() {
                          if (isSelected) {
                            _tempDifficulties.add(item);
                          } else {
                            _tempDifficulties.remove(item);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterSection(
                      title: 'Category',
                      items: [
                        'trail_completion',
                        'biodiversity',
                        'conservation',
                        'distance_elevation',
                      ],
                      selectedItems: _tempCategories,
                      onChanged: (item, isSelected) {
                        setState(() {
                          if (isSelected) {
                            _tempCategories.add(item);
                          } else {
                            _tempCategories.remove(item);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempRarities.clear();
                        _tempCategories.clear();
                        _tempDifficulties.clear();
                      });
                      widget.onFiltersChanged(
                        _tempRarities,
                        _tempCategories,
                        _tempDifficulties,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onFiltersChanged(
                        _tempRarities,
                        _tempCategories,
                        _tempDifficulties,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required List<String> items,
    required Set<String> selectedItems,
    required Function(String, bool) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => FilterChip(
                  label: Text(
                    item.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedItems.contains(item)
                          ? Colors.white
                          : Colors.grey[700],
                    ),
                  ),
                  selected: selectedItems.contains(item),
                  onSelected: (isSelected) => onChanged(item, isSelected),
                  backgroundColor: Colors.grey[200],
                  selectedColor: const Color(0xFF252B30),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
