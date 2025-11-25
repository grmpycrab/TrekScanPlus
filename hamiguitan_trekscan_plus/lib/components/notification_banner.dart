import 'package:flutter/material.dart';
import '../theme/color.dart';
import 'dart:async';

enum NotificationBannerType { success, info, warning, error }

class NotificationBannerData {
  final String title;
  final String message;
  final NotificationBannerType type;
  final Duration duration;
  final VoidCallback? onTap;
  final String id;

  NotificationBannerData({
    required this.title,
    required this.message,
    this.type = NotificationBannerType.info,
    this.duration = const Duration(seconds: 4),
    this.onTap,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class NotificationBannerOverlay extends StatefulWidget {
  const NotificationBannerOverlay({super.key});

  @override
  State<NotificationBannerOverlay> createState() =>
      NotificationBannerOverlayState();

  static void show(BuildContext context, NotificationBannerData data) {
    NotificationBannerOverlayState._currentState?.showNotification(data);
  }
}

class NotificationBannerOverlayState extends State<NotificationBannerOverlay>
    with TickerProviderStateMixin {
  static NotificationBannerOverlayState? _currentState;

  final List<NotificationBannerData> _queue = [];
  NotificationBannerData? _currentNotification;
  Timer? _dismissTimer;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentState = this;
    print('📢 [NotificationBanner] Overlay initialized!');
    _setupAnimations();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _currentState = null;
    _slideController.dispose();
    _fadeController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void showNotification(NotificationBannerData data) {
    print(
      '📢 [NotificationBanner] Adding notification to queue: ${data.title}',
    );
    _queue.add(data);
    print(
      '📢 [NotificationBanner] Queue size: ${_queue.length}, Current: $_currentNotification',
    );
    if (_currentNotification == null) {
      _showNext();
    }
  }

  void _showNext() {
    if (_queue.isEmpty) {
      print('📢 [NotificationBanner] Queue empty, hiding banner');
      setState(() {
        _currentNotification = null;
      });
      return;
    }

    setState(() {
      _currentNotification = _queue.removeAt(0);
    });
    print(
      '📢 [NotificationBanner] Showing notification: ${_currentNotification?.title}',
    );
    _slideController.forward().then((_) {
      _fadeController.forward();
      _startDismissTimer();
    });
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_currentNotification!.duration, _dismissCurrent);
  }

  void _dismissCurrent() async {
    await _slideController.reverse();
    _fadeController.reverse();
    _slideController.reset();
    _fadeController.reset();
    _showNext();
  }

  Color _getBackgroundColor() {
    return AppColors.primary.withValues(alpha: 0.95);
  }

  IconData _getIcon() {
    return switch (_currentNotification?.type) {
      NotificationBannerType.success => Icons.check_circle_rounded,
      NotificationBannerType.warning => Icons.warning_rounded,
      NotificationBannerType.error => Icons.error_rounded,
      NotificationBannerType.info => Icons.info_rounded,
      null => Icons.notifications_rounded,
    };
  }

  Color _getIconColor() {
    return switch (_currentNotification?.type) {
      NotificationBannerType.success => const Color(0xFF4CAF50), // Green
      NotificationBannerType.warning => Colors.orange,
      NotificationBannerType.error => Colors.red,
      NotificationBannerType.info => Colors.lightBlueAccent,
      null => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    print(
      '📢 [NotificationBanner] build() called, _currentNotification: $_currentNotification',
    );

    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: _currentNotification == null
          ? const SizedBox.shrink()
          : SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: _currentNotification!.onTap ?? _dismissCurrent,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _getBackgroundColor(),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(_getIcon(), color: _getIconColor(), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentNotification!.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentNotification!.message.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _currentNotification!.message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _dismissCurrent,
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
