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
// GroupRow — collapsible row with full admin inspection panel
// ---------------------------------------------------------------------------

function GroupRow({ group, expanded, onToggle }) {
  const [requests, setRequests] = useState([]);
  const [reqLoading, setReqLoading] = useState(false);
  const [acting, setActing] = useState(null);
  const [declineTarget, setDeclineTarget] = useState(null);
  const [declineReason, setDeclineReason] = useState('');
  // Gap M1 — admin notes state
  const [adminNoteDraft, setAdminNoteDraft] = useState(group.adminNotes ?? '');
  const [savingNotes, setSavingNotes] = useState(false);

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

  // Gap M1 — sync draft when another admin saves a note (stream update arrives)
  useEffect(() => {
    setAdminNoteDraft(group.adminNotes ?? '');
  }, [group.id, group.adminNotes]);

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

  // Gap M1 — save admin notes via existing updateGroupStatus extra parameter
  const handleSaveNotes = useCallback(async () => {
    setSavingNotes(true);
    try {
      await updateGroupStatus(group.id, group.status, { adminNotes: adminNoteDraft });
    } catch (err) {
      alert(`Save note failed: ${err.message}`);
    } finally {
      setSavingNotes(false);
    }
  }, [group.id, group.status, adminNoteDraft]);

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
          {/* Gap L2 — guide / scientist requirement badges */}
          {group.guideRequired && <span className="gbp-badge gbp-badge-guide">Guide</span>}
          {group.scientistRequired && <span className="gbp-badge gbp-badge-sci">Scientist</span>}
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

          {/* ── Admin status controls ──────────────────────────── */}
          <div className="gbp-admin-bar">
            <span className="gbp-admin-label">Admin Override:</span>
            {/* Gap H2 — 'completed' added to status override buttons */}
            {['open', 'pending_review', 'approved', 'declined', 'completed', 'cancelled'].map((s) => (
              <button
                key={s}
                className={`gbp-status-btn${group.status === s ? ' gbp-status-btn-active' : ''}`}
                onClick={() => handleGroupStatusChange(s)}
              >
                {s.replace(/_/g, ' ')}
              </button>
            ))}
          </div>

          {/* ── Gap M1: Admin notes ────────────────────────────── */}
          <div className="gbp-notes-bar">
            <div className="gbp-section-title">
              Admin Note
              <span className="gbp-notes-hint"> — visible to organizer in the mobile app</span>
            </div>
            <textarea
              className="gbp-notes-textarea"
              placeholder="Leave a note for the organizer…"
              value={adminNoteDraft}
              onChange={(e) => setAdminNoteDraft(e.target.value)}
              rows={2}
            />
            <button
              className="gbp-req-btn gbp-notes-save"
              onClick={handleSaveNotes}
              disabled={savingNotes || adminNoteDraft === (group.adminNotes ?? '')}
            >
              {savingNotes ? '…' : 'Save Note'}
            </button>
          </div>

          {/* ── Gap M2: Organizer + guest members ─────────────── */}
          {(group.organizerMember || group.guestMembers?.length > 0) && (
            <div className="gbp-members-section">
              <div className="gbp-section-title">
                Registered Members ({1 + (group.guestMembers?.length ?? 0)})
              </div>
              <div className="gbp-member-list">
                {group.organizerMember && (
                  <MemberCard
                    member={group.organizerMember}
                    role="Organizer"
                    groupAttachments={group.attachments ?? []}
                  />
                )}
                {group.guestMembers?.map((m, i) => (
                  <MemberCard
                    key={i}
                    member={m}
                    role="Guest"
                    groupAttachments={group.attachments ?? []}
                  />
                ))}
              </div>
            </div>
          )}

          {/* ── Gap C1: Letter of communication ───────────────── */}
          {group.letterOfCommunication?.downloadURL && (
            <div className="gbp-doc-bar">
              <span className="gbp-admin-label">Letter of Communication:</span>
              <a
                href={group.letterOfCommunication.downloadURL}
                target="_blank"
                rel="noreferrer"
                className="gbp-attach-link"
              >
                {group.letterOfCommunication.fileName ?? 'View Document'}
              </a>
            </div>
          )}

          {/* ── Gap C1: Group-level attachments (unowned — no memberName) ── */}
          {group.attachments?.filter((a) => !a.memberName).length > 0 && (
            <div className="gbp-doc-bar">
              <span className="gbp-admin-label">
                Group Documents ({group.attachments.filter((a) => !a.memberName).length}):
              </span>
              <div className="gbp-attach-list">
                {group.attachments.filter((a) => !a.memberName).map((a, i) => (
                  <a
                    key={i}
                    href={a.downloadURL}
                    target="_blank"
                    rel="noreferrer"
                    className="gbp-attach-link"
                  >
                    {a.fileName}
                  </a>
                ))}
              </div>
            </div>
          )}

          {/* ── Join requests ──────────────────────────────────── */}
          <div className="gbp-section-title" style={{ marginTop: 'var(--sp-2)' }}>
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
                  {/* Gap H1 — full member profile */}
                  <div className="gbp-req-info">
                    <div className="gbp-req-name">{r.userDisplayName}</div>
                    <div className="gbp-req-meta">
                      {r.member?.category?.replace(/_/g, ' ')}
                      {r.porterRequested && ' · Porter requested'}
                      {r.notes && ` · "${r.notes}"`}
                    </div>
                    <div className="gbp-req-detail">
                      {r.member?.contactNumber && (
                        <span className="gbp-req-detail-item">
                          <span className="gbp-detail-label">Contact:</span>{' '}
                          {r.member.contactNumber}
                        </span>
                      )}
                      {r.member?.gender && (
                        <span className="gbp-req-detail-item">
                          <span className="gbp-detail-label">Gender:</span>{' '}
                          {r.member.gender}
                        </span>
                      )}
                      {r.member?.birthDate && (
                        <span className="gbp-req-detail-item">
                          <span className="gbp-detail-label">Born:</span>{' '}
                          {r.member.birthDate}
                        </span>
                      )}
                      {r.member?.nationality && (
                        <span className="gbp-req-detail-item">
                          <span className="gbp-detail-label">Nationality:</span>{' '}
                          {r.member.nationality}
                        </span>
                      )}
                      {r.member?.homeAddress && (
                        <span className="gbp-req-detail-item gbp-req-detail-full">
                          <span className="gbp-detail-label">Address:</span>{' '}
                          {r.member.homeAddress}
                        </span>
                      )}
                    </div>
                    {/* Gap C1 — join request attachments */}
                    {r.attachments?.length > 0 && (
                      <div className="gbp-req-attach">
                        <span className="gbp-detail-label">
                          Documents ({r.attachments.length}):
                        </span>
                        <div className="gbp-attach-list">
                          {r.attachments.map((a, i) => (
                            <a
                              key={i}
                              href={a.downloadURL}
                              target="_blank"
                              rel="noreferrer"
                              className="gbp-attach-link"
                            >
                              {a.fileName}
                            </a>
                          ))}
                        </div>
                      </div>
                    )}
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

// ---------------------------------------------------------------------------
// MemberCard — Gap M2: renders organizer or guest member profile
// ---------------------------------------------------------------------------

function MemberCard({ member, role, groupAttachments = [] }) {
  const fullName = `${member.firstName} ${member.lastName}`.trim();
  // Filter group.attachments to only those belonging to this member
  const memberDocs = groupAttachments.filter((a) => a.memberName === fullName);

  return (
    <div className="gbp-member-card">
      <div className="gbp-member-role">{role}</div>
      <div className="gbp-member-name">
        {member.firstName} {member.lastName}
      </div>
      <div className="gbp-member-detail">
        {member.category && (
          <span className="gbp-req-detail-item">
            <span className="gbp-detail-label">Category:</span>{' '}
            {member.category.replace(/_/g, ' ')}
          </span>
        )}
        {member.gender && (
          <span className="gbp-req-detail-item">
            <span className="gbp-detail-label">Gender:</span> {member.gender}
          </span>
        )}
        {member.birthDate && (
          <span className="gbp-req-detail-item">
            <span className="gbp-detail-label">Born:</span> {member.birthDate}
          </span>
        )}
        {member.contactNumber && (
          <span className="gbp-req-detail-item">
            <span className="gbp-detail-label">Contact:</span> {member.contactNumber}
          </span>
        )}
        {member.nationality && (
          <span className="gbp-req-detail-item">
            <span className="gbp-detail-label">Nationality:</span> {member.nationality}
          </span>
        )}
        {member.homeAddress && (
          <span className="gbp-req-detail-item gbp-req-detail-full">
            <span className="gbp-detail-label">Address:</span> {member.homeAddress}
          </span>
        )}
      </div>
      {/* Documents uploaded for this specific member during group creation */}
      {memberDocs.length > 0 && (
        <div className="gbp-req-attach">
          <span className="gbp-detail-label">
            Documents ({memberDocs.length}):
          </span>
          <div className="gbp-attach-list">
            {memberDocs.map((a, i) => (
              <a
                key={i}
                href={a.downloadURL}
                target="_blank"
                rel="noreferrer"
                className="gbp-attach-link"
              >
                {a.fileName}
              </a>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// RequestStatusBadge — Gap L1: 'withdrawn' added to color and bg maps
// ---------------------------------------------------------------------------

function RequestStatusBadge({ status }) {
  const colors = {
    pending: '#d97706',
    approved: '#16a34a',
    declined: '#dc2626',
    withdrawn: '#546e7a',
  };
  const bgs = {
    pending: '#fffbeb',
    approved: '#f0fdf4',
    declined: '#fef2f2',
    withdrawn: '#f5f5f5',
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
