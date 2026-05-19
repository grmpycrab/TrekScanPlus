import Auth from '../models/Auth.js';
import { config } from '../config/config.js';

// AuthViewModel - handles authentication-related business logic and state
class AuthViewModel {
  constructor(apiClient) {
    this.apiClient = apiClient;
    this.auth = Auth.createEmpty();
    this.loading = false;
    this.error = null;
    this.listeners = [];
    
    // Load auth state from localStorage on initialization
    this.loadAuthFromStorage();
  }

  // Observer pattern for state changes
  subscribe(listener) {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  notify() {
    this.listeners.forEach(listener => listener(this.getState()));
  }

  getState() {
    return {
      auth: this.auth,
      loading: this.loading,
      error: this.error,
      isAuthenticated: this.auth.isAuthenticated && !this.auth.isTokenExpired()
    };
  }

  // Authentication methods
  async login(credentials) {
    this.setLoading(true);
    this.setError(null);
    
    try {
      const response = await this.apiClient.login(credentials);
      this.auth = Auth.fromLoginResponse(response);
      
      // Set auth token for future requests
      this.apiClient.setAuthToken(this.auth.token);
      
      // Save to localStorage
      this.saveAuthToStorage();
      
      this.notify();
      return this.auth;
    } catch (error) {
      this.setError(error.message || 'Login failed');
      throw error;
    } finally {
      this.setLoading(false);
    }
  }

  async logout() {
    this.setLoading(true);
    
    try {
      // Call logout API if authenticated
      if (this.auth.isAuthenticated) {
        await this.apiClient.logout();
      }
    } catch (error) {
      console.error('Logout API call failed:', error);
    } finally {
      // Clear auth state regardless of API call result
      this.auth = Auth.createEmpty();
      this.apiClient.removeAuthToken();
      this.clearAuthFromStorage();
      this.setLoading(false);
      this.notify();
    }
  }

  async refreshToken() {
    if (!this.auth.token) {
      throw new Error('No token to refresh');
    }

    try {
      const response = await this.apiClient.refreshToken();
      this.auth = Auth.fromLoginResponse(response);
      this.apiClient.setAuthToken(this.auth.token);
      this.saveAuthToStorage();
      this.notify();
      return this.auth;
    } catch (error) {
      // If refresh fails, logout user
      await this.logout();
      throw error;
    }
  }

  // Storage methods
  saveAuthToStorage() {
    try {
      localStorage.setItem(config.auth.tokenKey, JSON.stringify(this.auth.toJSON()));
    } catch (error) {
      console.error('Failed to save auth to storage:', error);
    }
  }

  loadAuthFromStorage() {
    try {
      const stored = localStorage.getItem(config.auth.tokenKey);
      if (stored) {
        const authData = JSON.parse(stored);
        this.auth = Auth.fromAPI(authData);
        
        // Check if token is expired
        if (this.auth.isTokenExpired()) {
          this.auth = Auth.createEmpty();
          this.clearAuthFromStorage();
        } else {
          // Set auth token for API client
          this.apiClient.setAuthToken(this.auth.token);
        }
      }
    } catch (error) {
      console.error('Failed to load auth from storage:', error);
      this.auth = Auth.createEmpty();
      this.clearAuthFromStorage();
    }
  }

  clearAuthFromStorage() {
    try {
      localStorage.removeItem(config.auth.tokenKey);
    } catch (error) {
      console.error('Failed to clear auth from storage:', error);
    }
  }

  // Helper methods
  setLoading(loading) {
    this.loading = loading;
    this.notify();
  }

  setError(error) {
    this.error = error;
    this.notify();
  }

  getCurrentUser() {
    return this.auth.user;
  }

  isAdmin() {
    return this.auth.isAdmin();
  }

  isAuthenticated() {
    return this.auth.isAuthenticated && !this.auth.isTokenExpired();
  }
}

export default AuthViewModel;
