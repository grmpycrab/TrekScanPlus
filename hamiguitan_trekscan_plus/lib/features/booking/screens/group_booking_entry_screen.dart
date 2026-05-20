import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'active_groups_screen.dart';
import 'create_group_flow_screen.dart';

/// Entry point for the group booking workflow.
///
/// Presents two choices to the user:
/// - Create a Group → [CreateGroupScreen]
/// - Join a Group   → [ActiveGroupsScreen]
class GroupBookingEntryScreen extends StatelessWidget {
  const GroupBookingEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Group Booking'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'How would you like to trek?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your own group or request to join an existing one.',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 32),
            _OptionCard(
              icon: Icons.group_add_outlined,
              title: 'Create a Group',
              description:
                  'Organize your own trek. Set the schedule, slots, and group details. '
                  'Other trekkers can request to join your group.',
              accentColor: colors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupFlowScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.travel_explore,
              title: 'Join a Group',
              description:
                  'Browse open groups and submit a request to join an existing trek. '
                  'The organizer will review and approve your request.',
              accentColor: colors.accent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActiveGroupsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
