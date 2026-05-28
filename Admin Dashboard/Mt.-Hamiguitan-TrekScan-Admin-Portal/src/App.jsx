import { useState, useEffect, useRef } from 'react'
import { onAuthStateChange, signOutUser } from './services/firebaseAuthService'
import { checkIsAdmin, ensureAdminClaim, ensureAdminSeedDocument, getAdminProfile } from './services/adminService'
import Login from './views/pages/Login.jsx'
import AppLayout from './layouts/AppLayout.jsx'
import { useToast, ToastContainer } from './components/Toast'
import './App.css'

// 'loading' | 'admin' | 'denied' | 'unauthenticated'
function App() {
  const [authStatus, setAuthStatus] = useState('loading')
  const [adminProfile, setAdminProfile] = useState(null)
  const prevWasAuthed = useRef(false)
  const { toasts, removeToast, success } = useToast()

  useEffect(() => {
    const unsubscribe = onAuthStateChange(async (user) => {
      if (!user) {
        prevWasAuthed.current = false
        setAdminProfile(null)
        setAuthStatus('unauthenticated')
        return
      }

      try {
        await ensureAdminSeedDocument(user)
        // Bootstrap: if this is the seed admin, ensure the custom claim is set.
        // ensureAdminClaim is a no-op for non-seed, non-admin callers (the Cloud
        // Function rejects them), so it's safe to call speculatively here.
        if (user.email === import.meta.env.VITE_ADMIN_SEED_EMAIL) {
          try { await ensureAdminClaim() } catch (e) { console.warn('ensureAdminClaim:', e?.message) }
        }
        const isAdmin = await checkIsAdmin(user)
        if (isAdmin) {
          const profile = await getAdminProfile(user.uid)
          setAdminProfile(profile)
          if (!prevWasAuthed.current) {
            success('Login successful! Welcome back.', 3000)
          }
          prevWasAuthed.current = true
          setAuthStatus('admin')
        } else {
          setAdminProfile(null)
          prevWasAuthed.current = true
          setAuthStatus('denied')
        }
      } catch (err) {
        console.error('Role check failed:', err)
        setAdminProfile(null)
        setAuthStatus('denied')
      }
    })

    return () => unsubscribe()
  }, [success])

  const handleLogout = async () => {
    try {
      await signOutUser()
    } catch (error) {
      console.error('Logout error:', error)
    }
  }

  if (authStatus === 'loading') {
    return (
      <div className="app-loading">
        <div className="loading-spinner"></div>
        <p>Loading...</p>
      </div>
    )
  }

  return (
    <div className="app">
      {authStatus === 'admin' && (
        <AppLayout adminProfile={adminProfile} onLogout={handleLogout} />
      )}
      {authStatus === 'denied' && (
        <AccessDenied onLogout={handleLogout} />
      )}
      {authStatus === 'unauthenticated' && (
        <Login />
      )}
      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  )
}

function AccessDenied({ onLogout }) {
  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      background: '#f9fafb',
    }}>
      <div style={{
        background: '#fff',
        border: '1px solid #e5e7eb',
        borderRadius: '16px',
        padding: '48px 40px',
        textAlign: 'center',
        maxWidth: '400px',
        width: '100%',
        boxShadow: '0 4px 24px rgba(0,0,0,0.08)',
      }}>
        <div style={{ fontSize: '48px', marginBottom: '16px' }}>🔒</div>
        <h2 style={{ fontSize: '22px', fontWeight: '700', color: '#111827', marginBottom: '12px' }}>
          Access Denied
        </h2>
        <p style={{ fontSize: '14px', color: '#6b7280', lineHeight: '1.6', marginBottom: '28px' }}>
          Your account does not have administrator privileges. Only authorized admins may access this portal.
        </p>
        <button
          onClick={onLogout}
          style={{
            padding: '10px 28px',
            borderRadius: '8px',
            border: 'none',
            background: '#30622f',
            color: '#fff',
            fontSize: '14px',
            fontWeight: '600',
            cursor: 'pointer',
          }}
        >
          Sign Out
        </button>
      </div>
    </div>
  )
}

export default App
