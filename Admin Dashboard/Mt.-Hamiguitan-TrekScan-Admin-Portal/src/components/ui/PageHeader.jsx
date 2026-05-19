import React from 'react';

/**
 * Consistent page-level header.
 *
 * @param {string}      title       - Main heading
 * @param {string}      [subtitle]  - Secondary description text
 * @param {React.Node}  [actions]   - Buttons/controls rendered on the right
 * @param {string[]}    [crumbs]    - Breadcrumb segments (optional)
 */
export default function PageHeader({ title, subtitle, actions, crumbs }) {
  return (
    <div style={{ marginBottom: 28 }}>
      {crumbs && crumbs.length > 0 && (
        <nav style={{ marginBottom: 6, display: 'flex', alignItems: 'center', gap: 6 }}>
          {crumbs.map((c, i) => (
            <React.Fragment key={i}>
              {i > 0 && (
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" style={{ color: 'var(--text-muted)', flexShrink: 0 }}>
                  <path d="M9 18l6-6-6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              )}
              <span
                style={{
                  fontSize: '0.75rem',
                  color: i === crumbs.length - 1 ? 'var(--text-secondary)' : 'var(--text-muted)',
                  fontWeight: i === crumbs.length - 1 ? 500 : 400,
                }}
              >
                {c}
              </span>
            </React.Fragment>
          ))}
        </nav>
      )}

      <div style={{ display: 'flex', alignItems: subtitle ? 'flex-start' : 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', lineHeight: 1.25, margin: 0 }}>
            {title}
          </h1>
          {subtitle && (
            <p style={{ marginTop: 4, fontSize: '0.875rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              {subtitle}
            </p>
          )}
        </div>
        {actions && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
            {actions}
          </div>
        )}
      </div>
    </div>
  );
}
