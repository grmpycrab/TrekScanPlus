import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/presence_service.dart';
import '../../theme/app_theme.dart';

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
    final colors = context.colors;
    return Stack(
      children: [
        // Profile avatar
        photoUrl != null
            ? CircleAvatar(
                radius: radius,
                backgroundColor: colors.primary,
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: photoUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colors.primary,
                      child: Icon(
                        Icons.person,
                        color: colors.primary,
                        size: radius * 0.9,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.primary,
                      child: Icon(
                        Icons.person,
                        color: colors.primary,
                        size: radius * 0.9,
                      ),
                    ),
                    memCacheWidth: (radius * 4).round(),
                    memCacheHeight: (radius * 4).round(),
                  ),
                ),
              )
            : CircleAvatar(
                radius: radius,
                backgroundColor: colors.primary,
                child: Icon(
                  Icons.person,
                  color: colors.primary,
                  size: radius * 0.9,
                ),
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
