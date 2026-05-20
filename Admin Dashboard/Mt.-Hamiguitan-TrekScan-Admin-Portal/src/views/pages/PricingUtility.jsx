import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  subscribeToActivePricingVersion,
  subscribeToPricingVersions,
  createPricingVersion,
  migrateFromLegacy,
  DEFAULT_PRICING,
  RESOLUTION_TYPES,
  formatVersionDate,
  resolutionTypeLabel,
  calculateMemberPrice,
} from '../../services/pricingService';
import { getCurrentUser } from '../../services/firebaseAuthService';
import '../style/PricingUtility.css';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const peso = (n) => `₱${Number(n).toLocaleString('en-PH')}`;

const cloneDeep = (obj) => JSON.parse(JSON.stringify(obj));

const todayISO = () => new Date().toISOString().slice(0, 10);

const TREK_TYPE_OPTIONS = [
  { key: 'special_trek',       label: 'Special Trek' },
  { key: 'research_trek',      label: 'Research Trek' },
  { key: 'government_official',label: 'Government / Official' },
  { key: 'benchmarking_trek',  label: 'Benchmarking' },
];

// ---------------------------------------------------------------------------
// PricingSummary  — read-only display of one version's pricing data
// ---------------------------------------------------------------------------

function PricingSummary({ version }) {
  const base = version?.basePricePerPerson ?? DEFAULT_PRICING.basePricePerPerson;
  const cats = version?.categories ?? DEFAULT_PRICING.categories;
  const svcs = version?.services ?? DEFAULT_PRICING.services;
  const season = version?.seasonalRules ?? DEFAULT_PRICING.seasonalRules;

  return (
    <div className="pu-summary">
      {/* Base price */}
      <div className="pu-summary-section">
        <div className="pu-summary-label">Base Price per Person</div>
        <div className="pu-summary-base">{peso(base)}</div>
      </div>

      {/* Category discounts */}
      <div className="pu-summary-section">
        <div className="pu-summary-label">Category Discounts</div>
        <div className="pu-summary-table">
          <div className="pu-summary-table-head">
            <span>Category</span>
            <span>Discount</span>
            <span>Price</span>
          </div>
          {Object.entries(cats).map(([key, cat]) => {
            const disc = Number(cat.discount) || 0;
            const price = Math.round(base * (1 - disc / 100));
            return (
              <div key={key} className="pu-summary-table-row">
                <span>{cat.displayName}</span>
                <span>{disc === 0 ? 'Full price' : `${disc}% off`}</span>
                <span className="pu-summary-price">{peso(price)}</span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Service fees */}
      <div className="pu-summary-section">
        <div className="pu-summary-label">Service Fees</div>
        <div className="pu-services-row">
          {[
            { key: 'porter',    label: 'Porter' },
            { key: 'guide',     label: 'Guide' },
            { key: 'scientist', label: 'Scientist' },
          ].map(({ key, label }) => (
            <div key={key} className="pu-service-chip">
              <span className="pu-service-chip-label">{label}</span>
              <span className="pu-service-chip-price">{peso(svcs[key] ?? 0)}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Off-season */}
      <div className="pu-summary-section">
        <div className="pu-summary-label">Off-Season Window</div>
        <div className="pu-summary-season">
          {season.offSeasonStart} – {season.offSeasonEnd}
          <span className="pu-summary-season-types">
            Allowed: {(season.allowedBookingTypes ?? []).join(', ') || '—'}
          </span>
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// VersionRow  — collapsible history row
// ---------------------------------------------------------------------------

function VersionRow({ version, defaultOpen = false }) {
  const [open, setOpen] = useState(defaultOpen);

  const statusColor = version.status === 'active' ? 'var(--green-500)' : 'var(--neutral-300)';
  const statusLabel = version.status === 'active' ? 'Active' : 'Superseded';

  return (
    <div className={`pu-version-row${version.status === 'active' ? ' pu-version-row-active' : ''}`}>
      <button className="pu-version-header" onClick={() => setOpen((o) => !o)}>
        <div className="pu-version-header-left">
          <span className="pu-version-dot" style={{ background: statusColor }} />
          <div>
            <div className="pu-version-title">
              Version {version.versionNumber}
              <span className="pu-version-status-label" style={{ color: statusColor }}>
                {statusLabel}
              </span>
            </div>
            <div className="pu-version-meta">
              {formatVersionDate(version.effectiveFrom)}
              {version.effectiveUntil
                ? ` – ${formatVersionDate(version.effectiveUntil)}`
                : ' – Present'}
              {version.resolutionRef && (
                <span className="pu-version-res"> · {version.resolutionRef}</span>
              )}
              <span className="pu-version-type">
                {resolutionTypeLabel(version.resolutionType)}
              </span>
            </div>
          </div>
        </div>
        <div className="pu-version-header-right">
          <span className="pu-version-base">
            {peso(version.basePricePerPerson ?? DEFAULT_PRICING.basePricePerPerson)}
          </span>
          <span className="pu-chevron">{open ? '▲' : '▼'}</span>
        </div>
      </button>

      {open && (
        <div className="pu-version-body">
          {version.resolutionNotes && (
            <div className="pu-version-notes">
              <span className="pu-version-notes-label">Notes: </span>
              {version.resolutionNotes}
            </div>
          )}
          <PricingSummary version={version} />
          <div className="pu-version-footer">
            Created by UID {version.createdBy ?? '—'} on {formatVersionDate(version.createdAt)}
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// NewVersionModal  — full form for creating a new pricing version
// ---------------------------------------------------------------------------

const emptyForm = (activeVersion) => ({
  resolutionRef:   '',
  resolutionType:  '',
  resolutionNotes: '',
  effectiveFrom:   todayISO(),
  basePricePerPerson: activeVersion?.basePricePerPerson ?? DEFAULT_PRICING.basePricePerPerson,
  categories:      cloneDeep(activeVersion?.categories ?? DEFAULT_PRICING.categories),
  services:        cloneDeep(activeVersion?.services   ?? DEFAULT_PRICING.services),
  seasonalRules:   cloneDeep(activeVersion?.seasonalRules ?? DEFAULT_PRICING.seasonalRules),
});

function NewVersionModal({ activeVersion, versionCount, onClose, onSuccess }) {
  const [form, setForm] = useState(() => emptyForm(activeVersion));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const set = (key, val) => setForm((f) => ({ ...f, [key]: val }));

  const setCat = (key, field, val) =>
    setForm((f) => ({
      ...f,
      categories: {
        ...f.categories,
        [key]: { ...f.categories[key], [field]: val },
      },
    }));

  const setSvc = (key, val) =>
    setForm((f) => ({ ...f, services: { ...f.services, [key]: val } }));

  const setSeason = (key, val) =>
    setForm((f) => ({ ...f, seasonalRules: { ...f.seasonalRules, [key]: val } }));

  const toggleAllowed = (key) => {
    const cur = form.seasonalRules.allowedBookingTypes ?? [];
    const next = cur.includes(key) ? cur.filter((t) => t !== key) : [...cur, key];
    setSeason('allowedBookingTypes', next);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    if (!form.resolutionRef.trim()) { setError('Resolution reference is required.'); return; }
    if (!form.resolutionType)       { setError('Resolution type is required.'); return; }
    if (!form.effectiveFrom)        { setError('Effective date is required.'); return; }

    setSaving(true);
    try {
      const user = getCurrentUser();
      if (!user) throw new Error('Not authenticated');

      const pricing = {
        basePricePerPerson: Number(form.basePricePerPerson),
        categories: Object.fromEntries(
          Object.entries(form.categories).map(([k, v]) => [
            k, { ...v, discount: Number(v.discount) },
          ]),
        ),
        services: {
          porter:    Number(form.services.porter),
          guide:     Number(form.services.guide),
          scientist: Number(form.services.scientist),
        },
        seasonalRules: form.seasonalRules,
      };

      await createPricingVersion({
        pricing,
        effectiveFrom:   new Date(form.effectiveFrom),
        resolutionRef:   form.resolutionRef.trim(),
        resolutionType:  form.resolutionType,
        resolutionNotes: form.resolutionNotes.trim(),
        versionNumber:   (versionCount ?? 0) + 1,
        adminUid:        user.uid,
      });

      onSuccess?.();
    } catch (err) {
      console.error('NewVersionModal submit:', err);
      setError(`Failed to create version: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const effectiveBase = Number(form.basePricePerPerson) || 0;

  return (
    <div className="pu-modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="pu-modal">
        <div className="pu-modal-header">
          <h2 className="pu-modal-title">Create New Pricing Version</h2>
          <button className="pu-modal-close" onClick={onClose} disabled={saving}>✕</button>
        </div>

        <form className="pu-modal-body" onSubmit={handleSubmit}>

          {/* ── Resolution details ─────────────────────────────────────── */}
          <div className="pu-form-section">
            <div className="pu-form-section-title">Resolution / Policy</div>
            <div className="pu-form-row-2">
              <div className="pu-field">
                <label className="pu-label">Resolution Reference <span className="pu-req">*</span></label>
                <input
                  className="pu-input"
                  type="text"
                  placeholder="e.g. Municipal Resolution No. 2025-14"
                  value={form.resolutionRef}
                  onChange={(e) => set('resolutionRef', e.target.value)}
                  required
                />
              </div>
              <div className="pu-field">
                <label className="pu-label">Resolution Type <span className="pu-req">*</span></label>
                <select
                  className="pu-input pu-select"
                  value={form.resolutionType}
                  onChange={(e) => set('resolutionType', e.target.value)}
                  required
                >
                  <option value="">Select type…</option>
                  {RESOLUTION_TYPES.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="pu-field">
              <label className="pu-label">Notes / Remarks</label>
              <textarea
                className="pu-input pu-textarea"
                rows={3}
                placeholder="Optional: additional context for this pricing change"
                value={form.resolutionNotes}
                onChange={(e) => set('resolutionNotes', e.target.value)}
              />
            </div>
            <div className="pu-field">
              <label className="pu-label">Effective From <span className="pu-req">*</span></label>
              <input
                className="pu-input"
                type="date"
                value={form.effectiveFrom}
                onChange={(e) => set('effectiveFrom', e.target.value)}
                required
              />
            </div>
          </div>

          {/* ── Base price ─────────────────────────────────────────────── */}
          <div className="pu-form-section">
            <div className="pu-form-section-title">Base Price per Person</div>
            <div className="pu-base-row">
              <span className="pu-peso-prefix">₱</span>
              <input
                type="number"
                className="pu-input pu-input-lg"
                value={form.basePricePerPerson}
                min={0}
                onChange={(e) => set('basePricePerPerson', e.target.value)}
              />
            </div>
          </div>

          {/* ── Category discounts ─────────────────────────────────────── */}
          <div className="pu-form-section">
            <div className="pu-form-section-title">Category Discounts</div>
            <div className="pu-table">
              <div className="pu-table-head">
                <span>Category</span>
                <span>Discount %</span>
                <span>Effective Price</span>
              </div>
              {Object.entries(form.categories).map(([key, cat]) => {
                const disc = Number(cat.discount) || 0;
                const effective = Math.round(effectiveBase * (1 - disc / 100));
                return (
                  <div key={key} className="pu-table-row">
                    <span className="pu-cat-name">{cat.displayName}</span>
                    <div className="pu-discount-cell">
                      <input
                        type="number"
                        className="pu-input pu-input-sm"
                        value={cat.discount}
                        min={0}
                        max={100}
                        onChange={(e) => setCat(key, 'discount', e.target.value)}
                      />
                      <span className="pu-pct">%</span>
                    </div>
                    <span className="pu-effective-price">{peso(effective)}</span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* ── Service fees ───────────────────────────────────────────── */}
          <div className="pu-form-section">
            <div className="pu-form-section-title">Service Fees</div>
            <div className="pu-services-grid">
              {[
                { key: 'porter',    label: 'Porter',     desc: 'Per member who requests one' },
                { key: 'guide',     label: 'Tour Guide', desc: 'Group-level, one per group' },
                { key: 'scientist', label: 'Scientist',  desc: 'Group-level, one per group' },
              ].map(({ key, label, desc }) => (
                <div key={key} className="pu-service-card">
                  <div className="pu-service-label">{label}</div>
                  <div className="pu-service-desc">{desc}</div>
                  <div className="pu-base-row pu-service-input-row">
                    <span className="pu-peso-prefix">₱</span>
                    <input
                      type="number"
                      className="pu-input"
                      value={form.services[key] ?? 0}
                      min={0}
                      onChange={(e) => setSvc(key, e.target.value)}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* ── Seasonal rules ─────────────────────────────────────────── */}
          <div className="pu-form-section">
            <div className="pu-form-section-title">Off-Season Rules</div>
            <div className="pu-seasonal-grid">
              <div className="pu-field">
                <label className="pu-label">Start (MM-DD)</label>
                <input
                  type="text"
                  className="pu-input"
                  placeholder="07-01"
                  value={form.seasonalRules.offSeasonStart}
                  onChange={(e) => setSeason('offSeasonStart', e.target.value)}
                />
              </div>
              <div className="pu-field">
                <label className="pu-label">End (MM-DD)</label>
                <input
                  type="text"
                  className="pu-input"
                  placeholder="09-30"
                  value={form.seasonalRules.offSeasonEnd}
                  onChange={(e) => setSeason('offSeasonEnd', e.target.value)}
                />
              </div>
            </div>
            <div className="pu-field pu-field-mt">
              <label className="pu-label">Allowed Trek Types During Off-Season</label>
              <div className="pu-checkbox-group">
                {TREK_TYPE_OPTIONS.map(({ key, label }) => {
                  const allowed = form.seasonalRules.allowedBookingTypes ?? [];
                  return (
                    <label key={key} className="pu-checkbox-label">
                      <input
                        type="checkbox"
                        checked={allowed.includes(key)}
                        onChange={() => toggleAllowed(key)}
                      />
                      {label}
                    </label>
                  );
                })}
              </div>
            </div>
          </div>

          {/* ── Error / submit ─────────────────────────────────────────── */}
          {error && <div className="pu-alert pu-alert-error">{error}</div>}

          <div className="pu-modal-footer">
            <button type="button" className="pu-btn-ghost" onClick={onClose} disabled={saving}>
              Cancel
            </button>
            <button type="submit" className="pu-btn-primary" disabled={saving}>
              {saving ? 'Creating…' : 'Create Version'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// PricingUtility  — root page component
// ---------------------------------------------------------------------------

function PricingUtility() {
  const [activeVersion, setActiveVersion]   = useState(undefined); // undefined = loading
  const [allVersions,   setAllVersions]     = useState([]);
  const [migrated,      setMigrated]        = useState(false);
  const [showModal,     setShowModal]       = useState(false);
  const [successMsg,    setSuccessMsg]      = useState(null);
  const successTimer = useRef(null);

  // ── Migration + subscriptions ────────────────────────────────────────────

  useEffect(() => {
    const user = getCurrentUser();
    migrateFromLegacy(user?.uid ?? 'system')
      .catch((err) => console.warn('migrateFromLegacy:', err))
      .finally(() => setMigrated(true));
  }, []);

  useEffect(() => {
    if (!migrated) return;
    const unsubActive = subscribeToActivePricingVersion(
      (v) => setActiveVersion(v),
      (err) => console.error('active pricing error:', err),
    );
    const unsubAll = subscribeToPricingVersions(
      (vs) => setAllVersions(vs),
      (err) => console.error('pricing versions error:', err),
    );
    return () => { unsubActive(); unsubAll(); };
  }, [migrated]);

  // ── Success flash ────────────────────────────────────────────────────────

  const flashSuccess = useCallback((msg) => {
    setSuccessMsg(msg);
    clearTimeout(successTimer.current);
    successTimer.current = setTimeout(() => setSuccessMsg(null), 4000);
  }, []);

  const handleModalSuccess = () => {
    setShowModal(false);
    flashSuccess('New pricing version created and is now active.');
  };

  // ── Loading ──────────────────────────────────────────────────────────────

  if (!migrated || activeVersion === undefined) {
    return (
      <div className="pu-loading">
        <span className="pu-spinner" />
        Loading pricing configuration…
      </div>
    );
  }

  return (
    <div className="pu-root">

      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="pu-page-header">
        <div>
          <h2 className="pu-title">Pricing Configuration</h2>
          <p className="pu-subtitle">
            All price changes are versioned and linked to a resolution or policy decision.
            Historical records are never overwritten.
          </p>
        </div>
        <button className="pu-btn-primary" onClick={() => setShowModal(true)}>
          + New Version
        </button>
      </div>

      {successMsg && (
        <div className="pu-alert pu-alert-success">{successMsg}</div>
      )}

      {/* ── Active version card ──────────────────────────────────────────── */}
      <section className="pu-section pu-active-card">
        <div className="pu-active-card-header">
          <div>
            <span className="pu-active-badge">Active</span>
            <span className="pu-active-version-label">
              {activeVersion
                ? `Version ${activeVersion.versionNumber}`
                : 'No active version'}
            </span>
          </div>
          {activeVersion && (
            <div className="pu-active-meta">
              <span>Effective: {formatVersionDate(activeVersion.effectiveFrom)}</span>
              {activeVersion.resolutionRef && (
                <span> · {activeVersion.resolutionRef}</span>
              )}
              <span className="pu-active-res-type">
                {resolutionTypeLabel(activeVersion.resolutionType)}
              </span>
            </div>
          )}
        </div>

        {activeVersion ? (
          <PricingSummary version={activeVersion} />
        ) : (
          <div className="pu-empty-state">
            No active pricing version found.{' '}
            <button className="pu-link-btn" onClick={() => setShowModal(true)}>
              Create the first version
            </button>
          </div>
        )}
      </section>

      {/* ── Version history ──────────────────────────────────────────────── */}
      <section className="pu-section">
        <h3 className="pu-section-title">Version History</h3>
        {allVersions.length === 0 ? (
          <div className="pu-empty-state">No pricing history yet.</div>
        ) : (
          <div className="pu-version-list">
            {allVersions.map((v) => (
              <VersionRow key={v.id} version={v} defaultOpen={v.status === 'active'} />
            ))}
          </div>
        )}
      </section>

      {/* ── New version modal ────────────────────────────────────────────── */}
      {showModal && (
        <NewVersionModal
          activeVersion={activeVersion}
          versionCount={allVersions.length}
          onClose={() => setShowModal(false)}
          onSuccess={handleModalSuccess}
        />
      )}
    </div>
  );
}

export default PricingUtility;
