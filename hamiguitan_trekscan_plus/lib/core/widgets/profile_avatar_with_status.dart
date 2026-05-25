import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/presence_service.dart';
import '../../theme/app_theme.dart';

/// Reusable profile avatar with online/offline status indicator.
///
/// Uses [StatefulWidget] so the presence stream is subscribed once in
/// [initState] rather than creating a new Firestore listener on every
/// parent rebuild (important when this widget appears in list items).
class ProfileAvatarWithStatus extends StatefulWidget {
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
  State<ProfileAvatarWithStatus> createState() =>
      _ProfileAvatarWithStatusState();
}

class _ProfileAvatarWithStatusState extends State<ProfileAvatarWithStatus> {
  late final Stream<bool> _onlineStream;

  @override
  void initState() {
    super.initState();
    _onlineStream =
        PresenceService.instance.userOnlineStatus(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        // Profile avatar
        widget.photoUrl != null
            ? CircleAvatar(
                radius: widget.radius,
                backgroundColor: colors.primary,
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.photoUrl!,
                    width: widget.radius * 2,
                    height: widget.radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colors.primary,
                      child: Icon(
                        Icons.person,
                        color: colors.primary,
                        size: widget.radius * 0.9,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.primary,
                      child: Icon(
                        Icons.person,
                        color: colors.primary,
                        size: widget.radius * 0.9,
                      ),
                    ),
                    memCacheWidth: (widget.radius * 4).round(),
                    memCacheHeight: (widget.radius * 4).round(),
                  ),
                ),
              )
            : CircleAvatar(
                radius: widget.radius,
                backgroundColor: colors.primary,
                child: Icon(
                  Icons.person,
                  color: colors.primary,
                  size: widget.radius * 0.9,
                ),
              ),
        // Status indicator
        if (widget.showStatus)
          Positioned(
            right: 0,
            bottom: 0,
            child: StreamBuilder<bool>(
              stream: _onlineStream,
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? false;
                return Container(
                  width: widget.radius * 0.6,
                  height: widget.radius * 0.6,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: widget.radius * 0.08,
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
