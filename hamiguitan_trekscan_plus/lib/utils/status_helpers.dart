import 'package:flutter/material.dart';
import '../theme/color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING STATUS  (Approved / Pending / Cancelled / Declined / Rejected / Completed)
// ─────────────────────────────────────────────────────────────────────────────

/// Centralised color and icon mappings for booking statuses.
///
/// Use instead of duplicating `_getStatusColor` / `_getStatusIcon` helpers
/// in individual widgets (BookingDetailsModal, ClimbCard, etc.).
class BookingStatusHelper {
  BookingStatusHelper._();

  /// Returns the theme color for a given booking [status] string.
  static Color color(String status) {
    switch (status) {
      case 'Approved':
        return AppColors.statusApproved;
      case 'Cancelled':
        return AppColors.statusCancelled;
      case 'Completed':
        return AppColors.notificationBooking;
      case 'Declined':
      case 'Rejected':
        return AppColors.statusRejected;
      case 'Pending':
        return AppColors.statusPending;
      default:
        return AppColors.primary;
    }
  }

  /// Returns the icon for a given booking [status] string.
  static IconData icon(String status) {
    switch (status) {
      case 'Approved':
      case 'Completed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIMB SESSION STATUS  (ongoing / completed / abandoned)
// ─────────────────────────────────────────────────────────────────────────────

/// Centralised color mapping for climb-session statuses.
///
/// Use instead of duplicating `_getStatusColor` in StationScreen,
/// ClimbSessionsListScreen, ClimbSessionDetailScreen, etc.
class ClimbSessionStatusHelper {
  ClimbSessionStatusHelper._();

  /// Returns the theme color for a given climb-session [status] string.
  static Color color(String status) {
    switch (status) {
      case 'ongoing':
        return AppColors.notificationBooking; // blue
      case 'completed':
        return AppColors.statusApproved; // green
      case 'abandoned':
        return AppColors.statusRejected; // red
      default:
        return AppColors.textSecondary; // grey
    }
  }
}
