import 'package:flutter/material.dart';
import '../theme/color.dart';

class TrekTips extends StatelessWidget {
  const TrekTips({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Best Time to Visit', [
              'Dry season is better. Months like November to April are recommended to avoid heavy rains.',
            ]),
            _buildSection('Pre-Trek Preparation', [
              'Check updates before going - Trail status, campsite condition, and permit processes may change.',
              'Let someone know your itinerary and expected return time.',
              'Train your legs and stamina beforehand with practice hikes and cardio.',
            ]),
            _buildSection('Essential Packing', [
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
            ]),
            _buildSection('Photography Tips', [
              'Bring a good camera or binoculars for birding',
              'Check rules on flash photography and drone use',
              'Protect equipment from moisture',
              'Best lighting is early morning or late afternoon',
            ]),
            _buildSection('Local Community Support', [
              'Hire local guides and porters',
              'Buy locally made food or souvenirs',
              'Respect indigenous peoples\' customs',
              'Learn basic local phrases',
              'Support local conservation efforts',
            ]),
            _buildSection('Recovery Tips', [
              'Leave enough rest days after the trek',
              'Stay hydrated during and after the trek',
              'Do light stretches to prevent muscle stiffness',
              'Get adequate rest and nutrition',
            ]),
            _buildSection('Mental Preparation', [
              'Be patient with slow progress',
              'Enjoy the small things (birds, moss, silence)',
              'Accept that weather may force plan changes',
              'Stay positive and support fellow trekkers',
              'Practice mindfulness and appreciate nature',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildTipItem(item)),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
