import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/group_booking.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import 'join_request_screen.dart';
import 'organizer_requests_screen.dart';

/// Discovery panel showing all open [GroupBooking]s.
///
/// Trekkers browse this list and tap a card to open [JoinRequestScreen].
/// Organizers who own a group see a "Manage" button instead of "Join".
class ActiveGroupsScreen extends StatefulWidget {
  const ActiveGroupsScreen({super.key});

  @override
  State<ActiveGroupsScreen> createState() => _ActiveGroupsScreenState();
}

class _ActiveGroupsScreenState extends State<ActiveGroupsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all';
  late final Stream<List<GroupBooking>> _openGroupsStream;

  @override
  void initState() {
    super.initState();
    _openGroupsStream = GroupBookingService.instance.streamOpenGroups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Browse Groups'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Search + filter bar ─────────────────────────────────────────
          Container(
            color: colors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by group or affiliation…',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white70),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      _filterChip('Regular', 'regular_trek'),
                      _filterChip('Special', 'special_trek'),
                      _filterChip('Research', 'research_trek'),
                      _filterChip('Government', 'government_official'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Group list ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<GroupBooking>>(
              stream: _openGroupsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load groups',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  );
                }

                final groups = (snapshot.data ?? []).where((g) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      g.groupName.toLowerCase().contains(_searchQuery) ||
                      g.affiliation.toLowerCase().contains(_searchQuery) ||
                      g.organizerName.toLowerCase().contains(_searchQuery);
                  final matchesType = _typeFilter == 'all' ||
                      g.trekType == _typeFilter;
                  return matchesSearch && matchesType;
                }).toList();

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_off,
                            size: 64, color: colors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No open groups found',
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your search or filter.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _GroupCard(
                    group: groups[i],
                    isOrganizer: groups[i].organizerId == currentUid,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final colors = context.colors;
    final selected = _typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = value),
        selectedColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? colors.primary : Colors.white,
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group card
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  final GroupBooking group;
  final bool isOrganizer;

  const _GroupCard({required this.group, required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = group.trekDate.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    final slotsLeft = group.availableSlots;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isOrganizer
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OrganizerRequestsScreen(groupId: group.id),
                  ),
                )
            : slotsLeft <= 0
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JoinRequestScreen(group: group),
                      ),
                    ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.groupName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                  _TrekTypeBadge(type: group.trekType),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                group.affiliation,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),

              // Info row
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _InfoChip(Icons.calendar_today, dateLabel),
                  _InfoChip(Icons.person, group.organizerName),
                  _InfoChip(
                    Icons.people,
                    '$slotsLeft slot${slotsLeft == 1 ? '' : 's'} left',
                    color: slotsLeft <= 3
                        ? Colors.orange
                        : Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action button
              SizedBox(
                width: double.infinity,
                child: isOrganizer
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.manage_accounts, size: 18),
                        label: const Text('Manage Requests'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                OrganizerRequestsScreen(groupId: group.id),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          side: BorderSide(color: colors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.how_to_reg, size: 18),
                        label: Text(
                          slotsLeft <= 0 ? 'Group Full' : 'Request to Join',
                        ),
                        onPressed: slotsLeft <= 0
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        JoinRequestScreen(group: group),
                                  ),
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colors.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrekTypeBadge extends StatelessWidget {
  final String type;
  const _TrekTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'research_trek' => ('Research', Colors.purple),
      'special_trek' => ('Special', Colors.orange),
      'government_official' => ('Official', Colors.blue),
      'benchmarking_trek' => ('Benchmark', Colors.teal),
      _ => ('Regular', Colors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}
