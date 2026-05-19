import { useState, useEffect, useRef } from 'react'
import { onAuthStateChange, getCurrentUser, signOutUser } from './services/firebaseAuthService'
import Login from './views/pages/Login.jsx'
import AppLayout from './layouts/AppLayout.jsx'
import { useToast, ToastContainer } from './components/Toast'
import './App.css'

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [loading, setLoading] = useState(true)
  const prevAuthState = useRef(false)
  const { toasts, removeToast, success } = useToast()

  // Listen to Firebase Auth state changes
  useEffect(() => {
    const unsubscribe = onAuthStateChange((user) => {
      const newAuthState = !!user
      
      // Show success toast when user logs in (transitions from false to true)
      if (!prevAuthState.current && newAuthState) {
        success('Login successful! Welcome back.', 3000)
      }
      
      prevAuthState.current = newAuthState
      setIsAuthenticated(newAuthState)
      setLoading(false)
    })

    // Check current user immediately
    const currentUser = getCurrentUser()
    const initialAuthState = !!currentUser
    prevAuthState.current = initialAuthState
    setIsAuthenticated(initialAuthState)
    setLoading(false)

    return () => unsubscribe()
  }, [success])

  const handleLoginSuccess = () => {
    setIsAuthenticated(true)
  }

  const handleLogout = async () => {
    try {
      await signOutUser()
      setIsAuthenticated(false)
    } catch (error) {
      console.error('Logout error:', error)
    }
  }

  if (loading) {
    return (
      <div className="app-loading">
        <div className="loading-spinner"></div>
        <p>Loading...</p>
      </div>
    )
  }

  return (
    <div className="app">
      {isAuthenticated ? (
        <AppLayout onLogout={handleLogout} />
      ) : (
        <Login onLoginSuccess={handleLoginSuccess} />
      )}
      {/* Toast Notifications - shown at app level so they persist across component changes */}
      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  )
}

export default App
