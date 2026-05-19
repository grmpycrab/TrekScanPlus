import React, { useState, useEffect, useCallback } from 'react';
import { collection, collectionGroup, getDocs, orderBy, query } from 'firebase/firestore';
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
      // Fetch all reviews via collectionGroup (requires a Firestore index on
      // station_reviews/{stationId}/reviews). Falls back to per-station fetch
      // if the index is missing.
      let reviewDocs = [];
      try {
        const snap = await getDocs(
          query(collectionGroup(db, 'reviews'), orderBy('createdAt', 'desc')),
        );
        reviewDocs = snap.docs.map((d) => ({
          id: d.id,
          stationId: d.ref.parent.parent?.id ?? 'unknown',
          ...d.data(),
        }));
      } catch (_) {
        // Fallback: iterate known station_reviews sub-collections
        const stationsSnap = await getDocs(collection(db, 'station_reviews'));
        for (const stationDoc of stationsSnap.docs) {
          const revSnap = await getDocs(
            query(collection(db, 'station_reviews', stationDoc.id, 'reviews'), orderBy('createdAt', 'desc')),
          );
          revSnap.docs.forEach((d) => {
            reviewDocs.push({ id: d.id, stationId: stationDoc.id, ...d.data() });
          });
        }
      }

      // Group by stationId
      const byStation = {};
      for (const rev of reviewDocs) {
        const sid = rev.stationId;
        if (!byStation[sid]) {
          byStation[sid] = { stationId: sid, reviews: [], totalRating: 0 };
        }
        byStation[sid].reviews.push(rev);
        byStation[sid].totalRating += typeof rev.rating === 'number' ? rev.rating : 0;
      }

      const aggregated = Object.values(byStation).map((s) => ({
        ...s,
        reviewCount: s.reviews.length,
        avgRating: s.reviews.length > 0 ? s.totalRating / s.reviews.length : 0,
        label: stationLabel(s.stationId),
      }));

      setStations(aggregated);
    } catch (err) {
      console.error('StationActivity load error:', err);
      showError('Failed to load station data. Check Firestore permissions.');
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
                          <span className="sa-reviewer-name">{rev.userDisplayName || 'Trekker'}</span>
                          <Stars rating={rev.rating} small />
                          <span className="sa-review-date">{formatReviewDate(rev.createdAt)}</span>
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

/** Convert a station document ID to a human-readable label. */
function stationLabel(id) {
  if (!id || id === 'unknown') return 'Unknown Station';
  // IDs may be "station_1", "station_8", "14", "camp3", etc.
  const clean = id.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  return clean;
}

function formatReviewDate(ts) {
  if (!ts) return '';
  const date = ts?.toDate ? ts.toDate() : ts?.seconds ? new Date(ts.seconds * 1000) : new Date(ts);
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export default StationActivity;
