import {
  collection,
  doc,
  addDoc,
  getDoc,
  getDocs,
  updateDoc,
  increment,
  query,
  orderBy,
  onSnapshot,
  Timestamp,
  where,
} from 'firebase/firestore';
import { db } from '../config/firebase';

const POSTS_COLLECTION = 'posts';

/**
 * Fetch all posts, optionally filtered by moderation status.
 * @param {string|null} status - 'pending' | 'approved' | 'declined' | null (all)
 * @returns {Promise<Array>}
 */
export const getAllPosts = async (status = null) => {
  try {
    let q = collection(db, POSTS_COLLECTION);

    if (status) {
      q = query(q, where('status', '==', status), orderBy('createdAt', 'desc'));
    } else {
      q = query(q, orderBy('createdAt', 'desc'));
    }

    const snapshot = await getDocs(q);
    return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (error) {
    console.error('postService.getAllPosts error:', error);
    // If the status-filtered query fails due to a missing index, fall back to
    // fetching all and filtering client-side.
    if (error.code === 'failed-precondition' && status) {
      const snapshot = await getDocs(collection(db, POSTS_COLLECTION));
      return snapshot.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((p) => p.status === status)
        .sort((a, b) => {
          const ta = a.createdAt instanceof Timestamp ? a.createdAt.toMillis() : 0;
          const tb = b.createdAt instanceof Timestamp ? b.createdAt.toMillis() : 0;
          return tb - ta;
        });
    }
    throw error;
  }
};

/**
 * Approve a pending post — sets status to 'approved'.
 * @param {string} postId
 * @param {string} adminName - display name of the reviewing admin
 */
export const approvePost = async (postId, adminName = 'Admin') => {
  try {
    const postRef = doc(db, POSTS_COLLECTION, postId);
    const postSnap = await getDoc(postRef);
    if (!postSnap.exists()) throw new Error('Post not found');
    const { userId } = postSnap.data();

    await updateDoc(postRef, {
      status: 'approved',
      moderatorNote: null,
      reviewedBy: adminName,
      reviewedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    // Increment postsCount now that the post is published.
    if (userId) {
      try {
        await updateDoc(doc(db, 'users', userId), { postsCount: increment(1) });
      } catch (e) {
        console.warn('approvePost: could not increment postsCount', e);
      }

      // Notify the post author in-app.
      try {
        await addDoc(
          collection(db, 'users', userId, 'notifications'),
          {
            title: 'Post Approved!',
            message: 'Your post is now live on the community feed.',
            type: 'success',
            timestamp: Timestamp.now(),
            isRead: false,
            actionType: 'post',
            actionData: postId,
          },
        );
      } catch (e) {
        console.warn('approvePost: could not send notification', e);
      }
    }
  } catch (error) {
    console.error('postService.approvePost error:', error);
    throw error;
  }
};

/**
 * Decline a pending post — sets status to 'declined' with a required moderator note.
 * @param {string} postId
 * @param {string} moderatorNote - required rejection reason
 * @param {string} adminName - display name of the reviewing admin
 */
export const declinePost = async (postId, moderatorNote, adminName = 'Admin') => {
  if (!moderatorNote || !moderatorNote.trim()) {
    throw new Error('A moderator note is required when declining a post.');
  }
  try {
    const postRef = doc(db, POSTS_COLLECTION, postId);
    const postSnap = await getDoc(postRef);
    if (!postSnap.exists()) throw new Error('Post not found');
    const { userId } = postSnap.data();

    await updateDoc(postRef, {
      status: 'declined',
      moderatorNote: moderatorNote.trim(),
      reviewedBy: adminName,
      reviewedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    // Notify the post author with the moderator reason.
    if (userId) {
      try {
        await addDoc(
          collection(db, 'users', userId, 'notifications'),
          {
            title: 'Post Declined',
            message: `Your post was declined: ${moderatorNote.trim()}`,
            type: 'warning',
            timestamp: Timestamp.now(),
            isRead: false,
            actionType: 'post',
            actionData: postId,
          },
        );
      } catch (e) {
        console.warn('declinePost: could not send notification', e);
      }
    }
  } catch (error) {
    console.error('postService.declinePost error:', error);
    throw error;
  }
};

/**
 * Subscribe to real-time post updates filtered by status.
 * @param {string|null} status - 'pending' | 'approved' | 'declined' | null (all)
 * @param {Function} callback - receives the updated post array
 * @returns {Function} unsubscribe function
 */
export const subscribeToPosts = (status = null, callback) => {
  try {
    let q = collection(db, POSTS_COLLECTION);

    if (status) {
      q = query(q, where('status', '==', status), orderBy('createdAt', 'desc'));
    } else {
      q = query(q, orderBy('createdAt', 'desc'));
    }

    return onSnapshot(
      q,
      (snapshot) => {
        const posts = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
        callback(posts);
      },
      (error) => console.error('subscribeToPosts error:', error),
    );
  } catch (error) {
    console.error('postService.subscribeToPosts setup error:', error);
    return () => {};
  }
};

/** Convert a Firestore Timestamp to a human-readable string. */
export const formatPostDate = (timestamp) => {
  if (!timestamp) return '—';
  const date = timestamp instanceof Timestamp ? timestamp.toDate() : new Date(timestamp);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
};
