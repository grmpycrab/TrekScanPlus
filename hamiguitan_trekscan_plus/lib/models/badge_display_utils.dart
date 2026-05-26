import 'package:flutter/material.dart';

/// Shared display utilities for [UserBadge] and [Achievement].
/// Consolidates icon-mapping and rarity-colour logic that was previously
/// duplicated across both model classes.
class BadgeDisplayUtils {
  BadgeDisplayUtils._();

  static IconData iconDataFor(String icon) {
    switch (icon) {
      case 'footprints':       return Icons.directions_walk;
      case 'mountain':         return Icons.landscape;
      case 'compass':          return Icons.explore;
      case 'timer':            return Icons.timer;
      case 'sunrise':          return Icons.wb_sunny;
      case 'route':            return Icons.route;
      case 'medal':            return Icons.military_tech;
      case 'trending_up':      return Icons.trending_up;
      case 'camera':           return Icons.camera_alt;
      case 'star':             return Icons.star;
      case 'forest':           return Icons.forest;
      case 'flower':           return Icons.local_florist;
      case 'eco':              return Icons.eco;
      case 'report':           return Icons.report_problem;
      case 'delete':           return Icons.delete_outline;
      case 'group':            return Icons.group;
      case 'person':           return Icons.person;
      case 'photo_camera':     return Icons.photo_camera;
      case 'calendar':         return Icons.calendar_today;
      case 'trophy':           return Icons.emoji_events;
      case 'event':            return Icons.event;
      case 'public':           return Icons.public;
      case 'explore':          return Icons.explore;
      case 'landscape':        return Icons.landscape;
      case 'replay':           return Icons.replay;
      case 'home':             return Icons.home;
      case 'directions_walk':  return Icons.directions_walk;
      case 'military_tech':    return Icons.military_tech;
      case 'wb_sunny':         return Icons.wb_sunny;
      case 'crown':            return Icons.workspace_premium;
      default:                 return Icons.emoji_events;
    }
  }

  static Color colorForRarity(String rarity) {
    switch (rarity) {
      case 'common':    return const Color(0xFF9E9E9E);
      case 'uncommon':  return const Color(0xFF4CAF50);
      case 'rare':      return const Color(0xFF2196F3);
      case 'epic':      return const Color(0xFF9C27B0);
      case 'legendary': return const Color(0xFFFF9800);
      default:          return Colors.grey;
    }
  }
}
