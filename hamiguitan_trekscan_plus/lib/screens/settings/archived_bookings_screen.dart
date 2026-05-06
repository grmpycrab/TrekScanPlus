import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../features/booking/providers/booking_provider.dart';
import '../../features/booking/widgets/booking_details_modal.dart';
import '../../models/booking_model.dart';
import '../../models/climb.dart';
import '../../services/booking_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/status_helpers.dart';
import '../../core/widgets/app_dialogue_handler.dart';

class ArchivedBookingsScreen extends StatefulWidget {
  const ArchivedBookingsScreen({super.key});

  @override
  State<ArchivedBookingsScreen> createState() => _ArchivedBookingsScreenState();
}

class _ArchivedBookingsScreenState extends State<ArchivedBookingsScreen> {
  final BookingProvider _bookingProvider = BookingProvider();
  List<Map<String, dynamic>> _archivedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load archived Firestore bookings
      final firebaseArchived = await BookingService.instance
          .streamArchivedBookingsForUser(user.uid)
          .first;

      // Load archived drafts from local storage
      await _bookingProvider.loadAllDraftBookings();
      final archivedDrafts = _bookingProvider.archivedDraftBookings;

      final firebaseItems = firebaseArchived
          .map((b) => _toDisplayItem(b, isDraft: false))
          .toList();
      final draftItems = archivedDrafts
          .map((b) => _toDisplayItem(b, isDraft: true))
          .toList();

      setState(() {
        _archivedItems = [...firebaseItems, ...draftItems];
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('Error loading archived bookings: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _toDisplayItem(BookingModel b, {required bool isDraft}) {
    final user = FirebaseAuth.instance.currentUser;
    return {
      'climb': Climb(
        id: b.id,
        name: b.members.isNotEmpty
            ? '${b.members[0].firstName} ${b.members[0].lastName}'
            : user?.displayName ?? (isDraft ? 'Draft' : 'Booking'),
        date: b.trekDate.toDate(),
        dateBooked: b.createdAt.toDate(),
        targetDate: b.trekDate.toDate(),
        dateApproved: b.updatedAt?.toDate(),
        type: b.trekType,
        status: isDraft ? 'draft' : b.status,
        documents: b.attachments.map((a) => a.fileName).toList(),
        adminNotes: b.adminNotes,
      ),
      'booking': b,
      'isDraft': isDraft,
    };
  }

  Future<void> _unarchive(BookingModel booking, bool isDraft) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Unarchive Booking',
      message: 'Move this booking back to your main list?',
      confirmText: 'Unarchive',
      cancelText: 'Cancel',
    );
    if (confirmed != true) return;

    try {
      if (isDraft) {
        await _bookingProvider.updateDraftBooking(
          booking.copyWith(isArchived: false),
        );
      } else {
        await BookingService.instance.unarchiveBooking(booking.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking restored to main list'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadArchived();
      }
    } catch (e) {
      AppLogger.e('Error unarchiving: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.primary,
        elevation: 0,
        title: const Text(
          'Archived Bookings',
          style: TextStyle(
            color: SharedColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: SharedColors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archivedItems.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadArchived,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _archivedItems.length,
                itemBuilder: (context, index) {
                  final item = _archivedItems[index];
                  final climb = item['climb'] as Climb;
                  final booking = item['booking'] as BookingModel;
                  final isDraft = item['isDraft'] as bool;
                  return _ArchivedCard(
                    climb: climb,
                    booking: booking,
                    isDraft: isDraft,
                    onUnarchive: () => _unarchive(booking, isDraft),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 64, color: colors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No archived bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Long-press a booking card to archive it.',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ArchivedCard extends StatelessWidget {
  final Climb climb;
  final BookingModel booking;
  final bool isDraft;
  final VoidCallback onUnarchive;

  const _ArchivedCard({
    required this.climb,
    required this.booking,
    required this.isDraft,
    required this.onUnarchive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = climb.computedStatus();
    final statusColor = BookingStatusHelper.color(status);

    return Opacity(
      opacity: 0.65,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: colors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          climb.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          climb.type,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Trek date: ${DateFormat('MMMM dd, yyyy').format(climb.targetDate!)}',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Archived',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (isDraft) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.statusPendingLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Draft',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.statusPendingDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => _showDetails(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Details',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                          onPressed: onUnarchive,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Restore',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: colors.shadowOverlay,
      builder: (context) => BookingDetailsModal(
        climb: climb,
        booking: booking,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}
