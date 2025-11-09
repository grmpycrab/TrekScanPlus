import 'package:flutter/material.dart';
import '../theme/color.dart';
import './trek_tips.dart';

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

class _DoAndDontState extends State<DoAndDont> {
  bool _isDosExpanded = false;
  bool _isDontsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.segmentBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildSegment(0, "Do's & Dont's"),
                _buildSegment(1, 'Tips & Tricks'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          widget.selectedIndex == 0 ? _buildTipsList() : const TrekTips(),
        ],
      ),
    );
  }

  Widget _buildSegment(int index, String text) {
    final isSelected = widget.selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onSegmentTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.buttonText : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipsList() {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Do\'s',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                );
              },
              isExpanded: _isDosExpanded,
              body: Column(
                children: [
                  _buildCard(
                    'Secure a permit ahead of time',
                    'You must coordinate with the MHRWS Protected Area Management Office (PAMO) to get the necessary permits.',
                  ),
                  _buildCard(
                    'Submit required documentation',
                    'This usually includes a medical certificate (to show you\'re fit for the trek), a valid ID, and sometimes a signed waiver.',
                  ),
                  _buildCard(
                    'Hire a local guide',
                    'Guided treks are mandatory. Guides help with navigation, safety, and also contribute to local livelihoods.',
                  ),
                  _buildCard(
                    'Follow trail regulations',
                    'Stay in approved trails, use existing campsites; don\'t cut new paths or camp anywhere not allowed.',
                  ),
                  _buildCard(
                    'Leave no trace',
                    'Bring down all your trash. Don\'t leave behind plastic, wrappers, bottles, etc. What you bring up, bring down.',
                  ),
                  _buildCard(
                    'Respect wildlife and plants',
                    'Don\'t feed animals, don\'t disturb nesting or breeding areas, don\'t pick or damage plants, saplings, or fungus.',
                  ),
                ],
              ),
            ),
            ExpansionPanel(
              headerBuilder: (context, isExpanded) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Don\'ts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                );
              },
              isExpanded: _isDontsExpanded,
              body: Column(
                children: [
                  _buildCard(
                    'Don\'t walk in without permit',
                    'Walk-in trekkers are generally not allowed.',
                  ),
                  _buildCard(
                    'Don\'t stray off the trail',
                    'Some trails are permanently closed or are open only by special arrangement.',
                  ),
                  _buildCard(
                    'Don\'t litter, burn, or pollute',
                    'No dumping waste, no throwing cigarette butts, no bathing with soap in streams.',
                  ),
                  _buildCard(
                    'Don\'t disturb wildlife or pick plants',
                    'This includes feeding animals, harvesting flora, removing anything from its place. It\'s a protected area with many endemic species.',
                  ),
                  _buildCard(
                    'Don\'t ignore physical fitness & safety',
                    'The trails are challenging. If you\'re not prepared (fitness-wise or gear-wise), you may be putting yourself or others at risk.',
                  ),
                  _buildCard(
                    'Don\'t set off fireworks or make noise',
                    'Disrupts wildlife and other trekkers. Respect the quietness of the forest.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
