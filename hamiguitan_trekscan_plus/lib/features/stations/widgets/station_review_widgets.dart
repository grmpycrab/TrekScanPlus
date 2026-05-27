import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/station_review.dart';
import '../services/station_review_service.dart';
import '../../../theme/app_theme.dart';
import '../../../features/auth/screens/login_screen.dart';

/// Pill showing average rating (reference-style), or a neutral state when empty.
class StationRatingSummaryPill extends StatelessWidget {
  const StationRatingSummaryPill({
    super.key,
    required this.loading,
    required this.average,
    required this.count,
  });

  final bool loading;
  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(left: 8, top: 2),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final hasReviews = count > 0;
    final label = hasReviews ? '${average.toStringAsFixed(1)}/5' : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasReviews ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            hasReviews ? '$label ($count)' : label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reviews list + sign-in / compose UI for a station.
class StationReviewsSectionBody extends StatefulWidget {
  const StationReviewsSectionBody({
    super.key,
    required this.stationId,
    required this.reviews,
    required this.loading,
    this.error,
  });

  final String stationId;
  final List<StationReview> reviews;
  final bool loading;
  final Object? error;

  @override
  State<StationReviewsSectionBody> createState() =>
      _StationReviewsSectionBodyState();
}

class _StationReviewsSectionBodyState extends State<StationReviewsSectionBody> {
  final _commentController = TextEditingController();
  int _draftRating = 5;
  bool _submitting = false;

  /// Review IDs that have been soft-deleted locally. The row is hidden from
  /// the UI immediately on user confirmation; the Firestore delete is
  /// dispatched in the background (offline persistence queues it if needed).
  final Set<String> _locallyDeleted = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _syncDraftFromMyReview(_myReview);
  }

  StationReview? get _myReview {
    final uid = StationReviewService.instance.currentUserId;
    if (uid == null) return null;
    for (final r in widget.reviews) {
      if (r.userId == uid && !_locallyDeleted.contains(r.id)) return r;
    }
    return null;
  }

  List<StationReview> get _visibleReviews =>
      widget.reviews.where((r) => !_locallyDeleted.contains(r.id)).toList();

  void _syncDraftFromMyReview(StationReview? mine) {
    if (mine == null) return;
    _draftRating = mine.rating;
    _commentController.text = mine.comment;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await StationReviewService.instance.upsertReview(
        stationId: widget.stationId,
        rating: _draftRating,
        comment: _commentController.text,
      );
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Soft-deletes the composer's own review: hides immediately, then fires
  /// the Firestore delete. Rolls back the local hide on error.
  Future<void> _deleteMine() async {
    final mine = _myReview;
    if (mine == null) return;

    setState(() {
      _locallyDeleted.add(mine.id);
      _draftRating = 5;
      _commentController.clear();
    });

    try {
      await StationReviewService.instance.deleteMyReview(widget.stationId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review removed')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locallyDeleted.remove(mine.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Three-dot menu actions
  // -------------------------------------------------------------------------

  Future<void> _showEditDialog(StationReview review) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _ReviewEditDialog(
        stationId: widget.stationId,
        review: review,
      ),
    );
  }

  Future<void> _showDeleteConfirmation(StationReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove review?'),
        content: const Text(
          'Your review will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Soft-delete: remove from UI immediately, flag as DELETE / PENDING_SYNC,
    // then dispatch the Firestore write in the background.
    setState(() {
      _locallyDeleted.add(review.id);
      // If this was the user's own review, reset the composer.
      if (review.userId == StationReviewService.instance.currentUserId) {
        _draftRating = 5;
        _commentController.clear();
      }
    });

    try {
      await StationReviewService.instance.deleteMyReview(widget.stationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review removed')),
        );
      }
    } catch (e) {
      // Roll back the local soft-delete if the Firestore call failed.
      if (mounted) {
        setState(() => _locallyDeleted.remove(review.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove review: $e')),
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    final currentUid = StationReviewService.instance.currentUserId;
    final visible = _visibleReviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Reviews'),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            'Could not load reviews. Check connection and try again.',
            style: TextStyle(color: Colors.red[700], fontSize: 14),
          ),
        ] else if (widget.loading && visible.isEmpty) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ] else if (visible.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'No reviews yet. Be the first to share your experience.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          ...visible.map(
            (r) => _ReviewTile(
              key: ValueKey(r.id),
              review: r,
              dateFmt: dateFmt,
              isOwner: currentUid != null && r.userId == currentUid,
              stationId: widget.stationId,
              onEditPressed: () => _showEditDialog(r),
              onDeleteRequested: () => _showDeleteConfirmation(r),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildComposer(context),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: context.colors.text,
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return OutlinedButton.icon(
        onPressed: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        icon: const Icon(Icons.login, size: 18),
        label: const Text('Sign in to leave a review'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.accent,
          side: BorderSide(color: context.colors.accent),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _myReview != null ? 'Update your review' : 'Write a review',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              final filled = n <= _draftRating;
              return InkWell(
                onTap: () => setState(() => _draftRating = n),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? Colors.amber[700] : Colors.grey[400],
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: 'Share tips or how it felt at this station…',
              filled: true,
              fillColor: context.colors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: context.colors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_myReview != null ? 'Update review' : 'Post review'),
              ),
              if (_myReview != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _submitting ? null : _deleteMine,
                  child: Text(
                    'Remove',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit dialog — pre-populated with the review's current rating + comment.
// ---------------------------------------------------------------------------

class _ReviewEditDialog extends StatefulWidget {
  const _ReviewEditDialog({required this.stationId, required this.review});

  final String stationId;
  final StationReview review;

  @override
  State<_ReviewEditDialog> createState() => _ReviewEditDialogState();
}

class _ReviewEditDialogState extends State<_ReviewEditDialog> {
  late int _rating;
  late final TextEditingController _commentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.review.rating;
    _commentController = TextEditingController(text: widget.review.comment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Mark locally as UPDATE / PENDING_SYNC while the call is in-flight.
      // Firestore offline persistence will queue the write if offline.
      await StationReviewService.instance.upsertReview(
        stationId: widget.stationId,
        rating: _rating,
        comment: _commentController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rating',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final n = i + 1;
                return InkWell(
                  onTap: () => setState(() => _rating = n),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      n <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: n <= _rating ? Colors.amber[700] : Colors.grey[400],
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Comment',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Share your experience…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual review tile.
// ---------------------------------------------------------------------------

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    super.key,
    required this.review,
    required this.dateFmt,
    required this.isOwner,
    required this.stationId,
    required this.onEditPressed,
    required this.onDeleteRequested,
  });

  final StationReview review;
  final DateFormat dateFmt;

  /// True when the active session user authored this review.
  /// Controls visibility of the trailing three-dot action menu.
  final bool isOwner;
  final String stationId;
  final VoidCallback onEditPressed;
  final VoidCallback onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = review.userDisplayName.isNotEmpty
        ? review.userDisplayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colors.accent.withValues(alpha: 0.15),
            foregroundColor: colors.accent,
            child: Text(initial),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.userDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      dateFmt.format(review.updatedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    // Three-dot menu — rendered only for the review's author.
                    if (isOwner)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                            onSelected: (value) {
                              if (value == 'edit') onEditPressed();
                              if (value == 'delete') onDeleteRequested();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 10),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Remove',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
                if (review.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    review.comment.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.black87,
                    ),
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
