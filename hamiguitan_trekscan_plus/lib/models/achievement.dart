import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final Map<String, dynamic> requirement;
  final String rarity;
  final String difficulty;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final bool isNotificationShown; // Track if notification was shown to user

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.requirement,
    required this.rarity,
    required this.difficulty,
    this.isUnlocked = false,
    this.unlockedAt,
    this.isNotificationShown = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String,
      requirement: json['requirement'] as Map<String, dynamic>,
      rarity: json['rarity'] as String,
      difficulty: json['difficulty'] as String? ?? 'medium',
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      isNotificationShown: json['isNotificationShown'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'icon': icon,
      'requirement': requirement,
      'rarity': rarity,
      'difficulty': difficulty,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'isNotificationShown': isNotificationShown,
    };
  }

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? icon,
    Map<String, dynamic>? requirement,
    String? rarity,
    String? difficulty,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool? isNotificationShown,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      requirement: requirement ?? this.requirement,
      rarity: rarity ?? this.rarity,
      difficulty: difficulty ?? this.difficulty,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isNotificationShown: isNotificationShown ?? this.isNotificationShown,
    );
  }

  Color getColor() {
    switch (rarity) {
      case 'common':
        return const Color(0xFF9E9E9E);
      case 'uncommon':
        return const Color(0xFF4CAF50);
      case 'rare':
        return const Color(0xFF2196F3);
      case 'epic':
        return const Color(0xFF9C27B0);
      case 'legendary':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  IconData getIconData() {
    switch (icon) {
      case 'footprints':
        return Icons.directions_walk;
      case 'mountain':
        return Icons.landscape;
      case 'compass':
        return Icons.explore;
      case 'timer':
        return Icons.timer;
      case 'sunrise':
        return Icons.wb_sunny;
      case 'route':
        return Icons.route;
      case 'medal':
        return Icons.military_tech;
      case 'trending_up':
        return Icons.trending_up;
      case 'camera':
        return Icons.camera_alt;
      case 'star':
        return Icons.star;
      case 'forest':
        return Icons.forest;
      case 'flower':
        return Icons.local_florist;
      case 'eco':
        return Icons.eco;
      case 'report':
        return Icons.report_problem;
      case 'delete':
        return Icons.delete_outline;
      case 'group':
        return Icons.group;
      case 'person':
        return Icons.person;
      case 'photo_camera':
        return Icons.photo_camera;
      case 'calendar':
        return Icons.calendar_today;
      case 'trophy':
        return Icons.emoji_events;
      case 'event':
        return Icons.event;
      case 'public':
        return Icons.public;
      case 'explore':
        return Icons.explore;
      case 'landscape':
        return Icons.landscape;
      default:
        return Icons.emoji_events;
    }
  }
}
