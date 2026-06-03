import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// BOOKING STATUS  (Approved / Pending / Cancelled / Declined / Rejected / Completed)
// -----------------------------------------------------------------------------

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
        return Colors.green;
      case 'Cancelled':
        return Colors.grey.shade500;
      case 'Completed':
        return const Color(0xFF2196F3); // blue
      case 'Declined':
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      case 'Changes Required':
        return Colors.amber.shade700;
      default:
        return const Color(0xFF252B30); // primary
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

// -----------------------------------------------------------------------------
// POST MODERATION STATUS  (pending / approved / declined)
// -----------------------------------------------------------------------------

/// Centralised color, icon, and label mappings for social post moderation statuses.
class PostStatusHelper {
  PostStatusHelper._();

  static Color color(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey.shade500;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }

  static String label(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      case 'pending':
        return 'Pending Review';
      default:
        return 'Unknown';
    }
  }
}

// -----------------------------------------------------------------------------
// CLIMB SESSION STATUS  (ongoing / completed / abandoned)
// -----------------------------------------------------------------------------

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
        return const Color(0xFF2196F3); // blue
      case 'completed':
        return Colors.green;
      case 'abandoned':
        return Colors.red;
      default:
        return Colors.grey.shade500;
    }
  }
}