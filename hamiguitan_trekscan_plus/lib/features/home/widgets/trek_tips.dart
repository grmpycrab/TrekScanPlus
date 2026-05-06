import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TrekTips extends StatefulWidget {
  const TrekTips({super.key});

  @override
  State<TrekTips> createState() => _TrekTipsState();
}

// Overlay version for use in dialogs
class TrekTipsOverlay extends StatefulWidget {
  const TrekTipsOverlay({super.key});

  @override
  State<TrekTipsOverlay> createState() => _TrekTipsOverlayState();
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
    final colors = context.colors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      child: Container(
        margin: EdgeInsets.only(
          bottom: 24,
          left: isSmallScreen ? 0 : 0,
          right: isSmallScreen ? 0 : 0,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              spreadRadius: 2,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ExpansionPanelList(
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
            animationDuration: const Duration(milliseconds: 300),
            expansionCallback: (index, isExpanded) {
              setState(() {
                final title = _sections.keys.elementAt(index);
                _expandedSections[title] = !(_expandedSections[title] ?? false);
              });
            },
            children: _sections.entries.map((entry) {
              final isExpanded = _expandedSections[entry.key] ?? false;
              return ExpansionPanel(
                headerBuilder: (context, isExpanded) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: isExpanded
                          ? LinearGradient(
                              colors: [
                                colors.primary.withValues(alpha: 0.1),
                                colors.primary.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getSectionIcon(entry.key),
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 10 : 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                body: Column(
                  children: [
                    ...entry.value.map(
                      (tip) => _buildTipItem(tip, colors, isSmallScreen),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                isExpanded: isExpanded,
                canTapOnHeader: true,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'Best Time to Visit':
        return Icons.calendar_today;
      case 'Pre-Trek Preparation':
        return Icons.assignment_turned_in;
      case 'Essential Packing':
        return Icons.backpack;
      case 'Photography Tips':
        return Icons.camera_alt;
      case 'Local Community Support':
        return Icons.people;
      case 'Recovery Tips':
        return Icons.healing;
      case 'Mental Preparation':
        return Icons.psychology;
      default:
        return Icons.info;
    }
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

  Widget _buildTipItem(String text, AppTheme colors, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isSmallScreen ? 12 : 16,
        right: isSmallScreen ? 12 : 16,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.tips_and_updates,
              size: isSmallScreen ? 16 : 18,
              color: colors.primary,
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: colors.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay state for dialog display
class _TrekTipsOverlayState extends State<TrekTipsOverlay> {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.60,
          maxWidth: 600,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent, const Color(0xFF053821)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Color.fromARGB(255, 252, 194, 6),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tips & Tricks',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Scrollable content - all sections expanded
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _sections.entries.map((entry) {
                    return _buildExpandedSection(
                      title: entry.key,
                      icon: _getSectionIcon(entry.key),
                      tips: entry.value,
                      colors: colors,
                      isSmallScreen: isSmallScreen,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'Best Time to Visit':
        return Icons.calendar_today;
      case 'Pre-Trek Preparation':
        return Icons.assignment_turned_in;
      case 'Essential Packing':
        return Icons.backpack;
      case 'Photography Tips':
        return Icons.camera_alt;
      case 'Local Community Support':
        return Icons.people;
      case 'Recovery Tips':
        return Icons.healing;
      case 'Mental Preparation':
        return Icons.psychology;
      default:
        return Icons.info;
    }
  }

  Widget _buildExpandedSection({
    required String title,
    required IconData icon,
    required List<String> tips,
    required AppTheme colors,
    required bool isSmallScreen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.1),
                  colors.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: colors.accent, size: 20),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 16,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: tips
                  .map((tip) => _buildTipCard(tip, colors, isSmallScreen))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip, AppTheme colors, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(
                255,
                167,
                136,
                0,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.lightbulb_outlined,
              size: isSmallScreen ? 16 : 20,
              color: Color.fromARGB(255, 252, 194, 6),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                color: colors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
