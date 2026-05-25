import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/badge.dart';
import '../../services/achievement_service.dart';
import '../../services/badge_claim_service.dart';
import '../../services/badge_sync_engine.dart';
import '../../services/connectivity_service.dart';
import '../../services/station_service.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// BADGE CARD — supports both Grid and List layouts
// ═══════════════════════════════════════════════════════════════════════════════

class BadgeCard extends StatelessWidget {
  final UserBadge badge;
  final bool isAcquired;
  final DateTime? acquiredDate;
  final VoidCallback? onTap;
  final bool isListView;

  const BadgeCard({
    super.key,
    required this.badge,
    this.isAcquired = false,
    this.acquiredDate,
    this.onTap,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    return isListView
        ? _ListCard(badge: badge, isAcquired: isAcquired, acquiredDate: acquiredDate, onTap: onTap)
        : _GridCard(badge: badge, isAcquired: isAcquired, onTap: onTap);
  }
}

// ── Grid card ────────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  const _GridCard({required this.badge, required this.isAcquired, this.onTap});

  final UserBadge badge;
  final bool isAcquired;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final rarityColor = badge.getColor();
    final tierColor = badge.getTierColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isAcquired ? tierColor : colors.borderLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isAcquired
                            ? rarityColor.withValues(alpha: 0.15)
                            : colors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        badge.getIconData(),
                        color: isAcquired ? rarityColor : colors.iconMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAcquired ? colors.text : colors.textSecondary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAcquired
                            ? tierColor.withValues(alpha: 0.12)
                            : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge.tierLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isAcquired ? tierColor : colors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAcquired)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(Icons.lock_rounded, color: colors.iconMuted, size: 22),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── List card ────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.badge,
    required this.isAcquired,
    this.acquiredDate,
    this.onTap,
  });

  final UserBadge badge;
  final bool isAcquired;
  final DateTime? acquiredDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final rarityColor = badge.getColor();
    final tierColor = badge.getTierColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAcquired
                        ? rarityColor.withValues(alpha: 0.15)
                        : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    badge.getIconData(),
                    color: isAcquired ? rarityColor : colors.iconMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isAcquired ? colors.text : colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAcquired
                                  ? tierColor.withValues(alpha: 0.12)
                                  : colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge.tierLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isAcquired ? tierColor : colors.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            badge.category.replaceAll('_', ' '),
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isAcquired)
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18)
                    else
                      Icon(Icons.lock_rounded, color: colors.iconMuted, size: 16),
                    if (isAcquired && acquiredDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d').format(acquiredDate!),
                        style: TextStyle(fontSize: 10, color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: colors.iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BADGE DETAIL SCREEN — immersive sliver hero + dynamic verification blocks
// ═══════════════════════════════════════════════════════════════════════════════

class BadgeDetailScreen extends StatefulWidget {
  final UserBadge badge;
  final DateTime? acquiredDate;
  final bool isAcquired;

  const BadgeDetailScreen({
    super.key,
    required this.badge,
    this.acquiredDate,
    this.isAcquired = false,
  });

  @override
  State<BadgeDetailScreen> createState() => _BadgeDetailScreenState();
}

class _BadgeDetailScreenState extends State<BadgeDetailScreen> {
  String? _claimStatus;
  String? _rejectionNote;
  bool _loadingClaim = false;
  bool _submitting = false;
  PlatformFile? _pickedFile;

  // Debug smoke-test state
  Timer? _debugLongPressTimer;
  bool _debugNetworkOverride = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAcquired &&
        widget.badge.verificationType == VerificationType.manualImageReview) {
      _loadClaimStatus();
    }
  }

  @override
  void dispose() {
    _debugLongPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadClaimStatus() async {
    setState(() => _loadingClaim = true);
    try {
      // Check for locally-staged (offline) submissions first
      final hasStaged = await BadgeClaimService.hasStagedClaim(widget.badge.id);
      if (hasStaged) {
        if (mounted) {
          setState(() {
            _claimStatus = 'PENDING_SYNC';
            _loadingClaim = false;
          });
        }
        return;
      }
      // Fall through to Firestore for online claim status
      final claim = await BadgeClaimService.getLatestClaim(widget.badge.id);
      if (mounted) {
        setState(() {
          _claimStatus = claim?.status;
          _rejectionNote = claim?.rejectionNote;
          _loadingClaim = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingClaim = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await BadgeClaimService.pickImage();
    if (file != null && mounted) {
      setState(() => _pickedFile = file);
    }
  }

  Future<bool> _isOnline() async {
    if (_debugNetworkOverride) return false;
    try {
      // connectivity_plus v7+ returns List<ConnectivityResult>
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitClaim() async {
    if (_pickedFile == null) return;
    setState(() => _submitting = true);
    try {
      final online = await _isOnline();
      if (online) {
        await BadgeClaimService.submitClaim(
          badgeId: widget.badge.id,
          badgeName: widget.badge.name,
          file: _pickedFile!,
        );
        if (mounted) {
          setState(() {
            _claimStatus = 'PENDING';
            _pickedFile = null;
            _submitting = false;
          });
        }
      } else {
        await BadgeClaimService.submitClaimOffline(
          badgeId: widget.badge.id,
          badgeName: widget.badge.name,
          file: _pickedFile!,
        );
        if (mounted) {
          setState(() {
            _claimStatus = 'PENDING_SYNC';
            _pickedFile = null;
            _submitting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    }
  }

  // ── Debug smoke-test methods (kDebugMode only) ─────────────────────────────

  void _onDebugLongPressStart(LongPressStartDetails _) {
    if (!kDebugMode) return;
    _debugLongPressTimer = Timer(
      const Duration(seconds: 3),
      _showSmokeTestPanel,
    );
  }

  void _onDebugLongPressEnd(LongPressEndDetails _) {
    _debugLongPressTimer?.cancel();
  }

  void _showSmokeTestPanel() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SmokeTestSheet(
        isNetworkOverridden: _debugNetworkOverride,
        onToggleNetwork: _toggleDebugNetwork,
        onTriggerSync: _triggerSync,
        onInjectScan: _injectMockScan,
      ),
    );
  }

  void _toggleDebugNetwork() {
    ConnectivityService.instance.debugToggleOffline();
    setState(() => _debugNetworkOverride = !_debugNetworkOverride);
  }

  Future<void> _triggerSync() => BadgeSyncEngine.instance.triggerSync();

  Future<String> _injectMockScan(String stationId) async {
    if (!StationService.isInitialized) {
      return 'StationService not initialized — launch a trek first.';
    }
    try {
      await StationService.instance.updateStationVisited(stationId, true);
      final visited = StationService.instance.getVisitedStations();
      final achievement = await AchievementService().checkAndUnlockAchievements(
        visited.length,
        visited.map((s) => s.id).toList(),
        currentStationId: stationId,
      );
      return achievement != null
          ? 'Achievement unlocked: ${achievement.name} (+${achievement.points} pts)'
          : 'Station $stationId marked visited — no new achievement triggered.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final rarityColor = widget.badge.getColor();

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: rarityColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: kDebugMode
                ? GestureDetector(
                    onLongPressStart: _onDebugLongPressStart,
                    onLongPressEnd: _onDebugLongPressEnd,
                    child: const Text(
                      'Badge Detail',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  )
                : const Text(
                    'Badge Detail',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HeroHeader(
                badge: widget.badge,
                isAcquired: widget.isAcquired,
                rarityColor: rarityColor,
                isDark: isDark,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    isAcquired: widget.isAcquired,
                    acquiredDate: widget.acquiredDate,
                    badge: widget.badge,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  _PointsCard(badge: widget.badge, colors: colors, isDark: isDark),
                  const SizedBox(height: 12),

                  _DetailCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Description',
                    colors: colors,
                    isDark: isDark,
                    child: Text(
                      widget.badge.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _MetaChip(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: widget.badge.category.replaceAll('_', ' '),
                          colors: colors,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetaChip(
                          icon: Icons.bar_chart_rounded,
                          label: 'Difficulty',
                          value: widget.badge.difficulty,
                          colors: colors,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildRequirementSection(colors, isDark),

                  if (widget.isAcquired && widget.acquiredDate != null) ...[
                    const SizedBox(height: 12),
                    _DetailCard(
                      icon: Icons.celebration_outlined,
                      title: 'Achievement Unlocked',
                      colors: colors,
                      isDark: isDark,
                      accentColor: Colors.green.shade400,
                      child: _AcquiredContent(
                        acquiredDate: widget.acquiredDate!,
                        colors: colors,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Requirement section — branches on verificationType ─────────────────────

  Widget _buildRequirementSection(AppTheme colors, bool isDark) {
    final isManual =
        widget.badge.verificationType == VerificationType.manualImageReview;

    if (isManual && !widget.isAcquired) {
      return _buildManualReviewBlock(colors, isDark);
    }

    return _DetailCard(
      icon: Icons.task_alt_rounded,
      title: 'Requirement',
      colors: colors,
      isDark: isDark,
      child: _RequirementContent(
        badge: widget.badge,
        isAcquired: widget.isAcquired,
        colors: colors,
      ),
    );
  }

  Widget _buildManualReviewBlock(AppTheme colors, bool isDark) {
    if (_loadingClaim) {
      return _DetailCard(
        icon: Icons.upload_file_rounded,
        title: 'Proof Submission',
        colors: colors,
        isDark: isDark,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_claimStatus == 'PENDING_SYNC') {
      return _OfflineSyncBanner(colors: colors, isDark: isDark);
    }

    if (_claimStatus == 'PENDING') {
      return _PendingBanner(colors: colors, isDark: isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_claimStatus == 'REJECTED') ...[
          _RejectionBanner(note: _rejectionNote, colors: colors, isDark: isDark),
          const SizedBox(height: 12),
        ],
        _DetailCard(
          icon: Icons.upload_file_rounded,
          title: 'Submit Proof',
          colors: colors,
          isDark: isDark,
          child: _buildSubmissionForm(colors, isDark),
        ),
      ],
    );
  }

  Widget _buildSubmissionForm(AppTheme colors, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.badge.requirement['value']?.toString() ??
              'Upload an image as proof of completion.',
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),

        GestureDetector(
          onTap: _submitting ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 148,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _pickedFile != null
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.borderLight,
                width: 1.5,
              ),
            ),
            child: _pickedFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _pickedFile!.path != null
                        ? Image.file(
                            File(_pickedFile!.path!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.memory(
                            _pickedFile!.bytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 36,
                        color: colors.iconMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to pick an image',
                        style: TextStyle(fontSize: 12, color: colors.textTertiary),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_pickedFile == null || _submitting) ? null : _submitClaim,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_submitting ? 'Submitting…' : 'Submit Proof'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.borderLight,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.badge,
    required this.isAcquired,
    required this.rarityColor,
    required this.isDark,
  });

  final UserBadge badge;
  final bool isAcquired;
  final Color rarityColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [rarityColor, rarityColor.withValues(alpha: 0.75)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(badge.getIconData(), color: Colors.white, size: 46),
                  if (!isAcquired)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 36,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                badge.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 4)],
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${badge.tierLabel.toUpperCase()} TIER',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.isAcquired,
    required this.acquiredDate,
    required this.badge,
    required this.colors,
    required this.isDark,
  });

  final bool isAcquired;
  final DateTime? acquiredDate;
  final UserBadge badge;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAcquired
            ? Colors.green.withValues(alpha: isDark ? 0.15 : 0.08)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAcquired
              ? Colors.green.withValues(alpha: 0.3)
              : colors.borderLight,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAcquired ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: isAcquired ? Colors.green.shade500 : colors.iconMuted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAcquired ? 'Badge Acquired' : 'Not Yet Unlocked',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isAcquired ? Colors.green.shade600 : colors.textSecondary,
                  ),
                ),
                if (isAcquired && acquiredDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Earned on ${DateFormat('MMMM d, yyyy').format(acquiredDate!)}',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade500),
                  ),
                ] else if (!isAcquired) ...[
                  const SizedBox(height: 2),
                  Text(
                    badge.verificationType == VerificationType.manualImageReview
                        ? 'Submit proof below for admin review'
                        : 'Complete the requirement to unlock this badge',
                    style: TextStyle(fontSize: 11, color: colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Points card ──────────────────────────────────────────────────────────────

class _PointsCard extends StatelessWidget {
  const _PointsCard({
    required this.badge,
    required this.colors,
    required this.isDark,
  });

  final UserBadge badge;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final tierColor = badge.getTierColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: tierColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${badge.tierLabel} Tier Badge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tierColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Earn ${badge.points} achievement points upon unlock',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✦ ${badge.points} pts',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tierColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending banner ───────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.colors, required this.isDark});

  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🟡', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Verification',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your proof has been submitted. An admin will review it shortly.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rejection banner ─────────────────────────────────────────────────────────

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({
    this.note,
    required this.colors,
    required this.isDark,
  });

  final String? note;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: red.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_rounded, color: red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submission Rejected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note?.isNotEmpty == true
                      ? note!
                      : 'Please resubmit with a clearer photo.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail card ──────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.colors,
    required this.isDark,
    required this.child,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final AppTheme colors;
  final bool isDark;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = accentColor ?? (isDark ? colors.iconSubtle : colors.primary);
    final iconBg = accentColor != null
        ? accentColor!.withValues(alpha: 0.1)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : colors.primary.withValues(alpha: 0.08));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: colors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? colors.iconSubtle : colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requirement content ──────────────────────────────────────────────────────

class _RequirementContent extends StatelessWidget {
  const _RequirementContent({
    required this.badge,
    required this.isAcquired,
    required this.colors,
  });

  final UserBadge badge;
  final bool isAcquired;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    final displayStation =
        badge.requirement['displayStation']?.toString() ?? '';
    final reqValue = badge.requirement['value']?.toString() ?? '';
    final label = displayStation.isNotEmpty ? displayStation : reqValue;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHECKPOINT REQUIRED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.textTertiary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isAcquired
                ? Colors.green.withValues(alpha: 0.1)
                : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAcquired ? Icons.check_rounded : Icons.qr_code_scanner_rounded,
                size: 14,
                color: isAcquired ? Colors.green.shade500 : colors.iconMuted,
              ),
              const SizedBox(width: 4),
              Text(
                isAcquired ? 'Scanned' : 'Scan QR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAcquired ? Colors.green.shade500 : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Acquired content ─────────────────────────────────────────────────────────

class _AcquiredContent extends StatelessWidget {
  const _AcquiredContent({required this.acquiredDate, required this.colors});

  final DateTime acquiredDate;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DateBlock(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('MMMM d, yyyy').format(acquiredDate),
            colors: colors,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateBlock(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: DateFormat('h:mm a').format(acquiredDate),
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.green.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Offline sync banner ───────────────────────────────────────────────────────

class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner({required this.colors, required this.isDark});

  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B82F6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blue.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('\u{1F504}', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting for Connection to Sync',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your proof is saved locally and will be uploaded to the review queue once a connection is available.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Developer smoke-test bottom sheet (kDebugMode only) ───────────────────────

class _SmokeTestSheet extends StatefulWidget {
  final Future<String> Function(String stationId) onInjectScan;
  final VoidCallback onToggleNetwork;
  final Future<void> Function() onTriggerSync;
  final bool isNetworkOverridden;

  const _SmokeTestSheet({
    required this.onInjectScan,
    required this.onToggleNetwork,
    required this.onTriggerSync,
    required this.isNetworkOverridden,
  });

  @override
  State<_SmokeTestSheet> createState() => _SmokeTestSheetState();
}

class _SmokeTestSheetState extends State<_SmokeTestSheet> {
  final _stationIdCtrl = TextEditingController();
  String _scanLog = '';
  String _syncLog = '';
  bool _injecting = false;
  bool _syncing = false;
  late bool _networkOverridden;

  @override
  void initState() {
    super.initState();
    _networkOverridden = widget.isNetworkOverridden;
  }

  @override
  void dispose() {
    _stationIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _doInjectScan() async {
    final id = _stationIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() { _injecting = true; _scanLog = ''; });
    final result = await widget.onInjectScan(id);
    if (mounted) setState(() { _injecting = false; _scanLog = result; });
  }

  void _doToggleNetwork() {
    widget.onToggleNetwork();
    setState(() => _networkOverridden = !_networkOverridden);
  }

  Future<void> _doTriggerSync() async {
    setState(() { _syncing = true; _syncLog = ''; });
    await widget.onTriggerSync();
    if (mounted) setState(() { _syncing = false; _syncLog = 'Sync run completed.'; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'DEBUG',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Smoke Test Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Desktop verification tools — simulates trail actions without hardware.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // ── Section 1: QR Scan Injector ────────────────────────────────
              _SmokeSection(
                icon: Icons.qr_code_scanner_rounded,
                title: 'QR Scan Injector',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter a station ID to inject a mock scan event directly into the local evaluation runtime.',
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _stationIdCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. 56okrkt0pb or r5kntj3sae',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _injecting ? null : _doInjectScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _injecting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(_injecting ? 'Injecting…' : 'Inject Scan'),
                      ),
                    ),
                    if (_scanLog.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _LogOutput(text: _scanLog),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Section 2: Network Toggle ──────────────────────────────────
              _SmokeSection(
                icon: Icons.wifi_rounded,
                title: 'Network Simulation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Force-toggle the global network state to simulate an offline trail environment.',
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _doToggleNetwork,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _networkOverridden
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _networkOverridden
                                ? Colors.red.withValues(alpha: 0.5)
                                : Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _networkOverridden ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                              color: _networkOverridden ? Colors.redAccent : Colors.greenAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _networkOverridden
                                    ? 'SIMULATED OFFLINE — tap to restore'
                                    : 'ONLINE — tap to simulate offline',
                                style: TextStyle(
                                  color: _networkOverridden ? Colors.redAccent : Colors.greenAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Section 3: Background Sync ─────────────────────────────────
              _SmokeSection(
                icon: Icons.sync_rounded,
                title: 'Background Sync Engine',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manually trigger the sync loop to push queued achievement records and staged badge-claim photos.',
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _syncing ? null : _doTriggerSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _syncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: Text(_syncing ? 'Syncing…' : 'Trigger Sync'),
                      ),
                    ),
                    if (_syncLog.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _LogOutput(text: _syncLog),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmokeSection extends StatelessWidget {
  const _SmokeSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white60),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LogOutput extends StatelessWidget {
  const _LogOutput({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }
}
