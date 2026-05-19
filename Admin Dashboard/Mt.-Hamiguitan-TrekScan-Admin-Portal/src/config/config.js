// Application configuration
const apiBaseUrl = (import.meta && import.meta.env && import.meta.env.VITE_API_URL) || 'http://localhost:3000';
const environment = (import.meta && import.meta.env && import.meta.env.MODE) || 'development';

export const config = {
  // API Configuration
  api: {
    baseURL: apiBaseUrl,
    timeout: 30000, // 30 seconds
  },
  
  // App Configuration
  app: {
    name: 'Trekscan Admin',
    version: '1.0.0',
    environment,
  },
  
  // Authentication Configuration
  auth: {
    tokenKey: 'trekscan_auth',
    refreshThreshold: 5 * 60 * 1000, // 5 minutes before expiry
  },
  
  // Firebase Configuration
  firebase: {
    enabled: Boolean(import.meta.env.VITE_FIREBASE_API_KEY),
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || '',
  }
};

export default config;

