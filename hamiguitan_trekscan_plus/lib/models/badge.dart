import 'package:flutter/material.dart';

enum VerificationType { scan, manualImageReview }

class UserBadge {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final Map<String, dynamic> requirement;
  final String rarity;
  final String difficulty;
  final String tier;
  final VerificationType verificationType;
  final String? triggerStationId; // QR station ID that awards this badge
  final int points;
  final bool earned;
  final String? claimStatus; // null | PENDING | APPROVED | REJECTED

  const UserBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.requirement,
    required this.rarity,
    required this.difficulty,
    this.tier = 'bronze',
    this.verificationType = VerificationType.scan,
    this.triggerStationId,
    this.points = 0,
    this.earned = false,
    this.claimStatus,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    final vtRaw = json['verificationType'] as String? ?? 'SCAN';
    return UserBadge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String,
      requirement: json['requirement'] as Map<String, dynamic>,
      rarity: json['rarity'] as String,
      difficulty: json['difficulty'] as String? ?? 'medium',
      tier: json['tier'] as String? ?? 'bronze',
      verificationType: vtRaw == 'MANUAL_IMAGE_REVIEW'
          ? VerificationType.manualImageReview
          : VerificationType.scan,
      triggerStationId: json['triggerStationId'] as String?,
      points: json['points'] as int? ?? 0,
      earned: false,
      claimStatus: json['claimStatus'] as String?,
    );
  }

  UserBadge copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? icon,
    Map<String, dynamic>? requirement,
    String? rarity,
    String? difficulty,
    String? tier,
    VerificationType? verificationType,
    String? triggerStationId,
    int? points,
    bool? earned,
    String? claimStatus,
  }) {
    return UserBadge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      requirement: requirement ?? this.requirement,
      rarity: rarity ?? this.rarity,
      difficulty: difficulty ?? this.difficulty,
      tier: tier ?? this.tier,
      verificationType: verificationType ?? this.verificationType,
      triggerStationId: triggerStationId ?? this.triggerStationId,
      points: points ?? this.points,
      earned: earned ?? this.earned,
      claimStatus: claimStatus ?? this.claimStatus,
    );
  }

  String get tierLabel {
    switch (tier) {
      case 'bronze':   return 'Bronze';
      case 'silver':   return 'Silver';
      case 'gold':     return 'Gold';
      case 'platinum': return 'Platinum';
      default: return '${tier[0].toUpperCase()}${tier.substring(1)}';
    }
  }

  Color getTierColor() {
    switch (tier) {
      case 'bronze':   return const Color(0xFFCD7F32);
      case 'silver':   return const Color(0xFF8E9AAF);
      case 'gold':     return const Color(0xFFFFB800);
      case 'platinum': return const Color(0xFF7C3AED);
      default: return getColor();
    }
  }

  Color getColor() {
    switch (rarity) {
      case 'common':    return const Color(0xFF9E9E9E);
      case 'uncommon':  return const Color(0xFF4CAF50);
      case 'rare':      return const Color(0xFF2196F3);
      case 'epic':      return const Color(0xFF9C27B0);
      case 'legendary': return const Color(0xFFFF9800);
      default: return Colors.grey;
    }
  }

  IconData getIconData() {
    switch (icon) {
      case 'footprints':    return Icons.directions_walk;
      case 'mountain':      return Icons.landscape;
      case 'compass':       return Icons.explore;
      case 'timer':         return Icons.timer;
      case 'sunrise':       return Icons.wb_sunny;
      case 'route':         return Icons.route;
      case 'medal':         return Icons.military_tech;
      case 'trending_up':   return Icons.trending_up;
      case 'camera':        return Icons.camera_alt;
      case 'star':          return Icons.star;
      case 'forest':        return Icons.forest;
      case 'flower':        return Icons.local_florist;
      case 'eco':           return Icons.eco;
      case 'report':        return Icons.report_problem;
      case 'delete':        return Icons.delete_outline;
      case 'group':         return Icons.group;
      case 'person':        return Icons.person;
      case 'photo_camera':  return Icons.photo_camera;
      case 'calendar':      return Icons.calendar_today;
      case 'trophy':        return Icons.emoji_events;
      case 'event':         return Icons.event;
      case 'public':        return Icons.public;
      case 'explore':       return Icons.explore;
      case 'landscape':     return Icons.landscape;
      default: return Icons.emoji_events;
    }
  }
}
