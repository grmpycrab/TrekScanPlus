import React, { useState, useEffect } from 'react';
import { signIn, signInWithGoogle, getCurrentUser, onAuthStateChange } from '../../services/firebaseAuthService';
import { Visibility, VisibilityOff } from '@mui/icons-material';
import '../style/Login.css';
import logoImage from '../../assets/Logo_admin_portal.png';
import trekScanText from '../../assets/TrekScan_welomelogo.png';

// Login page component
function Login({ onLoginSuccess }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showForgotMessage, setShowForgotMessage] = useState(false);
  
  // Disable body scroll while Login is mounted
  useEffect(() => {
    document.body.classList.add('no-scroll');
    return () => {
      document.body.classList.remove('no-scroll');
    };
  }, []);

  // Form state
  const [formData, setFormData] = useState({
    email: '', // Changed from username to email for Firebase Auth
    password: ''
  });
  const [formErrors, setFormErrors] = useState({});

  // Check if user is already authenticated on mount
  useEffect(() => {
    const unsubscribe = onAuthStateChange((user) => {
      if (user) {
        setIsAuthenticated(true);
        if (onLoginSuccess) {
          onLoginSuccess();
        }
      } else {
        setIsAuthenticated(false);
      }
    });

    // Check current user immediately
    const currentUser = getCurrentUser();
    if (currentUser) {
      setIsAuthenticated(true);
      if (onLoginSuccess) {
        onLoginSuccess();
      }
    }

    return () => unsubscribe();
  }, [onLoginSuccess]);

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && onLoginSuccess) {
      onLoginSuccess();
    }
  }, [isAuthenticated, onLoginSuccess]);

  // Handle form input changes
  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
    
    // Clear field error when user starts typing
    if (formErrors[name]) {
      setFormErrors(prev => ({
        ...prev,
        [name]: ''
      }));
    }
    
    // Clear general error when user starts typing
    if (error) {
      setError(null);
    }

    // Hide forgot-password message when user starts typing again
    if (showForgotMessage) {
      setShowForgotMessage(false);
    }
  };

  // Validate form
  const validateForm = () => {
    const errors = {};
    
    if (!formData.email) {
      errors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      errors.email = 'Email is invalid';
    }
    
    if (!formData.password) {
      errors.password = 'Password is required';
    }
    
    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  // Handle Google sign-in via popup
  const handleGoogleSignIn = async () => {
    setError(null);
    setLoading(true);
    try {
      await signInWithGoogle();
      // onAuthStateChanged in App.jsx handles the rest
    } catch (error) {
      console.error('Google login failed:', error.code, error.message);
      if (error.code !== 'auth/popup-closed-by-user' && error.code !== 'auth/cancelled-popup-request') {
        setError(error.message || 'Google sign-in failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    
    if (!validateForm()) {
      return;
    }

    setLoading(true);
    try {
      // Sign in with Firebase Auth
      await signIn(formData.email, formData.password);
      // Auth state change listener will handle the redirect and show toast
    } catch (error) {
      console.error('Login failed:', error);
      
      // Handle specific Firebase Auth errors
      let errorMessage = 'Login failed. Please try again.';
      if (error.code === 'auth/invalid-credential' || error.code === 'auth/user-not-found' || error.code === 'auth/wrong-password') {
        errorMessage = 'Incorrect email or password.';
      } else if (error.code === 'auth/invalid-email') {
        errorMessage = 'Invalid email address.';
        setFormErrors({ email: 'Email Validation Error' });
      } else if (error.code === 'auth/user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else if (error.code === 'auth/too-many-requests') {
        errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (error.message) {
        errorMessage = error.message;
      }
      
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-left">
        <img src={trekScanText} alt="TrekScan+ Text" className="trek-scan-text" />
      </div>
      <div className="login-card">
        <div className="login-header">
          <img src={logoImage} alt="TrekScan+ Admin Portal" className="login-logo" />
          <h2 className="welcome-text">Welcome back, Admin!</h2>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          {error && (
            <div className="error-message">
              {error}
            </div>
          )}

          <div className="form-group">
            <label htmlFor="email">Email</label>
            <input
              type="email"
              id="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              className={formErrors.email ? 'error' : ''}
              placeholder="Enter your email"
              disabled={loading}
            />
            {formErrors.email && (
              <span className="field-error">{formErrors.email}</span>
            )}
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <div className="password-input-wrapper">
              <input
                type={showPassword ? 'text' : 'password'}
                id="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                className={formErrors.password ? 'error' : ''}
                placeholder="Enter your password"
                disabled={loading}
              />
              <button
                type="button"
                className="password-toggle-btn"
                onClick={() => setShowPassword(!showPassword)}
                disabled={loading}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? (
                  <VisibilityOff sx={{ fontSize: 20, color: '#6b7280' }} />
                ) : (
                  <Visibility sx={{ fontSize: 20, color: '#6b7280' }} />
                )}
              </button>
            </div>
            {formErrors.password && formErrors.password === 'incorrect password' && (
              <span className="field-error">{formErrors.password}</span>
            )}
            {formErrors.password && formErrors.password !== 'incorrect password' && (
              <span className="field-error">{formErrors.password}</span>
            )}
          </div>

          <button
            type="submit"
            className="login-button"
            disabled={loading}
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>

          <div className="login-divider">
            <span>or</span>
          </div>

          <button
            type="button"
            className="google-login-button"
            onClick={handleGoogleSignIn}
            disabled={loading}
          >
            <svg width="18" height="18" viewBox="0 0 48 48" style={{ flexShrink: 0 }}>
              <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
              <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
              <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
              <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
              <path fill="none" d="M0 0h48v48H0z"/>
            </svg>
            Sign in with Google
          </button>
        </form>

        <div className="login-footer">
          <p>
            <a
              href="#"
              className="forgot-password"
              onClick={(e) => {
                e.preventDefault();
                setShowForgotMessage(true);
              }}
            >
              Forgot your password?
            </a>
          </p>
          {showForgotMessage && (
            <div className="password-reset-modal-overlay" onClick={() => setShowForgotMessage(false)}>
              <div className="password-reset-modal" onClick={(e) => e.stopPropagation()}>
                <div className="password-reset-header">
                  <div className="password-reset-header-content">
                    <div className="password-reset-title-group">
                      <h3 className="password-reset-title">Password Reset Help</h3>
                      <p className="password-reset-subtitle">Forgot your password?</p>
                    </div>
                  </div>
                  <button
                    type="button"
                    className="password-reset-close"
                    onClick={() => setShowForgotMessage(false)}
                    aria-label="Close"
                  >
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                      <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </button>
                </div>
                <div className="password-reset-content">
                  <p className="password-reset-instruction">
                    We're here to help! Contact system developer to reset your password securely.
                  </p>
                  <div className="password-reset-contacts">
                    <a href="mailto:keyntharly@gmail.com" className="password-reset-contact-item">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                        <path d="M4 4H20C21.1 4 22 4.9 22 6V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6C2 4.9 2.9 4 4 4Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                        <polyline points="22,6 12,13 2,6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                      <span>keyntharly@gmail.com</span>
                    </a>
                    <a href="tel:09978948782" className="password-reset-contact-item">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                        <path d="M3 5C3 3.89543 3.89543 3 5 3H8.27924C8.70967 3 9.09181 3.27543 9.22792 3.68377L10.7257 8.17721C10.8831 8.64932 10.6694 9.16531 10.2243 9.38787L7.96701 10.5165C9.06925 12.9612 11.0388 14.9308 13.4835 16.033L14.6121 13.7757C14.8347 13.3306 15.3507 13.1169 15.8228 13.2743L20.3162 14.7721C20.7246 14.9082 21 15.2903 21 15.7208V19C21 20.1046 20.1046 21 19 21H18C9.71573 21 3 14.2843 3 6V5Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                      <span>09978948782</span>
                    </a>
                  </div>
                  <p className="password-reset-response-time">Response time: Usually within 24 hours</p>
                </div>
                <div className="password-reset-footer">
                  <p>Your security is our priority. We'll verify your identity before resetting your password.</p>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default Login;
