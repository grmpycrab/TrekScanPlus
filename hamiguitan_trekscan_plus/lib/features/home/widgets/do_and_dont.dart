import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'trek_tips.dart';

class DoAndDont extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onSegmentTapped;

  const DoAndDont({
    super.key,
    required this.selectedIndex,
    required this.onSegmentTapped,
  });

  @override
  State<DoAndDont> createState() => _DoAndDontState();
}

// Overlay version for use in dialogs
class DoAndDontOverlay extends StatefulWidget {
  const DoAndDontOverlay({super.key});

  @override
  State<DoAndDontOverlay> createState() => _DoAndDontOverlayState();
}

class _InfoItem {
  final String title;
  final String description;
  final IconData icon;

  _InfoItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _DoAndDontState extends State<DoAndDont> {
  bool _isDosExpanded = false;
  bool _isDontsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildSegment(
                  0,
                  "Do's & Dont's",
                  Icons.rule,
                  colors,
                  isSmallScreen,
                ),
                _buildSegment(
                  1,
                  'Tips & Tricks',
                  Icons.lightbulb_outline,
                  colors,
                  isSmallScreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          widget.selectedIndex == 0
              ? _buildTipsList(colors, isSmallScreen)
              : const TrekTips(),
        ],
      ),
    );
  }

  Widget _buildSegment(
    int index,
    String text,
    IconData icon,
    AppTheme colors,
    bool isSmallScreen,
  ) {
    final isSelected = widget.selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onSegmentTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 10 : 12,
            horizontal: isSmallScreen ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 16 : 18,
                color: isSelected ? SharedColors.white : colors.textSecondary,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? SharedColors.white : colors.text,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsList(AppTheme colors, bool isSmallScreen) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
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
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                if (index == 0) {
                  _isDosExpanded = !_isDosExpanded;
                } else {
                  _isDontsExpanded = !_isDontsExpanded;
                }
              });
            },
            children: [
              ExpansionPanel(
                headerBuilder: (context, isExpanded) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: isExpanded
                          ? LinearGradient(
                              colors: [
                                Colors.green.withValues(alpha: 0.1),
                                Colors.green.withValues(alpha: 0.05),
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
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 10 : 12),
                          Text(
                            'Do\'s',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                isExpanded: _isDosExpanded,
                canTapOnHeader: true,
                body: Column(
                  children: [
                    _buildCard(
                      'Secure a permit ahead of time',
                      'You must coordinate with the MHRWS Protected Area Management Office (PAMO) to get the necessary permits.',
                      Colors.green,
                      Icons.assignment_turned_in,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Submit required documentation',
                      'This usually includes a medical certificate (to show you\'re fit for the trek), a valid ID, and sometimes a signed waiver.',
                      Colors.green,
                      Icons.description,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Hire a local guide',
                      'Guided treks are mandatory. Guides help with navigation, safety, and also contribute to local livelihoods.',
                      Colors.green,
                      Icons.person_pin_circle,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Follow trail regulations',
                      'Stay in approved trails, use existing campsites; don\'t cut new paths or camp anywhere not allowed.',
                      Colors.green,
                      Icons.hiking,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Leave no trace',
                      'Bring down all your trash. Don\'t leave behind plastic, wrappers, bottles, etc. What you bring up, bring down.',
                      Colors.green,
                      Icons.eco,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Respect wildlife and plants',
                      'Don\'t feed animals, don\'t disturb nesting or breeding areas, don\'t pick or damage plants, saplings, or fungus.',
                      Colors.green,
                      Icons.pets,
                      colors,
                      isSmallScreen,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              ExpansionPanel(
                headerBuilder: (context, isExpanded) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: isExpanded
                          ? LinearGradient(
                              colors: [
                                Colors.red.withValues(alpha: 0.1),
                                Colors.red.withValues(alpha: 0.05),
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
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 10 : 12),
                          Text(
                            'Don\'ts',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                isExpanded: _isDontsExpanded,
                canTapOnHeader: true,
                body: Column(
                  children: [
                    _buildCard(
                      'Don\'t walk in without permit',
                      'Walk-in trekkers are generally not allowed.',
                      Colors.red,
                      Icons.do_not_disturb,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Don\'t stray off the trail',
                      'Some trails are permanently closed or are open only by special arrangement.',
                      Colors.red,
                      Icons.wrong_location,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Don\'t litter, burn, or pollute',
                      'No dumping waste, no throwing cigarette butts, no bathing with soap in streams.',
                      Colors.red,
                      Icons.delete_outline,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Don\'t disturb wildlife or pick plants',
                      'This includes feeding animals, harvesting flora, removing anything from its place. It\'s a protected area with many endemic species.',
                      Colors.red,
                      Icons.nature_people,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Don\'t ignore physical fitness & safety',
                      'The trails are challenging. If you\'re not prepared (fitness-wise or gear-wise), you may be putting yourself or others at risk.',
                      Colors.red,
                      Icons.health_and_safety,
                      colors,
                      isSmallScreen,
                    ),
                    _buildCard(
                      'Don\'t set off fireworks or make noise',
                      'Disrupts wildlife and other trekkers. Respect the quietness of the forest.',
                      Colors.red,
                      Icons.volume_off,
                      colors,
                      isSmallScreen,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    String title,
    String content,
    Color accentColor,
    IconData icon,
    AppTheme colors,
    bool isSmallScreen,
  ) {
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
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: isSmallScreen ? 18 : 20,
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay state for dialog display
class _DoAndDontOverlayState extends State<DoAndDontOverlay> {
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
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.8),
                  ],
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
                  const Icon(Icons.rule, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Do's & Don'ts",
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
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildExpandedSection(
                      title: "Do's",
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      colors: colors,
                      items: [
                        _InfoItem(
                          title: 'Secure a permit ahead of time',
                          description:
                              'You must coordinate with the MHRWS Protected Area Management Office (PAMO) to get the necessary permits.',
                          icon: Icons.assignment_turned_in,
                        ),
                        _InfoItem(
                          title: 'Submit required documentation',
                          description:
                              'This usually includes a medical certificate (to show you\'re fit for the trek), a valid ID, and sometimes a signed waiver.',
                          icon: Icons.description,
                        ),
                        _InfoItem(
                          title: 'Hire a local guide',
                          description:
                              'Guided treks are mandatory. Guides help with navigation, safety, and also contribute to local livelihoods.',
                          icon: Icons.person_pin_circle,
                        ),
                        _InfoItem(
                          title: 'Follow trail regulations',
                          description:
                              'Stay in approved trails, use existing campsites; don\'t cut new paths or camp anywhere not allowed.',
                          icon: Icons.hiking,
                        ),
                        _InfoItem(
                          title: 'Leave no trace',
                          description:
                              'Bring down all your trash. Don\'t leave behind plastic, wrappers, bottles, etc. What you bring up, bring down.',
                          icon: Icons.eco,
                        ),
                        _InfoItem(
                          title: 'Respect wildlife and plants',
                          description:
                              'Don\'t feed animals, don\'t disturb nesting or breeding areas, don\'t pick or damage plants, saplings, or fungus.',
                          icon: Icons.pets,
                        ),
                      ],
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 16),
                    _buildExpandedSection(
                      title: "Don'ts",
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      colors: colors,
                      items: [
                        _InfoItem(
                          title: 'Don\'t walk in without permit',
                          description:
                              'Walk-in trekkers are generally not allowed.',
                          icon: Icons.do_not_disturb,
                        ),
                        _InfoItem(
                          title: 'Don\'t stray off the trail',
                          description:
                              'Some trails are permanently closed or are open only by special arrangement.',
                          icon: Icons.wrong_location,
                        ),
                        _InfoItem(
                          title: 'Don\'t litter, burn, or pollute',
                          description:
                              'No dumping waste, no throwing cigarette butts, no bathing with soap in streams.',
                          icon: Icons.delete_outline,
                        ),
                        _InfoItem(
                          title: 'Don\'t disturb wildlife or pick plants',
                          description:
                              'This includes feeding animals, harvesting flora, removing anything from its place. It\'s a protected area with many endemic species.',
                          icon: Icons.nature_people,
                        ),
                        _InfoItem(
                          title: 'Don\'t ignore physical fitness & safety',
                          description:
                              'The trails are challenging. If you\'re not prepared (fitness-wise or gear-wise), you may be putting yourself or others at risk.',
                          icon: Icons.health_and_safety,
                        ),
                        _InfoItem(
                          title: 'Don\'t set off fireworks or make noise',
                          description:
                              'Disrupts wildlife and other trekkers. Respect the quietness of the forest.',
                          icon: Icons.volume_off,
                        ),
                      ],
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection({
    required String title,
    required IconData icon,
    required Color color,
    required AppTheme colors,
    required List<_InfoItem> items,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
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
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.05),
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
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
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
              children: items
                  .map(
                    (item) =>
                        _buildInfoCard(item, color, colors, isSmallScreen),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    _InfoItem item,
    Color color,
    AppTheme colors,
    bool isSmallScreen,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: color, size: isSmallScreen ? 18 : 20),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
