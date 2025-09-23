import 'package:flutter/material.dart';

class DoAndDont extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSegmentTapped;

  const DoAndDont({
    super.key,
    required this.selectedIndex,
    required this.onSegmentTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildSegment(0, 'Tips & Tricks'),
                _buildSegment(1, "Do's & Dont's"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (selectedIndex == 0) _buildTipsList(),
        ],
      ),
    );
  }

  Widget _buildSegment(int index, String text) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSegmentTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF252B30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tips',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildTipCard(1),
        _buildTipCard(2),
        _buildTipCard(3),
      ],
    );
  }

  Widget _buildTipCard(int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Tip content will go here',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
