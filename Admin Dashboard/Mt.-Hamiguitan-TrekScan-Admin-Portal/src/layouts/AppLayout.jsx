import React, { useState, useEffect, useRef, useMemo } from 'react';
import './AppLayout.css';
import logoImage from '../assets/TrekScan.png';
import { Home, BarChart2, Settings, FileText, Shield, Award, MapPin, Calendar, ChevronLeft, ChevronRight, Bell, X, Search, CheckCircle, Trash2, MoreVertical, LogOut, Clock } from 'lucide-react';
import { Hiking, Build, RateReview, CardMembership, LocationOn } from '@mui/icons-material';
import { getAllBookings } from '../services/bookingService';
import { getUserById } from '../services/userService';
import { getCurrentUser, onAuthStateChange } from '../services/firebaseAuthService';
import { Timestamp } from 'firebase/firestore';

import Dashboard from '../views/pages/Dashboard.jsx';
import ClimbRequest from '../views/pages/ClimbRequest.jsx';
import ManageSchedule from '../views/pages/ManageSchedule.jsx';
import Reports from '../views/pages/Reports.jsx';
import Utility from '../views/pages/Utility.jsx';
import PostModeration from '../views/pages/PostModeration.jsx';
import Certificates from '../views/pages/Certificates.jsx';
import StationActivity from '../views/pages/StationActivity.jsx';
import { useToast, ToastContainer } from '../components/Toast';

// ── Nav configuration ──────────────────────────────────────────────────────
const NAV_ITEMS = [
  { id: 'dashboard',    label: 'Dashboard',        Icon: Home },
  { id: 'climb',        label: 'Climb Requests',    Icon: Hiking,         muiIcon: true },
  { id: 'users',        label: 'Booking Schedule',  Icon: Calendar },
  { id: 'reports',      label: 'Reports',           Icon: BarChart2 },
  { id: 'utility',      label: 'Utility',           Icon: Build,          muiIcon: true },
  { id: 'moderation',   label: 'Post Moderation',   Icon: RateReview,     muiIcon: true },
  { id: 'certificates', label: 'Certificates',      Icon: Award },
  { id: 'stations',     label: 'Station Activity',  Icon: MapPin },
];

const PAGE_TITLES = {
  dashboard:    'Dashboard',
  climb:        'Climb Requests',
  users:        'Booking Schedule',
  reports:      'Reports',
  utility:      'Utility',
  moderation:   'Post Moderation',
  certificates: 'Certificates',
  stations:     'Station Activity',
};

