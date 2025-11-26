import 'package:flutter/material.dart';
import '../services/presence_service.dart';
import '../theme/color.dart';

/// Reusable profile avatar with online/offline status indicator
class ProfileAvatarWithStatus extends StatelessWidget {
  final String userId;
  final String? photoUrl;
  final double radius;
  final bool showStatus;

  const ProfileAvatarWithStatus({
    super.key,
    required this.userId,
    this.photoUrl,
    this.radius = 20,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Profile avatar
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Icon(
                  Icons.person,
                  color: AppColors.iconPrimary,
                  size: radius * 0.9,
                )
              : null,
        ),
        // Status indicator
        if (showStatus)
          Positioned(
            right: 0,
            bottom: 0,
            child: StreamBuilder<bool>(
              stream: PresenceService.instance.userOnlineStatus(userId),
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? false;

                return Container(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: radius * 0.08,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
