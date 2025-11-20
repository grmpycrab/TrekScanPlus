import 'package:flutter/material.dart';
import '../theme/color.dart';

class TrekTips extends StatefulWidget {
  const TrekTips({super.key});

  @override
  State<TrekTips> createState() => _TrekTipsState();
}

class _TrekTipsState extends State<TrekTips> {
  final Map<String, bool> _expandedSections = {
    'Best Time to Visit': false,
    'Pre-Trek Preparation': false,
    'Essential Packing': false,
    'Photography Tips': false,
    'Local Community Support': false,
    'Recovery Tips': false,
    'Mental Preparation': false,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ExpansionPanelList(
          elevation: 0,
          expandedHeaderPadding: EdgeInsets.zero,
          animationDuration: const Duration(milliseconds: 200),
          expansionCallback: (index, isExpanded) {
            setState(() {
              final title = _sections.keys.elementAt(index);
              _expandedSections[title] = !(_expandedSections[title] ?? false);
            });
          },
          children: _sections.entries.map((entry) {
            return ExpansionPanel(
              headerBuilder: (context, isExpanded) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              body: Column(
                children: entry.value.map((tip) => _buildTipItem(tip)).toList(),
              ),
              isExpanded: _expandedSections[entry.key] ?? false,
            );
          }).toList(),
        ),
      ),
    );
  }

  final Map<String, List<String>> _sections = {
    'Best Time to Visit': [
      'Dry season is better. Months like November to April are recommended to avoid heavy rains.',
    ],
    'Pre-Trek Preparation': [
      'Check updates before going - Trail status, campsite condition, and permit processes may change.',
      'Let someone know your itinerary and expected return time.',
      'Train your legs and stamina beforehand with practice hikes and cardio.',
    ],
    'Essential Packing': [
      'Lightweight and quick-dry clothing',
      'Rain gear / waterproof jacket',
      'Good hiking boots with ankle support',
      'Water or water purification tools',
      'Sun protection (hat, sunglasses, sunscreen)',
      'Layers for cold/damp nights',
      'Headlamp with spare batteries',
      'First aid kit',
      'Insect repellent',
      'Energy snacks and food',
      'Small biodegradable soap (use away from water sources)',
    ],
    'Photography Tips': [
      'Bring a good camera or binoculars for birding',
      'Check rules on flash photography and drone use',
      'Protect equipment from moisture',
      'Best lighting is early morning or late afternoon',
    ],
    'Local Community Support': [
      'Hire local guides and porters',
      'Buy locally made food or souvenirs',
      'Respect indigenous peoples\' customs',
      'Learn basic local phrases',
      'Support local conservation efforts',
    ],
    'Recovery Tips': [
      'Leave enough rest days after the trek',
      'Stay hydrated during and after the trek',
      'Do light stretches to prevent muscle stiffness',
      'Get adequate rest and nutrition',
    ],
    'Mental Preparation': [
      'Be patient with slow progress',
      'Enjoy the small things (birds, moss, silence)',
      'Accept that weather may force plan changes',
      'Stay positive and support fellow trekkers',
      'Practice mindfulness and appreciate nature',
    ],
  };

  Widget _buildTipItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
