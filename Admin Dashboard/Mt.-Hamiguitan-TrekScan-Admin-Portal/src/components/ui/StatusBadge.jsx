import React from 'react';

const VARIANTS = {
  approved:   { bg: 'var(--status-success-bg)',  text: 'var(--status-success-text)',  border: 'var(--status-success-border)',  label: 'Approved'   },
  pending:    { bg: 'var(--status-pending-bg)',  text: 'var(--status-pending-text)',  border: 'var(--status-pending-border)',  label: 'Pending'    },
  rejected:   { bg: 'var(--status-error-bg)',    text: 'var(--status-error-text)',    border: 'var(--status-error-border)',    label: 'Rejected'   },
  declined:   { bg: 'var(--status-error-bg)',    text: 'var(--status-error-text)',    border: 'var(--status-error-border)',    label: 'Declined'   },
  cancelled:  { bg: 'var(--status-neutral-bg)',  text: 'var(--status-neutral-text)',  border: 'var(--status-neutral-border)', label: 'Cancelled'  },
  completed:  { bg: 'var(--status-info-bg)',     text: 'var(--status-info-text)',     border: 'var(--status-info-border)',    label: 'Completed'  },
  active:     { bg: 'var(--status-success-bg)',  text: 'var(--status-success-text)',  border: 'var(--status-success-border)', label: 'Active'     },
  inactive:   { bg: 'var(--status-neutral-bg)',  text: 'var(--status-neutral-text)',  border: 'var(--status-neutral-border)', label: 'Inactive'   },
  warning:    { bg: 'var(--status-warning-bg)',  text: 'var(--status-warning-text)',  border: 'var(--status-warning-border)', label: 'Warning'    },
  info:       { bg: 'var(--status-info-bg)',     text: 'var(--status-info-text)',     border: 'var(--status-info-border)',    label: 'Info'       },
  changes_required: { bg: 'var(--status-warning-bg)', text: 'var(--status-warning-text)', border: 'var(--status-warning-border)', label: 'Changes Required' },
};

/**
 * Consistent status badge.
 * @param {string}  status   - key from VARIANTS (or any string → neutral fallback)
 * @param {string}  [label]  - override the display text
 * @param {boolean} [dot]    - show a leading colored dot
 */
export default function StatusBadge({ status = '', label, dot = false }) {
  const key = status?.toLowerCase().replace(/\s+/g, '_');
  const v = VARIANTS[key] ?? {
    bg: 'var(--status-neutral-bg)',
    text: 'var(--status-neutral-text)',
    border: 'var(--status-neutral-border)',
    label: status,
  };

  return (
    <span
      style={{
        display:        'inline-flex',
        alignItems:     'center',
        gap:            '5px',
        padding:        '3px 9px',
        borderRadius:   'var(--radius-full)',
        fontSize:       '0.6875rem',
        fontWeight:     600,
        letterSpacing:  '0.04em',
        textTransform:  'uppercase',
        whiteSpace:     'nowrap',
        background:     v.bg,
        color:          v.text,
        border:         `1px solid ${v.border}`,
        lineHeight:     1.5,
      }}
    >
      {dot && (
        <span
          style={{
            width: 6,
            height: 6,
            borderRadius: '50%',
            background: v.text,
            flexShrink: 0,
          }}
        />
      )}
      {label ?? v.label}
    </span>
  );
}
