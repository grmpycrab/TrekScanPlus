import React, { useState, useEffect, useCallback } from 'react';
import {
  subscribeToGroupBookings,
  subscribeToJoinRequests,
  approveJoinRequest,
  declineJoinRequest,
  updateGroupStatus,
  formatGroupDate,
  trekTypeLabel,
  classificationLabel,
  groupStatusColor,
} from '../../services/groupBookingService';
import { getCurrentUser } from '../../services/firebaseAuthService';
import './GroupBookingsPanel.css';

// ---------------------------------------------------------------------------
// GroupBookingsPanel
// ---------------------------------------------------------------------------

function GroupBookingsPanel() {
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [expandedGroup, setExpandedGroup] = useState(null);

  useEffect(() => {
    setLoading(true);
    const unsub = subscribeToGroupBookings(
      (data) => { setGroups(data); setLoading(false); },
      (err) => { console.error('GroupBookingsPanel:', err); setLoading(false); },
      statusFilter === 'all' ? null : statusFilter,
    );
    return unsub;
  }, [statusFilter]);

  const filtered = groups.filter((g) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      g.groupName?.toLowerCase().includes(q) ||
      g.organizerName?.toLowerCase().includes(q) ||
      g.affiliation?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="gbp-root">
      {/* ── Toolbar ─────────────────────────────────────────────── */}
      <div className="gbp-toolbar">
        <input
          className="gbp-search"
          placeholder="Search group name, organizer, affiliation…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select
          className="gbp-select"
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
        >
          <option value="all">All Statuses</option>
          <option value="open">Open</option>
          <option value="pending_review">Pending Review</option>
          <option value="approved">Approved</option>
          <option value="full">Full</option>
          <option value="declined">Declined</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>

      {/* ── Content ─────────────────────────────────────────────── */}
      {loading ? (
        <div className="gbp-center"><span className="gbp-spinner" /> Loading groups…</div>
      ) : filtered.length === 0 ? (
        <div className="gbp-center gbp-empty">No group bookings found.</div>
      ) : (
        <div className="gbp-list">
          {filtered.map((g) => (
            <GroupRow
              key={g.id}
              group={g}
              expanded={expandedGroup === g.id}
              onToggle={() =>
                setExpandedGroup((prev) => (prev === g.id ? null : g.id))
              }
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// GroupRow — collapsible row with join-request sub-panel
// ---------------------------------------------------------------------------

function GroupRow({ group, expanded, onToggle }) {
  const [requests, setRequests] = useState([]);
  const [reqLoading, setReqLoading] = useState(false);
  const [acting, setActing] = useState(null);
  const [declineTarget, setDeclineTarget] = useState(null);
  const [declineReason, setDeclineReason] = useState('');

  useEffect(() => {
    if (!expanded) return;
    setReqLoading(true);
    const unsub = subscribeToJoinRequests(
      group.id,
      (data) => { setRequests(data); setReqLoading(false); },
      (err) => { console.error('joinRequests stream:', err); setReqLoading(false); },
    );
    return unsub;
  }, [expanded, group.id]);

  const handleApprove = useCallback(async (requestId) => {
    const user = getCurrentUser();
    if (!user) return;
    setActing(requestId);
    try {
      await approveJoinRequest(group.id, requestId, user.uid);
    } catch (err) {
      alert(`Approve failed: ${err.message}`);
    } finally {
      setActing(null);
    }
  }, [group.id]);

  const handleDeclineSubmit = useCallback(async () => {
    if (!declineTarget) return;
    const user = getCurrentUser();
    if (!user) return;
    setActing(declineTarget);
    try {
      await declineJoinRequest(group.id, declineTarget, user.uid, declineReason || null);
      setDeclineTarget(null);
      setDeclineReason('');
    } catch (err) {
      alert(`Decline failed: ${err.message}`);
    } finally {
      setActing(null);
    }
  }, [group.id, declineTarget, declineReason]);

  const handleGroupStatusChange = async (newStatus) => {
    try {
      await updateGroupStatus(group.id, newStatus);
    } catch (err) {
      alert(`Status update failed: ${err.message}`);
    }
  };

  const statusDot = { backgroundColor: groupStatusColor(group.status) };

  return (
    <div className="gbp-row">
      {/* Row header */}
      <button className="gbp-row-header" onClick={onToggle}>
        <div className="gbp-row-left">
          <span className="gbp-status-dot" style={statusDot} />
          <div>
            <div className="gbp-group-name">{group.groupName}</div>
            <div className="gbp-group-meta">
              {group.organizerName} · {group.affiliation} · {formatGroupDate(group.trekDate)}
            </div>
          </div>
        </div>
        <div className="gbp-row-right">
          <span className="gbp-badge gbp-badge-type">{trekTypeLabel(group.trekType)}</span>
          <span className="gbp-badge gbp-badge-class">{classificationLabel(group.bookingClassification)}</span>
          <span className="gbp-slots">{group.currentSlots}/{group.maxSlots} trekkers</span>
          <span className="gbp-status-label" style={{ color: groupStatusColor(group.status) }}>
            {group.status?.replace(/_/g, ' ').toUpperCase()}
          </span>
          <span className="gbp-chevron">{expanded ? '▲' : '▼'}</span>
        </div>
      </button>

      {/* Expanded panel */}
      {expanded && (
        <div className="gbp-expand">
          {/* Admin status controls */}
          <div className="gbp-admin-bar">
            <span className="gbp-admin-label">Admin Override:</span>
            {['open', 'pending_review', 'approved', 'declined', 'cancelled'].map((s) => (
              <button
                key={s}
                className={`gbp-status-btn${group.status === s ? ' gbp-status-btn-active' : ''}`}
                onClick={() => handleGroupStatusChange(s)}
              >
                {s.replace(/_/g, ' ')}
              </button>
            ))}
          </div>

          {/* Join requests */}
          <div className="gbp-requests-title">
            Join Requests ({requests.length})
          </div>

          {reqLoading ? (
            <div className="gbp-center"><span className="gbp-spinner" /> Loading requests…</div>
          ) : requests.length === 0 ? (
            <div className="gbp-empty gbp-requests-empty">No join requests yet.</div>
          ) : (
            <div className="gbp-req-list">
              {requests.map((r) => (
                <div key={r.id} className="gbp-req-row">
                  <div className="gbp-req-info">
                    <div className="gbp-req-name">{r.userDisplayName}</div>
                    <div className="gbp-req-meta">
                      {r.member?.category?.replace(/_/g, ' ')}
                      {r.porterRequested && ' · Porter requested'}
                      {r.notes && ` · "${r.notes}"`}
                    </div>
                  </div>
                  <div className="gbp-req-status">
                    <RequestStatusBadge status={r.status} />
                  </div>
                  {r.status === 'pending' && (
                    <div className="gbp-req-actions">
                      <button
                        className="gbp-req-btn gbp-req-approve"
                        disabled={acting === r.id}
                        onClick={() => handleApprove(r.id)}
                      >
                        {acting === r.id ? '…' : 'Approve'}
                      </button>
                      <button
                        className="gbp-req-btn gbp-req-decline"
                        disabled={acting === r.id}
                        onClick={() => setDeclineTarget(r.id)}
                      >
                        Decline
                      </button>
                    </div>
                  )}
                  {r.declineReason && (
                    <div className="gbp-decline-reason">Reason: {r.declineReason}</div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Decline reason modal */}
          {declineTarget && (
            <div className="gbp-decline-modal-overlay">
              <div className="gbp-decline-modal">
                <h4 className="gbp-decline-modal-title">Decline Join Request</h4>
                <textarea
                  className="gbp-decline-textarea"
                  placeholder="Reason for declining (optional)…"
                  value={declineReason}
                  onChange={(e) => setDeclineReason(e.target.value)}
                  rows={3}
                />
                <div className="gbp-decline-modal-actions">
                  <button
                    className="gbp-req-btn gbp-req-cancel"
                    onClick={() => { setDeclineTarget(null); setDeclineReason(''); }}
                  >
                    Cancel
                  </button>
                  <button
                    className="gbp-req-btn gbp-req-decline"
                    disabled={!!acting}
                    onClick={handleDeclineSubmit}
                  >
                    {acting ? '…' : 'Confirm Decline'}
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function RequestStatusBadge({ status }) {
  const colors = {
    pending: '#d97706',
    approved: '#16a34a',
    declined: '#dc2626',
  };
  const bgs = {
    pending: '#fffbeb',
    approved: '#f0fdf4',
    declined: '#fef2f2',
  };
  return (
    <span
      style={{
        padding: '2px 8px',
        borderRadius: 9999,
        fontSize: 11,
        fontWeight: 600,
        color: colors[status] ?? '#6b7280',
        background: bgs[status] ?? '#f3f4f6',
      }}
    >
      {status?.toUpperCase()}
    </span>
  );
}

export default GroupBookingsPanel;
