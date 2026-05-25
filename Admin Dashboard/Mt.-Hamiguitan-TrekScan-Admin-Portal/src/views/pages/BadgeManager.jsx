import React, {
  useState,
  useEffect,
  useCallback,
  useRef,
  useMemo,
  memo,
} from 'react';
import { Medal, PlusCircle, Inbox, CheckCircle, XCircle, ToggleLeft, ToggleRight } from 'lucide-react';
import {
  getAllClaims,
  approveClaim,
  rejectClaim,
  getBadgeDefinitions,
  createBadgeDefinition,
  toggleBadgeDefinitionActive,
} from '../../services/badgeService.js';
import { useToast, ToastContainer } from '../../components/Toast.jsx';
import '../style/BadgeManager.css';

// ── Module-level constants (never reconstructed) ─────────────────────────────

const REJECT_PRESETS = [
  'Image is too blurry or unclear to verify.',
  'Subject is not clearly identifiable in the photo.',
  'Proof does not match the badge requirement.',
  'Image appears digitally altered or misrepresented.',
];

const TIER_COLORS = {
  bronze:   '#CD7F32',
  silver:   '#8E9AAF',
  gold:     '#FFB800',
  platinum: '#7C3AED',
};

const EMPTY_FORM = {
  title: '',
  description: '',
  points: '',
  verificationType: 'SCAN',
  tier: 'bronze',
};

const STATUS_CLASS = {
  PENDING:  'bm-status-pending',
  APPROVED: 'bm-status-approved',
  REJECTED: 'bm-status-rejected',
};

function formatDate(val) {
  if (!val) return '—';
  const d = val.toDate ? val.toDate() : new Date(val);
  return d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' });
}

// ═══════════════════════════════════════════════════════════════════════════════
// BadgeManager — root shell (tab switcher only; holds no cross-panel state)
// ═══════════════════════════════════════════════════════════════════════════════

