// Auth Model - represents authentication data and business logic
class Auth {
  constructor(data = {}) {
    this.token = data.token || null;
    this.user = data.user || null;
    this.isAuthenticated = data.isAuthenticated || false;
    this.expiresAt = data.expiresAt || null;
  }

  // Validation methods
  isValid() {
    return this.token && this.user && this.isAuthenticated;
  }

  isTokenExpired() {
    if (!this.expiresAt) return false;
    return new Date() > new Date(this.expiresAt);
  }

  // Business logic methods
  isAdmin() {
    return this.user && this.user.role === 'admin';
  }

  isActive() {
    return this.user && this.user.status === 'active';
  }

  // Data transformation
  toJSON() {
    return {
      token: this.token,
      user: this.user,
      isAuthenticated: this.isAuthenticated,
      expiresAt: this.expiresAt
    };
  }

  // Static factory methods
  static fromAPI(data) {
    return new Auth(data);
  }

  static createEmpty() {
    return new Auth();
  }

  static fromLoginResponse(response) {
    return new Auth({
      token: response.token,
      user: response.user,
      isAuthenticated: true,
      expiresAt: response.expiresAt
    });
  }
}

export default Auth;
