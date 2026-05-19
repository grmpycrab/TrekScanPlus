# Configuration Guide

## API Base URL Configuration

The API base URL is now centralized in the configuration file. Here's how to update it:

### 1. **Environment Variable (Recommended)**

Create a `.env` file in your project root:

```bash
# .env
REACT_APP_API_URL=https://your-api-domain.com
```

### 2. **Direct Configuration File Update**

Edit `src/config/config.js`:

```javascript
export const config = {
  api: {
    baseURL: 'https://your-api-domain.com', // Update this line
    timeout: 30000,
  },
  // ... rest of config
};
```

### 3. **Current Configuration Locations**

The API base URL is now used in these files:
- ✅ `src/config/config.js` - Main configuration
- ✅ `src/App.jsx` - Main app component
- ✅ `src/views/pages/Login.jsx` - Login page
- ✅ `src/views/pages/Dashboard.jsx` - Dashboard page

### 4. **Environment-Specific URLs**

You can set different URLs for different environments:

```bash
# .env.development
REACT_APP_API_URL=http://localhost:3000

# .env.production
REACT_APP_API_URL=https://api.trekscan.com

# .env.staging
REACT_APP_API_URL=https://staging-api.trekscan.com
```

### 5. **Benefits of This Approach**

- ✅ **Single source of truth** for API configuration
- ✅ **Environment-specific** configuration support
- ✅ **Easy to maintain** and update
- ✅ **No more hardcoded URLs** scattered throughout the code
- ✅ **Environment variable support** for deployment flexibility

### 6. **Restart Required**

After updating the configuration, restart your development server:

```bash
npm run dev
```

## Other Configuration Options

The config file also includes:
- **App settings**: Name, version, environment
- **Auth settings**: Token storage key, refresh threshold
- **API settings**: Base URL, timeout

All settings can be customized in `src/config/config.js`.