function BadgeManager({ adminName = 'Admin' }) {
  const [activeTab, setActiveTab] = useState('queue');
  const { toasts, removeToast, success, error: showError } = useToast();

  const handleTabQueue   = useCallback(() => setActiveTab('queue'),   []);
  const handleTabCreator = useCallback(() => setActiveTab('creator'), []);

  return (
    <div className="bm-container">
      <ToastContainer toasts={toasts} onRemove={removeToast} />

      <div className="bm-tabs">
        <button
          className={`bm-tab ${activeTab === 'queue' ? 'bm-tab-active' : ''}`}
          onClick={handleTabQueue}
        >
          <Inbox size={15} />
          Claims Queue
        </button>
        <button
          className={`bm-tab ${activeTab === 'creator' ? 'bm-tab-active' : ''}`}
          onClick={handleTabCreator}
        >
          <PlusCircle size={15} />
          Badge Creator
        </button>
      </div>

      {/* Conditional rendering means only one panel is mounted at a time.
          Switching tabs unmounts the inactive panel, so its state (form
          drafts, busy flags) does not bleed into the other panel. */}
      {activeTab === 'queue' && (
        <ClaimsQueue adminName={adminName} success={success} showError={showError} />
      )}
      {activeTab === 'creator' && (
        <BadgeCreator success={success} showError={showError} />
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ClaimsQueue — isolated panel; fetches once on mount via getDocs()
// ═══════════════════════════════════════════════════════════════════════════════

function ClaimsQueue({ adminName, success, showError }) {
  const [claims,      setClaims]      = useState({ pending: [], approved: [], rejected: [] });
  const [loading,     setLoading]     = useState(true);
  const [filter,      setFilter]      = useState('pending');
  const [busy,        setBusy]        = useState(null);
  const [rejectModal, setRejectModal] = useState({ open: false, claim: null });
  const [rejectNote,  setRejectNote]  = useState('');
  const [rejectPreset,setRejectPreset]= useState('');
  const [lightbox,    setLightbox]    = useState(null);

  // Toast refs: always-current without being useCallback/useEffect dependencies.
  // Prevents loadClaims from being recreated when the toast function reference
  // changes between renders (which would re-trigger the fetch useEffect).
  const toastRef = useRef({ success, showError });
  useEffect(() => { toastRef.current = { success, showError }; });

  // Mount guard: blocks state updates after the component unmounts.
  const mountedRef = useRef(true);
  useEffect(() => () => { mountedRef.current = false; }, []);

  // Stable fetch — empty dep array means this is created exactly once.
  // Uses getDocs() (single HTTP round-trip), not onSnapshot().
  const loadClaims = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getAllClaims();
      if (mountedRef.current) setClaims(data);
    } catch (_) {
      if (mountedRef.current) toastRef.current.showError('Failed to load claims.');
    } finally {
      if (mountedRef.current) setLoading(false);
    }
  }, []); // intentionally empty — stability guaranteed by toastRef + mountedRef

  useEffect(() => { loadClaims(); }, [loadClaims]);

  // Stable reject-state ref: lets handleRejectConfirm read current modal/note
  // values without carrying them as useCallback dependencies.
  const rejectStateRef = useRef({ rejectModal, rejectPreset, rejectNote });
  useEffect(() => {
    rejectStateRef.current = { rejectModal, rejectPreset, rejectNote };
  });

  // ── Action handlers (stable references — memo'd ClaimCard won't re-render) ──

  const handleApprove = useCallback(async (claim) => {
    setBusy(claim.id);
    try {
      await approveClaim(claim.id, claim);
      toastRef.current.success(`✓ ${claim.badgeName} approved for ${claim.userName}`);
      await loadClaims();
    } catch (_) {
      toastRef.current.showError('Approval failed. Try again.');
    } finally {
      if (mountedRef.current) setBusy(null);
    }
  }, [loadClaims]);

  const openRejectModal = useCallback((claim) => {
    setRejectModal({ open: true, claim });
    setRejectNote('');
    setRejectPreset('');
  }, []);

  const closeRejectModal = useCallback(
    () => setRejectModal({ open: false, claim: null }),
    [],
  );

  const handleRejectConfirm = useCallback(async () => {
    const { rejectModal: modal, rejectPreset: preset, rejectNote: note } =
      rejectStateRef.current;
    const finalNote = preset || note;
    setBusy(modal.claim.id);
    setRejectModal({ open: false, claim: null });
    try {
      await rejectClaim(modal.claim.id, finalNote);
      toastRef.current.success(`Claim rejected for ${modal.claim.userName}.`);
      await loadClaims();
    } catch (_) {
      toastRef.current.showError('Rejection failed. Try again.');
    } finally {
      if (mountedRef.current) setBusy(null);
    }
  }, [loadClaims]); // rejectStateRef is read inside, not a dep

  const handleImageClick = useCallback((url) => setLightbox(url), []);
  const closeLightbox    = useCallback(() => setLightbox(null),   []);

  // ── Derived data (stable when counts don't change) ───────────────────────

  const FILTERS = useMemo(() => [
    { key: 'pending',  label: 'Pending',  count: claims.pending.length  },
    { key: 'approved', label: 'Approved', count: claims.approved.length },
    { key: 'rejected', label: 'Rejected', count: claims.rejected.length },
  ], [claims.pending.length, claims.approved.length, claims.rejected.length]);

  const displayed = claims[filter] ?? [];

  // ── Filter tab handlers (stable per key) ─────────────────────────────────
  const setFilterPending  = useCallback(() => setFilter('pending'),  []);
  const setFilterApproved = useCallback(() => setFilter('approved'), []);
  const setFilterRejected = useCallback(() => setFilter('rejected'), []);
  const filterHandlers = useMemo(
    () => ({ pending: setFilterPending, approved: setFilterApproved, rejected: setFilterRejected }),
    [setFilterPending, setFilterApproved, setFilterRejected],
  );

  return (
    <>
      <p className="bm-section-title">Claims Verification Queue</p>
      <p className="bm-section-sub">
        Review photographic proof submitted by trekkers for manual-review badges.
      </p>

      <div className="bm-filter-row">
        {FILTERS.map(({ key, label, count }) => (
          <button
            key={key}
            className={`bm-filter-btn ${filter === key ? 'bm-filter-btn-active' : ''}`}
            onClick={filterHandlers[key]}
          >
            {label}
            {count > 0 && (
              <span className="bm-tab-badge" style={{ marginLeft: 6 }}>{count}</span>
            )}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="bm-loading">
          <div className="bm-spinner" />
          <span>Loading claims…</span>
        </div>
      ) : displayed.length === 0 ? (
        <div className="bm-empty">
          <div className="bm-empty-icon">🏅</div>
          <p className="bm-empty-title">No {filter} claims</p>
          <p className="bm-empty-sub">
            {filter === 'pending'
              ? 'All submissions have been reviewed.'
              : `No ${filter} submissions yet.`}
          </p>
        </div>
      ) : (
        <div className="bm-claims-grid">
          {displayed.map((claim) => (
            // claim.id is the Firestore document ID — guaranteed stable and unique.
            <ClaimCard
              key={claim.id}
              claim={claim}
              filter={filter}
              busy={busy === claim.id}
              onApprove={handleApprove}
              onReject={openRejectModal}
              onImageClick={handleImageClick}
            />
          ))}
        </div>
      )}

      {rejectModal.open && (
        <div className="bm-modal-backdrop" onClick={closeRejectModal}>
          <div className="bm-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="bm-modal-title">Reject Claim</h3>
            <p className="bm-modal-sub">
              Rejecting <strong>{rejectModal.claim?.badgeName}</strong> for{' '}
              <strong>{rejectModal.claim?.userName}</strong>. Select a reason or
              write a custom note.
            </p>
            <div className="bm-preset-reasons">
              {REJECT_PRESETS.map((r) => (
                <button
                  key={r}
                  className={`bm-preset-btn ${rejectPreset === r ? 'bm-preset-btn-active' : ''}`}
                  onClick={() => { setRejectPreset(r); setRejectNote(''); }}
                >
                  {r}
                </button>
              ))}
            </div>
            <textarea
              className="bm-modal-textarea"
              rows={3}
              placeholder="Or write a custom note…"
              value={rejectNote}
              onChange={(e) => { setRejectNote(e.target.value); setRejectPreset(''); }}
            />
            <div className="bm-modal-actions">
              <button className="bm-btn-cancel" onClick={closeRejectModal}>
                Cancel
              </button>
              <button
                className="bm-btn-confirm-reject"
                disabled={!rejectPreset && !rejectNote.trim()}
                onClick={handleRejectConfirm}
              >
                ✕ Reject Claim
              </button>
            </div>
          </div>
        </div>
      )}

      {lightbox && (
        <div className="bm-lightbox" onClick={closeLightbox}>
          <img src={lightbox} alt="Proof" className="bm-lightbox-img" />
          <button className="bm-lightbox-close" onClick={closeLightbox}>✕</button>
        </div>
      )}
    </>
  );
}

// ── ClaimCard — memoized; only re-renders when its own props change ───────────
//
// Relies on:
//   • claim.id  as the stable DOM key (set by the parent map call)
//   • busy      being a per-card boolean (true only for the card being actioned)
//   • onApprove / onReject / onImageClick being stable useCallback references
//
// Result: approving/rejecting one card does not trigger a re-render of any
// other card in the grid.

const ClaimCard = memo(function ClaimCard({
  claim,
  filter,
  busy,
  onApprove,
  onReject,
  onImageClick,
}) {
  const initials = (claim.userName ?? 'T')
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  const statusClass = STATUS_CLASS[claim.status] ?? 'bm-status-pending';

  return (
    <div className={`bm-claim-card ${busy ? 'bm-claim-card-busy' : ''}`}>
      <div className="bm-claim-header">
        <div className="bm-claim-avatar">
          {claim.userPhotoUrl ? (
            <img src={claim.userPhotoUrl} alt={claim.userName} />
          ) : (
            <span className="bm-claim-avatar-initials">{initials}</span>
          )}
        </div>
        <div className="bm-claim-meta">
          <div className="bm-claim-user">{claim.userName}</div>
          <div className="bm-claim-date">{formatDate(claim.submittedAt)}</div>
        </div>
        <span className={`bm-status-badge ${statusClass}`}>{claim.status}</span>
      </div>

      <div className="bm-claim-badge-name">
        <Medal size={14} />
        {claim.badgeName}
      </div>

      {claim.imageUrl && (
        <img
          src={claim.imageUrl}
          alt="Proof"
          className="bm-claim-image"
          onClick={() => onImageClick(claim.imageUrl)}
        />
      )}

      {claim.reviewNote && (
        <div className="bm-claim-rejection">
          <div className="bm-claim-rejection-label">Rejection Note</div>
          {claim.reviewNote}
        </div>
      )}

      {filter === 'pending' && (
        <div className="bm-claim-actions">
          <button
            className="bm-btn-reject"
            disabled={busy}
            onClick={() => onReject(claim)}
          >
            <XCircle size={14} style={{ marginRight: 5, verticalAlign: 'middle' }} />
            Reject Claim
          </button>
          <button
            className="bm-btn-approve"
            disabled={busy}
            onClick={() => onApprove(claim)}
          >
            <CheckCircle size={14} style={{ marginRight: 5, verticalAlign: 'middle' }} />
            Approve &amp; Unlock
          </button>
        </div>
      )}
    </div>
  );
});

// ═══════════════════════════════════════════════════════════════════════════════
// BadgeCreator — isolated panel; form state is quarantined from DefinitionsList
// ═══════════════════════════════════════════════════════════════════════════════

function BadgeCreator({ success, showError }) {
  const [form,    setForm]    = useState(EMPTY_FORM);
  const [saving,  setSaving]  = useState(false);
  const [definitions,  setDefinitions]  = useState([]);
  const [loadingDefs,  setLoadingDefs]  = useState(true);
  const [togglingId,   setTogglingId]   = useState(null);

  const toastRef  = useRef({ success, showError });
  useEffect(() => { toastRef.current = { success, showError }; });

  const mountedRef = useRef(true);
  useEffect(() => () => { mountedRef.current = false; }, []);

  const loadDefinitions = useCallback(async () => {
    setLoadingDefs(true);
    try {
      const defs = await getBadgeDefinitions();
      if (mountedRef.current) setDefinitions(defs);
    } catch (_) {
      // non-critical; list stays stale rather than showing an error
    } finally {
      if (mountedRef.current) setLoadingDefs(false);
    }
  }, []); // intentionally empty

  useEffect(() => { loadDefinitions(); }, [loadDefinitions]);

  // Single stable onChange handler — reads field name from the DOM element.
  // Using a name-based approach avoids creating a new closure per field per render.
  const handleFieldChange = useCallback((e) => {
    const { name, value } = e.target;
    setForm((f) => ({ ...f, [name]: value }));
  }, []);

  const handleCreate = useCallback(async (e) => {
    e.preventDefault();
    const { title, description, points, verificationType, tier } = form;
    if (!title.trim() || !description.trim() || !Number(points)) return;
    setSaving(true);
    try {
      await createBadgeDefinition({
        title:            title.trim(),
        description:      description.trim(),
        points:           Number(points),
        verificationType,
        tier,
      });
      toastRef.current.success(`Badge "${title}" created successfully.`);
      setForm(EMPTY_FORM);
      await loadDefinitions();
    } catch (_) {
      toastRef.current.showError('Failed to create badge. Try again.');
    } finally {
      if (mountedRef.current) setSaving(false);
    }
  }, [form, loadDefinitions]);

  const handleToggle = useCallback(async (def) => {
    setTogglingId(def.id);
    try {
      await toggleBadgeDefinitionActive(def.id, !def.isActive);
      await loadDefinitions();
    } catch (_) {
      toastRef.current.showError('Toggle failed.');
    } finally {
      if (mountedRef.current) setTogglingId(null);
    }
  }, [loadDefinitions]);

  const isValid = form.title.trim() && form.description.trim() && Number(form.points) > 0;

  return (
    <>
      <p className="bm-section-title">Dynamic Badge Creator</p>
      <p className="bm-section-sub">
        Spin up time-limited or event-based badges on the fly. Created badges appear
        in the mobile app's badge gallery immediately.
      </p>

      {/* Form is its own isolated block. Keystrokes here update `form` state
          only inside BadgeCreator and do NOT propagate to DefinitionsList. */}
      <form className="bm-creator-card" onSubmit={handleCreate}>
        <div className="bm-field">
          <label className="bm-label">Badge Title</label>
          <input
            className="bm-input"
            name="title"
            placeholder="e.g. Founders' Day Trekker"
            value={form.title}
            onChange={handleFieldChange}
            maxLength={60}
            required
          />
        </div>

        <div className="bm-field">
          <label className="bm-label">Description</label>
          <textarea
            className="bm-textarea"
            name="description"
            placeholder="What must the trekker do or achieve to earn this badge?"
            value={form.description}
            onChange={handleFieldChange}
            maxLength={300}
            required
          />
        </div>

        <div className="bm-field-row">
          <div className="bm-field">
            <label className="bm-label">Points</label>
            <input
              className="bm-input"
              name="points"
              type="number"
              min="1"
              max="9999"
              placeholder="e.g. 250"
              value={form.points}
              onChange={handleFieldChange}
              required
            />
          </div>

          <div className="bm-field">
            <label className="bm-label">Tier</label>
            <select
              className="bm-select"
              name="tier"
              value={form.tier}
              onChange={handleFieldChange}
            >
              <option value="bronze">Bronze</option>
              <option value="silver">Silver</option>
              <option value="gold">Gold</option>
              <option value="platinum">Platinum</option>
            </select>
          </div>
        </div>

        <div className="bm-field">
          <label className="bm-label">Verification Type</label>
          <select
            className="bm-select"
            name="verificationType"
            value={form.verificationType}
            onChange={handleFieldChange}
          >
            <option value="SCAN">SCAN — unlocked automatically on QR scan</option>
            <option value="MANUAL_IMAGE_REVIEW">
              MANUAL IMAGE REVIEW — trekker uploads proof for admin approval
            </option>
          </select>
        </div>

        <button className="bm-btn-create" type="submit" disabled={saving || !isValid}>
          <PlusCircle size={16} />
          {saving ? 'Creating…' : 'Create Badge'}
        </button>
      </form>

      {/* DefinitionsList is a separate memoized component. It does NOT re-render
          when form state changes — only when definitions or togglingId change. */}
      <DefinitionsList
        definitions={definitions}
        loadingDefs={loadingDefs}
        togglingId={togglingId}
        onToggle={handleToggle}
      />
    </>
  );
}

// ── DefinitionsList — memoized; immune to BadgeCreator form re-renders ────────

const DefinitionsList = memo(function DefinitionsList({
  definitions,
  loadingDefs,
  togglingId,
  onToggle,
}) {
  return (
    <div className="bm-def-list">
      <div className="bm-def-list-title">Admin-Created Badges</div>

      {loadingDefs ? (
        <div style={{ color: '#9ca3af', fontSize: 13, padding: '12px 0' }}>Loading…</div>
      ) : definitions.length === 0 ? (
        <div style={{ color: '#9ca3af', fontSize: 13, padding: '12px 0' }}>
          No custom badges created yet.
        </div>
      ) : (
        // key is the Firestore document ID — stable across re-renders
        definitions.map((def) => (
          <div key={def.id} className="bm-def-item">
            <div
              className="bm-def-icon"
              style={{ background: `${TIER_COLORS[def.tier] ?? '#7c3aed'}22` }}
            >
              🏅
            </div>
            <div className="bm-def-info">
              <div className="bm-def-name">{def.title}</div>
              <div className="bm-def-meta">
                <span
                  className={`bm-def-pill ${
                    def.verificationType === 'MANUAL_IMAGE_REVIEW'
                      ? 'bm-def-pill-manual'
                      : 'bm-def-pill-scan'
                  }`}
                >
                  {def.verificationType === 'MANUAL_IMAGE_REVIEW' ? 'Manual' : 'Scan'}
                </span>
                <span className="bm-def-pill bm-def-pill-pts">✦ {def.points} pts</span>
                {!def.isActive && (
                  <span className="bm-def-pill bm-def-pill-inactive">Inactive</span>
                )}
              </div>
            </div>
            <button
              className="bm-def-toggle"
              disabled={togglingId === def.id}
              onClick={() => onToggle(def)}
              title={def.isActive ? 'Deactivate' : 'Activate'}
            >
              {def.isActive ? (
                <ToggleRight size={16} style={{ verticalAlign: 'middle', color: '#7c3aed' }} />
              ) : (
                <ToggleLeft size={16} style={{ verticalAlign: 'middle' }} />
              )}
            </button>
          </div>
        ))
      )}
    </div>
  );
});

export default BadgeManager;
