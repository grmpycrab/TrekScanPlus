import React, { useState, useEffect, useCallback } from 'react';
import {
  getEligibleUsers,
  issueCertificate,
  CERT_TYPE,
  formatCertDate,
} from '../../services/certificateService.js';
import { useToast, ToastContainer } from '../../components/Toast.jsx';
import '../style/Certificates.css';

const CERT_TYPE_KEYS = ['peakConqueror', 'fullTrek', 'camp3'];

const CERT_COLORS = {
  peakConqueror: { bg: '#fef3c7', border: '#f59e0b', text: '#92400e', dot: '#f59e0b' },
  fullTrek:      { bg: '#dcfce7', border: '#22c55e', text: '#166534', dot: '#22c55e' },
  camp3:         { bg: '#dbeafe', border: '#3b82f6', text: '#1e3a8a', dot: '#3b82f6' },
};

function Certificates() {
  const [eligibleUsers, setEligibleUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [issuing, setIssuing] = useState(null); // `${userId}_${certType}`
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState('all');

  const { toasts, removeToast, success, error: showError } = useToast();

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getEligibleUsers();
      setEligibleUsers(data);
    } catch (err) {
      console.error(err);
      showError('Failed to load eligible users. Check Firestore permissions.');
    } finally {
      setLoading(false);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { load(); }, [load]);

  const handleIssue = async (userId, certType, trekkerName, session) => {
    const key = `${userId}_${certType}`;
    setIssuing(key);
    try {
      await issueCertificate(userId, certType, trekkerName, session, 'Admin');
      success(`${CERT_TYPE[certType].title} issued to ${trekkerName}.`);
      // Refresh to update issuedTypes
      await load();
    } catch (err) {
      showError(err.message || 'Failed to issue certificate.');
    } finally {
      setIssuing(null);
    }
  };

  const fullName = (u) =>
    u?.user ? `${u.user.firstName || ''} ${u.user.lastName || ''}`.trim() || 'Unknown User' : 'Unknown User';

  const filtered = eligibleUsers.filter((u) => {
    const name = fullName(u).toLowerCase();
    const matchSearch = name.includes(search.toLowerCase());
    const matchType = filterType === 'all' || u.eligibleTypes.includes(filterType);
    return matchSearch && matchType;
  });

  return (
    <div className="cert-container">
      {/* Header controls */}
      <div className="cert-controls">
        <input
          type="text"
          className="cert-search"
          placeholder="Search trekkers…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select
          className="cert-filter"
          value={filterType}
          onChange={(e) => setFilterType(e.target.value)}
        >
          <option value="all">All certificate types</option>
          {CERT_TYPE_KEYS.map((k) => (
            <option key={k} value={k}>{CERT_TYPE[k].title}</option>
          ))}
        </select>
        <button className="cert-refresh-btn" onClick={load} disabled={loading}>
          {loading ? 'Loading…' : '↺ Refresh'}
        </button>
      </div>

      {/* Legend */}
      <div className="cert-legend">
        {CERT_TYPE_KEYS.map((k) => (
          <div key={k} className="cert-legend-item">
            <span className="cert-legend-dot" style={{ background: CERT_COLORS[k].dot }} />
            <span>{CERT_TYPE[k].title}</span>
          </div>
        ))}
      </div>

      {loading ? (
        <div className="cert-loading">
          <div className="cert-spinner" />
          <span>Loading eligible trekkers…</span>
        </div>
      ) : filtered.length === 0 ? (
        <div className="cert-empty">
          <div className="cert-empty-icon">🏅</div>
          <div className="cert-empty-title">No eligible trekkers found</div>
          <div className="cert-empty-sub">
            Trekkers appear here once they have a completed climb session in the system.
          </div>
        </div>
      ) : (
        <div className="cert-table-wrapper">
          <table className="cert-table">
            <thead>
              <tr>
                <th>Trekker</th>
                <th>Stations Visited</th>
                <th>Eligible Certificates</th>
                <th>Already Issued</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((entry) => {
                const name = fullName(entry);
                const pendingTypes = entry.eligibleTypes.filter(
                  (t) => !entry.issuedTypes.includes(t),
                );
                return (
                  <tr key={entry.userId}>
                    {/* Trekker */}
                    <td>
                      <div className="cert-trekker">
                        <div className="cert-avatar">
                          {entry.user?.profileImage
                            ? <img src={entry.user.profileImage} alt={name} className="cert-avatar-img" />
                            : <span>{name.charAt(0).toUpperCase()}</span>
                          }
                        </div>
                        <div>
                          <div className="cert-trekker-name">{name}</div>
                          <div className="cert-trekker-email">{entry.user?.email || '—'}</div>
                        </div>
                      </div>
                    </td>

                    {/* Stations */}
                    <td className="cert-stations">{entry.stationsVisited}</td>

                    {/* Eligible types */}
                    <td>
                      <div className="cert-type-chips">
                        {entry.eligibleTypes.map((t) => (
                          <span
                            key={t}
                            className="cert-type-chip"
                            style={{
                              background: CERT_COLORS[t].bg,
                              borderColor: CERT_COLORS[t].border,
                              color: CERT_COLORS[t].text,
                            }}
                          >
                            {CERT_TYPE[t].title}
                          </span>
                        ))}
                      </div>
                    </td>

                    {/* Already issued */}
                    <td>
                      <div className="cert-type-chips">
                        {entry.issuedTypes.length === 0
                          ? <span className="cert-none">None yet</span>
                          : entry.issuedTypes.map((t) => (
                            <span key={t} className="cert-issued-chip">
                              {CERT_TYPE[t]?.title ?? t}
                            </span>
                          ))
                        }
                      </div>
                    </td>

                    {/* Issue buttons */}
                    <td>
                      <div className="cert-actions">
                        {pendingTypes.length === 0 ? (
                          <span className="cert-all-issued">All issued ✓</span>
                        ) : (
                          pendingTypes.map((t) => {
                            const key = `${entry.userId}_${t}`;
                            const busy = issuing === key;
                            return (
                              <button
                                key={t}
                                className="cert-issue-btn"
                                style={{ borderColor: CERT_COLORS[t].border, color: CERT_COLORS[t].text }}
                                disabled={busy || issuing !== null}
                                onClick={() =>
                                  handleIssue(entry.userId, t, name, entry.session)
                                }
                              >
                                {busy ? 'Issuing…' : `Issue ${CERT_TYPE[t].title}`}
                              </button>
                            );
                          })
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

export default Certificates;
