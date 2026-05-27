import React, { useState, useEffect, useCallback } from 'react';
import { collectionGroup, getDocs } from 'firebase/firestore';
import { db } from '../../config/firebase.js';
import { useToast, ToastContainer } from '../../components/Toast.jsx';
import '../style/StationActivity.css';

const STAR_COUNT = 5;

function StationActivity() {
  const [stations, setStations] = useState([]);   // aggregated station data
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState('reviews'); // 'reviews' | 'rating' | 'name'
  const [expanded, setExpanded] = useState(null);  // stationId with expanded reviews

  const { toasts, removeToast, error: showError } = useToast();

  const load = useCallback(async () => {
    setLoading(true);
    try {
      // collectionGroup('reviews') fetches every review document across all
      // station_reviews/{stationId}/reviews subcollections in a single round
      // trip. No orderBy here — Firestore composite indexes are not required
      // for unordered collectionGroup queries, and sorting is done client-side
      // below. Security rules must include a wildcard path rule:
      //   match /{path=**}/reviews/{reviewId} { allow read: if true; }
      const snap = await getDocs(collectionGroup(db, 'reviews'));
      const reviewDocs = snap.docs.map((d) => ({
        id: d.id,
        stationId: d.ref.parent.parent?.id ?? 'unknown',
        ...d.data(),
      }));

      // Normalise field names: the mobile app writes camelCase (`userDisplayName`,
      // `updatedAt`, etc.). Guard against any legacy snake_case variants that may
      // have been written by older builds.
      const normalise = (rev) => ({
        ...rev,
        userDisplayName: rev.userDisplayName ?? rev.user_display_name ?? 'Trekker',
        rating: typeof rev.rating === 'number' ? rev.rating : 0,
        updatedAt: rev.updatedAt ?? rev.updated_at ?? rev.createdAt ?? rev.created_at ?? null,
        createdAt: rev.createdAt ?? rev.created_at ?? null,
      });

      // Group by stationId
      const byStation = {};
      for (const raw of reviewDocs) {
        const rev = normalise(raw);
        const sid = rev.stationId;
        if (!byStation[sid]) {
          byStation[sid] = { stationId: sid, reviews: [], totalRating: 0 };
        }
        byStation[sid].reviews.push(rev);
        byStation[sid].totalRating += rev.rating;
      }

      const toMs = (ts) => {
        if (!ts) return 0;
        if (ts.toDate) return ts.toDate().getTime();
        if (ts.seconds) return ts.seconds * 1000;
        return new Date(ts).getTime();
      };

      const aggregated = Object.values(byStation).map((s) => {
        // Sort reviews newest-first client-side (no Firestore composite index needed).
        const sorted = [...s.reviews].sort(
          (a, b) => toMs(b.updatedAt ?? b.createdAt) - toMs(a.updatedAt ?? a.createdAt),
        );
        return {
          ...s,
          reviews: sorted,
          reviewCount: sorted.length,
          avgRating: sorted.length > 0 ? s.totalRating / sorted.length : 0,
          label: stationLabel(s.stationId),
        };
      });

      setStations(aggregated);
    } catch (err) {
      console.error('StationActivity load error:', err);
      const msg = String(err?.message ?? err ?? '');
      const isPermissionDenied = msg.includes('permission') || msg.includes('Missing or insufficient permissions');
      const isBlocked = msg.includes('ERR_BLOCKED_BY_CLIENT') || msg.includes('net::ERR');
      const hint = isPermissionDenied
        ? 'Firestore permission denied — ensure the wildcard collectionGroup rule for "reviews" is deployed.'
        : isBlocked
        ? 'Network request blocked by a browser extension (e.g. ad-blocker). Disable it for this portal and refresh.'
        : 'Failed to load station reviews. Check the browser console for details.';
      showError(hint);
    } finally {
      setLoading(false);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { load(); }, [load]);

  const filtered = stations
    .filter((s) => s.label.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      if (sortBy === 'rating') return b.avgRating - a.avgRating;
      if (sortBy === 'name')   return a.label.localeCompare(b.label);
      return b.reviewCount - a.reviewCount; // default: most reviews first
    });

  const toggleExpand = (stationId) =>
    setExpanded((prev) => (prev === stationId ? null : stationId));

  return (
    <div className="sa-container">
      {/* Controls */}
      <div className="sa-controls">
        <input
          type="text"
          className="sa-search"
          placeholder="Search station…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select
          className="sa-sort"
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value)}
        >
          <option value="reviews">Sort: Most Reviews</option>
          <option value="rating">Sort: Highest Rating</option>
          <option value="name">Sort: Name A–Z</option>
        </select>
        <button className="sa-refresh-btn" onClick={load} disabled={loading}>
          {loading ? 'Loading…' : '↺ Refresh'}
        </button>
      </div>

      {/* Summary bar */}
      {!loading && (
        <div className="sa-summary">
          <div className="sa-summary-stat">
            <span className="sa-summary-value">{stations.length}</span>
            <span className="sa-summary-label">Stations with activity</span>
          </div>
          <div className="sa-summary-stat">
            <span className="sa-summary-value">
              {stations.reduce((acc, s) => acc + s.reviewCount, 0)}
            </span>
            <span className="sa-summary-label">Total reviews</span>
          </div>
          <div className="sa-summary-stat">
            <span className="sa-summary-value">
              {stations.length > 0
                ? (stations.reduce((acc, s) => acc + s.avgRating, 0) / stations.length).toFixed(1)
                : '—'}
            </span>
            <span className="sa-summary-label">Avg rating (all stations)</span>
          </div>
        </div>
      )}

      {loading ? (
        <div className="sa-loading">
          <div className="sa-spinner" />
          <span>Loading station activity…</span>
        </div>
      ) : filtered.length === 0 ? (
        <div className="sa-empty">
          <div className="sa-empty-icon">🗺️</div>
          <div className="sa-empty-title">No station activity found</div>
          <div className="sa-empty-sub">
            Station reviews from the mobile app will appear here once submitted.
          </div>
        </div>
      ) : (
        <div className="sa-list">
          {filtered.map((station) => (
            <div key={station.stationId} className="sa-card">
              {/* Station header */}
              <div className="sa-card-header" onClick={() => toggleExpand(station.stationId)}>
                <div className="sa-station-info">
                  <div className="sa-station-name">{station.label}</div>
                  <div className="sa-station-sub">{station.reviewCount} review{station.reviewCount !== 1 ? 's' : ''}</div>
                </div>
                <div className="sa-rating-group">
                  <Stars rating={station.avgRating} />
                  <span className="sa-rating-num">{station.avgRating.toFixed(1)}</span>
                </div>
                <div className="sa-rating-bar-wrap">
                  <div
                    className="sa-rating-bar"
                    style={{ width: `${(station.avgRating / STAR_COUNT) * 100}%` }}
                  />
                </div>
                <button className={`sa-expand-btn${expanded === station.stationId ? ' sa-expand-open' : ''}`}>
                  ▾
                </button>
              </div>

              {/* Expanded reviews */}
              {expanded === station.stationId && (
                <div className="sa-reviews">
                  {station.reviews.length === 0 ? (
                    <p className="sa-no-reviews">No reviews yet.</p>
                  ) : (
                    station.reviews.map((rev) => (
                      <div key={rev.id} className="sa-review-item">
                        <div className="sa-review-header">
                          <span className="sa-reviewer-name">{rev.userDisplayName}</span>
                          <Stars rating={rev.rating} small />
                          {/* Use updatedAt so edits surface the latest timestamp,
                              matching what the mobile app displays. */}
                          <span className="sa-review-date">{formatReviewDate(rev.updatedAt ?? rev.createdAt)}</span>
                        </div>
                        {rev.comment && <p className="sa-review-comment">{rev.comment}</p>}
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

function Stars({ rating, small = false }) {
  const full = Math.floor(rating);
  const half = rating - full >= 0.5;
  return (
    <div className={`sa-stars${small ? ' sa-stars-small' : ''}`}>
      {Array.from({ length: STAR_COUNT }).map((_, i) => (
        <span
          key={i}
          className={`sa-star${i < full ? ' sa-star-full' : i === full && half ? ' sa-star-half' : ''}`}
        >
          ★
        </span>
      ))}
    </div>
  );
}

const STATION_NAMES = {
  '56okrkt0pb': 'UNESCO Marker',
  'hu2c5c0kfn': 'Crossing Stampa',
  'um6j8dnii4': 'Puting Bato',
  '3ko938o2gb': 'Lantawan 1',
  '33ii1jrc5s': 'Camp 4',
  'vaatj8uomu': 'Uwang-Uwang Trail',
  'cbensi5juq': 'Lantawan 2',
  'utvrrkfkh9': 'Camp 3',
  '6mm4kle34g': 'Pygmy Field',
  'g5uabiveqd': 'Lantawan 3 / Mossy Forest',
  '79t42cmo77': 'Tinagong Dagat',
  'i73hl7b7g3': 'Hidden Garden',
  'mr2l529okj': 'Mt. Hamiguitan Summit',
  '44r5tebjrc': 'Black Mountain',
  'r5kntj3sae': 'Twin Falls',
};

/** Resolve a station document ID to its human-readable trail name. */
function stationLabel(id) {
  if (!id || id === 'unknown') return 'Unknown Station';
  return STATION_NAMES[id] ?? `Unknown Station (${id})`;
}

function formatReviewDate(ts) {
  if (!ts) return '';
  const date = ts?.toDate ? ts.toDate() : ts?.seconds ? new Date(ts.seconds * 1000) : new Date(ts);
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export default StationActivity;