function timeAgoStr(date) {
  const diff = Date.now() - date.getTime();
  const m = Math.floor(diff / 60000);
  const h = Math.floor(diff / 3600000);
  const d = Math.floor(diff / 86400000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  if (h < 24) return `${h}h ago`;
  return `${d}d ago`;
}

function getInitials(name = '') {
  return name.split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || 'A';
}

// ── AppLayout ──────────────────────────────────────────────────────────────
function AppLayout({ adminProfile, onLogout }) {
  const adminName = [adminProfile?.firstName, adminProfile?.lastName].filter(Boolean).join(' ') || 'Administrator';

  const [activeItem,       setActiveItem]       = useState('dashboard');
  const [collapsed,        setCollapsed]        = useState(false);
  const [mobileOpen,       setMobileOpen]       = useState(false);
  const [showNotifs,       setShowNotifs]       = useState(false);
  const [showProfileMenu,  setShowProfileMenu]  = useState(false);
  const [showLogoutDialog, setShowLogoutDialog] = useState(false);
  const [showActionsMenu,  setShowActionsMenu]  = useState(false);
  const [profileImage,     setProfileImage]     = useState(null);

  // Notification state
  const [allBookings,       setAllBookings]       = useState([]);
  const [notifList,         setNotifList]         = useState([]);
  const [readIds,           setReadIds]           = useState(new Set());
  const [notifFilter,       setNotifFilter]       = useState('all');
  const [notifSearch,       setNotifSearch]       = useState('');
  const [bookingIdToOpen,   setBookingIdToOpen]   = useState(null);
  const [deletedNotifs,     setDeletedNotifs]     = useState(new Map());

  const notifsRef     = useRef(null);
  const profileRef    = useRef(null);
  const actionsRef    = useRef(null);
  const { toasts, removeToast, success } = useToast();

  // Scroll to top on page change
  useEffect(() => {
    document.querySelector('.page-content')?.scrollTo({ top: 0, behavior: 'auto' });
  }, [activeItem]);

  // Fetch bookings for notification generation
  useEffect(() => {
    let intervalId = null;
    const fetchBookings = async () => {
      try {
        if (!getCurrentUser()) return;
        setAllBookings(await getAllBookings());
      } catch (e) {
        console.error('Notification fetch error:', e);
      }
    };
    const unsub = onAuthStateChange((user) => {
      if (user) { fetchBookings(); intervalId = setInterval(fetchBookings, 30000); }
      else       { setAllBookings([]); clearInterval(intervalId); }
    });
    if (getCurrentUser()) { fetchBookings(); intervalId = setInterval(fetchBookings, 30000); }
    return () => { unsub(); clearInterval(intervalId); };
  }, []);

  // Build notification items from bookings
  useEffect(() => {
    if (!allBookings.length) { setNotifList([]); return; }
    (async () => {
      const notifs = [];
      for (const b of allBookings) {
        if (!b.createdAt) continue;
        const createdAt = b.createdAt instanceof Timestamp ? b.createdAt.toDate() : new Date(b.createdAt);
        let user = null;
        if (b.userId) { try { user = await getUserById(b.userId); } catch {} }
        const userName = user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown';
        const trekDate = b.trekDate instanceof Timestamp ? b.trekDate.toDate() : new Date(b.trekDate);
        const fmtDate = trekDate.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        const shortDate = trekDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
        const status = b.status?.toLowerCase();
        const now = Date.now();

        if (status === 'pending') {
          notifs.push({ id: `booking-${b.id}`, type: 'booking', iconColor: '#3b82f6',
            title: 'New Booking Request', desc: `${userName} requested Mt. Hamiguitan for ${fmtDate}`,
            timeAgo: timeAgoStr(createdAt), timestamp: createdAt,
            isRead: readIds.has(`booking-${b.id}`), bookingId: b.id });
        }
        if (status === 'cancelled' && b.updatedAt) {
          const upd = b.updatedAt instanceof Timestamp ? b.updatedAt.toDate() : new Date(b.updatedAt);
          if (now - upd.getTime() < 7 * 86400000) {
            notifs.push({ id: `cancelled-${b.id}`, type: 'cancelled', iconColor: '#f59e0b',
              title: 'Booking Cancelled', desc: `${userName}'s booking on ${shortDate} was cancelled`,
              timeAgo: timeAgoStr(upd), timestamp: upd,
              isRead: readIds.has(`cancelled-${b.id}`), bookingId: b.id });
          }
        }
        if ((status === 'rejected' || status === 'pending') && b.updatedAt) {
          const upd = b.updatedAt instanceof Timestamp ? b.updatedAt.toDate() : new Date(b.updatedAt);
          const diff = upd.getTime() - createdAt.getTime();
          if (now - upd.getTime() < 7 * 86400000 && diff > 60000) {
            notifs.push({ id: `update-${b.id}`, type: 'update',
              iconColor: status === 'rejected' ? '#ef4444' : '#3b82f6',
              title: status === 'rejected' ? 'Booking Rejected' : 'Booking Updated',
              desc: `${userName}'s booking on ${shortDate} was ${status === 'rejected' ? 'rejected' : 'updated'}`,
              timeAgo: timeAgoStr(upd), timestamp: upd,
              isRead: readIds.has(`update-${b.id}`), bookingId: b.id });
          }
        }
      }
      setNotifList(notifs.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime()));
    })();
  }, [allBookings, readIds]);

  const filteredNotifs = useMemo(() => {
    let list = [...notifList];
    if (notifFilter === 'unread') list = list.filter(n => !n.isRead);
    if (notifFilter === 'read')   list = list.filter(n => n.isRead);
    if (notifSearch.trim()) {
      const q = notifSearch.toLowerCase();
      list = list.filter(n => n.title.toLowerCase().includes(q) || n.desc.toLowerCase().includes(q));
    }
    return list;
  }, [notifList, notifFilter, notifSearch]);

  const unreadCount = notifList.filter(n => !n.isRead).length;

  const markRead = (id) => setReadIds(prev => new Set([...prev, id]));
  const markAllRead = () => setReadIds(prev => new Set([...prev, ...notifList.map(n => n.id)]));
  const clearAll = () => { setNotifList([]); setReadIds(new Set()); };

  const handleNotifClick = (n) => {
    if (!n.bookingId) return;
    markRead(n.id);
    setShowNotifs(false);
    setActiveItem('climb');
    setBookingIdToOpen(n.bookingId);
  };

  const deleteNotif = (id, e) => {
    e?.stopPropagation();
    const item = notifList.find(n => n.id === id);
    if (!item) return;
    setDeletedNotifs(prev => new Map(prev).set(id, item));
    setNotifList(prev => prev.filter(n => n.id !== id));
    success('Notification removed', 5000, {
      label: 'Undo',
      onClick: (ev) => {
        ev?.stopPropagation();
        ev?.preventDefault();
        setNotifList(prev => {
          if (prev.find(n => n.id === id)) return prev;
          return [...prev, item].sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
        });
        setDeletedNotifs(prev => { const m = new Map(prev); m.delete(id); return m; });
      },
    });
    setTimeout(() => setDeletedNotifs(prev => { const m = new Map(prev); m.delete(id); return m; }), 5000);
  };

  // Close panels on outside click / Escape
  useEffect(() => {
    const handleClick = (e) => {
      const isToast = e.target.closest('.toast, .toast-container, .toast-action-btn');
      if (!isToast) {
        if (notifsRef.current   && !notifsRef.current.contains(e.target))   setShowNotifs(false);
        if (profileRef.current  && !profileRef.current.contains(e.target))  setShowProfileMenu(false);
        if (actionsRef.current  && !actionsRef.current.contains(e.target))  setShowActionsMenu(false);
      }
      const sidebar = document.querySelector('.sidebar');
      if (sidebar && !sidebar.contains(e.target) && !e.target.closest('.mobile-burger')) setMobileOpen(false);
    };
    const handleKey = (e) => {
      if (e.key === 'Escape') { setShowNotifs(false); setShowProfileMenu(false); setShowActionsMenu(false); setMobileOpen(false); }
    };
    document.addEventListener('mousedown', handleClick);
    document.addEventListener('keydown', handleKey);
    return () => { document.removeEventListener('mousedown', handleClick); document.removeEventListener('keydown', handleKey); };
  }, []);

  return (
    <div className="shell">
      {/* ── Sidebar ── */}
      {mobileOpen && <div className="sidebar-backdrop visible" onClick={() => setMobileOpen(false)} />}
      <aside className={`sidebar${collapsed ? ' collapsed' : ''}${mobileOpen ? ' mobile-open' : ''}`}>
        {/* Brand */}
        <div className="sidebar-head">
          <div className="sidebar-logo-wrap">
            <img src={logoImage} alt="TrekScan+" />
          </div>
          {!collapsed && (
            <div className="sidebar-brand">
              <div className="sidebar-brand-name">TrekScan+</div>
              <div className="sidebar-brand-sub">Heritage Admin</div>
            </div>
          )}
          <button
            className="sidebar-toggle"
            onClick={() => setCollapsed(c => !c)}
            title={collapsed ? 'Expand' : 'Collapse'}
          >
            {collapsed
              ? <ChevronRight size={16} />
              : <ChevronLeft  size={16} />
            }
          </button>
        </div>

        {/* Navigation */}
        <nav className="sidebar-nav">
          {NAV_ITEMS.map(({ id, label, Icon, muiIcon }) => (
            <button
              key={id}
              className={`nav-item${activeItem === id ? ' active' : ''}`}
              onClick={() => { setActiveItem(id); setMobileOpen(false); }}
              title={collapsed ? label : undefined}
            >
              <span className="nav-icon">
                {muiIcon
                  ? <Icon style={{ fontSize: 20 }} />
                  : <Icon size={18} strokeWidth={1.75} />
                }
              </span>
              <span className="nav-label">{label}</span>
              {id === 'climb' && unreadCount > 0 && (
                <span className="nav-badge">{unreadCount > 9 ? '9+' : unreadCount}</span>
              )}
            </button>
          ))}
        </nav>
      </aside>

      {/* ── Main area ── */}
      <div className="shell-main">
        {/* Header */}
        <header className="top-header">
          <div className="header-left">
            <button className="mobile-burger header-icon-btn" onClick={() => setMobileOpen(o => !o)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M3 12H21M3 6H21M3 18H21" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="header-page-title">{PAGE_TITLES[activeItem] ?? ''}</span>
          </div>

          <div className="header-right">
            {/* Notifications */}
            <div ref={notifsRef} className="notif-wrapper">
              <button
                className="header-icon-btn"
                onClick={() => setShowNotifs(v => !v)}
                title="Notifications"
              >
                <Bell size={20} />
                {unreadCount > 0 && <span className="notif-dot" />}
              </button>

              {showNotifs && (
                <div className="notif-panel">
                  {/* Head */}
                  <div className="notif-panel-head">
                    <span className="notif-panel-title">
                      Notifications
                      {unreadCount > 0 && <span className="notif-unread-chip">{unreadCount}</span>}
                    </span>
                    <button className="notif-close-btn" onClick={() => setShowNotifs(false)}>
                      <X size={16} />
                    </button>
                  </div>

                  {/* Tabs */}
                  <div className="notif-tabs">
                    {[['all', `All (${notifList.length})`], ['unread', `Unread (${unreadCount})`], ['read', `Read (${notifList.length - unreadCount})`]].map(([val, text]) => (
                      <button
                        key={val}
                        className={`notif-tab${notifFilter === val ? ' active' : ''}`}
                        onClick={() => setNotifFilter(val)}
                      >{text}</button>
                    ))}
                    <span className="notif-tab-spacer" />
                    <div ref={actionsRef} style={{ position: 'relative' }}>
                      <button className="notif-actions-btn" onClick={() => setShowActionsMenu(v => !v)}>
                        <MoreVertical size={16} />
                      </button>
                      {showActionsMenu && (
                        <div className="notif-actions-dropdown">
                          <button className="notif-action-item" disabled={unreadCount === 0} onClick={() => { markAllRead(); setShowActionsMenu(false); }}>
                            <CheckCircle size={16} /> Mark all read
                          </button>
                          <button className="notif-action-item delete" disabled={!notifList.length} onClick={() => { clearAll(); setShowActionsMenu(false); }}>
                            <Trash2 size={16} /> Clear all
                          </button>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Search */}
                  <div className="notif-search">
                    <Search size={14} color="var(--text-muted)" />
                    <input
                      className="notif-search-input"
                      placeholder="Search notifications…"
                      value={notifSearch}
                      onChange={e => setNotifSearch(e.target.value)}
                    />
                  </div>

                  {/* List */}
                  <div className="notif-list">
                    {filteredNotifs.length === 0 ? (
                      <div className="notif-empty">
                        <div className="notif-empty-icon">🔔</div>
                        <div className="notif-empty-title">No notifications</div>
                        <div className="notif-empty-sub">You're all caught up!</div>
                      </div>
                    ) : filteredNotifs.map(n => (
                      <div
                        key={n.id}
                        className={`notif-item${!n.isRead ? ' unread' : ''}${n.bookingId ? ' clickable' : ''}`}
                        onClick={() => handleNotifClick(n)}
                      >
                        <div className="notif-item-icon" style={{ background: n.iconColor }}>
                          <Bell size={16} color="#fff" />
                        </div>
                        <div className="notif-item-body">
                          <div className="notif-item-title">{n.title}</div>
                          <div className="notif-item-desc">{n.desc}</div>
                          <div className="notif-item-meta">
                            <span className="notif-item-time">
                              <Clock size={11} /> {n.timeAgo}
                            </span>
                            <div className="notif-item-btns" onClick={e => e.stopPropagation()}>
                              {!n.isRead && (
                                <button className="notif-text-btn read" onClick={() => markRead(n.id)}>Mark read</button>
                              )}
                              <button className="notif-text-btn del" onClick={e => deleteNotif(n.id, e)}>Delete</button>
                            </div>
                          </div>
                        </div>
                        {!n.isRead && <span className="notif-unread-indicator" />}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* Profile */}
            <div ref={profileRef} style={{ position: 'relative' }}>
              <button className="header-profile-btn" onClick={() => setShowProfileMenu(v => !v)}>
                <div className="header-avatar">
                  {profileImage
                    ? <img src={profileImage} alt={adminName} />
                    : getInitials(adminName)
                  }
                </div>
                <div className="header-profile-info">
                  <div className="header-profile-name">{adminName}</div>
                </div>
              </button>

              {showProfileMenu && (
                <div className="profile-menu">
                  <div className="profile-menu-header">
                    <div className="profile-menu-name">{adminName}</div>
                    <div className="profile-menu-role">Administrator</div>
                  </div>
                  <button
                    className="profile-menu-item danger"
                    onClick={() => { setShowLogoutDialog(true); setShowProfileMenu(false); }}
                  >
                    <LogOut size={16} />
                    <span>Log out</span>
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="page-content">
          {activeItem === 'dashboard'    && <Dashboard onNavigate={setActiveItem} />}
          {activeItem === 'climb'        && <ClimbRequest bookingIdToOpen={bookingIdToOpen} onBookingOpened={() => setBookingIdToOpen(null)} />}
          {activeItem === 'users'        && <ManageSchedule />}
          {activeItem === 'reports'      && <Reports />}
          {activeItem === 'utility'      && <Utility />}
          {activeItem === 'moderation'   && <PostModeration adminName={adminName} />}
          {activeItem === 'certificates' && <Certificates adminName={adminName} />}
          {activeItem === 'stations'     && <StationActivity />}
        </main>
      </div>

      {/* ── Logout confirmation ── */}
      {showLogoutDialog && (
        <div className="modal-backdrop" onClick={() => setShowLogoutDialog(false)}>
          <div className="confirm-modal" onClick={e => e.stopPropagation()}>
            <div className="confirm-modal-head">
              <div className="confirm-modal-icon">
                <LogOut size={22} />
              </div>
              <div className="confirm-modal-title">Log out?</div>
              <div className="confirm-modal-body">You'll be returned to the login screen.</div>
            </div>
            <div className="confirm-modal-foot">
              <button className="btn-ghost" onClick={() => setShowLogoutDialog(false)}>Cancel</button>
              <button className="btn-danger" onClick={() => { onLogout?.(); setShowLogoutDialog(false); }}>Log out</button>
            </div>
          </div>
        </div>
      )}

      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

export default AppLayout;
