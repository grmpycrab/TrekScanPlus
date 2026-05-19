import React, { useState, useEffect, useCallback } from 'react';
import { Timestamp } from 'firebase/firestore';
import { getAllPosts, approvePost, declinePost, formatPostDate } from '../../services/postService.js';
import { getUserById } from '../../services/userService.js';
import { useToast, ToastContainer } from '../../components/Toast.jsx';
import '../style/PostModeration.css';

const STATUS_TABS = [
  { key: 'pending',  label: 'Pending',  color: '#f59e0b' },
  { key: 'approved', label: 'Approved', color: '#22c55e' },
  { key: 'declined', label: 'Declined', color: '#ef4444' },
];

const PRESET_DECLINE_REASONS = [
  'Does not align with community guidelines.',
  'Contains inappropriate or offensive content.',
  'Irrelevant to Mt. Hamiguitan trekking community.',
  'Potential misinformation or misleading content.',
];

function PostModeration({ adminName = 'Admin' }) {
  const [activeTab, setActiveTab] = useState('pending');
  const [posts, setPosts] = useState({ pending: [], approved: [], declined: [] });
  const [loading, setLoading] = useState(true);
  const [userCache, setUserCache] = useState({});

  // Decline modal state
  const [declineModal, setDeclineModal] = useState({ open: false, postId: null });
  const [declineNote, setDeclineNote] = useState('');
  const [submitting, setSubmitting] = useState(null); // postId being actioned

  // Image lightbox
  const [lightbox, setLightbox] = useState(null);

  const { toasts, removeToast, success, error: showError } = useToast();

  const fetchAllPosts = useCallback(async () => {
    setLoading(true);
    try {
      const [pending, approved, declined] = await Promise.all([
        getAllPosts('pending'),
        getAllPosts('approved'),
        getAllPosts('declined'),
      ]);

      // Collect unique user IDs
      const allPosts = [...pending, ...approved, ...declined];
      const uids = [...new Set(allPosts.map((p) => p.userId).filter(Boolean))];

      const cache = { ...userCache };
      await Promise.all(
        uids
          .filter((uid) => !cache[uid])
          .map(async (uid) => {
            try {
              const user = await getUserById(uid);
              if (user) cache[uid] = user;
            } catch (_) {}
          }),
      );

      setUserCache(cache);
      setPosts({ pending, approved, declined });
    } catch (err) {
      console.error('PostModeration fetch error:', err);
      showError('Failed to load posts. Please refresh.');
    } finally {
      setLoading(false);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    fetchAllPosts();
  }, [fetchAllPosts]);

  const handleApprove = async (postId) => {
    setSubmitting(postId);
    try {
      await approvePost(postId, adminName);
      success('Post approved and published to the feed.');
      await fetchAllPosts();
    } catch (err) {
      showError('Failed to approve post. Please try again.');
    } finally {
      setSubmitting(null);
    }
  };

  const openDeclineModal = (postId) => {
    setDeclineNote('');
    setDeclineModal({ open: true, postId });
  };

  const handleDeclineConfirm = async () => {
    if (!declineNote.trim()) return;
    const { postId } = declineModal;
    setSubmitting(postId);
    setDeclineModal({ open: false, postId: null });
    try {
      await declinePost(postId, declineNote, adminName);
      success('Post declined. The author will see your note.');
      await fetchAllPosts();
    } catch (err) {
      showError(err.message || 'Failed to decline post.');
    } finally {
      setSubmitting(null);
    }
  };

  const userName = (post) => {
    const u = userCache[post.userId];
    if (u) return `${u.firstName || ''} ${u.lastName || ''}`.trim() || post.userName || 'Unknown';
    return post.userName || 'Unknown';
  };

  const userPhoto = (post) => userCache[post.userId]?.profileImage || null;

  const currentPosts = posts[activeTab] || [];

  return (
    <div className="pm-container">
      {/* Tab bar */}
      <div className="pm-tabs">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.key}
            className={`pm-tab${activeTab === tab.key ? ' pm-tab-active' : ''}`}
            style={activeTab === tab.key ? { borderBottomColor: tab.color, color: tab.color } : {}}
            onClick={() => setActiveTab(tab.key)}
          >
            {tab.label}
            <span
              className="pm-tab-badge"
              style={activeTab === tab.key ? { background: tab.color } : {}}
            >
              {posts[tab.key]?.length ?? 0}
            </span>
          </button>
        ))}
      </div>

      {/* Content */}
      {loading ? (
        <div className="pm-loading">
          <div className="pm-spinner" />
          <span>Loading posts…</span>
        </div>
      ) : currentPosts.length === 0 ? (
        <div className="pm-empty">
          <div className="pm-empty-icon">📭</div>
          <div className="pm-empty-title">No {activeTab} posts</div>
          <div className="pm-empty-sub">Nothing to show here right now.</div>
        </div>
      ) : (
        <div className="pm-grid">
          {currentPosts.map((post) => (
            <PostCard
              key={post.id}
              post={post}
              userName={userName(post)}
              userPhoto={userPhoto(post)}
              activeTab={activeTab}
              submitting={submitting === post.id}
              onApprove={() => handleApprove(post.id)}
              onDecline={() => openDeclineModal(post.id)}
              onImageClick={(url) => setLightbox(url)}
            />
          ))}
        </div>
      )}

      {/* Decline Modal */}
      {declineModal.open && (
        <div className="pm-modal-backdrop" onClick={() => setDeclineModal({ open: false, postId: null })}>
          <div className="pm-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="pm-modal-title">Decline Post</h3>
            <p className="pm-modal-sub">
              Provide a reason. This note will be visible to the post author.
            </p>

            {/* Preset reasons */}
            <div className="pm-preset-reasons">
              {PRESET_DECLINE_REASONS.map((r) => (
                <button
                  key={r}
                  className={`pm-preset-btn${declineNote === r ? ' pm-preset-btn-active' : ''}`}
                  onClick={() => setDeclineNote(r)}
                >
                  {r}
                </button>
              ))}
            </div>

            <textarea
              className="pm-textarea"
              rows={4}
              placeholder="Or type a custom reason…"
              value={declineNote}
              onChange={(e) => setDeclineNote(e.target.value)}
            />

            <div className="pm-modal-actions">
              <button
                className="pm-btn-cancel"
                onClick={() => setDeclineModal({ open: false, postId: null })}
              >
                Cancel
              </button>
              <button
                className="pm-btn-decline"
                disabled={!declineNote.trim()}
                onClick={handleDeclineConfirm}
              >
                Confirm Decline
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Image lightbox */}
      {lightbox && (
        <div className="pm-lightbox" onClick={() => setLightbox(null)}>
          <img src={lightbox} alt="Post" className="pm-lightbox-img" />
          <button className="pm-lightbox-close" onClick={() => setLightbox(null)}>✕</button>
        </div>
      )}

      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

function PostCard({ post, userName, userPhoto, activeTab, submitting, onApprove, onDecline, onImageClick }) {
  const images = Array.isArray(post.imageUrls) ? post.imageUrls : [];
  const createdAt = post.createdAt instanceof Timestamp
    ? post.createdAt.toDate()
    : post.createdAt?.seconds
      ? new Date(post.createdAt.seconds * 1000)
      : null;

  const dateStr = createdAt
    ? createdAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    : '—';

  const privacyLabel = { public: 'Public', followers: 'Followers', private: 'Private' }[post.privacy] || post.privacy;

  return (
    <div className={`pm-card${submitting ? ' pm-card-loading' : ''}`}>
      {/* Header */}
      <div className="pm-card-header">
        <div className="pm-avatar">
          {userPhoto
            ? <img src={userPhoto} alt={userName} className="pm-avatar-img" />
            : <span className="pm-avatar-initials">{userName.charAt(0).toUpperCase()}</span>
          }
        </div>
        <div className="pm-card-meta">
          <span className="pm-card-username">{userName}</span>
          <span className="pm-card-date">{dateStr} · {privacyLabel}</span>
        </div>
        <span className={`pm-status-badge pm-status-${post.status || 'pending'}`}>
          {post.status || 'pending'}
        </span>
      </div>

      {/* Caption */}
      <p className="pm-card-caption">{post.caption || <em>No caption</em>}</p>

      {/* Images */}
      {images.length > 0 && (
        <div className={`pm-images pm-images-${Math.min(images.length, 4)}`}>
          {images.slice(0, 4).map((url, i) => (
            <div
              key={i}
              className="pm-img-wrapper"
              onClick={() => onImageClick(url)}
            >
              <img src={url} alt={`img-${i}`} className="pm-img" />
              {i === 3 && images.length > 4 && (
                <div className="pm-img-more">+{images.length - 4}</div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Moderator note (declined posts) */}
      {post.status === 'declined' && post.moderatorNote && (
        <div className="pm-decline-note">
          <span className="pm-decline-note-label">Moderator note:</span>
          <span>{post.moderatorNote}</span>
        </div>
      )}

      {/* Reviewer info */}
      {post.reviewedBy && post.reviewedAt && (
        <div className="pm-reviewed-by">
          Reviewed by {post.reviewedBy} · {formatPostDate(post.reviewedAt)}
        </div>
      )}

      {/* Actions — only on pending tab */}
      {activeTab === 'pending' && (
        <div className="pm-card-actions">
          <button
            className="pm-btn-approve"
            disabled={submitting}
            onClick={onApprove}
          >
            {submitting ? 'Processing…' : '✓ Approve'}
          </button>
          <button
            className="pm-btn-decline-card"
            disabled={submitting}
            onClick={onDecline}
          >
            ✕ Decline
          </button>
        </div>
      )}
    </div>
  );
}

export default PostModeration;
